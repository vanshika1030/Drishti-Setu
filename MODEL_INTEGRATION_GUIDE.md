# DR Screening Pipeline — Model Integration Guide

> **For**: Backend/Frontend team  
> **Date**: September 10, 2026  
> **From**: ML Team

---

## 3 Models — Quick Reference

| # | Model | Architecture | Input | Output | ONNX File |
|---|-------|-------------|-------|--------|-----------|
| 1 | DR Severity Grading | ResNet50 | `(1,3,256,256)` | 5-class probabilities | `dr_severity_resnet50_fixed.onnx` |
| 2 | Vessel Segmentation | Custom U-Net | `(1,3,512,512)` | Binary vessel mask | `drive_vessel_unet.onnx` |
| 3 | Lesion Segmentation | U-Net + ResNet34 | `(1,3,512,512)` | 5-channel lesion masks | `segmentation_model.onnx` |

---

## Files to Share

```
dr_severity_resnet50_fixed.onnx   (89 MB)   — DR grading, single file, no dependencies
drive_vessel_unet.onnx            (80 KB)   — Vessel segmentation
segmentation_model.onnx           (97 MB)   — Lesion segmentation (copy from segmentation_results/)
MODEL_INTEGRATION_GUIDE.md                  — This file
```

Optional (only if using PyTorch instead of ONNX):
```
best_sih_resnet50.pth             (94 MB)
best_vessel_unet.pth              (124 MB)
best_segmentation_model.pth       (293 MB)
```

> Use ONNX files for deployment. They are faster, smaller, and don't need PyTorch installed.  
> Only dependency: `pip install onnxruntime opencv-python numpy`

---

## End-to-End Pipeline Flow

The pipeline is **sequential** — Model 1 runs first. If no DR is detected, we skip the other models to save time.

```
USER UPLOADS FUNDUS IMAGE
         |
         v
STEP 1: IMAGE QUALITY CHECK
         - Is image too dark / blurry / wrong type?
         - YES → Return error, ask to recapture
         - NO  → Continue
         |
         v
STEP 2: RUN MODEL 1 — DR SEVERITY GRADING
         - Resize to 256x256
         - ImageNet normalize
         - Get grade (0-4) + confidence
         |
         v
STEP 3: CHECK RESULT
         |
    +----+----+
    |         |
    v         v
 Grade = 0   Grade >= 1
 (No DR)     (DR Detected)
    |              |
    v              v
 STOP HERE    STEP 4: RUN MODEL 2 + MODEL 3 (parallel)
 Return:           |
 "No DR found,     +--------+-----------+
  eyes healthy"    |                    |
                   v                    v
              MODEL 2:             MODEL 3:
              Vessel Seg           Lesion Seg
              (512x512)            (512x512)
              CLAHE + norm         CLAHE + norm
                   |                    |
                   v                    v
              Vessel mask          5 lesion masks
              (binary)             MA, HE, EX, SE, OD
                   |                    |
                   +--------+-----------+
                            |
                            v
                   STEP 5: GENERATE REPORT
                   - DR grade + confidence
                   - Color-coded lesion overlay
                   - Vessel map
                   - Lesion counts
                   - Referral recommendation
                            |
                            v
                   STEP 6: RETURN RESULTS TO FRONTEND
```

### Why Sequential?
- **No DR (Grade 0)**: ~40-60% of screening patients are healthy. Skipping 2 models saves ~3 seconds per patient.
- **DR Detected (Grade 1-4)**: Run vessel + lesion models to show the doctor exactly WHERE the problems are.

---

## Critical Preprocessing Rules

| Rule | Details |
|------|---------|
| Image format | Always **RGB** (not BGR). Use `cv2.cvtColor(img, cv2.COLOR_BGR2RGB)` |
| ImageNet normalization | `mean=[0.485, 0.456, 0.406]`, `std=[0.229, 0.224, 0.225]` — ALL 3 models use this |
| CLAHE | Apply on L-channel of LAB colorspace — only for Model 2 and Model 3 |
| Tensor shape | `(Batch, Channels, Height, Width)` — NOT `(H, W, C)` |

