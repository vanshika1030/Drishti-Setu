function create_screening_model()
% CREATE_SCREENING_MODEL  Build the DrishtiSetu Screening Simulink Model
%
% This model simulates the screening pipeline using standard Simulink blocks
% organized into clear, professional subsystems since SimEvents is not installed.
%
% Usage:
%   create_screening_model()                % Create the .slx file
%   open_system('DrishtiSetu_Screening')    % View the model

modelName = 'DrishtiSetu_Screening';
modelDir = fileparts(mfilename('fullpath'));
slxPath = fullfile(modelDir, [modelName '.slx']);

% Close if loaded
try
    if bdIsLoaded(modelName)
        close_system(modelName, 0);
    end
catch
end

% Create model
new_system(modelName);
set_param(modelName, 'Solver', 'FixedStepDiscrete', 'FixedStep', '1', 'StopTime', '0');

% ════════════════════════════════════════════════════════
% MAIN WORKSPACE VARIABLES (Inputs)
% ════════════════════════════════════════════════════════
add_block('simulink/Sources/Constant', [modelName '/Total_Population'], 'Value', 'sim_pop', 'Position', [20 50 120 80], 'BackgroundColor', 'cyan');
add_block('simulink/Sources/Constant', [modelName '/DM_Prevalence'], 'Value', 'sim_dm_prev', 'Position', [20 100 120 130], 'BackgroundColor', 'cyan');
add_block('simulink/Sources/Constant', [modelName '/Devices_Per_Camp'], 'Value', 'sim_devices', 'Position', [20 200 120 230], 'BackgroundColor', 'cyan');
add_block('simulink/Sources/Constant', [modelName '/Camp_Days_Per_Month'], 'Value', 'sim_camp_days', 'Position', [20 250 120 280], 'BackgroundColor', 'cyan');

% ════════════════════════════════════════════════════════
% SUBSYSTEM 1: PATIENT POPULATION MODEL
% ════════════════════════════════════════════════════════
popSys = [modelName '/1. Patient Population Model'];
add_block('simulink/Ports & Subsystems/Subsystem', popSys, 'Position', [180 60 320 120], 'BackgroundColor', 'lightBlue');
% Inside popSys
add_block('simulink/Sources/In1', [popSys '/Pop_In'], 'Position', [20 40 50 55]);
add_block('simulink/Sources/In1', [popSys '/Prev_In'], 'Position', [20 80 50 95]);
add_block('simulink/Math Operations/Product', [popSys '/Mult'], 'Position', [100 50 140 90]);
add_block('simulink/Sinks/Out1', [popSys '/Diabetic_Pop'], 'Position', [200 65 230 80]);
add_line(popSys, 'Pop_In/1', 'Mult/1'); add_line(popSys, 'Prev_In/1', 'Mult/2'); add_line(popSys, 'Mult/1', 'Diabetic_Pop/1');

add_line(modelName, 'Total_Population/1', '1. Patient Population Model/1');
add_line(modelName, 'DM_Prevalence/1', '1. Patient Population Model/2');

% ════════════════════════════════════════════════════════
% SUBSYSTEM 2: SCREENING CAMP THROUGHPUT
% ════════════════════════════════════════════════════════
campSys = [modelName '/2. Screening Camp Capacity'];
add_block('simulink/Ports & Subsystems/Subsystem', campSys, 'Position', [180 200 320 280], 'BackgroundColor', 'lightBlue');
% Inside campSys
add_block('simulink/Sources/In1', [campSys '/Devices_In'], 'Position', [20 40 50 55]);
add_block('simulink/Sources/In1', [campSys '/Days_In'], 'Position', [20 120 50 135]);
add_block('simulink/Sources/Constant', [campSys '/Min_Per_Day'], 'Value', '360', 'Position', [20 70 60 85]);
add_block('simulink/Sources/Constant', [campSys '/Min_Per_Patient'], 'Value', '5', 'Position', [20 95 60 110]);
add_block('simulink/Math Operations/Product', [campSys '/Device_Cap'], 'Inputs', '*/', 'Position', [100 70 130 110]);
add_block('simulink/Math Operations/Product', [campSys '/Daily_Cap'], 'Position', [180 50 210 90]);
add_block('simulink/Math Operations/Product', [campSys '/Monthly_Cap'], 'Position', [260 70 290 110]);
add_block('simulink/Sinks/Out1', [campSys '/Patients_Per_Day'], 'Position', [260 30 290 45]);
add_block('simulink/Sinks/Out1', [campSys '/Patients_Per_Month'], 'Position', [340 85 370 100]);
add_line(campSys, 'Min_Per_Day/1', 'Device_Cap/1'); add_line(campSys, 'Min_Per_Patient/1', 'Device_Cap/2');
add_line(campSys, 'Devices_In/1', 'Daily_Cap/1'); add_line(campSys, 'Device_Cap/1', 'Daily_Cap/2');
add_line(campSys, 'Daily_Cap/1', 'Monthly_Cap/1'); add_line(campSys, 'Days_In/1', 'Monthly_Cap/2');
add_line(campSys, 'Daily_Cap/1', 'Patients_Per_Day/1'); add_line(campSys, 'Monthly_Cap/1', 'Patients_Per_Month/1');

