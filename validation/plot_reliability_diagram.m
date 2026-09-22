function [fig] = plot_reliability_diagram(confidences, correct, num_bins, save_path)
% PLOT_RELIABILITY_DIAGRAM Plots reliability diagram for calibration.
% Usage: [fig] = plot_reliability_diagram(confidences, correct, num_bins, save_path)

addpath(genpath(fileparts(fileparts(mfilename('fullpath')))));

if nargin < 3, num_bins = 10; end
if nargin < 4, save_path = ''; end

[ece, bin_accs, bin_confs, ~] = compute_ece(confidences, correct, num_bins);

fig = figure;
bar(bin_confs, bin_accs);
hold on;
plot([0 1], [0 1], 'r--', 'LineWidth', 2);
xlabel('Mean Predicted Confidence');
ylabel('Fraction of Positives');
title('Reliability Diagram — DrishtiSetu');
text(0.1, 0.9, sprintf('ECE = %.4f', ece), 'FontSize', 12, 'BackgroundColor', 'w');
axis([0 1 0 1]);
hold off;

if ~isempty(save_path)
    try
        saveas(fig, save_path);
    catch
        warning('Failed to save reliability diagram.');
    end
end
end