---

## Model 1: DR Severity Grading (ResNet50)

### What it does
Classifies how severe the Diabetic Retinopathy is.

| Class | Label | Meaning | Action |
|-------|-------|---------|--------|
| 0 | No DR | Healthy retina | No referral needed |
| 1 | Mild NPDR | Few microaneurysms | Rescreen in 12 months |
| 2 | Moderate NPDR | Multiple lesions | Refer within 4 weeks |
| 3 | Severe NPDR | Extensive damage | Urgent referral |
| 4 | Proliferative DR | New abnormal vessels | Emergency referral |

**Referable DR** = Grade 2, 3, or 4 (needs ophthalmologist)

### ONNX Spec

| | Name | Shape | Type | Notes |
|---|------|-------|------|-------|
| Input | `input` | `[1, 3, 256, 256]` | float32 | RGB, ImageNet normalized |
| Output | `output` | `[1, 5]` | float32 | Raw logits → apply softmax to get probabilities |

### Preprocessing + Inference Code

```python
import cv2
import numpy as np
import onnxruntime as ort

def predict_dr_severity(image_path, session):
    """
    Predict DR severity grade (0-4).
    
    Returns: (grade, label, confidence, probabilities, is_referable)
    """
    CLASS_NAMES = ['No DR', 'Mild NPDR', 'Moderate NPDR', 'Severe NPDR', 'Proliferative DR']
    
    # Load and preprocess
    img = cv2.imread(image_path)
    img = cv2.cvtColor(img, cv2.COLOR_BGR2RGB)
    img = cv2.resize(img, (256, 256))
    img = img.astype(np.float32) / 255.0
    img = (img - [0.485, 0.456, 0.406]) / [0.229, 0.224, 0.225]
    img = np.transpose(img, (2, 0, 1))[np.newaxis, ...].astype(np.float32)
    
    # Inference
    logits = session.run(None, {'input': img})[0]  # (1, 5)
    probs = np.exp(logits) / np.sum(np.exp(logits), axis=1, keepdims=True)
    grade = int(np.argmax(probs))
    
    return {
        'grade': grade,
        'label': CLASS_NAMES[grade],
        'confidence': float(probs[0, grade]),
        'probabilities': {CLASS_NAMES[i]: float(probs[0, i]) for i in range(5)},
        'is_referable': grade >= 2,
    }
```

---

## Model 2: Vessel Segmentation (U-Net on DRIVE)

### What it does
Segments retinal blood vessels. White pixels = vessels, black = background.
Helps detect neovascularization (abnormal new vessels in Proliferative DR).

### ONNX Spec

| | Name | Shape | Type | Notes |
|---|------|-------|------|-------|
| Input | `input_image` | `[1, 3, 512, 512]` | float32 | RGB, CLAHE + ImageNet normalized |
| Output | `vessel_mask` | `[1, 1, 512, 512]` | float32 | Raw logits → sigmoid → threshold at 0.5 |

### Preprocessing + Inference Code

```python
def predict_vessels(image_path, session):
    """
    Segment retinal blood vessels.
    
    Returns: vessel_mask (H x W, uint8, 0 or 255)
    """
    img = cv2.imread(image_path)
    img = cv2.cvtColor(img, cv2.COLOR_BGR2RGB)
    orig_h, orig_w = img.shape[:2]
    
    # CLAHE on L-channel
    lab = cv2.cvtColor(img, cv2.COLOR_RGB2LAB)
    clahe = cv2.createCLAHE(clipLimit=2.0, tileGridSize=(8, 8))
    lab[:, :, 0] = clahe.apply(lab[:, :, 0])
    img = cv2.cvtColor(lab, cv2.COLOR_LAB2RGB)
    
    # Resize + normalize
    img = cv2.resize(img, (512, 512))
    img = img.astype(np.float32) / 255.0
    img = (img - [0.485, 0.456, 0.406]) / [0.229, 0.224, 0.225]
    img = np.transpose(img, (2, 0, 1))[np.newaxis, ...].astype(np.float32)
    
    # Inference
    logits = session.run(None, {'input_image': img})[0]  # (1, 1, 512, 512)
    prob = 1 / (1 + np.exp(-logits))
    mask = (prob[0, 0] > 0.5).astype(np.uint8) * 255     # (512, 512)
    
    # Resize to original dimensions
    mask = cv2.resize(mask, (orig_w, orig_h))
    return mask
```

