function [hem_mask] = classify_hemorrhages(std_img, vessel_mask, od_mask, retina_mask)
%CLASSIFY_HEMORRHAGES Classical CV fallback for detecting hemorrhages.
%   [hem_mask] = CLASSIFY_HEMORRHAGES(std_img, vessel_mask, od_mask, retina_mask)

addpath(genpath(fileparts(fileparts(mfilename('fullpath')))));

try
    r_ch = im2double(std_img(:,:,1));
    g_ch = im2double(std_img(:,:,2));
    
    % Hemorrhages are dark in green, dark in red.
    feat_map = (1 - g_ch) .* (1 - r_ch);
    
    % Threshold
    thresh = prctile(feat_map(retina_mask), 98);
    candidates = (feat_map > thresh) & retina_mask;
    
    % Remove OD and vessels
    v_dilated = imdilate(vessel_mask, strel('disk', 3));
    candidates = candidates & ~v_dilated & ~od_mask;
    
    % Filter by area
    hem_mask = false(size(candidates));
    stats = regionprops(candidates, 'Area', 'PixelIdxList');
    for i = 1:length(stats)
        if stats(i).Area >= 100 && stats(i).Area <= 5000
            hem_mask(stats(i).PixelIdxList) = true;
        end
    end
    
    % Morphological cleanup
    hem_mask = imclose(hem_mask, strel('disk', 2));
catch ME
    warning('Hemorrhage detection failed: %s', ME.message);
    hem_mask = false(size(std_img,1), size(std_img,2));
end
end
