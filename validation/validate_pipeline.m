function [results] = validate_pipeline(cfg)
% VALIDATE_PIPELINE Full validation orchestrator.
% Usage: [results] = validate_pipeline(cfg)

addpath(genpath(fileparts(fileparts(mfilename('fullpath')))));

if nargin < 1
    cfg.model_dir = 'models';
end

results = struct();

% 1. Load test logits
resnet_path = fullfile(cfg.model_dir, 'resnet50_test_logits.mat');
effnet_path = fullfile(cfg.model_dir, 'efficientnet_test_logits.mat');

if ~exist(resnet_path, 'file') || ~exist(effnet_path, 'file')
    warning('No test data found. Run after training models.');
    return;
end

try
    res_data = load(resnet_path);
    eff_data = load(effnet_path);
    test_logits_resnet = res_data.logits;
    test_logits_effnet = eff_data.logits;
    test_labels = res_data.labels;
catch
    warning('Error loading test data.');
    return;
end

% 3. Apply calibrated T values (mock)
T_values.resnet = 1.0;
T_values.effnet = 1.0;
try
    if exist(fullfile(cfg.model_dir, 'calibration.mat'), 'file')
        cal_data = load(fullfile(cfg.model_dir, 'calibration.mat'));
        T_values = cal_data.T_values;
    end
catch
end

% 4. Run ensemble vote
try
    [preds_ens, probs_ens, pRef_ens] = ensemble_vote(test_logits_resnet, test_logits_effnet, T_values);
catch
    warning('ensemble_vote failed, skipping validation.');
    return;
end

% 5. Compute metrics
confidences = max(probs_ens, [], 2);
results.metrics = compute_metrics(preds_ens, test_labels, confidences, pRef_ens);

% 6. Plot reliability diagram
correct = (preds_ens == test_labels);
results.rel_fig = plot_reliability_diagram(confidences, correct, 10, fullfile(cfg.model_dir, 'reliability.png'));

% 7. Run ablation
pref_band = [0.4, 0.6];
results.ablation_table = run_ablation(test_logits_resnet, test_logits_effnet, test_labels, T_values, pref_band, cfg);

% 8. Save everything
save_path = fullfile(cfg.model_dir, 'validation_results.mat');
try
    save(save_path, 'results');
    fprintf('Validation results saved to %s\n', save_path);
catch
    warning('Failed to save validation results.');
end
end
