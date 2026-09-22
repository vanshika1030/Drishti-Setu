function [metrics] = compute_metrics(predictions, labels, confidences, pRef_values)
% COMPUTE_METRICS Computes various metrics for DR grading
% Usage: [metrics] = compute_metrics(predictions, labels, confidences, pRef_values)

addpath(genpath(fileparts(fileparts(mfilename('fullpath')))));

% Binary Referable DR
is_referable = labels >= 2;
pred_referable = predictions >= 2;

TP = sum(is_referable & pred_referable);
TN = sum(~is_referable & ~pred_referable);
FP = sum(~is_referable & pred_referable);
FN = sum(is_referable & ~pred_referable);

metrics.sensitivity = TP / (TP + FN);
metrics.specificity = TN / (TN + FP);

% Bootstrapping for CI (graceful try/catch)
try
    sens_func = @(data) sum(data(:,1)>=2 & data(:,2)>=2) / sum(data(:,1)>=2);
    spec_func = @(data) sum(data(:,1)<2 & data(:,2)<2) / sum(data(:,1)<2);
    data = [labels, predictions];
    metrics.sensitivity_ci = bootci(2000, sens_func, data);
    metrics.specificity_ci = bootci(2000, spec_func, data);
catch
    metrics.sensitivity_ci = [NaN, NaN];
    metrics.specificity_ci = [NaN, NaN];
end

try
    [~,~,~,metrics.auroc] = perfcurve(is_referable, pRef_values, true);
catch
    metrics.auroc = NaN;
end

% 5-class metrics
metrics.confusion_matrix = confusionmat(labels, predictions);

% Manual QWK
O = metrics.confusion_matrix;
N = sum(sum(O));
hist_true = sum(O, 2);
hist_pred = sum(O, 1);
E = (hist_true * hist_pred) / N;
w = zeros(5, 5);
for i = 1:5
    for j = 1:5
        w(i,j) = ((i - j) ^ 2) / (4 ^ 2);
    end
end
metrics.qwk = 1 - (sum(sum(w .* O)) / sum(sum(w .* E)));

metrics.per_class_accuracy = diag(O) ./ sum(O, 2);

% Calibration
correct = (predictions == labels);
try
    metrics.ece = compute_ece(confidences, correct, 10);
catch
    metrics.ece = NaN;
end

end
