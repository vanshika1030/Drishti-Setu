function [all_masks, lesion_counts, seg_info] = segment_all(std_img, retina_mask, cfg)
%SEGMENT_ALL Master orchestrator for all segmentation tasks.
%
%   [all_masks, lesion_counts, seg_info] = SEGMENT_ALL(std_img, retina_mask, cfg)
%
%   Orchestrates:
%     1. Optic Disc detection (classical)
%     2. Fovea estimation
%     3. Vessel segmentation (ONNX or classical)
%     4. Neovascularization detection
%     5. Lesion segmentation (ONNX or classical)
%     6. Overlay generation
%
%   When ONNX lesion model provides an OD mask (channel 4), it is used to
%   enhance/replace the classical OD detection for better accuracy.

addpath(genpath(fileparts(fileparts(mfilename('fullpath')))));

% 1. Optic Disc (classical initial detection)
[od_mask, od_center, od_radius] = locate_optic_disc(std_img, retina_mask);

% 2. Fovea
fovea_center = estimate_fovea(std_img, od_center, od_radius, retina_mask);

% 3. Vessels (now accepts cfg for ONNX model support)
vessel_mask = segment_vessels(std_img, retina_mask, cfg);

% 4. Neovascularization
[nv_mask, nv_suspected] = detect_neovascularization(std_img, vessel_mask, od_mask, retina_mask);

% 5. Lesions (ONNX model returns 5 channels including OD)
[lesion_masks, lesion_counts, onnx_od_mask] = tile_and_segment(std_img, retina_mask, od_mask, od_center, od_radius, fovea_center, vessel_mask, cfg);

% 5b. If ONNX model provided an OD mask, use it (better than classical)
if ~isempty(onnx_od_mask) && any(onnx_od_mask(:))
    fprintf('Using ONNX-derived optic disc mask (replacing classical detection).\n');
    od_mask = onnx_od_mask;
    
    % Recompute OD center and radius from the ONNX mask
    od_stats = regionprops(od_mask, 'Centroid', 'EquivDiameter');
    if ~isempty(od_stats)
        od_center = od_stats(1).Centroid;
        od_radius = od_stats(1).EquivDiameter / 2;
        
        % Re-estimate fovea with better OD position
        fovea_center = estimate_fovea(std_img, od_center, od_radius, retina_mask);
    end
end

% 6. Overlay
overlay_img = create_lesion_overlay(std_img, lesion_masks, od_mask, vessel_mask, fovea_center);

% Compile outputs
all_masks = struct();
all_masks.od = od_mask;
all_masks.fovea_center = fovea_center;
all_masks.vessels = vessel_mask;
all_masks.nv = nv_mask;
all_masks.ma = lesion_masks.ma;
all_masks.hemorrhages = lesion_masks.hemorrhages;
all_masks.hard_exudates = lesion_masks.hard_exudates;
all_masks.soft_exudates = lesion_masks.soft_exudates;

seg_info = struct();
seg_info.od_center = od_center;
seg_info.od_radius = od_radius;
seg_info.fovea_center = fovea_center;
seg_info.nv_suspected = nv_suspected;
seg_info.overlay_img = overlay_img;

% Determine method used based on actual inference success
if ~isempty(onnx_od_mask)
    seg_info.method_used = 'ONNX';
elseif exist(fullfile(cfg.model_dir, 'unet_lesion_segmenter.mat'), 'file')
    seg_info.method_used = 'U-Net';
else
    seg_info.method_used = 'Classical';
end

fprintf('Segmentation complete. Method: %s\n', seg_info.method_used);

end
