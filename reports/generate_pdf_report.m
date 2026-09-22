function [pdf_path] = generate_pdf_report(patient_result, output_dir)
%GENERATE_PDF_REPORT Generates a multipage PDF report for the patient
%   [pdf_path] = generate_pdf_report(patient_result, output_dir)

addpath(genpath(fileparts(fileparts(mfilename('fullpath')))));

if nargin < 2
    output_dir = fullfile(pwd, 'output_reports');
end

if ~exist(output_dir, 'dir')
    mkdir(output_dir);
end

patient_id = 'UNKNOWN';
if isfield(patient_result, 'patient_id')
    patient_id = patient_result.patient_id;
end

pdf_path = fullfile(output_dir, sprintf('Report_%s.pdf', patient_id));

fig = figure('Visible', 'off', 'PaperPositionMode', 'auto', 'Color', 'w');
set(fig, 'Units', 'normalized', 'Position', [0 0 1 1]);

% Header
ax_header = axes('Position', [0 0.9 1 0.1], 'Visible', 'off');
text(ax_header, 0.5, 0.5, 'DrishtiSetu Diabetic Retinopathy Screening Report', 'FontSize', 16, 'FontWeight', 'bold', 'HorizontalAlignment', 'center');
text(ax_header, 0.5, 0.2, sprintf('Patient ID: %s | Date: %s', patient_id, datestr(now, 'yyyy-mm-dd')), 'FontSize', 12, 'HorizontalAlignment', 'center');

% Very basic layout for left/right eye
if isfield(patient_result, 'left_eye')
    ax_left_text = axes('Position', [0.1 0.7 0.4 0.15], 'Visible', 'off');
    text(ax_left_text, 0, 0.8, 'Left Eye', 'FontSize', 14, 'FontWeight', 'bold');
    
    if isfield(patient_result.left_eye, 'grade_result')
        gr = patient_result.left_eye.grade_result;
        text(ax_left_text, 0, 0.5, sprintf('Grade: %d | pRef: %.2f', gr.grade, gr.pRef), 'FontSize', 12);
    end
end

if isfield(patient_result, 'right_eye')
    ax_right_text = axes('Position', [0.55 0.7 0.4 0.15], 'Visible', 'off');
    text(ax_right_text, 0, 0.8, 'Right Eye', 'FontSize', 14, 'FontWeight', 'bold');
    
    if isfield(patient_result.right_eye, 'grade_result')
        gr = patient_result.right_eye.grade_result;
        text(ax_right_text, 0, 0.5, sprintf('Grade: %d | pRef: %.2f', gr.grade, gr.pRef), 'FontSize', 12);
    end
end

% Footer
ax_footer = axes('Position', [0 0.05 1 0.05], 'Visible', 'off');
text(ax_footer, 0.5, 0.5, 'Disclaimer: AI-assisted screening, not a diagnosis. Consult an ophthalmologist.', 'FontSize', 10, 'HorizontalAlignment', 'center', 'FontAngle', 'italic');

try
    print(fig, pdf_path, '-dpdf', '-fillpage');
catch
    warning('Failed to generate PDF. Saving as PNG instead.');
    pdf_path = fullfile(output_dir, sprintf('Report_%s.png', patient_id));
    saveas(fig, pdf_path);
end
close(fig);

end
