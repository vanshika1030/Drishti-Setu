function [is_ood, ood_reason] = check_ood(probs_1, probs_2, cfg)
% CHECK_OOD Checks if the input is Out-Of-Distribution (OOD).
% Uses Jensen-Shannon Divergence and Confidence thresholds.
%
% Inputs:
%   probs_1 - Probabilities from model 1
%   probs_2 - Probabilities from model 2
%   cfg     - Configuration struct with fields ood_jsd_threshold and ood_conf_threshold
%
% Outputs:
%   is_ood     - Boolean flag indicating OOD
%   ood_reason - String explanation if OOD

    addpath(genpath(fileparts(fileparts(mfilename('fullpath')))));
    
    % Compute average probability distribution
    avg = (probs_1 + probs_2) / 2;
    
    % KL divergence function with safety bounds
    kl_div = @(p, q) sum(p .* log(max(p, 1e-10) ./ max(q, 1e-10)), 2);
    
    % Jensen-Shannon Divergence
    jsd = (kl_div(probs_1, avg) + kl_div(probs_2, avg)) / 2;
    
    % Maximum confidence mean
    max_conf = mean([max(probs_1, [], 2), max(probs_2, [], 2)], 2);
    
    % Check heuristics
    is_ood = false;
    ood_reason = '';
    
    % HEURISTIC thresholds, not yet calibrated
    if jsd > cfg.ood_jsd_threshold
        is_ood = true;
        ood_reason = 'High divergence between models (JSD threshold exceeded)';
    elseif max_conf < cfg.ood_conf_threshold
        is_ood = true;
        ood_reason = 'Low confidence from both models (Confidence threshold not met)';
    end
end
