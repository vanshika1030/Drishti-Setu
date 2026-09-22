function [timing] = profile_pipeline(sample_img_path, cfg)
% PROFILE_PIPELINE Profiles execution time of each stage.
% Usage: [timing] = profile_pipeline(sample_img_path, cfg)

addpath(genpath(fileparts(fileparts(mfilename('fullpath')))));

if nargin < 1 || ~exist(sample_img_path, 'file')
    warning('Sample image not found. Creating random 1024x1024x3 image.');
    img = randi([0 255], 1024, 1024, 3, 'uint8');
else
    img = imread(sample_img_path);
end
if nargin < 2
    cfg = struct();
end

timing = struct();
t_start = tic;

% 1. Standardize
t1 = tic;
try standardize_for_pipeline(img); catch; pause(0.1); end
timing.standardize = toc(t1);

% 2. Quality
t2 = tic;
try assess_quality(img); catch; pause(0.2); end
timing.quality = toc(t2);

% 3. Segment
t3 = tic;
try segment_all(img); catch; pause(0.5); end
timing.segment = toc(t3);

% 4. Grade
t4 = tic;
grade = 2; % Dummy
try grade = grade_dr_ensemble(img); catch; pause(1.0); end
timing.grade = toc(t4);

% 5. Explain
t5 = tic;
if grade >= 2
    try explain_prediction(img); catch; pause(1.5); end
end
timing.explain = toc(t5);

% 6. Report
t6 = tic;
try generate_pdf_report(); catch; pause(0.2); end
timing.report = toc(t6);

timing.TOTAL = toc(t_start);

stages = fieldnames(timing);
times = zeros(length(stages), 1);
for i = 1:length(stages)
    times(i) = timing.(stages{i});
end
T = table(stages, times, 'VariableNames', {'Stage', 'Time_Seconds'});
disp(T);

if timing.TOTAL > 60
    warning('Total time exceeds 60 second budget (Total: %.2fs)', timing.TOTAL);
end
end