### Model Architecture (needed only if loading .pth file)

```python
import torch
import torch.nn as nn

class DoubleConv(nn.Module):
    def __init__(self, in_channels, out_channels):
        super().__init__()
        self.conv = nn.Sequential(
            nn.Conv2d(in_channels, out_channels, 3, padding=1),
            nn.BatchNorm2d(out_channels),
            nn.ReLU(inplace=True),
            nn.Conv2d(out_channels, out_channels, 3, padding=1),
            nn.BatchNorm2d(out_channels),
            nn.ReLU(inplace=True),
        )
    def forward(self, x):
        return self.conv(x)

class UNet(nn.Module):
    def __init__(self, in_channels=3, out_channels=1, features=[64, 128, 256, 512]):
        super().__init__()
        self.downs = nn.ModuleList()
        self.ups = nn.ModuleList()
        self.pool = nn.MaxPool2d(2, 2)
        for f in features:
            self.downs.append(DoubleConv(in_channels, f))
            in_channels = f
        self.bottleneck = DoubleConv(features[-1], features[-1] * 2)
        for f in reversed(features):
            self.ups.append(nn.ConvTranspose2d(f * 2, f, 2, stride=2))
            self.ups.append(DoubleConv(f * 2, f))
        self.final_conv = nn.Conv2d(features[0], out_channels, 1)

    def forward(self, x):
        skip_connections = []
        for down in self.downs:
            x = down(x)
            skip_connections.append(x)
            x = self.pool(x)
        x = self.bottleneck(x)
        skip_connections = skip_connections[::-1]
        for i in range(0, len(self.ups), 2):
            x = self.ups[i](x)
            skip = skip_connections[i // 2]
            if x.shape != skip.shape:
                x = torch.nn.functional.interpolate(x, size=skip.shape[2:])
            x = torch.cat((skip, x), dim=1)
            x = self.ups[i + 1](x)
        return self.final_conv(x)

# Load: model = UNet(3, 1); model.load_state_dict(torch.load('best_vessel_unet.pth', map_location='cpu'))
```

---

## Model 3: Lesion Segmentation (U-Net + ResNet34 on IDRiD)

### What it does
Detects 5 types of retinal lesions. Each output channel is a separate binary mask.

| Channel | Lesion | What it means |
|---------|--------|--------------|
| 0 | **MA** (Microaneurysms) | Earliest DR sign — tiny red dots |
| 1 | **HE** (Haemorrhages) | Blood leaking from damaged vessels |
| 2 | **EX** (Hard Exudates) | Yellow fat deposits — macular edema risk |
| 3 | **SE** (Soft Exudates) | Cotton-wool spots — nerve fiber damage |
| 4 | **OD** (Optic Disc) | Normal landmark (for reference) |

### ONNX Spec

| | Name | Shape | Type | Notes |
|---|------|-------|------|-------|
| Input | `input` | `[1, 3, 512, 512]` | float32 | RGB, CLAHE + ImageNet normalized |
| Output | `output` | `[1, 5, 512, 512]` | float32 | Raw logits → sigmoid → threshold at 0.5, per channel |

### Preprocessing + Inference Code

