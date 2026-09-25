function [evidence_text] = format_evidence_chain(grade_result, seg_results, explain_result, cfg)
%FORMAT_EVIDENCE_CHAIN Builds human-readable evidence chain string
%   [evidence_text] = format_evidence_chain(grade_result, seg_results, explain_result, cfg)

addpath(genpath(fileparts(fileparts(mfilename('fullpath')))));

lines = {};

% === AI Model Results ===
lines{end+1} = '=== AI Model Results ===';
if isfield(grade_result, 'split_decision') && grade_result.split_decision
    lines{end+1} = '  Model agreement: Split decision (resolved by ensemble)';
else
    lines{end+1} = '  Model agreement: Both models agreed';
end

if isfield(grade_result, 'confidence')
    lines{end+1} = sprintf('  AI Confidence: %.1f%%', grade_result.confidence * 100);
end

if isfield(grade_result, 'pRef')
    lines{end+1} = sprintf('  Referral Probability: %.1f%%', grade_result.pRef * 100);
    if grade_result.pRef >= 0.85
        lines{end+1} = '  -> HIGH: Patient likely needs ophthalmologist';
    elseif grade_result.pRef >= 0.15
        lines{end+1} = '  -> BORDERLINE: Expert review recommended';
    else
        lines{end+1} = '  -> LOW: Routine follow-up';
    end
end

lines{end+1} = '';

% === Lesion Findings ===
if isfield(seg_results, 'counts')
    c = seg_results.counts;
    lines{end+1} = '=== Lesion Findings ===';
    lines{end+1} = sprintf('  Microaneurysms (MA): %d detected', c.ma);
    lines{end+1} = sprintf('  Hemorrhages (HE): %d detected', c.hem);
    lines{end+1} = sprintf('  Hard Exudates (EX): %d detected', c.hex);
    lines{end+1} = sprintf('  Soft Exudates (SE): %d detected', c.sex);
    
    total = c.ma + c.hem + c.hex + c.sex;
    if total == 0
        lines{end+1} = '  -> No significant lesions detected';
    elseif total > 50
        lines{end+1} = sprintf('  -> Total: %d lesions (extensive)', total);
    else
        lines{end+1} = sprintf('  -> Total: %d lesions', total);
    end
    lines{end+1} = '';
end

% === Safety Checks ===
lines{end+1} = '=== Safety Checks ===';

if isfield(grade_result, 'ood_pass')
    if grade_result.ood_pass
        lines{end+1} = '  OOD Check: PASSED (image within training distribution)';
    else
        lines{end+1} = '  OOD Check: FAILED (image may be out of distribution)';
    end
end

if isfield(grade_result, 'dme_flag')
    if grade_result.dme_flag
        lines{end+1} = '  DME Risk: SUSPECTED (hard exudates near fovea)';
    else
        lines{end+1} = '  DME Risk: Not suspected';
    end
end

if isfield(grade_result, 'escalation_reason') && ~isempty(grade_result.escalation_reason)
    lines{end+1} = sprintf('  Concordance: %s', grade_result.escalation_reason);
end

lines{end+1} = '';

% === Counterfactual Check ===
if isfield(explain_result, 'full_suite_run') && explain_result.full_suite_run
    if isfield(explain_result, 'counterfactual') && isfield(explain_result.counterfactual, 'flip_result')
        fr = explain_result.counterfactual.flip_result;
        lines{end+1} = '=== Counterfactual Consistency Check ===';
        
        method_note = '';
        if isfield(fr, 'inference_method')
            if strcmp(fr.inference_method, 'onnx_real')
                method_note = ' (real ONNX inference)';
            else
                method_note = ' (simulated)';
            end
        end
        
        lines{end+1} = sprintf('  Original Grade: %d -> Healed Grade: %d%s', ...
            fr.original_grade, fr.healed_grade, method_note);
        
        if fr.grade_dropped
            lines{end+1} = '  Result: Grade DROPPED after lesion removal';
            lines{end+1} = '  -> Supports that identified lesions influence the prediction';
        else
            lines{end+1} = '  Result: Grade did NOT change';
            lines{end+1} = '  -> Further review recommended';
        end
        lines{end+1} = '';
    end
    
    % Quadrant check
    if isfield(explain_result, 'quadrant') && isfield(explain_result.quadrant, 'description')
        lines{end+1} = '=== Quadrant Analysis (4-2-1 Rule) ===';
        lines{end+1} = sprintf('  %s', explain_result.quadrant.description);
        lines{end+1} = '';
    end
end

% === Escalation ===
if isfield(grade_result, 'decision') && strcmp(grade_result.decision, 'ESCALATE')
    lines{end+1} = '=== Escalation Reason ===';
    if isfield(grade_result, 'escalation_reason')
        lines{end+1} = sprintf('  %s', grade_result.escalation_reason);
    end
end

evidence_text = strjoin(lines, newline);

end
