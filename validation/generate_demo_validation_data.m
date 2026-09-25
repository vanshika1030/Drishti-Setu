function generate_demo_validation_data()
%GENERATE_DEMO_VALIDATION_DATA Creates realistic demo validation metrics.
%
%   Creates a validation_results.mat file with plausible metrics for the
%   District Officer dashboard display. This is DEMO DATA — not from running
%   the model on a real validation dataset.
%
%   Run once before the demo:
%       generate_demo_validation_data()

    addpath(genpath(fileparts(fileparts(mfilename('fullpath')))));
    cfg = pipeline_config();
    
    output_path = fullfile(cfg.model_dir, 'validation_results.mat');
    
    fprintf('Generating demo validation data...\n');
    
    % ===== Main Metrics =====
    results = struct();
    
    % Classification performance
    results.sensitivity = 0.9048;       % 90.5% sensitivity
    results.sensitivity_ci = [0.88, 0.93];
    results.specificity = 0.9213;       % 92.1% specificity
    results.specificity_ci = [0.89, 0.94];
    results.auroc = 0.9512;             % 95.1% AUROC
    results.accuracy = 0.8735;          % 87.4% accuracy
    
    % Calibration
    results.qwk = 0.8245;              % Quadratic Weighted Kappa
    results.ece = 0.0423;              % Expected Calibration Error
    
    % ===== Reliability Diagram Data =====
    % 10 bins for reliability diagram
    results.num_bins = 10;
    results.bin_confs = [0.05, 0.15, 0.25, 0.35, 0.45, 0.55, 0.65, 0.75, 0.85, 0.95];
    results.bin_accs  = [0.04, 0.13, 0.22, 0.31, 0.42, 0.51, 0.64, 0.73, 0.84, 0.93];
    results.bin_counts = [45, 62, 78, 55, 41, 38, 52, 68, 85, 76];
    
    % ===== Confusion Matrix (5x5 for grades 0-4) =====
    results.confusion_matrix = [
        182  12   3   0   0;   % Grade 0
         15 145  18   2   0;   % Grade 1
          2  20 138  15   3;   % Grade 2
          0   3  12 125  10;   % Grade 3
          0   0   2   8  85;   % Grade 4
    ];
    results.grade_labels = {'No DR', 'Mild NPDR', 'Moderate NPDR', 'Severe NPDR', 'PDR'};
    
    % ===== Per-class metrics =====
    results.per_class_sensitivity = [0.92, 0.81, 0.78, 0.83, 0.87];
    results.per_class_specificity = [0.97, 0.93, 0.94, 0.97, 0.99];
    
    % ===== Ablation Table (for simulation module) =====
    results.ablation_table = struct();
    results.ablation_table.Config = {'No Safety Gate'; 'OOD Only'; 'Full Pipeline'; 'Full + Concordance'};
    results.ablation_table.Sensitivity = [0.905; 0.905; 0.905; 0.905];
    results.ablation_table.Specificity = [0.921; 0.921; 0.921; 0.921];
    results.ablation_table.EscalationPct = [0; 8.5; 16.8; 22.3];
    results.ablation_table.LeakRate = [0; 0; 0.02; 0.01];
    
    % ===== Metadata =====
    results.is_demo_data = true;
    results.generated_date = datestr(now);
    results.note = 'DEMO DATA — Generated for dashboard display. Not from real validation run.';
    results.dataset = 'Simulated (based on typical DR screening performance)';
    results.n_samples = 600;
    
    % Save
    save(output_path, 'results');
    fprintf('Demo validation data saved to: %s\n', output_path);
    fprintf('  Sensitivity: %.1f%%\n', results.sensitivity * 100);
    fprintf('  Specificity: %.1f%%\n', results.specificity * 100);
    fprintf('  AUROC: %.3f\n', results.auroc);
    fprintf('  QWK: %.3f\n', results.qwk);
    fprintf('  ECE: %.4f\n', results.ece);
    fprintf('  NOTE: This is DEMO data for display purposes.\n');
end
