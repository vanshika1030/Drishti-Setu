function [sim_results] = run_simulation(cfg, custom_params)
% RUN_SIMULATION Simulink parameter setup and throughput computation.
% Usage: [sim_results] = run_simulation(cfg, custom_params)

addpath(genpath(fileparts(fileparts(mfilename('fullpath')))));

if nargin < 1, cfg = struct(); end
if nargin < 2, custom_params = struct(); end

% Default parameters
params.population = 500000;
params.dm_prevalence = 0.12;
params.camp_days_per_month = 4;
params.devices_per_camp = 3;
params.minutes_per_patient = 5;
params.hours_per_camp_day = 6;
params.escalation_rate = 0.168;
params.doctor_hours_per_day = 4;
params.doctor_min_per_review = 2;
params.referral_adherence = 0.145;
params.bandwidth_kbps = 100;
params.outage_probability = 0.15;

% Load escalation rate and referable rate if available
try
    if isfield(cfg, 'model_dir') && exist(fullfile(cfg.model_dir, 'validation_results.mat'), 'file')
        val_data = load(fullfile(cfg.model_dir, 'validation_results.mat'));
        if isfield(val_data.results, 'ablation_table')
            params.escalation_rate = val_data.results.ablation_table.EscalationPct(3) / 100;
        end
        % Assuming referable rate stored somewhere, default to 0.30
        referable_rate = 0.30;
    else
        referable_rate = 0.30;
        warning('validation_results.mat not found. Using default referable_rate = 0.30');
    end
catch
    referable_rate = 0.30;
    warning('Using default referable_rate = 0.30');
end

% Override defaults
fields = fieldnames(custom_params);
for i = 1:length(fields)
    params.(fields{i}) = custom_params.(fields{i});
end

% COMPUTED outputs
sim_results.diabetic_pop = params.population * params.dm_prevalence;
sim_results.patients_per_device_day = (params.hours_per_camp_day * 60) / params.minutes_per_patient;
sim_results.patients_per_camp_day = sim_results.patients_per_device_day * params.devices_per_camp;
sim_results.patients_per_month = sim_results.patients_per_camp_day * params.camp_days_per_month;
sim_results.months_to_screen = sim_results.diabetic_pop / sim_results.patients_per_month;

sim_results.escalated_per_day = sim_results.patients_per_camp_day * params.escalation_rate;
sim_results.doctor_minutes_per_day = sim_results.escalated_per_day * params.doctor_min_per_review;
sim_results.doctor_utilization = sim_results.doctor_minutes_per_day / (params.doctor_hours_per_day * 60);

sim_results.compute_hours_per_day = params.hours_per_camp_day * params.devices_per_camp; % rough estimate

sim_results.patients_needing_treatment = sim_results.diabetic_pop * referable_rate;
sim_results.patients_actually_treated = sim_results.patients_needing_treatment * params.referral_adherence;
sim_results.treatment_gap = sim_results.patients_needing_treatment - sim_results.patients_actually_treated;

% Bottleneck
doctor_capacity_per_day = (params.doctor_hours_per_day * 60) / params.doctor_min_per_review;
if doctor_capacity_per_day < sim_results.escalated_per_day
    sim_results.bottleneck = 'Doctor Review Capacity';
else
    sim_results.bottleneck = 'Screening Throughput';
end

% Parameter sweep
camp_days_sweep = 2:2:20;
devices_sweep = 1:5;
sweep_matrix = zeros(length(camp_days_sweep), length(devices_sweep));

for i = 1:length(camp_days_sweep)
    for j = 1:length(devices_sweep)
        ppm = ((params.hours_per_camp_day * 60) / params.minutes_per_patient) * devices_sweep(j) * camp_days_sweep(i);
        sweep_matrix(i, j) = sim_results.diabetic_pop / ppm;
    end
end
sim_results.sweep_matrix = sweep_matrix;

% Print summary
fprintf('--- Simulation Summary ---\n');
fprintf('Months to screen population: %.1f\n', sim_results.months_to_screen);
fprintf('Doctor Utilization: %.1f%%\n', sim_results.doctor_utilization * 100);
fprintf('Treatment Gap: %d patients\n', round(sim_results.treatment_gap));
fprintf('Bottleneck: %s\n', sim_results.bottleneck);

end
