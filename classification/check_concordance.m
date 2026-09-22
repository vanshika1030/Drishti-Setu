function [is_concordant, conc_reason] = check_concordance(grade, lesion_counts, nv_suspected, cfg)
% CHECK_CONCORDANCE Checks if the model grade aligns with the detected lesions.
%
% Inputs:
%   grade         - Predicted DR grade (0-4)
%   lesion_counts - Struct with ma_count, hem_count, he_count, se_count, total
%   nv_suspected  - Boolean indicating neovascularization
%   cfg           - Configuration struct for thresholds
%
% Outputs:
%   is_concordant - Boolean indicating concordance
%   conc_reason   - String reason if discordant

    addpath(genpath(fileparts(fileparts(mfilename('fullpath')))));
    
    is_concordant = true;
    conc_reason = '';
    
    if grade >= 3 && lesion_counts.total < cfg.concordance_min_lesions_for_high_grade
        is_concordant = false;
        conc_reason = 'Grade >= 3 but fewer than 5 lesions detected';
    elseif grade == 0 && lesion_counts.total > cfg.concordance_max_lesions_for_grade0
        is_concordant = false;
        conc_reason = 'Grade 0 but more than 20 lesions detected';
    elseif grade == 4 && ~nv_suspected
        is_concordant = false;
        conc_reason = 'PDR grade but no neovascularization suspected';
    end
end
