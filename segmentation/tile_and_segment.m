function [lesion_masks, lesion_counts] = tile_and_segment(std_img, retina_mask, od_mask, od_center, od_radius, fovea_center, vessel_mask, cfg)
%TILE_AND_SEGMENT Segments lesions using U-Net if available, else fallback.
%   [lesion_masks, lesion_counts] = TILE_AND_SEGMENT(...)

addpath(genpath(fileparts(fileparts(mfilename('fullpath')))));

lesion_masks = struct('ma', false(size(retina_mask)), ...
                      'hemorrhages', false(size(retina_mask)), ...
                      'hard_exudates', false(size(retina_mask)), ...
                      'soft_exudates', false(size(retina_mask)));
lesion_counts = struct('ma_count', 0, 'hem_count', 0, 'he_count', 0, 'se_count', 0, 'total', 0);

model_path = fullfile(cfg.model_dir, 'unet_lesion_segmenter.mat');

if exist(model_path, 'file')
    fprintf('U-Net model found. Using deep learning for segmentation.\n');
    try
        load(model_path, 'net');
        warning('Deep learning inference not fully implemented in this stub. Falling back to classical.');
        use_classical = true;
    catch
        use_classical = true;
    end
else
    fprintf('U-Net model not found at %s. Using classical fallback for ALL.\n', model_path);
    use_classical = true;
end

if use_classical
    lesion_masks.ma = detect_microaneurysms(std_img, vessel_mask, retina_mask);
    lesion_masks.hemorrhages = classify_hemorrhages(std_img, vessel_mask, od_mask, retina_mask);
    lesion_masks.hard_exudates = segment_hard_exudates(std_img, od_mask, retina_mask);
    lesion_masks.soft_exudates = segment_soft_exudates(std_img, od_mask, retina_mask);
end

% Compute counts
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