```python
def predict_lesions(image_path, session):
    """
    Segment 5 lesion types: MA, HE, EX, SE, OD.
    
    Returns: dict of {lesion_name: mask} and pixel counts
    """
    LESION_NAMES = ['MA', 'HE', 'EX', 'SE', 'OD']
    
    img = cv2.imread(image_path)
    img = cv2.cvtColor(img, cv2.COLOR_BGR2RGB)
    orig_h, orig_w = img.shape[:2]
    
    # CLAHE on L-channel
    lab = cv2.cvtColor(img, cv2.COLOR_RGB2LAB)
    clahe = cv2.createCLAHE(clipLimit=2.0, tileGridSize=(8, 8))
    lab[:, :, 0] = clahe.apply(lab[:, :, 0])
    img = cv2.cvtColor(lab, cv2.COLOR_LAB2RGB)
    
    # Resize + normalize
    img = cv2.resize(img, (512, 512))
    img = img.astype(np.float32) / 255.0
    img = (img - [0.485, 0.456, 0.406]) / [0.229, 0.224, 0.225]
    img = np.transpose(img, (2, 0, 1))[np.newaxis, ...].astype(np.float32)
    
    # Inference
    logits = session.run(None, {'input': img})[0]  # (1, 5, 512, 512)
    probs = 1 / (1 + np.exp(-logits))
    
    masks = {}
    counts = {}
    for i, name in enumerate(LESION_NAMES):
        mask = (probs[0, i] > 0.5).astype(np.uint8) * 255
        mask = cv2.resize(mask, (orig_w, orig_h))
        masks[name] = mask
        counts[name] = int(mask.sum() / 255)
    
    return {'masks': masks, 'pixel_counts': counts}

# For PyTorch loading:
# import segmentation_models_pytorch as smp
# model = smp.Unet(encoder_name='resnet34', encoder_weights=None, in_channels=3, classes=5, activation=None)
# ckpt = torch.load('best_segmentation_model.pth', map_location='cpu', weights_only=False)
# model.load_state_dict(ckpt['model_state_dict'])
```

---

## Complete Pipeline Class (Copy-Paste Ready)

