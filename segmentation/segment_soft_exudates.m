function [se_mask] = segment_soft_exudates(std_img, od_mask, retina_mask)
%SEGMENT_SOFT_EXUDATES Classical CV fallback for soft exudates.
%   [se_mask] = SEGMENT_SOFT_EXUDATES(std_img, od_mask, retina_mask)

addpath(genpath(fileparts(fileparts(mfilename('fullpath')))));

try
    g_ch = im2double(std_img(:,:,2));
    
    % Smooth to find diffuse regions
    smoothed = imgaussfilt(g_ch, 5);
    
    % Edge energy
    [Gmag, ~] = imgradient(g_ch);
    
    thresh_val = prctile(smoothed(retina_mask), 95);
    candidates = (smoothed > thresh_val) & retina_mask;
    
    % Filter by edge energy (soft exudates have low edges compared to HE)
    edge_thresh = prctile(Gmag(retina_mask), 70);
    candidates = candidates & (Gmag < edge_thresh);
    
    % Mask out OD
    od_dilated = imdilate(od_mask, strel('disk', 10));
    candidates = candidates & ~od_dilated;
    
    % Filter by area
    se_mask = false(size(candidates));
    stats = regionprops(candidates, 'Area', 'PixelIdxList');
    for i = 1:length(stats)
        if stats(i).Area >= 500 && stats(i).Area <= 10000
            se_mask(stats(i).PixelIdxList) = true;
        end
    end
catch ME
    warning('Soft exudate segmentation failed: %s', ME.message);
    se_mask = false(size(std_img,1), size(std_img,2));
end
end
