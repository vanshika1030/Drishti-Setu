function [explain_result] = explain_prediction(std_img, retina_mask, grade_result, seg_results, cfg)
%EXPLAIN_PREDICTION Orchestrates explainability components (Grad-CAM, counterfactual, etc.)
%   [explain_result] = explain_prediction(std_img, retina_mask, grade_result, seg_results, cfg)

addpath(genpath(fileparts(fileparts(mfilename('fullpath')))));

explain_result = struct();
explain_result.quadrant = struct();
explain_result.counterfactual = struct();
explain_result.full_suite_run = false;

% Grad-CAM (always run)
net = []; % Assume empty for now unless passed via cfg
target_class = num2str(grade_result.grade);
[gradcam_map, gradcam_overlay] = generate_gradcam(std_img, net, target_class, cfg);
explain_result.gradcam_map = gradcam_map;
explain_result.gradcam_overlay = gradcam_overlay;

run_full = (grade_result.grade >= 2) || (isfield(grade_result, 'decision') && strcmp(grade_result.decision, 'ESCALATE'));

if run_full
    explain_result.full_suite_run = true;
    
    % Quadrant check
    if isfield(seg_results, 'hem_mask') && isfield(seg_results, 'fovea_center')
        quad_result = quadrant_hemorrhage_check(seg_results.hem_mask, seg_results.fovea_center, retina_mask);
        explain_result.quadrant = quad_result;
    end
    
    % Counterfactual heal
    if isfield(seg_results, 'lesion_mask')
        combined_lesions = seg_results.lesion_mask;
    else
        combined_lesions = false(size(retina_mask));
        if isfield(seg_results, 'ma_mask'), combined_lesions = combined_lesions | seg_results.ma_mask; end
        if isfield(seg_results, 'hem_mask'), combined_lesions = combined_lesions | seg_results.hem_mask; end
        if isfield(seg_results, 'ex_mask'), combined_lesions = combined_lesions | seg_results.ex_mask; end
        if isfield(seg_results, 'se_mask'), combined_lesions = combined_lesions | seg_results.se_mask; end
    end
    
    healed_img = counterfactual_heal(std_img, combined_lesions);
    
    flip_result = decision_flip_check(grade_result.grade, grade_result.pRef, healed_img, retina_mask, cfg);
    
    explain_result.counterfactual.healed_img = healed_img;
    explain_result.counterfactual.flip_result = flip_result;
end

end
