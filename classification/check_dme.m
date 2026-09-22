function [dme_suspected, dme_info] = check_dme(he_mask, fovea_center, od_radius, retina_mask)
% CHECK_DME Checks for suspected Diabetic Macular Edema based on hard exudates.
%
% Inputs:
%   he_mask      - Binary mask of hard exudates
%   fovea_center - [row, col] coordinates of the fovea
%   od_radius    - Radius of the optic disc
%   retina_mask  - Mask of the valid retina area
%
% Outputs:
%   dme_suspected - Boolean indicating if DME is suspected
%   dme_info      - Struct with detailed metrics

    addpath(genpath(fileparts(fileparts(mfilename('fullpath')))));
    
    % Default config internally since it's a heuristic
    dme_pixel_threshold = 50; % HEURISTIC threshold, not validated against OCT
    
    % Find hard exudate pixels
    [ex_rows, ex_cols] = find(he_mask);
    
    if isempty(ex_rows) || isempty(fovea_center)
        near_fovea_pixels = 0;
        threshold_distance = od_radius * 2;
    else
        % Calculate distances from fovea
        distances = sqrt((ex_rows - fovea_center(1)).^2 + (ex_cols - fovea_center(2)).^2);
        
        % Distance threshold is 1 disc diameter (radius * 2)
        threshold_distance = od_radius * 2;
        
        near_fovea_pixels = sum(distances < threshold_distance);
    end
    
    % Determine if DME is suspected
    dme_suspected = near_fovea_pixels > dme_pixel_threshold;
    
    % Populate info struct
    dme_info = struct();
    dme_info.near_fovea_count = near_fovea_pixels;
    dme_info.threshold_distance = threshold_distance;
    dme_info.dme_suspected = dme_suspected;
end
