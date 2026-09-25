function [lesion_masks, lesion_counts, onnx_od_mask] = tile_and_segment(std_img, retina_mask, od_mask, od_center, od_radius, fovea_center, vessel_mask, cfg)
%TILE_AND_SEGMENT Segments lesions using ONNX model or classical fallback.
%
%   [lesion_masks, lesion_counts, onnx_od_mask] = TILE_AND_SEGMENT(...)
%
%   Uses segmentation_model.onnx via Python onnxruntime when available.
%   Outputs 5 channels: MA, HE, EX, SE, OD.
%   Falls back to classical CV methods if unavailable.

addpath(genpath(fileparts(fileparts(mfilename('fullpath')))));

[orig_h, orig_w, ~] = size(std_img);

lesion_masks = struct('ma', false(size(retina_mask)), ...
                      'hemorrhages', false(size(retina_mask)), ...
                      'hard_exudates', false(size(retina_mask)), ...
                      'soft_exudates', false(size(retina_mask)));
lesion_counts = struct('ma_count', 0, 'hem_count', 0, 'he_count', 0, 'se_count', 0, 'total', 0);
onnx_od_mask = [];

use_onnx = false;

% ================================================================
% STRATEGY 1: ONNX via Python onnxruntime
% ================================================================
onnx_path = '';
if isfield(cfg, 'onnx_lesion_model')
    onnx_path = cfg.onnx_lesion_model;
else
    onnx_path = fullfile(cfg.model_dir, 'segmentation_model.onnx');
end

if exist(onnx_path, 'file')
    try
        % Save image to temp file for Python
        temp_img = fullfile(tempdir, 'drrr_temp_lesion_input.png');
        imwrite(std_img, temp_img);
        
        % Run Python ONNX inference
        onnx_result = run_onnx_inference('lesion', temp_img, onnx_path);
        
        % Cleanup temp
        if exist(temp_img, 'file'), delete(temp_img); end
        
        if isfield(onnx_result, 'success') && onnx_result.success
            % Extract 5 channel masks
            % Channel mapping: MA, HE (hemorrhages), EX (hard_exudates), SE (soft_exudates), OD
            field_map = struct('MA', 'ma', 'HE', 'hemorrhages', 'EX', 'hard_exudates', 'SE', 'soft_exudates');
            
            channels = {'MA', 'HE', 'EX', 'SE', 'OD'};
            for i = 1:length(channels)
                ch_name = channels{i};
                mask_field = sprintf('mask_%s', ch_name);
                
                if isfield(onnx_result, mask_field)
                    mask = logical(onnx_result.(mask_field) > 127);
                    
                    % Resize if needed
                    if size(mask,1) ~= orig_h || size(mask,2) ~= orig_w
                        mask = imresize(uint8(mask)*255, [orig_h, orig_w], 'nearest') > 127;
                    end
                    
                    % Apply retina mask
                    mask = mask & retina_mask;
                    
                    if strcmp(ch_name, 'OD')
                        onnx_od_mask = mask;
                    elseif isfield(field_map, ch_name)
                        lesion_masks.(field_map.(ch_name)) = mask;
                    end
                    
                    count_field = sprintf('count_%s', ch_name);
                    if isfield(onnx_result, count_field)
                        fprintf('  %s: %d pixels\n', ch_name, onnx_result.(count_field));
                    end
                end
            end
            
            use_onnx = true;
            fprintf('ONNX lesion segmentation complete.\n');
        else
            if isfield(onnx_result, 'error_msg')
                warning('ONNX lesion error: %s', onnx_result.error_msg);
            end
        end
    catch ME
        warning('ONNX lesion pipeline error: %s. Falling back.', ME.message);
        temp_img = fullfile(tempdir, 'drrr_temp_lesion_input.png');
        if exist(temp_img, 'file'), delete(temp_img); end
    end
end

% ================================================================
% STRATEGY 2: Classical CV fallback
% ================================================================
if ~use_onnx
    model_path = fullfile(cfg.model_dir, 'unet_lesion_segmenter.mat');
    
    if exist(model_path, 'file')
        fprintf('U-Net .mat model found.\n');
        try
            load(model_path, 'net');
            warning('Legacy .mat inference not implemented. Falling back to classical.');
        catch
        end
    else
        fprintf('No ONNX or .mat model. Using classical fallback.\n');
    end
    
    lesion_masks.ma = detect_microaneurysms(std_img, vessel_mask, retina_mask);
    lesion_masks.hemorrhages = classify_hemorrhages(std_img, vessel_mask, od_mask, retina_mask);
    lesion_masks.hard_exudates = segment_hard_exudates(std_img, od_mask, retina_mask);
    lesion_masks.soft_exudates = segment_soft_exudates(std_img, od_mask, retina_mask);
end

% ================================================================
% Compute lesion counts
% ================================================================
[~, num_ma] = bwlabel(lesion_masks.ma);
[~, num_hem] = bwlabel(lesion_masks.hemorrhages);
[~, num_he] = bwlabel(lesion_masks.hard_exudates);
[~, num_se] = bwlabel(lesion_masks.soft_exudates);

lesion_counts.ma_count = num_ma;
lesion_counts.hem_count = num_hem;
lesion_counts.he_count = num_he;
lesion_counts.se_count = num_se;
lesion_counts.total = num_ma + num_hem + num_he + num_se;

end
