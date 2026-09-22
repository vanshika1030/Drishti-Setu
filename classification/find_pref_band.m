function [low_thr, high_thr, coverage, band_info] = find_pref_band(cal_pRef, cal_labels)
% FIND_PREF_BAND Finds optimal lower and upper bounds for probability of referable DR.
%
% Inputs:
%   cal_pRef   - Vector of pRef values for calibration set
%   cal_labels - True grades (0-4)
%
% Outputs:
%   low_thr    - Lower threshold for safe cases
%   high_thr   - Upper threshold for referable cases
%   coverage   - Fraction of cases outside the band
%   band_info  - Struct with detailed metrics

    addpath(genpath(fileparts(fileparts(mfilename('fullpath')))));
    
    is_referable = cal_labels >= 2;
    num_referable = sum(is_referable);
    num_safe = sum(~is_referable);
    N = length(cal_labels);
    
    high_thr = 0.95;
    found_high = false;
    
    % Sweep high_threshold down
    for ht = 0.95:-0.01:0.05
        % Sensitivity: referable cases correctly above high threshold
        tp = sum(cal_pRef >= ht & is_referable);
        sens = tp / max(num_referable, 1);
        
        if sens >= 0.90
            high_thr = ht;
            found_high = true;
            break;
        end
    end
    
    low_thr = 0.05;
    best_low = 0.05;
    found_low = false;
    best_sens = 0;
    best_spec = 0;
    best_leak = 0;
    
    % Sweep low_threshold up
    for lt = 0.05:0.01:high_thr
        % Referable patients that leak into safe bucket
        fn = sum(cal_pRef < lt & is_referable);
        leak_rate = fn / max(num_referable, 1);
        
        % Safety overrides throughput
        if leak_rate > 0.10
            break;
        end
        
        % Specificity: safe cases correctly below low threshold
        tn = sum(cal_pRef < lt & ~is_referable);
        spec = tn / max(num_safe, 1);
        
        if spec >= 0.85
            best_low = lt;
            found_low = true;
            best_spec = spec;
            best_leak = leak_rate;
            best_sens = sum(cal_pRef >= high_thr & is_referable) / max(num_referable, 1);
        end
    end
    
    if found_high && found_low && best_low < high_thr
        low_thr = best_low;
    else
        warning('All cases escalated: No valid band found meeting safety thresholds.');
        low_thr = 0;
        high_thr = 0;
        coverage = 0;
        
        band_info = struct('sensitivity', 0, 'specificity', 0, 'leak_rate', 0, ...
            'coverage', 0, 'cases_escalated_pct', 100);
        return;
    end
    
    % Coverage calculation
    escalated = sum(cal_pRef >= low_thr & cal_pRef < high_thr);
    coverage = (N - escalated) / N;
    
    band_info = struct();
    band_info.sensitivity = best_sens;
    band_info.specificity = best_spec;
    band_info.leak_rate = best_leak;
    band_info.coverage = coverage;
    band_info.cases_escalated_pct = (escalated / N) * 100;
    
    fprintf('Band found: [%.2f, %.2f]. Coverage: %.1f%%. Esc: %.1f%%\n', ...
        low_thr, high_thr, coverage*100, band_info.cases_escalated_pct);
end
