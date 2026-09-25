function [tensor] = onnx_preprocess(img, target_size, cfg, apply_clahe)
%ONNX_PREPROCESS Preprocess an image for ONNX model inference.
%
%   tensor = ONNX_PREPROCESS(img, target_size, cfg, apply_clahe)
%
%   Implements the preprocessing pipeline from MODEL_INTEGRATION_GUIDE.md:
%     1. Ensure RGB uint8 input
%     2. Optional CLAHE on LAB L-channel (for vessel & lesion models)
%     3. Resize to target_size [H, W]
%     4. Convert to float32, divide by 255
%     5. ImageNet normalize: (pixel - mean) / std
%     6. Transpose to NCHW format: [1, 3, H, W]
%
%   Inputs:
%     img          - RGB image (uint8 or double)
%     target_size  - [H, W] target resolution, e.g. [256 256] or [512 512]
%     cfg          - Pipeline config struct (needs imagenet_mean, imagenet_std)
%     apply_clahe  - Boolean, true for vessel/lesion models, false for DR model
%
%   Outputs:
%     tensor       - single array of shape [1, 3, H, W] ready for ONNX inference

    if nargin < 4
        apply_clahe = false;
    end

    % Ensure uint8 RGB
    if ~isa(img, 'uint8')
        if max(img(:)) <= 1.0
            img = im2uint8(img);
        else
            img = uint8(img);
        end
    end

    % Step 1: Apply CLAHE on LAB L-channel (for Models 2 & 3 only)
    if apply_clahe
        lab = rgb2lab(img);
        L = lab(:,:,1);
        % Normalize L to [0, 1] for adapthisteq
        L_norm = L / 100;
        L_clahe = adapthisteq(L_norm, ...
            'ClipLimit', cfg.onnx_clahe_clip_limit / 100, ...
            'NumTiles', cfg.onnx_clahe_tile_size, ...
            'Distribution', 'uniform');
        lab(:,:,1) = L_clahe * 100;
        img = lab2rgb(lab);
        img = im2uint8(img);
    end

    % Step 2: Resize to target dimensions
    img = imresize(img, target_size);

    % Step 3: Convert to float32 and normalize to [0, 1]
    img_float = single(img) / 255.0;

    % Step 4: ImageNet normalization per channel
    %   (pixel - mean) / std
    mean_vals = single(cfg.imagenet_mean);  % [0.485, 0.456, 0.406]
    std_vals  = single(cfg.imagenet_std);   % [0.229, 0.224, 0.225]

    for ch = 1:3
        img_float(:,:,ch) = (img_float(:,:,ch) - mean_vals(ch)) / std_vals(ch);
    end

    % Step 5: Transpose from HWC [H, W, 3] to NCHW [1, 3, H, W]
    %   MATLAB dim order: permute (H,W,C) → (C,H,W), then add batch dim
    tensor = permute(img_float, [3, 1, 2]);   % [3, H, W]
    tensor = reshape(tensor, [1, size(tensor)]);  % [1, 3, H, W]

end
