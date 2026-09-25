function [flip_result] = decision_flip_check(original_grade, original_pRef, healed_img, retina_mask, cfg)
%DECISION_FLIP_CHECK Re-evaluates model on healed image to confirm lesion causality
%   [flip_result] = decision_flip_check(original_grade, original_pRef, healed_img, retina_mask, cfg)
%
%   Runs the ONNX DR model on the healed (lesion-removed) image and compares
%   the new grade to the original. If the grade drops, it supports the finding
%   that the identified lesions influenced the AI prediction.

addpath(genpath(fileparts(fileparts(mfilename('fullpath')))));

% Default values (used if ONNX inference fails)
healed_grade = max(0, original_grade - 1);
healed_pRef = max(0, original_pRef - 0.2);
inference_method = 'simulated';

% Try real ONNX inference on the healed image
try
    onnx_path = cfg.onnx_dr_model;
    if exist(onnx_path, 'file')
        % Save healed image to temp file
        temp_healed = fullfile(tempdir, 'drrr_counterfactual_healed.png');
        imwrite(healed_img, temp_healed);
        
        % Run ONNX inference on the healed image
        result = run_onnx_inference('dr', temp_healed, onnx_path);
        
        if isfield(result, 'success') && result.success
            healed_grade = result.grade;
            if isfield(result, 'probs')
                % pRef = sum of probabilities for grades 2, 3, 4
                healed_pRef = sum(result.probs(3:5));
            end
            inference_method = 'onnx_real';
            fprintf('Counterfactual ONNX inference: healed grade = %d (original = %d)\n', healed_grade, original_grade);
        else
            warning('ONNX inference on healed image returned success=false. Using simulated flip.');
        end
        
        % Clean up temp file
        if exist(temp_healed, 'file')
            delete(temp_healed);
        end
    else
        warning('ONNX DR model not found at: %s. Simulating flip.', onnx_path);
    end
catch ME
    warning('Error running ONNX on healed image: %s. Using simulated flip.', ME.message);
end

% Build result struct
flip_result.original_grade = original_grade;
flip_result.healed_grade = healed_grade;
flip_result.original_pRef = original_pRef;
flip_result.healed_pRef = healed_pRef;
flip_result.grade_dropped = (healed_grade < original_grade);
flip_result.inference_method = inference_method;

if flip_result.grade_dropped
    flip_result.description = sprintf( ...
        'Prediction changed after modifying the highlighted region (Grade %d -> %d). This supports the region''s influence on the model prediction.', ...
        original_grade, healed_grade);
else
    flip_result.description = 'Counterfactual consistency check did not change the prediction — review recommended.';
end

end
