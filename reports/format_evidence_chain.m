function [evidence_text] = format_evidence_chain(grade_result, seg_results, explain_result, cfg)
%FORMAT_EVIDENCE_CHAIN Builds human-readable evidence chain string
%   [evidence_text] = format_evidence_chain(grade_result, seg_results, explain_result, cfg)

addpath(genpath(fileparts(fileparts(mfilename('fullpath')))));

evidence_text = '';

% Model info
if isfield(grade_result, 'split_decision') && grade_result.split_decision
    model_agree = 'Split decision (resolved)';
else
    model_agree = 'Models agreed';
end

evidence_text = sprintf('%s%s\nConfidence: %.2f\npRef: %.2f\n', evidence_text, model_agree, grade_result.confidence, grade_result.pRef);

% Lesion Summary
if isfield(seg_results, 'counts')
    c = seg_results.counts;
    evidence_text = sprintf('%sLesions: %d MAs, %d Hemorrhages, %d Hard Exudates, %d Soft Exudates\n', ...
        evidence_text, c.ma, c.hem, c.hex, c.sex);
end

% Safety checks
if isfield(grade_result, 'ood_pass')
    evidence_text = sprintf('%sOOD Check: %s\n', evidence_text, mat2str(grade_result.ood_pass));
end

if isfield(grade_result, 'dme_flag') && grade_result.dme_flag
    evidence_text = sprintf('%sDME Flag: TRIGGERED\n', evidence_text);
end

% Explainability
if isfield(explain_result, 'full_suite_run') && explain_result.full_suite_run
    if isfield(explain_result, 'quadrant') && isfield(explain_result.quadrant, 'description')
        evidence_text = sprintf('%sQuadrant Check: %s\n', evidence_text, explain_result.quadrant.description);
    end
    if isfield(explain_result, 'counterfactual') && isfield(explain_result.counterfactual, 'flip_result')
        evidence_text = sprintf('%sCounterfactual: %s\n', evidence_text, explain_result.counterfactual.flip_result.description);
    end
end

if isfield(grade_result, 'escalation_reason')
    evidence_text = sprintf('%sEscalation Reason: %s\n', evidence_text, grade_result.escalation_reason);
end

end
