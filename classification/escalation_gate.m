function [decision, escalation_reason, escalation_details] = escalation_gate(pRef, grade, lesion_counts, nv_suspected, probs_1, probs_2, cfg)
% ESCALATION_GATE Master safety gate deciding whether to accept or escalate a prediction.
%
% Inputs:
%   pRef          - Probability of referable DR
%   grade         - Predicted DR grade (0-4)
%   lesion_counts - Struct with lesion counts
%   nv_suspected  - Boolean indicating neovascularization
%   probs_1       - Probabilities from model 1
%   probs_2       - Probabilities from model 2
%   cfg           - Configuration struct
%
% Outputs:
%   decision            - 'ACCEPT' or 'ESCALATE'
%   escalation_reason   - Explanation string
%   escalation_details  - Struct with all check results

    addpath(genpath(fileparts(fileparts(mfilename('fullpath')))));
    
    decision = 'ACCEPT';
    escalation_reason = '';
    escalation_details = struct();
    
    % 1. OOD Check
    [is_ood, ood_reason] = check_ood(probs_1, probs_2, cfg);
    escalation_details.ood_result = struct('is_ood', is_ood, 'reason', ood_reason);
    
    if is_ood
        decision = 'ESCALATE';
        escalation_reason = ['OOD detected: ', ood_reason];
        return;
    end
    
    % 2. pRef Band Check
    escalation_details.pref_status = '';
    if pRef > cfg.pref_band.high
        escalation_details.pref_status = 'REFERABLE';
    elseif pRef < cfg.pref_band.low
        escalation_details.pref_status = 'SAFE';
    else
        decision = 'ESCALATE';
        escalation_reason = 'borderline pRef';
        escalation_details.pref_status = 'BORDERLINE';
        return;
    end
    
    % 3. Concordance Check
    [is_concordant, conc_reason] = check_concordance(grade, lesion_counts, nv_suspected, cfg);
    escalation_details.concordance_result = struct('is_concordant', is_concordant, 'reason', conc_reason);
    
    if ~is_concordant
        decision = 'ESCALATE';
        escalation_reason = ['Discordant findings: ', conc_reason];
        return;
    end
end
