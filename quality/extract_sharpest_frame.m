function [best_frame, best_score, best_idx, all_scores] = extract_sharpest_frame(video_path)
% EXTRACT_SHARPEST_FRAME Extract the sharpest frame from a fundus video.
%
%   [best_frame, best_score, best_idx, all_scores] = extract_sharpest_frame(video_path)
%
%   For smartphone + clip-on lens fundus capture, operators often record 
%   video and manually scrub for a clear frame. This automates that step.
%
%   Published workflow reference: "Continuous video recording is often used
%   during the session; the operator can then extract the sharpest, most 
%   well-focused frames from the video for grading."
%
%   INPUTS:
%       video_path  - Path to video file (MP4, AVI, MOV)
%
%   OUTPUTS:
%       best_frame  - RGB image (uint8) of the sharpest frame
%       best_score  - Combined sharpness-coverage score of best frame
%       best_idx    - Frame index of the best frame
%       all_scores  - Nx3 matrix [frame_idx, sharpness, coverage]
%
%   Video is processed LOCALLY — never uploaded. Only the extracted frame
%   enters the pipeline. Zero bandwidth impact.

    addpath(genpath(fileparts(fileparts(mfilename('fullpath')))));
    
    % Validate input
    if ~exist(video_path, 'file')
        error('extract_sharpest_frame:FileNotFound', 'Video file not found: %s', video_path);
    end
    
    try
        vid = VideoReader(video_path);
    catch ME
        error('extract_sharpest_frame:ReadError', 'Cannot read video: %s\n%s', video_path, ME.message);
    end
    
    fprintf('Analyzing video: %s\n', video_path);
    fprintf('Duration: %.1f sec, Resolution: %dx%d, FPS: %.1f\n', ...
        vid.Duration, vid.Width, vid.Height, vid.FrameRate);
    
    % Pre-allocate
    laplacian_kernel = fspecial('laplacian', 0.2);
    min_coverage = 0.30;  % Skip frames with <30% retinal coverage
    
    frame_idx = 0;
    scores = [];
    frames = {};
    
    while hasFrame(vid)
        frame_idx = frame_idx + 1;
        frame = readFrame(vid);
        
        % Sample every 3rd frame for speed (if video is long)
        if vid.FrameRate > 15 && mod(frame_idx, 3) ~= 1
            continue;
        end
        
        % Detect retinal FOV
        gray = im2gray(frame);
        retina_mask = imbinarize(gray, 15/255);
        retina_mask = imfill(retina_mask, 'holes');
        if sum(retina_mask(:)) > 100
            retina_mask = bwareafilt(retina_mask, 1);
        end
        
        % Compute coverage
        coverage = sum(retina_mask(:)) / numel(retina_mask);
        
        % Skip frames with too little retina (blinks, misalignment)
        if coverage < min_coverage
            scores = [scores; frame_idx, 0, coverage]; %#ok<AGROW>
            continue;
        end
        
        % Compute sharpness WITHIN retinal mask only
        lap = imfilter(double(gray), laplacian_kernel, 'replicate');
        masked_lap = lap(retina_mask);
        sharpness = var(masked_lap);
        
        % Combined score
        combined = sharpness * coverage;
        
        scores = [scores; frame_idx, sharpness, coverage]; %#ok<AGROW>
        frames{end+1} = struct('frame', frame, 'idx', frame_idx, ...
            'sharpness', sharpness, 'coverage', coverage, 'combined', combined); %#ok<AGROW>
    end
    
    if isempty(frames)
        error('extract_sharpest_frame:NoFrames', 'No valid frames found in video.');
    end
    
    % Find best frame
    combined_scores = cellfun(@(f) f.combined, frames);
    [best_score, best_local_idx] = max(combined_scores);
    best_frame = frames{best_local_idx}.frame;
    best_idx = frames{best_local_idx}.idx;
    all_scores = scores;
    
    fprintf('Best frame: #%d (sharpness=%.1f, coverage=%.1f%%, combined=%.1f)\n', ...
        best_idx, frames{best_local_idx}.sharpness, ...
        frames{best_local_idx}.coverage * 100, best_score);
    fprintf('Analyzed %d frames, %d valid (%.0f%% had sufficient coverage)\n', ...
        frame_idx, length(frames), length(frames)/size(scores,1)*100);
end
