function [fovea_center] = estimate_fovea(std_img, od_center, od_radius, retina_mask)
%ESTIMATE_FOVEA Estimates the position of the fovea relative to the OD.
%   [fovea_center] = ESTIMATE_FOVEA(std_img, od_center, od_radius, retina_mask)

addpath(genpath(fileparts(fileparts(mfilename('fullpath')))));

[h, w, ~] = size(std_img);

% Fovea is roughly 2.5 OD diameters away from OD center, temporal side.
% OD diameter = 2 * od_radius
dist = 2.5 * 2 * od_radius;

% Determine Laterality (OD is typically nasal).
% If OD x-coord < img center, the fovea is to the RIGHT of OD.
if od_center(1) < w / 2
    direction = 1;
else
    direction = -1;
end

fovea_x = od_center(1) + direction * dist;
fovea_y = od_center(2); % roughly same vertical level

% Clamp to image bounds
fovea_x = max(1, min(w, fovea_x));
fovea_y = max(1, min(h, fovea_y));

fovea_center = [fovea_x, fovea_y];

try
    gray_img = im2gray(std_img);
    % Define search window
    window_size = round(2 * od_radius);
    x_min = max(1, round(fovea_x - window_size/2));
    x_max = min(w, round(fovea_x + window_size/2));
    y_min = max(1, round(fovea_y - window_size/2));
    y_max = min(h, round(fovea_y + window_size/2));
    
    search_roi = gray_img(y_min:y_max, x_min:x_max);
    mask_roi = retina_mask(y_min:y_max, x_min:x_max);
    
    % Fovea is the darkest region
    search_roi(~mask_roi) = 255; 
    [~, min_idx] = min(search_roi(:));
    if ~isempty(min_idx)
        [min_y, min_x] = ind2sub(size(search_roi), min_idx);
        fovea_center = [x_min + min_x - 1, y_min + min_y - 1];
    end
catch ME
    warning('Error refining fovea: %s', ME.message);
end

end
