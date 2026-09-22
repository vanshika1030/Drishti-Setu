function [healed_img] = counterfactual_heal(std_img, lesion_mask)
%COUNTERFACTUAL_HEAL Synthesizes a healed retina image without lesions
%   [healed_img] = counterfactual_heal(std_img, lesion_mask)

addpath(genpath(fileparts(fileparts(mfilename('fullpath')))));

if ~any(lesion_mask(:))
    healed_img = std_img;
    return;
end

% Dilate mask slightly to ensure full coverage
dilated_mask = imdilate(lesion_mask, strel('disk', 3));

healed_img = zeros(size(std_img), 'like', std_img);

try
    % Use inpaintExemplar which copies texture, better than regionfill
    healed_img = inpaintExemplar(std_img, dilated_mask, 'PatchSize', 9, 'FillOrder', 'tensor');
catch
    warning('inpaintExemplar failed. Falling back to regionfill per channel.');
    for c = 1:size(std_img, 3)
        healed_img(:,:,c) = regionfill(std_img(:,:,c), dilated_mask);
    end
end

end
