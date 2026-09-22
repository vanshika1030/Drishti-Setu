function [nv_mask, nv_suspected] = detect_neovascularization(std_img, vessel_mask, od_mask, retina_mask)
%DETECT_NEOVASCULARIZATION Detects suspected neovascularization near OD.
%   [nv_mask, nv_suspected] = DETECT_NEOVASCULARIZATION(std_img, vessel_mask, od_mask, retina_mask)

addpath(genpath(fileparts(fileparts(mfilename('fullpath')))));
warning('NV detection is heuristic. If suspected, refer for FFA confirmation.');

try
    % Dilate OD mask to define 'near OD' region
    stats = regionprops(od_mask, 'EquivDiameter');
    if isempty(stats)
        r = 50;
    else
        r = round(stats(1).EquivDiameter);
    end
    se = strel('disk', r);
    near_od_mask = imdilate(od_mask, se) & ~od_mask & retina_mask;
    
    % Find vessels near OD
    vessels_near_od = vessel_mask & near_od_mask;
    
    % Calculate local density
    density_filter = fspecial('disk', 15);
    local_density = imfilter(double(vessels_near_od), density_filter);
    
    % Threshold for abnormally high density
    nv_mask = (local_density > 0.4) & near_od_mask;
    nv_mask = bwareaopen(nv_mask, 20);
    
    nv_suspected = any(nv_mask(:));
catch ME
    warning('NV detection error: %s', ME.message);
    nv_mask = false(size(std_img,1), size(std_img,2));
    nv_suspected = false;
end
end
