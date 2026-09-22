function [ma_mask] = detect_microaneurysms(std_img, vessel_mask, retina_mask)
%DETECT_MICROANEURYSMS Classical CV fallback for detecting MAs.
%   [ma_mask] = DETECT_MICROANEURYSMS(std_img, vessel_mask, retina_mask)

addpath(genpath(fileparts(fileparts(mfilename('fullpath')))));

try
    green_ch = im2double(std_img(:,:,2));
    
    % Invert green channel
    inv_green = 1 - green_ch;
    
    % Morphological top-hat to find small bright spots
    se = strel('disk', 5);
    tophat_img = imtophat(inv_green, se);
    
    % Threshold
    thresh = prctile(tophat_img(retina_mask), 99);
    candidates = (tophat_img > thresh) & retina_mask;
    
    % Remove vessels
    vessel_dilated = imdilate(vessel_mask, strel('disk', 2));
    candidates = candidates & ~vessel_dilated;
    
    % Filter by area and circularity
    ma_mask = false(size(candidates));
    stats = regionprops(candidates, 'Area', 'Circularity', 'PixelIdxList');
    for i = 1:length(stats)
        if stats(i).Area >= 5 && stats(i).Area <= 100 && stats(i).Circularity > 0.5
            ma_mask(stats(i).PixelIdxList) = true;
        end
    end
catch ME
    warning('MA detection failed: %s', ME.message);
    ma_mask = false(size(std_img,1), size(std_img,2));
end
end
