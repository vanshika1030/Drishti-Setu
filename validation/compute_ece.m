function [ece, bin_accs, bin_confs, bin_counts] = compute_ece(confidences, correct, num_bins)
% COMPUTE_ECE Computes Expected Calibration Error
% Usage: [ece, bin_accs, bin_confs, bin_counts] = compute_ece(confidences, correct, num_bins)

addpath(genpath(fileparts(fileparts(mfilename('fullpath')))));

if nargin < 3, num_bins = 10; end

bin_edges = linspace(0, 1, num_bins + 1);
bin_accs = zeros(num_bins, 1);
bin_confs = zeros(num_bins, 1);
bin_counts = zeros(num_bins, 1);

ece = 0;
total_count = length(confidences);

for i = 1:num_bins
    idx = confidences >= bin_edges(i) & confidences < bin_edges(i+1);
    if i == num_bins
        idx = confidences >= bin_edges(i) & confidences <= bin_edges(i+1);
    end
    
    bin_counts(i) = sum(idx);
    if bin_counts(i) > 0
        bin_accs(i) = mean(correct(idx));
        bin_confs(i) = mean(confidences(idx));
        ece = ece + (abs(bin_accs(i) - bin_confs(i)) * bin_counts(i) / total_count);
    end
end
end
