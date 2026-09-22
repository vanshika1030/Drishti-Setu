function [final_grade, confidence, avg_probs, individual_grades, agreement, pRef] = ensemble_vote(logits_resnet, logits_effnet, T_values)
% ENSEMBLE_VOTE Combines predictions from ResNet and EfficientNet models.
%
% Inputs:
%   logits_resnet - Nx5 raw output logits from ResNet
%   logits_effnet - Nx5 raw output logits from EfficientNet
%   T_values      - [T_resnet, T_effnet] (default [1.0, 1.0])
%
% Outputs:
%   final_grade   - 0-indexed ICDR grade
%   confidence    - Maximum average probability
%   avg_probs     - Averaged probabilities
%   individual_grades - [grade_resnet, grade_effnet]
%   agreement     - Boolean indicating if models agree on grade
%   pRef          - Probability of referable DR (grade >= 2)

    addpath(genpath(fileparts(fileparts(mfilename('fullpath')))));
    
    if nargin < 3 || isempty(T_values)
        T_values = [1.0, 1.0];
    end
    
    % Temperature scaling with numerical stability
    T_resnet = T_values(1);
    T_effnet = T_values(2);
    
    % Scaled logits
    logits_resnet_scaled = logits_resnet / T_resnet;
    logits_effnet_scaled = logits_effnet / T_effnet;
    
    % Subtract max for numerical stability before exp
    max_res = max(logits_resnet_scaled, [], 2);
    max_eff = max(logits_effnet_scaled, [], 2);
    
    exp_res = exp(logits_resnet_scaled - max_res);
    exp_eff = exp(logits_effnet_scaled - max_eff);
    
    probs_1 = exp_res ./ sum(exp_res, 2);
    probs_2 = exp_eff ./ sum(exp_eff, 2);
    
    % Equal weight average
    avg_probs = (probs_1 + probs_2) / 2;
    
    % Get grades (0-indexed)
    [~, max_idx_1] = max(probs_1, [], 2);
    [~, max_idx_2] = max(probs_2, [], 2);
    [confidence, max_idx_avg] = max(avg_probs, [], 2);
    
    grade_1 = max_idx_1 - 1;
    grade_2 = max_idx_2 - 1;
    final_grade = max_idx_avg - 1;
    
    individual_grades = [grade_1, grade_2];
    agreement = (grade_1 == grade_2);
    
    % Probability of referable DR (sum of probs for grades 2, 3, 4)
    % Using 1-indexed MATLAB arrays, so indices 3, 4, 5
    pRef = sum(avg_probs(:, 3:5), 2);
end
