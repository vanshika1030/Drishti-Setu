function [he_mask] = segment_hard_exudates(std_img, od_mask, retina_mask)
%SEGMENT_HARD_EXUDATES Classical CV fallback for hard exudates.
%   [he_mask] = SEGMENT_HARD_EXUDATES(std_img, od_mask, retina_mask)

addpath(genpath(fileparts(fileparts(mfilename('fullpath')))));

try
    g_ch = im2double(std_img(:,:,2));
    b_ch = im2double(std_img(:,:,3));
    
    % HE are bright in green and blue
    intensity = (g_ch + b_ch) / 2;
    
    thresh = prctile(intensity(retina_mask), 98);
    candidates = (intensity > thresh) & retina_mask;
    
    % CRITICAL: mask out OD
    od_dilated = imdilate(od_mask, strel('disk', 5));
    candidates = candidates & ~od_dilated;
    
    % Filter by area
    he_mask = false(size(candidates));
    stats = regionprops(candidates, 'Area', 'PixelIdxList');
    for i = 1:length(stats)
        if stats(i).Area >= 20 && stats(i).Area <= 3000
            he_mask(stats(i).PixelIdxList) = true;
        end
    end
catch ME
    warning('Hard exudate segmentation failed: %s', ME.message);
    he_mask = false(size(std_img,1), size(std_img,2));
end
end
