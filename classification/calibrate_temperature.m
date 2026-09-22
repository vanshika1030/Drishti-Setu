function [T_optimal, nll_before, nll_after] = calibrate_temperature(val_logits, val_labels)
% CALIBRATE_TEMPERATURE Calibrates temperature scaling using negative log-likelihood.
%
% Inputs:
%   val_logits - Nx5 matrix of raw logits
%   val_labels - Nx1 vector of true grades (0-4)
%
% Outputs:
%   T_optimal  - The optimal temperature value
%   nll_before - NLL before calibration (T=1)
%   nll_after  - NLL after calibration

    addpath(genpath(fileparts(fileparts(mfilename('fullpath')))));
    
    % Convert to 1-indexed for MATLAB
    labels_idx = val_labels + 1;
    
    % Compute NLL before (T=1.0)
    nll_before = compute_nll(val_logits, labels_idx, 1.0);
    
    % Optimize log(T) to guarantee T > 0 using fminsearch
    log_T_opt = fminsearch(@(log_T) compute_nll(val_logits, labels_idx, exp(log_T)), log(1.0));
    
    % Optimal temperature
    T_optimal = exp(log_T_opt);
    
    % NLL after
    nll_after = compute_nll(val_logits, labels_idx, T_optimal);
end

function nll = compute_nll(logits, labels_idx, T)
    % Apply temperature scaling
    scaled = logits / T;
    
    % Numerical stability
    max_scaled = max(scaled, [], 2);
    exp_scaled = exp(scaled - max_scaled);
    probs = exp_scaled ./ sum(exp_scaled, 2);
    
    % Extract true class probabilities
    N = size(logits, 1);
    true_probs = zeros(N, 1);
    for i = 1:N
        true_probs(i) = probs(i, labels_idx(i));
    end
    
    % Calculate Negative Log-Likelihood
    nll = -mean(log(true_probs + eps));
end
