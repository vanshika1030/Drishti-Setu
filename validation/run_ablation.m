function [ablation_table] = run_ablation(test_logits_resnet, test_logits_effnet, test_labels, T_values, pref_band, cfg)
% RUN_ABLATION Evaluates three configurations.
% Usage: [ablation_table] = run_ablation(test_logits_resnet, test_logits_effnet, test_labels, T_values, pref_band, cfg)

addpath(genpath(fileparts(fileparts(mfilename('fullpath')))));

% Dummy values if functions missing
sens = zeros(3,1); spec = zeros(3,1); auroc = zeros(3,1); qwk = zeros(3,1); esc = zeros(3,1);
configs = {'ResNet-50 alone'; 'Ensemble (ResNet + EfficientNet)'; 'Ensemble + escalation gate'};

% Row 1
try
    scaled_resnet = test_logits_resnet / T_values.resnet;
    probs_resnet = exp(scaled_resnet) ./ sum(exp(scaled_resnet), 2);
    [max_prob, pred_resnet] = max(probs_resnet, [], 2);
    pred_resnet = pred_resnet - 1;
    pRef_resnet = sum(probs_resnet(:, 3:5), 2);
    m1 = compute_metrics(pred_resnet, test_labels, max_prob, pRef_resnet);
    sens(1) = m1.sensitivity; spec(1) = m1.specificity; auroc(1) = m1.auroc; qwk(1) = m1.qwk; esc(1) = 0;
catch
    warning('Error in Row 1.');
end

% Row 2
try
    [preds_ens, probs_ens, pRef_ens] = ensemble_vote(test_logits_resnet, test_logits_effnet, T_values);
    m2 = compute_metrics(preds_ens, test_labels, max(probs_ens,[],2), pRef_ens);
    sens(2) = m2.sensitivity; spec(2) = m2.specificity; auroc(2) = m2.auroc; qwk(2) = m2.qwk; esc(2) = 0;
catch
    warning('Error in Row 2.');
end

% Row 3
try
    if ~exist('pRef_ens', 'var')
        [preds_ens, probs_ens, pRef_ens] = ensemble_vote(test_logits_resnet, test_logits_effnet, T_values);
    end
    escalated = pRef_ens >= pref_band(1) & pRef_ens <= pref_band(2);
    handled = ~escalated;
    
    m3 = compute_metrics(preds_ens(handled), test_labels(handled), max(probs_ens(handled,:),[],2), pRef_ens(handled));
    sens(3) = m3.sensitivity; spec(3) = m3.specificity; auroc(3) = m3.auroc; qwk(3) = m3.qwk; esc(3) = sum(escalated)/length(escalated) * 100;
catch
    warning('Error in Row 3.');
end

ablation_table = table(configs, sens, spec, auroc, qwk, esc, 'VariableNames', {'Config', 'Sensitivity', 'Specificity', 'AUROC', 'QWK', 'EscalationPct'});
disp(ablation_table);
end
