function [patient_result] = combine_eyes(left_result, right_result)
% COMBINE_EYES Combines eye-level predictions into a patient-level result.
%
% Inputs:
%   left_result  - Struct with left eye predictions
%   right_result - Struct with right eye predictions
%
% Outputs:
%   patient_result - Patient-level combination

    addpath(genpath(fileparts(fileparts(mfilename('fullpath')))));
    
    patient_result = struct();
    patient_result.left = left_result;
    patient_result.right = right_result;
    
    % Handle ungradeable
    left_ungradeable = isempty(left_result) || (isfield(left_result, 'grade') && isnan(left_result.grade));
    right_ungradeable = isempty(right_result) || (isfield(right_result, 'grade') && isnan(right_result.grade));
    
    if left_ungradeable && right_ungradeable
        patient_result.worse_eye = 'none';
        patient_result.patient_grade = NaN;
        patient_result.patient_pRef = NaN;
        patient_result.patient_decision = 'ESCALATE';
        patient_result.recommendation = 'UNGRADEABLE';
        return;
    elseif left_ungradeable
        patient_result.worse_eye = 'right';
        patient_result.patient_grade = right_result.grade;
        patient_result.patient_pRef = right_result.pRef;
        patient_result.patient_decision = right_result.decision;
    elseif right_ungradeable
        patient_result.worse_eye = 'left';
        patient_result.patient_grade = left_result.grade;
        patient_result.patient_pRef = left_result.pRef;
        patient_result.patient_decision = left_result.decision;
    else
        % Both gradeable
        if left_result.grade > right_result.grade
            patient_result.worse_eye = 'left';
        elseif right_result.grade > left_result.grade
            patient_result.worse_eye = 'right';
        else
            if left_result.pRef >= right_result.pRef
                patient_result.worse_eye = 'left';
            else
                patient_result.worse_eye = 'right';
            end
        end
        
        patient_result.patient_grade = max(left_result.grade, right_result.grade);
        patient_result.patient_pRef = max(left_result.pRef, right_result.pRef);
        
        if strcmp(left_result.decision, 'ESCALATE') || strcmp(right_result.decision, 'ESCALATE')
            patient_result.patient_decision = 'ESCALATE';
        else
            patient_result.patient_decision = 'ACCEPT';
        end
    end
    
    % Recommendation
    if patient_result.patient_grade == 0
        patient_result.recommendation = 'Routine Screening';
    elseif patient_result.patient_grade == 1
        patient_result.recommendation = 'Routine Screening';
    elseif patient_result.patient_grade == 2
        patient_result.recommendation = 'Refer to Ophthalmologist within 12 weeks';
    elseif patient_result.patient_grade == 3
        patient_result.recommendation = 'Refer to Ophthalmologist within 4 weeks';
    elseif patient_result.patient_grade == 4
        patient_result.recommendation = 'URGENT: Refer to Ophthalmologist within 1-2 weeks';
    else
        patient_result.recommendation = 'Refer to Ophthalmologist';
    end
end
