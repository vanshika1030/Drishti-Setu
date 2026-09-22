function [std_img, retina_mask, fov_props] = standardize_for_pipeline(img)
%STANDARDIZE_FOR_PIPELINE Standardizes input image for the DrishtiSetu pipeline
%
% Inputs:
%   img - RGB image
%
% Outputs:
%   std_img - Standardized 1024x1024 RGB image with CLAHE applied
%   retina_mask - Binary mask of the retina at final resolution
%   fov_props - Struct with centroid, diameter, coverage of the FOV

addpath(genpath(fileparts(fileparts(mfilename('fullpath')))));
config = pipeline_config();

% Detect retinal FOV
gray = im2gray(img);
mask = imbinarize(gray, 15/255);
mask = imfill(mask, 'holes');
mask = bwareafilt(mask, 1);

props = regionprops(mask, 'EquivDiameter', 'Centroid', 'BoundingBox');

if isempty(props)
    warning('No retina found in image. Returning resized image directly.');
    std_img = imresize(img, config.input_size(1:2));
    retina_mask = true(config.input_size(1:2));
    fov_props = struct('Centroid', [512 512], 'EquivDiameter', 1024, 'Coverage', 1.0);
    
    % Apply CLAHE
    for i = 1:size(std_img, 3)
        std_img(:,:,i) = adapthisteq(std_img(:,:,i), 'ClipLimit', config.clahe_clip_limit);
    end
    return;
end

diameter = props(1).EquivDiameter;
centroid = props(1).Centroid;

% Scale so diameter = target
scale = config.retina_diameter_target / diameter;
img_scaled = imresize(img, scale);
mask_scaled = imresize(mask, scale);

% Calculate new centroid
centroid_scaled = centroid * scale;

% Center-crop to 1024x1024
target_size = config.input_size(1:2);
std_img = zeros([target_size, size(img, 3)], class(img));
retina_mask = false(target_size);

% Calculate cropping/padding boundaries
r_start_scaled = round(centroid_scaled(2) - target_size(1)/2) + 1;
r_end_scaled = r_start_scaled + target_size(1) - 1;
c_start_scaled = round(centroid_scaled(1) - target_size(2)/2) + 1;
c_end_scaled = c_start_scaled + target_size(2) - 1;

% Source image indices
r_src_start = max(1, r_start_scaled);
r_src_end = min(size(img_scaled, 1), r_end_scaled);
c_src_start = max(1, c_start_scaled);
c_src_end = min(size(img_scaled, 2), c_end_scaled);

% Target image indices
r_tgt_start = max(1, 2 - r_start_scaled);
r_tgt_end = r_tgt_start + (r_src_end - r_src_start);
c_tgt_start = max(1, 2 - c_start_scaled);
c_tgt_end = c_tgt_start + (c_src_end - c_src_start);

std_img(r_tgt_start:r_tgt_end, c_tgt_start:c_tgt_end, :) = img_scaled(r_src_start:r_src_end, c_src_start:c_src_end, :);
retina_mask(r_tgt_start:r_tgt_end, c_tgt_start:c_tgt_end) = mask_scaled(r_src_start:r_src_end, c_src_start:c_src_end);

% Apply CLAHE
for i = 1:size(std_img, 3)
    std_img(:,:,i) = adapthisteq(std_img(:,:,i), 'ClipLimit', config.clahe_clip_limit);
end

coverage = sum(retina_mask(:)) / numel(retina_mask);
fov_props = struct('Centroid', props(1).Centroid, 'EquivDiameter', props(1).EquivDiameter, 'Coverage', coverage);

end
