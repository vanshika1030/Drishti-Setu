function [pass_flag, feedback, quality_info] = assess_quality(std_img, retina_mask)
%ASSESS_QUALITY High-level wrapper to evaluate image quality
%
% Inputs:
%   std_img - Standardized RGB image
%   retina_mask - Binary mask of retina
%
% Outputs:
%   pass_flag - Boolean, true if image passes quality check
%   feedback - String feedback message
%   quality_info - Struct with detailed quality metrics

addpath(genpath(fileparts(fileparts(mfilename('fullpath')))));

overall_coverage = sum(retina_mask(:)) / numel(retina_mask);

[quality_map, tiles_pass, tiles_feedback, tile_scores] = compute_quality_tiles(std_img, retina_mask);

overall_sharpness = NaN;
overall_illumination = NaN;

if ~isempty(tile_scores)
    overall_sharpness = mean([tile_scores.sharpness]);
    overall_illumination = mean([tile_scores.illumination]);
end

quality_info = struct('quality_map', {quality_map}, ...
    'tile_scores', tile_scores, ...
    'fov_coverage', overall_coverage, ...
    'overall_sharpness', overall_sharpness, ...
    'overall_illumination', overall_illumination);

pass_flag = true;
feedback = 'Image quality is acceptable.';

if overall_coverage < 0.5
    pass_flag = false;
    feedback = 'Insufficient field of view (retina coverage < 50%).';
elseif ~tiles_pass
    pass_flag = false;
    feedback = tiles_feedback;
end

end