```python
import cv2
import numpy as np
import onnxruntime as ort
import time

class DRScreeningPipeline:
    """
    Complete DR Screening Pipeline.
    
    Sequential: Runs DR severity first.
    If No DR → stops early, saves time.
    If DR detected → runs vessel + lesion segmentation.
    """
    
    DR_CLASSES = ['No DR', 'Mild NPDR', 'Moderate NPDR', 'Severe NPDR', 'Proliferative DR']
    LESION_NAMES = ['MA', 'HE', 'EX', 'SE', 'OD']
    LESION_COLORS = {
        'MA': (255, 0, 0),       # Red
        'HE': (255, 165, 0),     # Orange
        'EX': (255, 255, 0),     # Yellow
        'SE': (0, 255, 255),     # Cyan
        'OD': (0, 255, 0),       # Green
    }
    
    def __init__(self, dr_model, vessel_model, lesion_model):
        self.dr = ort.InferenceSession(dr_model)
        self.vessel = ort.InferenceSession(vessel_model)
        self.lesion = ort.InferenceSession(lesion_model)
    
    def _clahe(self, img):
        lab = cv2.cvtColor(img, cv2.COLOR_RGB2LAB)
        clahe = cv2.createCLAHE(clipLimit=2.0, tileGridSize=(8, 8))
        lab[:, :, 0] = clahe.apply(lab[:, :, 0])
        return cv2.cvtColor(lab, cv2.COLOR_LAB2RGB)
    
    def _prep(self, img, size):
        img = cv2.resize(img, (size, size))
        img = img.astype(np.float32) / 255.0
        img = (img - [0.485, 0.456, 0.406]) / [0.229, 0.224, 0.225]
        return np.transpose(img, (2, 0, 1))[np.newaxis, ...].astype(np.float32)
    
    def predict(self, image_path):
        start = time.time()
        
        # Load image
        raw = cv2.imread(image_path)
        if raw is None:
            return {'status': 'error', 'message': 'Could not read image file'}
        img = cv2.cvtColor(raw, cv2.COLOR_BGR2RGB)
        h, w = img.shape[:2]
        
        # ============ STEP 1: DR SEVERITY (always runs) ============
        dr_input = self._prep(img.copy(), 256)
        dr_logits = self.dr.run(None, {'input': dr_input})[0]
        dr_probs = np.exp(dr_logits) / np.sum(np.exp(dr_logits), axis=1, keepdims=True)
        grade = int(np.argmax(dr_probs))
        
        result = {
            'status': 'success',
            'dr_grade': grade,
            'dr_label': self.DR_CLASSES[grade],
            'dr_confidence': round(float(dr_probs[0, grade]), 4),
            'dr_probabilities': {self.DR_CLASSES[i]: round(float(dr_probs[0, i]), 4) for i in range(5)},
            'is_referable': grade >= 2,
        }
        
        # ============ STEP 2: If No DR → Stop early ============
        if grade == 0:
            result['vessel_mask'] = None
            result['lesion_masks'] = None
            result['lesion_pixel_counts'] = None
            result['recommendation'] = 'No Diabetic Retinopathy detected. Rescreen in 12 months.'
            result['processing_time'] = round(time.time() - start, 2)
            return result
        
        # ============ STEP 3: DR detected → Run vessel + lesion models ============
        img_clahe = self._clahe(img.copy())
        
        # Vessel segmentation
        v_input = self._prep(img_clahe, 512)
        v_logits = self.vessel.run(None, {'input_image': v_input})[0]
        v_prob = 1 / (1 + np.exp(-v_logits))
        vessel_mask = (v_prob[0, 0] > 0.5).astype(np.uint8) * 255
        vessel_mask = cv2.resize(vessel_mask, (w, h))
        result['vessel_mask'] = vessel_mask
        
        # Lesion segmentation
        l_input = self._prep(img_clahe, 512)
        l_logits = self.lesion.run(None, {'input': l_input})[0]
        l_probs = 1 / (1 + np.exp(-l_logits))
        
        lesion_masks = {}
        lesion_counts = {}
        for i, name in enumerate(self.LESION_NAMES):
            mask = (l_probs[0, i] > 0.5).astype(np.uint8) * 255
            mask = cv2.resize(mask, (w, h))
            lesion_masks[name] = mask
            lesion_counts[name] = int(mask.sum() / 255)
        
        result['lesion_masks'] = lesion_masks
        result['lesion_pixel_counts'] = lesion_counts
        
        # Recommendation based on grade
        recommendations = {
            1: 'Mild DR detected. Rescreen in 6-12 months.',
            2: 'Moderate DR detected. Refer to ophthalmologist within 4 weeks.',
            3: 'Severe DR detected. Urgent referral to ophthalmologist within 1 week.',
            4: 'Proliferative DR detected. EMERGENCY — immediate referral required.',
        }
        result['recommendation'] = recommendations[grade]
        result['processing_time'] = round(time.time() - start, 2)
        
        return result
    
    def create_overlay(self, image_path, result):
        """Create color-coded lesion overlay on original image."""
        if result['dr_grade'] == 0:
            # No DR — just return original with "Healthy" stamp
            img = cv2.imread(image_path)
            cv2.putText(img, 'No DR Detected - Healthy', (20, 40),
                        cv2.FONT_HERSHEY_SIMPLEX, 1.0, (0, 255, 0), 2)
            return img
        
        img = cv2.imread(image_path)
        overlay = img.copy()
        
        for name, color in self.LESION_COLORS.items():
            mask = result['lesion_masks'][name]
            if mask.sum() > 0:
                bgr_color = color[::-1]  # RGB to BGR for OpenCV
                colored = np.zeros_like(img)
                colored[mask > 0] = bgr_color
                overlay = cv2.addWeighted(overlay, 1.0, colored, 0.5, 0)
        
        # Add text
        label = f"DR: {result['dr_label']} ({result['dr_confidence']:.0%})"
        cv2.putText(overlay, label, (20, 40), cv2.FONT_HERSHEY_SIMPLEX, 1.0, (255, 255, 255), 2)
        
        if result['is_referable']:
            cv2.putText(overlay, 'REFERABLE - Needs Ophthalmologist', (20, 80),
                        cv2.FONT_HERSHEY_SIMPLEX, 0.8, (0, 0, 255), 2)
        
        return overlay


# ==================== USAGE ====================
pipeline = DRScreeningPipeline(
    dr_model='dr_severity_resnet50_fixed.onnx',
    vessel_model='drive_vessel_unet.onnx',
    lesion_model='segmentation_model.onnx',
)

result = pipeline.predict('patient_fundus.jpg')

print(f"DR Grade: {result['dr_label']} ({result['dr_confidence']:.2%})")
print(f"Referable: {'YES' if result['is_referable'] else 'No'}")
print(f"Recommendation: {result['recommendation']}")
print(f"Time: {result['processing_time']}s")

if result['dr_grade'] > 0:
    print(f"Lesions: {result['lesion_pixel_counts']}")
    overlay = pipeline.create_overlay('patient_fundus.jpg', result)
    cv2.imwrite('result_overlay.jpg', overlay)
```

