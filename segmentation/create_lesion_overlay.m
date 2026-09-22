function [overlay_img] = create_lesion_overlay(std_img, lesion_masks, od_mask, vessel_mask, fovea_center)
%CREATE_LESION_OVERLAY Creates an RGB overlay of all detections on original image.
%   [overlay_img] = CREATE_LESION_OVERLAY(std_img, lesion_masks, od_mask, vessel_mask, fovea_center)

addpath(genpath(fileparts(fileparts(mfilename('fullpath')))));

overlay_img = im2double(std_img);

% Helper for alpha blending
blend = @(img, mask, color, alpha) ...
    cat(3, img(:,:,1).*(1-mask*alpha) + mask*color(1)*alpha, ...
           img(:,:,2).*(1-mask*alpha) + mask*color(2)*alpha, ...
           img(:,:,3).*(1-mask*alpha) + mask*color(3)*alpha);

overlay_img = blend(overlay_img, vessel_mask, [0, 1, 0], 0.3);
overlay_img = blend(overlay_img, lesion_masks.soft_exudates, [0.5, 0.5, 1], 0.5);
overlay_img = blend(overlay_img, lesion_masks.hemorrhages, [0.6, 0, 0], 0.5);
overlay_img = blend(overlay_img, lesion_masks.hard_exudates, [1, 1, 0], 1.0);
overlay_img = blend(overlay_img, lesion_masks.ma, [1, 0, 0], 1.0);

% OD Outline (cyan)
od_perim = bwperim(od_mask);
overlay_img = blend(overlay_img, od_perim, [0, 1, 1], 1.0);

% Fovea Crosshair (green)
if ~isempty(fovea_center) && ~any(isnan(fovea_center))
    cx = round(fovea_center(1));
    cy = round(fovea_center(2));
    fovea_mask = false(size(od_mask));
    len = 10;
    
    y_idx = max(1, cy-len):min(size(fovea_mask,1), cy+len);
    x_idx = max(1, cx-len):min(size(fovea_mask,2), cx+len);
    
    if cx >= 1 && cx <= size(fovea_mask,2)
        fovea_mask(y_idx, cx) = true;
    end
    if cy >= 1 && cy <= size(fovea_mask,1)
        fovea_mask(cy, x_idx) = true;
    end
    overlay_img = blend(overlay_img, fovea_mask, [0, 1, 0], 1.0);
end

% Ensure output is [0, 1]
overlay_img = max(0, min(1, overlay_img));

end
