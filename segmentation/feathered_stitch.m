function [stitched] = feathered_stitch(patches, positions, img_size, patch_size, stride)
%FEATHERED_STITCH Reassembles overlapping patches with feathered blending.
%   [stitched] = FEATHERED_STITCH(patches, positions, img_size, patch_size, stride)

addpath(genpath(fileparts(fileparts(mfilename('fullpath')))));

num_channels = size(patches{1}, 3);
stitched = zeros([img_size(1), img_size(2), num_channels], 'double');
weight_sum = zeros(img_size(1), img_size(2), 'double');

% Create cosine-ramp weight mask
overlap = patch_size - stride;
if overlap > 0
    ramp = (1 - cos(linspace(0, pi, overlap))) / 2;
    w_1d = [ramp, ones(1, patch_size - 2*overlap), fliplr(ramp)];
else
    w_1d = ones(1, patch_size);
end
weight_mask = w_1d' * w_1d;

num_patches = length(patches);
for i = 1:num_patches
    r = positions(i, 1);
    c = positions(i, 2);
    
    r_end = min(r + patch_size - 1, img_size(1));
    c_end = min(c + patch_size - 1, img_size(2));
    
    p_h = r_end - r + 1;
    p_w = c_end - c + 1;
    
    w_crop = weight_mask(1:p_h, 1:p_w);
    
    for ch = 1:num_channels
        patch_crop = patches{i}(1:p_h, 1:p_w, ch);
        stitched(r:r_end, c:c_end, ch) = stitched(r:r_end, c:c_end, ch) + double(patch_crop) .* w_crop;
    end
    weight_sum(r:r_end, c:c_end) = weight_sum(r:r_end, c:c_end) + w_crop;
end

stitched = stitched ./ max(weight_sum, eps);

end
