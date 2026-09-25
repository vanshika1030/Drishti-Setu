"""
onnx_inference.py — ONNX Runtime inference bridge for MATLAB DrishtiSetu pipeline.

Called from MATLAB via system() command. Accepts an image path and model path,
runs preprocessing + inference, and writes results to a .mat file.

Usage:
  python3 onnx_inference.py <model_type> <image_path> <model_path> <output_mat_path>

Model types:
  dr       — DR severity grading (ResNet50, 256x256, no CLAHE)
  vessel   — Vessel segmentation (U-Net, 512x512, CLAHE)
  lesion   — Lesion segmentation (U-Net+ResNet34, 512x512, CLAHE)

Preprocessing follows MODEL_INTEGRATION_GUIDE.md exactly.
"""

import sys
import os
import numpy as np
import cv2
import onnxruntime as ort
import scipy.io as sio


def apply_clahe(img_rgb):
    """Apply CLAHE on L-channel of LAB colorspace."""
    lab = cv2.cvtColor(img_rgb, cv2.COLOR_RGB2LAB)
    clahe = cv2.createCLAHE(clipLimit=2.0, tileGridSize=(8, 8))
    lab[:, :, 0] = clahe.apply(lab[:, :, 0])
    return cv2.cvtColor(lab, cv2.COLOR_LAB2RGB)


def preprocess(img_rgb, target_size, use_clahe=False):
    """
    Full preprocessing pipeline per MODEL_INTEGRATION_GUIDE.md:
      1. Optional CLAHE on LAB L-channel
      2. Resize to target_size
      3. float32, /255
      4. ImageNet normalize
      5. Transpose to NCHW [1, 3, H, W]
    """
    if use_clahe:
        img_rgb = apply_clahe(img_rgb)

    img = cv2.resize(img_rgb, (target_size[1], target_size[0]))
    img = img.astype(np.float32) / 255.0
    img = (img - [0.485, 0.456, 0.406]) / [0.229, 0.224, 0.225]
    img = np.transpose(img, (2, 0, 1))[np.newaxis, ...].astype(np.float32)
    return img


def softmax(logits):
    """Numerically stable softmax."""
    e = np.exp(logits - np.max(logits, axis=1, keepdims=True))
    return e / np.sum(e, axis=1, keepdims=True)


def sigmoid(x):
    return 1.0 / (1.0 + np.exp(-x))


def run_dr(image_path, model_path, output_path):
    """DR severity grading: 256x256, no CLAHE, softmax output."""
    img = cv2.imread(image_path)
    if img is None:
        raise ValueError(f"Could not read image: {image_path}")
    img = cv2.cvtColor(img, cv2.COLOR_BGR2RGB)

    tensor = preprocess(img, (256, 256), use_clahe=False)

    session = ort.InferenceSession(model_path)
    input_name = session.get_inputs()[0].name
    logits = session.run(None, {input_name: tensor})[0]  # (1, 5)

    probs = softmax(logits)
    grade = int(np.argmax(probs))

    sio.savemat(output_path, {
        'logits': logits.flatten(),
        'probs': probs.flatten(),
        'grade': grade,
        'confidence': float(probs[0, grade]),
        'success': True
    })
    print(f"DR inference done. Grade={grade}, Confidence={probs[0, grade]:.4f}")


def run_vessel(image_path, model_path, output_path):
    """Vessel segmentation: 512x512, CLAHE, sigmoid+threshold output."""
    img = cv2.imread(image_path)
    if img is None:
        raise ValueError(f"Could not read image: {image_path}")
    img = cv2.cvtColor(img, cv2.COLOR_BGR2RGB)
    orig_h, orig_w = img.shape[:2]

    tensor = preprocess(img, (512, 512), use_clahe=True)

    session = ort.InferenceSession(model_path)
    input_name = session.get_inputs()[0].name
    logits = session.run(None, {input_name: tensor})[0]  # (1, 1, 512, 512)

    prob = sigmoid(logits)
    mask = (prob[0, 0] > 0.5).astype(np.uint8) * 255  # (512, 512)

    # Resize to original
    mask = cv2.resize(mask, (orig_w, orig_h), interpolation=cv2.INTER_NEAREST)

    sio.savemat(output_path, {
        'vessel_mask': mask,
        'vessel_pixels': int(mask.sum() / 255),
        'orig_h': orig_h,
        'orig_w': orig_w,
        'success': True
    })
    print(f"Vessel inference done. Pixels={int(mask.sum() / 255)}")


def run_lesion(image_path, model_path, output_path):
    """Lesion segmentation: 512x512, CLAHE, 5-channel sigmoid+threshold output."""
    img = cv2.imread(image_path)
    if img is None:
        raise ValueError(f"Could not read image: {image_path}")
    img = cv2.cvtColor(img, cv2.COLOR_BGR2RGB)
    orig_h, orig_w = img.shape[:2]

    tensor = preprocess(img, (512, 512), use_clahe=True)

    session = ort.InferenceSession(model_path)
    input_name = session.get_inputs()[0].name
    logits = session.run(None, {input_name: tensor})[0]  # (1, 5, 512, 512)

    probs = sigmoid(logits)

    channel_names = ['MA', 'HE', 'EX', 'SE', 'OD']
    results = {'orig_h': orig_h, 'orig_w': orig_w, 'success': True}

    for i, name in enumerate(channel_names):
        mask = (probs[0, i] > 0.5).astype(np.uint8) * 255
        mask = cv2.resize(mask, (orig_w, orig_h), interpolation=cv2.INTER_NEAREST)
        results[f'mask_{name}'] = mask
        results[f'count_{name}'] = int(mask.sum() / 255)
        print(f"  {name}: {results[f'count_{name}']} pixels")

    sio.savemat(output_path, results)
    print("Lesion inference done.")


if __name__ == '__main__':
    if len(sys.argv) != 5:
        print(f"Usage: {sys.argv[0]} <model_type> <image_path> <model_path> <output_mat_path>")
        sys.exit(1)

    model_type = sys.argv[1]
    image_path = sys.argv[2]
    model_path = sys.argv[3]
    output_path = sys.argv[4]

    try:
        if model_type == 'dr':
            run_dr(image_path, model_path, output_path)
        elif model_type == 'vessel':
            run_vessel(image_path, model_path, output_path)
        elif model_type == 'lesion':
            run_lesion(image_path, model_path, output_path)
        else:
            print(f"Unknown model type: {model_type}")
            sys.exit(1)
    except Exception as e:
        # Write error to output so MATLAB can detect it
        sio.savemat(output_path, {'success': False, 'error_msg': str(e)})
        print(f"ERROR: {e}")
        sys.exit(1)