add_line(modelName, 'Devices_Per_Camp/1', '2. Screening Camp Capacity/1');
add_line(modelName, 'Camp_Days_Per_Month/1', '2. Screening Camp Capacity/2');

% ════════════════════════════════════════════════════════
% SUBSYSTEM 3: AI TRIAGE & DOCTOR REVIEW
% ════════════════════════════════════════════════════════
docSys = [modelName '/3. AI Triage & Doctor Escalation'];
add_block('simulink/Ports & Subsystems/Subsystem', docSys, 'Position', [400 200 560 250], 'BackgroundColor', 'orange');
% Inside docSys
add_block('simulink/Sources/In1', [docSys '/Daily_Pats_In'], 'Position', [20 40 50 55]);
add_block('simulink/Sources/Constant', [docSys '/Escalation_Rate'], 'Value', '0.168', 'Position', [20 70 70 85]);
add_block('simulink/Math Operations/Product', [docSys '/Escalated'], 'Position', [120 40 150 80]);
add_block('simulink/Math Operations/Gain', [docSys '/Util_Calc'], 'Gain', '2/240', 'Position', [200 45 250 75]);
add_block('simulink/Sinks/Out1', [docSys '/Escalated_Per_Day'], 'Position', [200 20 230 35]);
add_block('simulink/Sinks/Out1', [docSys '/Doctor_Utilization'], 'Position', [300 55 330 70]);
add_line(docSys, 'Daily_Pats_In/1', 'Escalated/1'); add_line(docSys, 'Escalation_Rate/1', 'Escalated/2');
add_line(docSys, 'Escalated/1', 'Util_Calc/1'); add_line(docSys, 'Escalated/1', 'Escalated_Per_Day/1');
add_line(docSys, 'Util_Calc/1', 'Doctor_Utilization/1');

add_line(modelName, '2. Screening Camp Capacity/1', '3. AI Triage & Doctor Escalation/1');

% ════════════════════════════════════════════════════════
% SUBSYSTEM 4: TREATMENT GAP ANALYSIS
% ════════════════════════════════════════════════════════
gapSys = [modelName '/4. Referral & Treatment Gap'];
add_block('simulink/Ports & Subsystems/Subsystem', gapSys, 'Position', [400 70 560 120], 'BackgroundColor', 'magenta');
% Inside gapSys
add_block('simulink/Sources/In1', [gapSys '/DiabPop_In'], 'Position', [20 40 50 55]);
add_block('simulink/Sources/Constant', [gapSys '/Referable_Rate'], 'Value', '0.30', 'Position', [20 70 70 85]);
add_block('simulink/Sources/Constant', [gapSys '/Adherence'], 'Value', 'sim_adherence', 'Position', [100 120 150 135]);
add_block('simulink/Math Operations/Product', [gapSys '/Needing'], 'Position', [120 40 150 80]);
add_block('simulink/Math Operations/Product', [gapSys '/Treated'], 'Position', [220 50 250 90]);
add_block('simulink/Math Operations/Sum', [gapSys '/Gap'], 'Inputs', '+-', 'Position', [320 45 350 75]);
add_block('simulink/Sinks/Out1', [gapSys '/Patients_Needing'], 'Position', [220 20 250 35]);
add_block('simulink/Sinks/Out1', [gapSys '/Patients_Treated'], 'Position', [320 90 350 105]);
add_block('simulink/Sinks/Out1', [gapSys '/Treatment_Gap'], 'Position', [400 55 430 70]);

