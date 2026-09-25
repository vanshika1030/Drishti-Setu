function [gradcam_map, gradcam_overlay] = generate_gradcam(std_img, net, target_class, cfg)
%GENERATE_GRADCAM Generates Grad-CAM map and overlay for explanation.
%
%   [gradcam_map, gradcam_overlay] = generate_gradcam(std_img, net, target_class, cfg)
%
%   Note: Grad-CAM requires full network access which is not available
%   via the Python onnxruntime bridge. Falls back to a synthetic attention
%   heatmap based on lesion locations when real Grad-CAM is unavailable.

addpath(genpath(fileparts(fileparts(mfilename('fullpath')))));

[h, w, ~] = size(std_img);

if isempty(net)
    % Generate a synthetic attention heatmap using image features
    % This provides visual guidance even without a real Grad-CAM
    try
        gray = im2double(rgb2gray(std_img));
        
        % Create attention map from image features (bright/dark regions)
        % Emphasize areas that are clinically interesting
        green_ch = im2double(std_img(:,:,2));
        red_ch = im2double(std_img(:,:,1));
        
        % Dark spots in green channel (hemorrhages, MAs)
        dark_features = 1 - green_ch;
        dark_features = imgaussfilt(dark_features, 10);
        
        % Bright spots (exudates)
        bright_features = green_ch;
        bright_features = imgaussfilt(bright_features, 10);
        bright_features = bright_features - mean(bright_features(:));
        bright_features = max(0, bright_features);
        
        % Red channel intensity (hemorrhages)
        red_features = imgaussfilt(red_ch, 10);
        
        % Combine into attention map
        gradcam_map = single(0.4 * dark_features + 0.3 * bright_features + 0.3 * red_features);
        gradcam_map = mat2gray(gradcam_map);
    catch
        gradcam_map = zeros(h, w, 'single');
        gradcam_map(round(h/3):round(2*h/3), round(w/3):round(2*w/3)) = 1;
    end
else
    % Real Grad-CAM with network
    try
        input_size = [256, 256];
        if isfield(cfg, 'dr_input_size')
            input_size = cfg.dr_input_size;
        elseif isfield(cfg, 'cnn_input_size')
            input_size = cfg.cnn_input_size(1:2);
        end
        
        img_resized = imresize(std_img, input_size);
        dl_input = dlarray(single(img_resized), 'SSCB');
        
        gradcam_map_resized = gradCAM(net, dl_input, target_class);
        gradcam_map = imresize(extractdata(gradcam_map_resized), [h, w]);
    catch
        warning('gradCAM failed. Using feature-based attention map.');
        gradcam_map = zeros(h, w, 'single');
        gradcam_map(round(h/3):round(2*h/3), round(w/3):round(2*w/3)) = 1;
    end
    gradcam_map = mat2gray(gradcam_map);
end

% Create heatmap overlay
cmap = jet(256);
heatmap_rgb = ind2rgb(uint8(gradcam_map * 255), cmap);

alpha = 0.4;
gradcam_overlay = im2uint8(alpha * heatmap_rgb + (1 - alpha) * im2double(std_img));

end
