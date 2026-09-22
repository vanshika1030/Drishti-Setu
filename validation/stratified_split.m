function [train_idx, cal_idx, test_idx] = stratified_split(labels, train_ratio, cal_ratio, test_ratio)
% STRATIFIED_SPLIT Splits data into train, calibration, and test sets.
% Usage: [train_idx, cal_idx, test_idx] = stratified_split(labels, train_ratio, cal_ratio, test_ratio)

addpath(genpath(fileparts(fileparts(mfilename('fullpath')))));

if nargin < 2, train_ratio = 0.70; end
if nargin < 3, cal_ratio = 0.15; end
if nargin < 4, test_ratio = 0.15; end

% Normalize ratios just in case
total = train_ratio + cal_ratio + test_ratio;
train_ratio = train_ratio / total;
cal_ratio = cal_ratio / total;

rng(42);
unique_labels = unique(labels);
train_idx = [];
cal_idx = [];
test_idx = [];

for i = 1:length(unique_labels)
    l = unique_labels(i);
    idx = find(labels == l);
    idx = idx(randperm(length(idx)));
    
    n = length(idx);
    n_train = round(n * train_ratio);
    n_cal = round(n * cal_ratio);
    
    train_idx = [train_idx; idx(1:n_train)];
    cal_idx = [cal_idx; idx(n_train+1:n_train+n_cal)];
    test_idx = [test_idx; idx(n_train+n_cal+1:end)];
end
end
