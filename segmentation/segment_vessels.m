function [vessel_mask] = segment_vessels(std_img, retina_mask, cfg)
%SEGMENT_VESSELS Segments blood vessels using ONNX U-Net or classical fallback.
%
%   vessel_mask = SEGMENT_VESSELS(std_img, retina_mask, cfg)
%
%   Uses drive_vessel_unet.onnx via Python onnxruntime when available.
%   Falls back to classical matched-filter approach otherwise.

addpath(genpath(fileparts(fileparts(mfilename('fullpath')))));

[orig_h, orig_w, ~] = size(std_img);
use_onnx = false;

% ================================================================
% STRATEGY 1: ONNX via Python onnxruntime
% ================================================================
if nargin >= 3 && ~isempty(cfg)
    onnx_path = '';
    if isfield(cfg, 'onnx_vessel_model')
        onnx_path = cfg.onnx_vessel_model;
    else
        onnx_path = fullfile(cfg.model_dir, 'drive_vessel_unet.onnx');
    end
    
    if exist(onnx_path, 'file')
        try
            % Save image to temp file for Python
            temp_img = fullfile(tempdir, 'drrr_temp_vessel_input.png');
            imwrite(std_img, temp_img);
            
            % Run Python ONNX inference
            onnx_result = run_onnx_inference('vessel', temp_img, onnx_path);
            
            % Cleanup temp
            if exist(temp_img, 'file'), delete(temp_img); end
            
            if isfield(onnx_result, 'success') && onnx_result.success
                vessel_mask = logical(onnx_result.vessel_mask > 127);
                
                % Resize to match std_img if needed
                if size(vessel_mask,1) ~= orig_h || size(vessel_mask,2) ~= orig_w
                    vessel_mask = imresize(uint8(vessel_mask)*255, [orig_h, orig_w], 'nearest') > 127;
                end
                
                % Apply retina mask
                vessel_mask = vessel_mask & retina_mask;
                
                use_onnx = true;
                fprintf('ONNX vessel segmentation: %d vessel pixels\n', sum(vessel_mask(:)));
            else
                if isfield(onnx_result, 'error_msg')
                    warning('ONNX vessel error: %s', onnx_result.error_msg);
                end
            end
        catch ME
            warning('ONNX vessel pipeline error: %s. Falling back.', ME.message);
            temp_img = fullfile(tempdir, 'drrr_temp_vessel_input.png');
            if exist(temp_img, 'file'), delete(temp_img); end
        end
    end
end

% ================================================================
% STRATEGY 2: Classical matched-filter fallback
% ================================================================
if ~use_onnx
    fprintf('Using classical vessel segmentation fallback.\n');
    try
        green_ch = std_img(:,:,2);
        green_ch = im2double(green_ch);
        green_ch = 1 - green_ch;
        
        angles = 0:15:165;
        max_response = zeros(size(green_ch));
        L = 9;
        
        for ang = angles
            se = strel('line', L, ang);
            filt_img = imtophat(green_ch, se);
            max_response = max(max_response, filt_img);
        end
        
        retina_vals = max_response(retina_mask);
        if isempty(retina_vals)
            thresh = graythresh(max_response);
        else
            thresh = graythresh(retina_vals);
        end
        
        v_mask = max_response > thresh;
        v_mask = v_mask & retina_mask;
        v_mask = bwareaopen(v_mask, 30);
        vessel_mask = bwmorph(v_mask, 'thin', Inf);
        vessel_mask = bwmorph(vessel_mask, 'clean');
    catch ME
        warning('Vessel segmentation failed: %s', ME.message);
        vessel_mask = false(orig_h, orig_w);
    end
end

end