add_line(gapSys, 'DiabPop_In/1', 'Needing/1'); add_line(gapSys, 'Referable_Rate/1', 'Needing/2');
add_line(gapSys, 'Needing/1', 'Patients_Needing/1'); add_line(gapSys, 'Needing/1', 'Treated/1');
add_line(gapSys, 'Adherence/1', 'Treated/2'); add_line(gapSys, 'Treated/1', 'Patients_Treated/1');
add_line(gapSys, 'Needing/1', 'Gap/1'); add_line(gapSys, 'Treated/1', 'Gap/2'); add_line(gapSys, 'Gap/1', 'Treatment_Gap/1');

add_line(modelName, '1. Patient Population Model/1', '4. Referral & Treatment Gap/1');

% ════════════════════════════════════════════════════════
% GLOBAL METRICS: COVERAGE TIMELINE
% ════════════════════════════════════════════════════════
add_block('simulink/Math Operations/Product', [modelName '/Months_To_Screen'], 'Inputs', '*/', 'Position', [420 135 450 175]);
add_line(modelName, '1. Patient Population Model/1', 'Months_To_Screen/1');
add_line(modelName, '2. Screening Camp Capacity/2', 'Months_To_Screen/2');

% ════════════════════════════════════════════════════════
% OUTPUTS (To Workspace & Displays)
% ════════════════════════════════════════════════════════
add_block('simulink/Sinks/To Workspace', [modelName '/ws_diab_pop'], 'VariableName', 'out_diabetic_pop', 'Position', [650 35 770 65]);
add_block('simulink/Sinks/To Workspace', [modelName '/ws_needing'], 'VariableName', 'out_patients_needing', 'Position', [650 75 770 105]);
add_block('simulink/Sinks/To Workspace', [modelName '/ws_treated'], 'VariableName', 'out_patients_treated', 'Position', [650 115 770 145]);
add_block('simulink/Sinks/To Workspace', [modelName '/ws_gap'], 'VariableName', 'out_treatment_gap', 'Position', [650 155 770 185]);
add_block('simulink/Sinks/Display', [modelName '/Disp_Gap'], 'Position', [800 155 880 185]);

add_block('simulink/Sinks/To Workspace', [modelName '/ws_months'], 'VariableName', 'out_months_to_screen', 'Position', [650 200 770 230]);
add_block('simulink/Sinks/To Workspace', [modelName '/ws_escalated'], 'VariableName', 'out_escalated_day', 'Position', [650 240 770 270]);
add_block('simulink/Sinks/To Workspace', [modelName '/ws_doc_util'], 'VariableName', 'out_doctor_util', 'Position', [650 280 770 310]);
add_block('simulink/Sinks/Display', [modelName '/Disp_Util'], 'Position', [800 280 880 310]);

% Connect remaining
add_block('simulink/Signal Routing/Goto', [modelName '/goto_pop'], 'GotoTag', 'POP', 'Position', [340 75 380 95]);
add_line(modelName, '1. Patient Population Model/1', 'goto_pop/1');
add_block('simulink/Signal Routing/From', [modelName '/from_pop'], 'GotoTag', 'POP', 'Position', [550 40 600 60]);
add_line(modelName, 'from_pop/1', 'ws_diab_pop/1');

add_line(modelName, '4. Referral & Treatment Gap/1', 'ws_needing/1');
add_line(modelName, '4. Referral & Treatment Gap/2', 'ws_treated/1');
add_line(modelName, '4. Referral & Treatment Gap/3', 'ws_gap/1');
add_line(modelName, '4. Referral & Treatment Gap/3', 'Disp_Gap/1');

add_line(modelName, 'Months_To_Screen/1', 'ws_months/1');
add_line(modelName, '3. AI Triage & Doctor Escalation/1', 'ws_escalated/1');
add_line(modelName, '3. AI Triage & Doctor Escalation/2', 'ws_doc_util/1');
add_line(modelName, '3. AI Triage & Doctor Escalation/2', 'Disp_Util/1');

% Add a final workspace out for PPCD and PPM so run_simulation doesn't break
add_block('simulink/Sinks/To Workspace', [modelName '/ws_ppcd'], 'VariableName', 'out_patients_camp_day', 'Position', [400 320 520 350]);
add_block('simulink/Sinks/To Workspace', [modelName '/ws_ppm'], 'VariableName', 'out_patients_month', 'Position', [400 370 520 400]);
add_line(modelName, '2. Screening Camp Capacity/1', 'ws_ppcd/1');
add_line(modelName, '2. Screening Camp Capacity/2', 'ws_ppm/1');

% ════════════════════════════════════════════════════════
% SAVE
% ════════════════════════════════════════════════════════
save_system(modelName, slxPath);
close_system(modelName);

fprintf('DrishtiSetu Professional Simulink Model Created Successfully!\n');
end
