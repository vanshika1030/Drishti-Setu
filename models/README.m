% MODELS DIRECTORY
% ================
%
% This folder holds trained model weights for the DrishtiSetu DR screening pipeline.
%
% === ONNX Models (Primary - used for inference) ===
%
%   dr_severity_resnet50_fixed.onnx  (89 MB)  — DR severity grading (ResNet50)
%       Input:  'input'       [1, 3, 256, 256]  float32, RGB, ImageNet normalized
%       Output: 'output'      [1, 5]            float32, raw logits → softmax
%       Classes: 0=No DR, 1=Mild NPDR, 2=Moderate NPDR, 3=Severe NPDR, 4=PDR
%
%   drive_vessel_unet.onnx           (80 KB)  — Vessel segmentation (U-Net, DRIVE dataset)
%       Input:  'input_image' [1, 3, 512, 512]  float32, RGB, CLAHE + ImageNet normalized
%       Output: 'vessel_mask' [1, 1, 512, 512]  float32, raw logits → sigmoid → threshold 0.5
%
%   segmentation_model.onnx          (93 MB)  — Lesion segmentation (U-Net+ResNet34, IDRiD)
%       Input:  'input'       [1, 3, 512, 512]  float32, RGB, CLAHE + ImageNet normalized
%       Output: 'output'      [1, 5, 512, 512]  float32, raw logits → sigmoid → threshold 0.5
%       Channels: 0=MA, 1=HE, 2=EX, 3=SE, 4=OD
%
%   onnx_preprocess.m  — Shared ONNX preprocessing function
%       Handles: RGB, optional CLAHE on LAB, resize, ImageNet normalize, NCHW transpose
%
% === Legacy .mat Models (Optional) ===
%
%   resnet50_dr_grader.mat      - Trained ResNet-50 (DR grading)
%   resnet50_cal_logits.mat     - Calibration set logits
%   resnet50_test_logits.mat    - Test set logits
%   efficientnet_dr_grader.mat  - Trained EfficientNet-B0 (DR grading)
%   efficientnet_cal_logits.mat - Calibration set logits
%   efficientnet_test_logits.mat- Test set logits
%   unet_lesion_segmenter.mat   - Trained U-Net (4 sigmoid heads)
%   T_values.mat                - Calibrated temperatures [T1, T2]
%   pref_band.mat               - Calibrated pRef thresholds
%   validation_results.mat      - Full validation metrics
%   split_indices.mat           - Train/cal/test split indices
%
% === Model Loading Priority ===
%   1. ONNX models (via importONNXNetwork / importNetworkFromONNX)
%   2. Legacy .mat models
%   3. Classical CV fallbacks (no models needed)
%
% See MODEL_INTEGRATION_GUIDE.md in the project root for full preprocessing details.
