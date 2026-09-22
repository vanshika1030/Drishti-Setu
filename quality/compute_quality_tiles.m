function [quality_map, pass_flag, feedback, tile_scores] = compute_quality_tiles(std_img, retina_mask)
%COMPUTE_QUALITY_TILES Assesses image quality on a grid of tiles
%
% Inputs:
%   std_img - Standardized RGB image
%   retina_mask - Binary mask of retina
%
% Outputs:
%   quality_map - Cell array with statuses
%   pass_flag - Boolean, true if image passes quality check
%   feedback - String feedback message
%   tile_scores - Struct array of tile properties

addpath(genpath(fileparts(fileparts(mfilename('fullpath')))));
config = pipeline_config();

grid_size = config.quality_tile_grid;
quality_map = cell(grid_size);
pass_flag = true;
feedback = 'Quality is good';
tile_scores = [];

gray_img = im2gray(std_img);
laplacian_filter = fspecial('laplacian', 0.2);

[h, w] = size(gray_img);
tile_h = floor(h / grid_size(1));
tile_w = floor(w / grid_size(2));

blur_count = 0;
dark_count = 0;
glare_count = 0;

for r = 1:grid_size(1)
    for c = 1:grid_size(2)
        r_start = (r-1)*tile_h + 1;
        r_end = min(r*tile_h, h);
        c_start = (c-1)*tile_w + 1;
        c_end = min(c*tile_w, w);
        
        tile_gray = gray_img(r_start:r_end, c_start:c_end);
        tile_mask = retina_mask(r_start:r_end, c_start:c_end);
        
        coverage = sum(tile_mask(:)) / numel(tile_mask);
        
        if coverage < 0.5
            quality_map{r, c} = '';
            continue;
        end
        
        tile_gray_double = double(tile_gray);
        filtered_tile = imfilter(tile_gray_double, laplacian_filter);
        
        mask_pixels = tile_mask(:);
        filtered_pixels = filtered_tile(:);
        gray_pixels = tile_gray_double(:);
        
        sharpness = var(filtered_pixels(mask_pixels));
        illumination = mean(gray_pixels(mask_pixels));
        
        status = 'good';
        if sharpness < config.quality_sharpness_threshold
            status = 'blur';
            blur_count = blur_count + 1;
        elseif illumination < config.quality_illumination_range(1)
            status = 'dark';
            dark_count = dark_count + 1;
        elseif illumination > config.quality_illumination_range(2)
            status = 'glare';
            glare_count = glare_count + 1;
        end
        
        quality_map{r, c} = status;
        
        if ~strcmp(status, 'good')
            pass_flag = false;
        end
        
        ts = struct('row', r, 'col', c, 'sharpness', sharpness, 'illumination', illumination, 'status', status);
        if isempty(tile_scores)
            tile_scores = ts;
        else
            tile_scores(end+1) = ts; %#ok<AGROW>
        end
    end
end

if ~pass_flag
    if blur_count > max(dark_count, glare_count)
        feedback = 'Image too blurry in some regions';
    elseif dark_count > max(blur_count, glare_count)
        feedback = 'Image too dark in some regions';
    else
        feedback = 'Image has glare/too bright in some regions';
    end
end

end