---

## Sample JSON Response for Frontend

### Case 1: No DR (Grade 0) — Fast response, only Model 1 ran

```json
{
    "status": "success",
    "dr_grade": 0,
    "dr_label": "No DR",
    "dr_confidence": 0.94,
    "is_referable": false,
    "vessel_mask": null,
    "lesion_masks": null,
    "recommendation": "No Diabetic Retinopathy detected. Rescreen in 12 months.",
    "processing_time": 0.8
}
```

### Case 2: DR Detected (Grade 2) — All 3 models ran

```json
{
    "status": "success",
    "dr_grade": 2,
    "dr_label": "Moderate NPDR",
    "dr_confidence": 0.83,
    "is_referable": true,
    "dr_probabilities": {
        "No DR": 0.05,
        "Mild NPDR": 0.07,
        "Moderate NPDR": 0.83,
        "Severe NPDR": 0.04,
        "Proliferative DR": 0.01
    },
    "lesion_pixel_counts": {
        "MA": 120,
        "HE": 450,
        "EX": 800,
        "SE": 0,
        "OD": 5200
    },
    "recommendation": "Moderate DR detected. Refer to ophthalmologist within 4 weeks.",
    "processing_time": 3.2
}
```

---

## Lesion Color Legend (for Frontend UI)

| Lesion | Overlay Color | Meaning |
|--------|--------------|---------|
| MA (Microaneurysms) | Red | Tiny bulges in blood vessels — earliest warning |
| HE (Haemorrhages) | Orange | Blood leaking from damaged vessels |
| EX (Hard Exudates) | Yellow | Fat deposits — vision loss risk if near center |
| SE (Soft Exudates) | Cyan | Nerve fiber damage spots |
| OD (Optic Disc) | Green | Normal landmark (reference point) |
| Vessels | Light Blue | Blood vessel network |

---

## Dependencies

```bash
pip install onnxruntime opencv-python numpy
```

For GPU inference (faster):
```bash
pip install onnxruntime-gpu
```

---

## Common Pitfalls

| Problem | Cause | Fix |
|---------|-------|-----|
| All black predictions | Forgot normalization | Apply ImageNet mean/std after dividing by 255 |
| Wrong class | BGR instead of RGB | Always `cv2.cvtColor(img, cv2.COLOR_BGR2RGB)` |
| Shape error | Wrong input size | DR = 256x256, Vessel/Lesion = 512x512 |
| Garbage masks | No CLAHE for vessel/lesion | Apply CLAHE on LAB L-channel before normalizing |
| Model won't load | Wrong ONNX file | Use `dr_severity_resnet50_fixed.onnx` (NOT the old one) |
