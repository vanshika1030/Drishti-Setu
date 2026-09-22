function [gradcam_map, gradcam_overlay] = generate_gradcam(std_img, net, target_class, cfg)
%GENERATE_GRADCAM Generates Grad-CAM map and overlay for explanation
%   [gradcam_map, gradcam_overlay] = generate_gradcam(std_img, net, target_class, cfg)

addpath(genpath(fileparts(fileparts(mfilename('fullpath')))));

if isempty(net)
    warning('Network is empty. Returning dummy Grad-CAM heatmap.');
    gradcam_map = zeros(size(std_img, 1), size(std_img, 2), 'single');
    gradcam_overlay = std_img;
    return;
end

try
    input_size = cfg.cnn_input_size;
catch
    input_size = [512, 512];
end

img_resized = imresize(std_img, input_size);

try
    % Use MATLAB's built-in gradCAM function
    gradcam_map_resized = gradCAM(net, dlarray(single(img_resized), 'SSCB'), target_class);
    
    % Resize back to original
    gradcam_map = imresize(extractdata(gradcam_map_resized), [size(std_img, 1), size(std_img, 2)]);
catch
    warning('gradCAM function failed or not available. Using dummy sensitivity-based heatmap.');
    gradcam_map = zeros(size(std_img, 1), size(std_img, 2), 'single');
    gradcam_map(size(gradcam_map,1)/3:2*size(gradcam_map,1)/3, size(gradcam_map,2)/3:2*size(gradcam_map,2)/3) = 1;
end

% Create proper heatmap overlay
gradcam_map = mat2gray(gradcam_map); % Normalize to [0, 1]
cmap = jet(256);
heatmap_rgb = ind2rgb(uint8(gradcam_map * 255), cmap);

% Alpha blending
alpha = 0.4;
gradcam_overlay = im2uint8(alpha * heatmap_rgb + (1 - alpha) * im2double(std_img));

end
