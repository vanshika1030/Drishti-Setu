% This folder holds trained model weights.
% Place the following files here after training:
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
% Until models are trained, the pipeline uses classical CV fallbacks.
