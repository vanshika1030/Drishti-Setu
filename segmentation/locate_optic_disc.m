function [od_mask, od_center, od_radius] = locate_optic_disc(std_img, retina_mask)
%LOCATE_OPTIC_DISC Finds the optic disc in a standardized fundus image.
%   [od_mask, od_center, od_radius] = LOCATE_OPTIC_DISC(std_img, retina_mask)
%   std_img: RGB input image
%   retina_mask: binary mask of the retina

addpath(genpath(fileparts(fileparts(mfilename('fullpath')))));

if nargin < 2 || isempty(retina_mask)
    retina_mask = true(size(std_img,1), size(std_img,2));
end

try
    gray_img = im2gray(std_img);
    % Smooth to reduce noise
    filtered_img = medfilt2(gray_img, [15 15]);
    
    % Find highest intensity within retina
    retina_pixels = filtered_img(retina_mask);
    if isempty(retina_pixels)
        error('Empty retina mask');
    end
    thresh = prctile(retina_pixels, 95);
    
    % Initial mask
    init_mask = (filtered_img >= thresh) & retina_mask;
    
    % Morphological cleanup
    se = strel('disk', 10);
    cleaned_mask = imclose(init_mask, se);
    
    % Keep largest blob
    od_mask = bwareafilt(cleaned_mask, 1);
    
    stats = regionprops(od_mask, 'Centroid', 'EquivDiameter');
    if isempty(stats)
        % Fallback
        warning('Optic disc not found, using default position.');
        od_mask = false(size(gray_img));
        od_center = [size(gray_img, 2)*0.7, size(gray_img, 1)*0.5];
        od_radius = size(gray_img, 2)*0.1;
    else
        od_center = stats.Centroid;
        od_radius = stats.EquivDiameter / 2;
        od_mask = imfill(od_mask, 'holes');
    end
catch ME
    warning('Error locating OD: %s. Using default.', ME.message);
    od_mask = false(size(std_img,1), size(std_img,2));
    od_center = [size(std_img, 2)*0.7, size(std_img, 1)*0.5];
    od_radius = size(std_img, 2)*0.1;
end
end
