function [result] = grade_dr_ensemble(std_img, retina_mask, seg_results, cfg)
% GRADE_DR_ENSEMBLE Master grading orchestrator for DrishtiSetu.
%
% Inputs:
%   std_img     - Standardized fundus image
%   retina_mask - Mask of valid retina
%   seg_results - Segmentation results (he_mask, ma_mask, etc)
%   cfg         - Configuration struct
%
% Outputs:
%   result      - Comprehensive grading result struct

    addpath(genpath(fileparts(fileparts(mfilename('fullpath')))));
    
    result = struct();
    models_loaded = false;
    
    % 1. Load models
    resnet_path = fullfile(cfg.model_dir, 'resnet50_dr_grader.mat');
    effnet_path = fullfile(cfg.model_dir, 'efficientnet_dr_grader.mat');
    
    try
        if exist(resnet_path, 'file') && exist(effnet_path, 'file')
            resnet_data = load(resnet_path);
            effnet_data = load(effnet_path);
            
            % 2. Resize and predict
            % using im2gray if needed internally, here we assume predict handles it
            img_resized = imresize(std_img, [512 512]);
            
            % Assuming predict method on the models
            logits_1 = predict(resnet_data.model, img_resized);
            logits_2 = predict(effnet_data.model, img_resized);
            models_loaded = true;
        end
    catch ME
        warning('Error loading or running models: %s', ME.message);
    end
    
    % 3. Fallback if models missing
    if ~models_loaded
        warning('No trained models found. Using placeholder predictions.');
        % Generate placeholder logits where grade 0 is most likely
        logits_1 = [5.0, 1.0, -1.0, -2.0, -3.0];
        logits_2 = [4.5, 1.5, -0.5, -1.5, -2.5];
    end
    
    % 4. Load T_values
    if isfield(cfg, 'T_values')
        T_values = cfg.T_values;
    else
        T_values = [1.0, 1.0];
    end
    
    % 5. Call ensemble vote
    [final_grade, confidence, avg_probs, individual_grades, agreement, pRef] = ensemble_vote(logits_1, logits_2, T_values);
    
    result.grade = final_grade;
    result.pRef = pRef;
    result.confidence = confidence;
    result.avg_probs = avg_probs;
    result.individual_grades = individual_grades;
    result.agreement = agreement;
    result.logits_1 = logits_1;
    result.logits_2 = logits_2;
    
    % Probabilities after temperature scaling (recomputed here for output)
    T_res = T_values(1); T_eff = T_values(2);
    l1_sc = logits_1 / T_res; l2_sc = logits_2 / T_eff;
    p1 = exp(l1_sc - max(l1_sc, [], 2)); result.probs_1 = p1 ./ sum(p1, 2);
    p2 = exp(l2_sc - max(l2_sc, [], 2)); result.probs_2 = p2 ./ sum(p2, 2);
    
    % 6. Check DME
    he_mask = false(size(std_img,1), size(std_img,2)); % Fallback empty masks
    fovea_center = [size(std_img,1)/2, size(std_img,2)/2];
    od_radius = size(std_img,1) / 10;
    if isfield(seg_results, 'he_mask')
        he_mask = seg_results.he_mask;
    end
    if isfield(seg_results, 'fovea_center')
        fovea_center = seg_results.fovea_center;
    end
    if isfield(seg_results, 'od_radius')
        od_radius = seg_results.od_radius;
    end
    
    [dme_suspected, dme_info] = check_dme(he_mask, fovea_center, od_radius, retina_mask);
    result.dme_suspected = dme_suspected;
    result.dme_info = dme_info;
    
    % 7. Escalation gate
    lesion_counts = struct('total', 0, 'ma_count', 0, 'hem_count', 0, 'he_count', 0, 'se_count', 0);
    if isfield(seg_results, 'lesion_counts')
        lesion_counts = seg_results.lesion_counts;
    end
    
    nv_suspected = false;
    if isfield(seg_results, 'nv_suspected')
        nv_suspected = seg_results.nv_suspected;
    end
    
    [decision, esc_reason, esc_details] = escalation_gate(pRef, final_grade, lesion_counts, nv_suspected, result.probs_1, result.probs_2, cfg);
    
    result.decision = decision;
    result.escalation_reason = esc_reason;
    result.escalation_details = esc_details;
end
