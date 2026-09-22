function [vessel_mask] = segment_vessels(std_img, retina_mask)
%SEGMENT_VESSELS Segments blood vessels using matched filtering.
%   [vessel_mask] = SEGMENT_VESSELS(std_img, retina_mask)

addpath(genpath(fileparts(fileparts(mfilename('fullpath')))));

try
    % Use green channel
    green_ch = std_img(:,:,2);
    green_ch = im2double(green_ch);
    
    % Invert so vessels are bright
    green_ch = 1 - green_ch;
    
    % Matched filtering (simplified as oriented lines)
    angles = 0:15:165;
    max_response = zeros(size(green_ch));
    L = 9;
    
    for ang = angles
        % Create simple line kernel
        se = strel('line', L, ang);
        filt_img = imtophat(green_ch, se); % Tophat enhances thin structures
        max_response = max(max_response, filt_img);
    end
    
    % Threshold
    retina_vals = max_response(retina_mask);
    if isempty(retina_vals)
        thresh = graythresh(max_response);
    else
        thresh = graythresh(retina_vals); % Or adaptive
    end
    
    v_mask = max_response > thresh;
    
    % Cleanup
    v_mask = v_mask & retina_mask;
    v_mask = bwareaopen(v_mask, 30);
    vessel_mask = bwmorph(v_mask, 'thin', Inf);
    % Or simply bwmorph clean, based on request
    vessel_mask = bwmorph(vessel_mask, 'clean');
catch ME
    warning('Vessel segmentation failed: %s', ME.message);
    vessel_mask = false(size(std_img,1), size(std_img,2));
end

end
