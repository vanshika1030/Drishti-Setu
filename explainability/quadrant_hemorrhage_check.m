function [quad_result] = quadrant_hemorrhage_check(hem_mask, fovea_center, retina_mask)
%QUADRANT_HEMORRHAGE_CHECK Checks hemorrhages in 4 quadrants (4-2-1 rule)
%   [quad_result] = quadrant_hemorrhage_check(hem_mask, fovea_center, retina_mask)

addpath(genpath(fileparts(fileparts(mfilename('fullpath')))));

if nargin < 3
    retina_mask = true(size(hem_mask));
end

[h, w] = size(hem_mask);
fx = round(fovea_center(1));
fy = round(fovea_center(2));

% Ensure fx, fy are within bounds
fx = max(1, min(w, fx));
fy = max(1, min(h, fy));

% Define quadrants
Q1 = false(h, w); Q1(1:fy, 1:fx) = true; % Top-left
Q2 = false(h, w); Q2(1:fy, fx+1:w) = true; % Top-right
Q3 = false(h, w); Q3(fy+1:h, 1:fx) = true; % Bottom-left
Q4 = false(h, w); Q4(fy+1:h, fx+1:w) = true; % Bottom-right

% Mask by retina
Q1 = Q1 & retina_mask;
Q2 = Q2 & retina_mask;
Q3 = Q3 & retina_mask;
Q4 = Q4 & retina_mask;

% Count hemorrhage blobs per quadrant
hem_in_q1 = hem_mask & Q1;
hem_in_q2 = hem_mask & Q2;
hem_in_q3 = hem_mask & Q3;
hem_in_q4 = hem_mask & Q4;

cc1 = bwconncomp(hem_in_q1);
cc2 = bwconncomp(hem_in_q2);
cc3 = bwconncomp(hem_in_q3);
cc4 = bwconncomp(hem_in_q4);

q1_count = cc1.NumObjects;
q2_count = cc2.NumObjects;
q3_count = cc3.NumObjects;
q4_count = cc4.NumObjects;

quad_result.counts = [q1_count, q2_count, q3_count, q4_count];

% Threshold for a quadrant to be "affected" (e.g., > 5 blobs)
threshold = 5;
affected = quad_result.counts > threshold;
quad_result.quadrants_affected = sum(affected);

quad_result.four_two_one_met = (quad_result.quadrants_affected >= 4);

if quad_result.four_two_one_met
    quad_result.description = sprintf('Hemorrhages in %d/4 quadrants (Q1: %d, Q2: %d, Q3: %d, Q4: %d) - 4-2-1 "4" criterion MET -> confirms Severe NPDR', ...
        quad_result.quadrants_affected, q1_count, q2_count, q3_count, q4_count);
else
    quad_result.description = sprintf('Hemorrhages in %d/4 quadrants - 4-2-1 "4" criterion NOT met', quad_result.quadrants_affected);
end

end
