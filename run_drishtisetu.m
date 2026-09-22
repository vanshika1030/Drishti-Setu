function run_drishtisetu()
% RUN_DRISHTISETU Main entry point for DrishtiSetu DR Screening App
%
%   run_drishtisetu()
%
%   Launches the DrishtiSetu programmatic GUI with:
%   - Role dropdown (top-right): Technician / Doctor / District Officer
%   - 3 panels that swap based on selected role
%   - Full pipeline integration
%
%   SIH 2026, PS 26038 — Diabetic Retinopathy Screening
%   Pure MATLAB. Offline-first. Rural India.

    % Add all pipeline modules to path
    rootDir = fileparts(mfilename('fullpath'));
    addpath(genpath(rootDir));
    
    % Load configuration
    cfg = pipeline_config();
    
    % Create app state
    app = struct();
    app.cfg = cfg;
    app.rootDir = rootDir;
    app.currentRole = 'Technician';
    app.retakeCount = 0;
    app.maxRetakes = cfg.max_retake_attempts;
    app.currentEye = 'Right';
    app.leftResult = [];
    app.rightResult = [];
    app.patientInfo = struct('name', '', 'age', '', 'dm_years', '', 'abha_id', '');
    app.videoMode = false;
    app.escalatedQueue = {};
    app.screeningLog = {};
    
    % ============================================================
    % CREATE MAIN FIGURE
    % ============================================================
    app.fig = uifigure('Name', 'DrishtiSetu — DR Screening', ...
        'Position', [50 50 1280 800], ...
        'Color', [0.95 0.96 0.97], ...
        'CloseRequestFcn', @(~,~) closeFig(app));
    
    % ============================================================
    % TOP BAR
    % ============================================================
    topPanel = uipanel(app.fig, 'Position', [0 760 1280 40], ...
        'BackgroundColor', [0.13 0.35 0.55], 'BorderType', 'none');
    
    uilabel(topPanel, 'Position', [15 5 350 30], ...
        'Text', '🔬 DrishtiSetu — AI-Assisted DR Screening', ...
        'FontSize', 16, 'FontWeight', 'bold', 'FontColor', 'white');
    
    uilabel(topPanel, 'Position', [980 8 60 25], ...
        'Text', 'Role:', 'FontSize', 13, 'FontColor', 'white');
    
    app.roleDropdown = uidropdown(topPanel, ...
        'Position', [1040 6 220 28], ...
        'Items', {'Technician (तकनीशियन)', 'Doctor (डॉक्टर)', 'District Officer (जिला अधिकारी)'}, ...
        'Value', 'Technician (तकनीशियन)', ...
        'ValueChangedFcn', @(dd, ~) switchRole(app, dd.Value));
    
    % ============================================================
    % THREE ROLE PANELS (only one visible at a time)
    % ============================================================
    panelPos = [0 0 1280 760];
    
    % --- TECHNICIAN PANEL ---
    app.techPanel = uipanel(app.fig, 'Position', panelPos, ...
        'BackgroundColor', [0.95 0.96 0.97], 'BorderType', 'none', ...
        'Visible', 'on');
    buildTechnicianPanel(app);
    
    % --- DOCTOR PANEL ---
    app.docPanel = uipanel(app.fig, 'Position', panelPos, ...
        'BackgroundColor', [0.95 0.96 0.97], 'BorderType', 'none', ...
        'Visible', 'off');
    buildDoctorPanel(app);
    
    % --- DISTRICT PANEL ---
    app.distPanel = uipanel(app.fig, 'Position', panelPos, ...
        'BackgroundColor', [0.95 0.96 0.97], 'BorderType', 'none', ...
        'Visible', 'off');
    buildDistrictPanel(app);
    
    % Store app in figure for access in callbacks
    app.fig.UserData = app;
    
    fprintf('DrishtiSetu launched successfully.\n');
    fprintf('Pipeline root: %s\n', rootDir);
    fprintf('Model directory: %s\n', cfg.model_dir);
end

% ================================================================
% ROLE SWITCHING
% ================================================================
function switchRole(app, roleStr)
    app = app.fig.UserData;
    if contains(roleStr, 'Technician')
        app.techPanel.Visible = 'on';
        app.docPanel.Visible = 'off';
        app.distPanel.Visible = 'off';
        app.currentRole = 'Technician';
    elseif contains(roleStr, 'Doctor')
        app.techPanel.Visible = 'off';
        app.docPanel.Visible = 'on';
        app.distPanel.Visible = 'off';
        app.currentRole = 'Doctor';
        refreshDoctorQueue(app);
    else
        app.techPanel.Visible = 'off';
        app.docPanel.Visible = 'off';
        app.distPanel.Visible = 'on';
        app.currentRole = 'District';
        refreshDistrictDashboard(app);
    end
    app.fig.UserData = app;
end

% ================================================================
% TECHNICIAN PANEL
% ================================================================
function buildTechnicianPanel(app)
    p = app.techPanel;
    
    % --- LEFT COLUMN: Patient Info + Controls ---
    leftBox = uipanel(p, 'Position', [15 15 380 730], ...
        'Title', '📋 Patient Information (रोगी जानकारी)', ...
        'FontSize', 13, 'FontWeight', 'bold');
    
    % Consent
    app.consentCheck1 = uicheckbox(leftBox, 'Position', [15 670 350 22], ...
        'Text', '☑ AI सहायता आधारित जाँच (निदान नहीं)', 'FontSize', 11);
    app.consentCheck2 = uicheckbox(leftBox, 'Position', [15 645 350 22], ...
        'Text', '☑ डेटा स्थानीय रूप से संग्रहीत (DPDP Act)', 'FontSize', 11);
    
    % Name
    uilabel(leftBox, 'Position', [15 605 100 22], 'Text', 'नाम (Name):', 'FontSize', 12);
    app.nameField = uieditfield(leftBox, 'Position', [120 605 240 25], 'FontSize', 12);
    
    % Age
    uilabel(leftBox, 'Position', [15 570 100 22], 'Text', 'उम्र (Age):', 'FontSize', 12);
    app.ageField = uieditfield(leftBox, 'numeric', 'Position', [120 570 80 25], 'FontSize', 12);
    
    % DM Duration
    uilabel(leftBox, 'Position', [15 535 120 22], 'Text', 'DM अवधि (yrs):', 'FontSize', 12);
    app.dmField = uieditfield(leftBox, 'numeric', 'Position', [140 535 60 25], 'FontSize', 12);
    
    % ABHA ID
    uilabel(leftBox, 'Position', [15 500 100 22], 'Text', 'ABHA ID:', 'FontSize', 12);
    app.abhaField = uieditfield(leftBox, 'Position', [120 500 240 25], 'FontSize', 12);
    
    % Eye selector
    uilabel(leftBox, 'Position', [15 455 100 22], 'Text', 'आँख (Eye):', 'FontSize', 13, 'FontWeight', 'bold');
    app.eyeGroup = uibuttongroup(leftBox, 'Position', [120 450 240 30], 'BorderType', 'none');
    uiradiobutton(app.eyeGroup, 'Position', [5 5 100 22], 'Text', 'दाहिनी (Right)', 'FontSize', 11);
    uiradiobutton(app.eyeGroup, 'Position', [120 5 100 22], 'Text', 'बाएं (Left)', 'FontSize', 11);
    
    % Input mode
    uilabel(leftBox, 'Position', [15 415 150 22], 'Text', 'Input Mode:', 'FontSize', 12);
    app.modeDropdown = uidropdown(leftBox, 'Position', [120 413 240 25], ...
        'Items', {'📷 Still Photo', '🎥 Video Capture'}, ...
        'FontSize', 11);
    
    % Load buttons
    app.loadBtn = uibutton(leftBox, 'Position', [15 365 345 45], ...
        'Text', '📂 Load Image / Video', 'FontSize', 14, 'FontWeight', 'bold', ...
        'BackgroundColor', [0.2 0.6 0.9], 'FontColor', 'white', ...
        'ButtonPushedFcn', @(~,~) loadImage(app));
    
    % Quality display
    app.qualityLabel = uilabel(leftBox, 'Position', [15 325 345 30], ...
        'Text', 'Quality: Not assessed', 'FontSize', 13, ...
        'FontWeight', 'bold', 'HorizontalAlignment', 'center');
    app.retakeLabel = uilabel(leftBox, 'Position', [15 300 345 22], ...
        'Text', '', 'FontSize', 11, 'HorizontalAlignment', 'center');
    
    % RUN ANALYSIS BUTTON
    app.runBtn = uibutton(leftBox, 'Position', [15 240 345 55], ...
        'Text', '▶️ जाँच शुरू करें (Run Analysis)', 'FontSize', 16, 'FontWeight', 'bold', ...
        'BackgroundColor', [0.2 0.7 0.3], 'FontColor', 'white', ...
        'Enable', 'off', ...
        'ButtonPushedFcn', @(~,~) runAnalysis(app));
    
    % Progress
    app.progressLabel = uilabel(leftBox, 'Position', [15 210 345 25], ...
        'Text', '', 'FontSize', 11, 'HorizontalAlignment', 'center');
    
    % RESULT DISPLAY
    app.resultPanel = uipanel(leftBox, 'Position', [15 80 345 120], ...
        'BackgroundColor', [0.93 0.93 0.93], 'BorderType', 'line');
    app.resultLabel = uilabel(app.resultPanel, 'Position', [10 60 325 50], ...
        'Text', 'परिणाम यहाँ दिखेगा', 'FontSize', 20, 'FontWeight', 'bold', ...
        'HorizontalAlignment', 'center');
    app.resultDetail = uilabel(app.resultPanel, 'Position', [10 10 325 45], ...
        'Text', '', 'FontSize', 12, 'HorizontalAlignment', 'center', ...
        'WordWrap', 'on');
    
    % Action buttons
    app.printBtn = uibutton(leftBox, 'Position', [15 35 165 35], ...
        'Text', '🖨️ Print Report', 'FontSize', 12, 'Enable', 'off', ...
        'ButtonPushedFcn', @(~,~) printReport(app));
    app.nextBtn = uibutton(leftBox, 'Position', [195 35 165 35], ...
        'Text', '➡️ Next Patient', 'FontSize', 12, ...
        'ButtonPushedFcn', @(~,~) nextPatient(app));
    
    % --- RIGHT COLUMN: Image Display ---
    rightBox = uipanel(p, 'Position', [410 15 855 730], ...
        'Title', '🖼️ Fundus Image', 'FontSize', 13, 'FontWeight', 'bold');
    
    % Main image axes
    app.imgAxes = uiaxes(rightBox, 'Position', [15 370 400 330]);
    title(app.imgAxes, 'Original Image');
    axis(app.imgAxes, 'image'); app.imgAxes.XTick = []; app.imgAxes.YTick = [];
    
    % Quality heatmap axes
    app.qualAxes = uiaxes(rightBox, 'Position', [430 370 400 330]);
    title(app.qualAxes, 'Quality Heatmap');
    axis(app.qualAxes, 'image'); app.qualAxes.XTick = []; app.qualAxes.YTick = [];
    
    % Lesion overlay axes
    app.overlayAxes = uiaxes(rightBox, 'Position', [15 20 400 330]);
    title(app.overlayAxes, 'Lesion Overlay');
    axis(app.overlayAxes, 'image'); app.overlayAxes.XTick = []; app.overlayAxes.YTick = [];
    
    % Grad-CAM axes
    app.gcamAxes = uiaxes(rightBox, 'Position', [430 20 400 330]);
    title(app.gcamAxes, 'Grad-CAM Attention');
    axis(app.gcamAxes, 'image'); app.gcamAxes.XTick = []; app.gcamAxes.YTick = [];
end

% ================================================================
% DOCTOR PANEL
% ================================================================
function buildDoctorPanel(app)
    p = app.docPanel;
    
    % Queue list
    queueBox = uipanel(p, 'Position', [15 15 300 730], ...
        'Title', '📋 Escalated Cases Queue', 'FontSize', 13, 'FontWeight', 'bold');
    
    app.queueList = uilistbox(queueBox, 'Position', [10 50 280 640], ...
        'FontSize', 12, 'Items', {'No escalated cases'}, ...
        'ValueChangedFcn', @(lb, ~) loadEscalatedCase(app, lb.Value));
    
    app.refreshQueueBtn = uibutton(queueBox, 'Position', [10 10 280 30], ...
        'Text', '🔄 Refresh Queue', 'FontSize', 11, ...
        'ButtonPushedFcn', @(~,~) refreshDoctorQueue(app));
    
    % Case detail panel
    detailBox = uipanel(p, 'Position', [330 15 935 730], ...
        'Title', '🔬 Case Review', 'FontSize', 13, 'FontWeight', 'bold');
    
    % Patient info
    app.docPatientLabel = uilabel(detailBox, 'Position', [15 680 500 30], ...
        'Text', 'Select a case from the queue', 'FontSize', 14, 'FontWeight', 'bold');
    
    % Escalation reason
    app.escReasonLabel = uilabel(detailBox, 'Position', [15 650 900 25], ...
        'Text', '', 'FontSize', 13, 'FontColor', [0.8 0.2 0.2], 'FontWeight', 'bold');
    
    % Evidence images
    app.docImgAxes = uiaxes(detailBox, 'Position', [15 340 290 290]);
    title(app.docImgAxes, 'Enhanced Image');
    axis(app.docImgAxes, 'image'); app.docImgAxes.XTick = []; app.docImgAxes.YTick = [];
    
    app.docOverlayAxes = uiaxes(detailBox, 'Position', [320 340 290 290]);
    title(app.docOverlayAxes, 'Lesion Overlay');
    axis(app.docOverlayAxes, 'image'); app.docOverlayAxes.XTick = []; app.docOverlayAxes.YTick = [];
    
    app.docGcamAxes = uiaxes(detailBox, 'Position', [625 340 290 290]);
    title(app.docGcamAxes, 'Grad-CAM');
    axis(app.docGcamAxes, 'image'); app.docGcamAxes.XTick = []; app.docGcamAxes.YTick = [];
    
    % Evidence text
    app.evidenceText = uitextarea(detailBox, 'Position', [15 120 600 210], ...
        'FontSize', 11, 'Editable', 'off', 'Value', {'Evidence chain will appear here'});
    
    % Metrics
    metricsBox = uipanel(detailBox, 'Position', [630 120 280 210], ...
        'Title', 'Metrics', 'FontSize', 11);
    app.docMetricsLabel = uilabel(metricsBox, 'Position', [10 10 260 170], ...
        'Text', '', 'FontSize', 11, 'WordWrap', 'on', 'VerticalAlignment', 'top');
    
    % Doctor actions
    actionBox = uipanel(detailBox, 'Position', [15 15 900 95], ...
        'Title', 'Doctor Action', 'FontSize', 12, 'FontWeight', 'bold', ...
        'BackgroundColor', [0.95 0.95 1.0]);
    
    app.confirmBtn = uibutton(actionBox, 'Position', [15 30 200 40], ...
        'Text', '✅ Confirm AI Grade', 'FontSize', 13, 'FontWeight', 'bold', ...
        'BackgroundColor', [0.2 0.7 0.3], 'FontColor', 'white', ...
        'Enable', 'off', ...
        'ButtonPushedFcn', @(~,~) doctorConfirm(app));
    
    uilabel(actionBox, 'Position', [240 35 80 25], 'Text', 'Override to:', 'FontSize', 12);
    app.overrideDropdown = uidropdown(actionBox, 'Position', [320 33 150 28], ...
        'Items', {'Grade 0', 'Grade 1', 'Grade 2', 'Grade 3', 'Grade 4'}, ...
        'FontSize', 11);
    
    uilabel(actionBox, 'Position', [240 5 80 25], 'Text', 'Reason:', 'FontSize', 12);
    app.overrideReason = uieditfield(actionBox, 'Position', [320 3 350 28], ...
        'Placeholder', 'Typed reason required for override', 'FontSize', 11);
    
    app.overrideBtn = uibutton(actionBox, 'Position', [690 30 200 40], ...
        'Text', '✏️ Override Grade', 'FontSize', 13, 'FontWeight', 'bold', ...
        'BackgroundColor', [0.9 0.5 0.1], 'FontColor', 'white', ...
        'Enable', 'off', ...
        'ButtonPushedFcn', @(~,~) doctorOverride(app));
end

% ================================================================
% DISTRICT OFFICER PANEL
% ================================================================
function buildDistrictPanel(app)
    p = app.distPanel;
    
    % Left: Metrics
    metricsBox = uipanel(p, 'Position', [15 380 630 365], ...
        'Title', '📊 Validation Metrics', 'FontSize', 13, 'FontWeight', 'bold');
    
    app.metricsText = uitextarea(metricsBox, 'Position', [10 10 610 320], ...
        'FontSize', 11, 'Editable', 'off', ...
        'Value', {'Metrics will load from validation_results.mat', ...
                  'Run validate_pipeline(pipeline_config()) to generate.'});
    
    % Right: Reliability diagram
    reliabilityBox = uipanel(p, 'Position', [660 380 605 365], ...
        'Title', '📈 Reliability Diagram', 'FontSize', 13, 'FontWeight', 'bold');
    app.relDiagAxes = uiaxes(reliabilityBox, 'Position', [10 10 580 310]);
    title(app.relDiagAxes, 'Reliability Diagram');
    
    % Left bottom: Escalation breakdown
    escBox = uipanel(p, 'Position', [15 15 630 355], ...
        'Title', '🔔 Escalation Breakdown & Ablation', 'FontSize', 13, 'FontWeight', 'bold');
    app.escText = uitextarea(escBox, 'Position', [10 10 610 310], ...
        'FontSize', 11, 'Editable', 'off', ...
        'Value', {'Escalation breakdown and ablation results will appear here.'});
    
    % Right bottom: Simulation
    simBox = uipanel(p, 'Position', [660 15 605 355], ...
        'Title', '⚙️ Screening Simulation', 'FontSize', 13, 'FontWeight', 'bold');
    
    % Simulation parameters
    uilabel(simBox, 'Position', [15 290 150 22], 'Text', 'Population:', 'FontSize', 11);
    app.simPopField = uieditfield(simBox, 'numeric', 'Position', [170 290 100 22], 'Value', 500000);
    
    uilabel(simBox, 'Position', [15 260 150 22], 'Text', 'DM Prevalence:', 'FontSize', 11);
    app.simDmField = uieditfield(simBox, 'numeric', 'Position', [170 260 100 22], 'Value', 0.12);
    
    uilabel(simBox, 'Position', [15 230 150 22], 'Text', 'Camp days/month:', 'FontSize', 11);
    app.simCampField = uieditfield(simBox, 'numeric', 'Position', [170 230 100 22], 'Value', 4);
    
    uilabel(simBox, 'Position', [15 200 150 22], 'Text', 'Devices/camp:', 'FontSize', 11);
    app.simDevField = uieditfield(simBox, 'numeric', 'Position', [170 200 100 22], 'Value', 3);
    
    uilabel(simBox, 'Position', [290 290 170 22], 'Text', 'Referral adherence:', 'FontSize', 11);
    app.simAdhSlider = uislider(simBox, 'Position', [290 275 270 3], ...
        'Limits', [0.11 0.57], 'Value', 0.145);
    app.simAdhLabel = uilabel(simBox, 'Position', [565 268 40 22], 'Text', '14.5%', 'FontSize', 10);
    app.simAdhSlider.ValueChangedFcn = @(s,~) set(app.simAdhLabel, 'Text', sprintf('%.1f%%', s.Value*100));
    
    app.runSimBtn = uibutton(simBox, 'Position', [290 225 280 30], ...
        'Text', '▶️ Run Simulation', 'FontSize', 12, 'FontWeight', 'bold', ...
        'BackgroundColor', [0.2 0.6 0.9], 'FontColor', 'white', ...
        'ButtonPushedFcn', @(~,~) runSimFromGUI(app));
    
    app.simResultText = uitextarea(simBox, 'Position', [15 10 570 205], ...
        'FontSize', 10, 'Editable', 'off', ...
        'Value', {'Simulation results will appear here.'});
end

% ================================================================
% CALLBACKS — TECHNICIAN
% ================================================================
function loadImage(app)
    app = app.fig.UserData;
    
    if contains(app.modeDropdown.Value, 'Video')
        [fname, fpath] = uigetfile({'*.mp4;*.avi;*.mov', 'Video Files'}, 'Select Fundus Video');
        if isequal(fname, 0), return; end
        
        app.progressLabel.Text = 'Extracting best frame from video...';
        drawnow;
        
        try
            [best_frame, score, ~, ~] = extract_sharpest_frame(fullfile(fpath, fname));
            app.currentImage = best_frame;
            app.progressLabel.Text = sprintf('Best frame extracted (score=%.1f)', score);
        catch ME
            uialert(app.fig, ME.message, 'Video Error');
            return;
        end
    else
        [fname, fpath] = uigetfile({'*.png;*.jpg;*.jpeg;*.tif;*.bmp;*.dcm', 'Image Files'}, 'Select Fundus Image');
        if isequal(fname, 0), return; end
        
        filepath = fullfile(fpath, fname);
        
        % DICOM support
        if endsWith(lower(fname), '.dcm')
            try
                app.currentImage = dicomread(filepath);
                info = dicominfo(filepath);
                app.progressLabel.Text = sprintf('DICOM loaded: %s', info.PatientName.FamilyName);
            catch
                app.currentImage = imread(filepath);
            end
        else
            app.currentImage = imread(filepath);
        end
    end
    
    % Standardize
    app.progressLabel.Text = 'Standardizing image...';
    drawnow;
    [app.stdImage, app.retinaMask, app.fovProps] = standardize_for_pipeline(app.currentImage);
    
    % Display
    imshow(app.stdImage, 'Parent', app.imgAxes);
    title(app.imgAxes, 'Standardized Image');
    
    % Quality check
    app.progressLabel.Text = 'Checking image quality...';
    drawnow;
    [pass_flag, feedback, quality_info] = assess_quality(app.stdImage, app.retinaMask);
    
    % Display quality heatmap
    displayQualityHeatmap(app, quality_info);
    
    if pass_flag
        app.qualityLabel.Text = '🟢 Quality: PASS';
        app.qualityLabel.FontColor = [0.1 0.6 0.1];
        app.retakeLabel.Text = '';
        app.runBtn.Enable = 'on';
        app.retakeCount = 0;
    else
        app.retakeCount = app.retakeCount + 1;
        if app.retakeCount >= app.maxRetakes
            app.qualityLabel.Text = '🔴 UNGRADEABLE — Auto-referring';
            app.qualityLabel.FontColor = [0.8 0.1 0.1];
            app.retakeLabel.Text = sprintf('3/3 retakes failed. Reason: %s', feedback);
            % Create ungradeable result
            eye = getCurrentEye(app);
            result = struct('grade', -1, 'pRef', NaN, 'confidence', NaN, ...
                'decision', 'UNGRADEABLE', 'escalation_reason', 'Quality failed after 3 retakes', ...
                'dme_suspected', false);
            if strcmp(eye, 'Right')
                app.rightResult = result;
            else
                app.leftResult = result;
            end
            app.resultLabel.Text = '🔴 अनिश्चित (Ungradeable)';
            app.resultPanel.BackgroundColor = [1 0.85 0.85];
            app.resultDetail.Text = sprintf('Reason: %s. Referred to hospital.', feedback);
            app.printBtn.Enable = 'on';
        else
            app.qualityLabel.Text = sprintf('🔴 Quality: FAIL (%d/%d)', app.retakeCount, app.maxRetakes);
            app.qualityLabel.FontColor = [0.8 0.1 0.1];
            app.retakeLabel.Text = sprintf('Feedback: %s. Please retake.', feedback);
            app.runBtn.Enable = 'off';
        end
    end
    
    app.progressLabel.Text = '';
    app.fig.UserData = app;
end

function runAnalysis(app)
    app = app.fig.UserData;
    
    if ~isfield(app, 'stdImage') || isempty(app.stdImage)
        uialert(app.fig, 'Load an image first.', 'No Image');
        return;
    end
    
    % Check consent
    if ~app.consentCheck1.Value || ~app.consentCheck2.Value
        uialert(app.fig, 'Consent checkboxes must be checked.', 'Consent Required');
        return;
    end
    
    cfg = app.cfg;
    tic;
    
    % Step 1: Segmentation
    app.progressLabel.Text = 'Step 1/4: Segmenting retinal structures...';
    drawnow;
    [all_masks, lesion_counts, seg_info] = segment_all(app.stdImage, app.retinaMask, cfg);
    
    % Display overlay
    if isfield(seg_info, 'overlay_img') && ~isempty(seg_info.overlay_img)
        imshow(seg_info.overlay_img, 'Parent', app.overlayAxes);
    end
    title(app.overlayAxes, 'Lesion Overlay');
    
    % Step 2: Grading
    app.progressLabel.Text = 'Step 2/4: Grading with ensemble...';
    drawnow;
    grade_result = grade_dr_ensemble(app.stdImage, app.retinaMask, seg_info, cfg);
    
    % Add segmentation results to grade_result
    grade_result.lesion_counts = lesion_counts;
    grade_result.seg_info = seg_info;
    grade_result.all_masks = all_masks;
    
    % Step 3: Explainability (gated)
    app.progressLabel.Text = 'Step 3/4: Generating explanations...';
    drawnow;
    explain_result = explain_prediction(app.stdImage, app.retinaMask, grade_result, seg_info, cfg);
    grade_result.explain = explain_result;
    
    % Display Grad-CAM
    if isfield(explain_result, 'gradcam_overlay') && ~isempty(explain_result.gradcam_overlay)
        imshow(explain_result.gradcam_overlay, 'Parent', app.gcamAxes);
    end
    title(app.gcamAxes, 'Grad-CAM Attention');
    
    % Step 4: Display result
    elapsed = toc;
    app.progressLabel.Text = sprintf('Complete in %.1f sec', elapsed);
    
    eye = getCurrentEye(app);
    grade_result.eye = eye;
    grade_result.elapsed_sec = elapsed;
    
    % Store result
    if strcmp(eye, 'Right')
        app.rightResult = grade_result;
    else
        app.leftResult = grade_result;
    end
    
    % Display result in Hindi
    displayResult(app, grade_result);
    
    % If escalated, add to queue
    if strcmp(grade_result.decision, 'ESCALATE')
        caseData = struct();
        caseData.patientInfo = getPatientInfo(app);
        caseData.grade_result = grade_result;
        caseData.image = app.stdImage;
        caseData.timestamp = datestr(now);
        app.escalatedQueue{end+1} = caseData;
    end
    
    app.printBtn.Enable = 'on';
    app.fig.UserData = app;
end

function displayResult(app, result)
    cfg = app.cfg;
    grade = result.grade;
    
    if grade < 0
        app.resultLabel.Text = '🔴 अनिश्चित (Ungradeable)';
        app.resultPanel.BackgroundColor = [1 0.85 0.85];
        app.resultDetail.Text = 'Referred to hospital';
        return;
    end
    
    hindi_grades = cfg.icdr_hindi;
    
    if grade <= 1
        color = [0.85 1 0.85]; % green
        emoji = '🟢';
    elseif grade == 2
        color = [1 1 0.8]; % yellow
        emoji = '🟡';
    else
        color = [1 0.85 0.85]; % red
        emoji = '🔴';
    end
    
    app.resultPanel.BackgroundColor = color;
    
    if strcmp(result.decision, 'ESCALATE')
        app.resultLabel.Text = sprintf('%s अनिश्चित — Doctor review needed', emoji);
        app.resultDetail.Text = sprintf('Reason: %s', result.escalation_reason);
    else
        app.resultLabel.Text = sprintf('%s %s (Grade %d)', emoji, hindi_grades{grade+1}, grade);
        urgency = cfg.urgency_labels{min(grade+1, length(cfg.urgency_labels))};
        app.resultDetail.Text = urgency;
        if isfield(result, 'dme_suspected') && result.dme_suspected
            app.resultDetail.Text = [app.resultDetail.Text ' | ⚠️ DME suspected'];
        end
    end
end

function displayQualityHeatmap(app, quality_info)
    if ~isfield(quality_info, 'quality_map'), return; end
    
    qmap = quality_info.quality_map;
    [rows, cols] = size(qmap);
    heatmap_img = zeros(rows * 50, cols * 50, 3, 'uint8');
    
    for r = 1:rows
        for c = 1:cols
            r1 = (r-1)*50+1; r2 = r*50;
            c1 = (c-1)*50+1; c2 = c*50;
            
            status = qmap{r,c};
            if isempty(status) || strcmp(status, '')
                color = uint8([200 200 200]); % gray for skipped
            elseif strcmp(status, 'good')
                color = uint8([50 200 50]); % green
            elseif strcmp(status, 'blur')
                color = uint8([200 50 50]); % red
            elseif strcmp(status, 'dark')
                color = uint8([100 50 50]); % dark red
            elseif strcmp(status, 'glare')
                color = uint8([200 200 50]); % yellow
            else
                color = uint8([150 150 150]);
            end
            
            for ch = 1:3
                heatmap_img(r1:r2, c1:c2, ch) = color(ch);
            end
        end
    end
    
    imshow(heatmap_img, 'Parent', app.qualAxes);
    title(app.qualAxes, 'Quality Heatmap (🟢good 🔴blur/dark 🟡glare)');
end

function eye = getCurrentEye(app)
    app = app.fig.UserData;
    selected = app.eyeGroup.SelectedObject;
    if contains(selected.Text, 'Right') || contains(selected.Text, 'दाहिनी')
        eye = 'Right';
    else
        eye = 'Left';
    end
end

function info = getPatientInfo(app)
    app = app.fig.UserData;
    info = struct();
    info.name = app.nameField.Value;
    info.age = app.ageField.Value;
    info.dm_years = app.dmField.Value;
    info.abha_id = app.abhaField.Value;
end

function printReport(app)
    app = app.fig.UserData;
    
    patient_result = combine_eyes(app.leftResult, app.rightResult);
    patient_result.info = getPatientInfo(app);
    
    output_dir = fullfile(app.rootDir, 'data', 'screening_results');
    if ~exist(output_dir, 'dir'), mkdir(output_dir); end
    
    try
        pdf_path = generate_pdf_report(patient_result, output_dir);
        uialert(app.fig, sprintf('Report saved: %s', pdf_path), 'Report Generated', 'Icon', 'success');
    catch ME
        uialert(app.fig, ME.message, 'Report Error');
    end
end

function nextPatient(app)
    app = app.fig.UserData;
    
    % Reset
    app.nameField.Value = '';
    app.ageField.Value = 0;
    app.dmField.Value = 0;
    app.abhaField.Value = '';
    app.retakeCount = 0;
    app.leftResult = [];
    app.rightResult = [];
    app.consentCheck1.Value = false;
    app.consentCheck2.Value = false;
    app.qualityLabel.Text = 'Quality: Not assessed';
    app.qualityLabel.FontColor = [0 0 0];
    app.retakeLabel.Text = '';
    app.resultLabel.Text = 'परिणाम यहाँ दिखेगा';
    app.resultPanel.BackgroundColor = [0.93 0.93 0.93];
    app.resultDetail.Text = '';
    app.progressLabel.Text = '';
    app.runBtn.Enable = 'off';
    app.printBtn.Enable = 'off';
    
    cla(app.imgAxes); cla(app.qualAxes);
    cla(app.overlayAxes); cla(app.gcamAxes);
    
    app.fig.UserData = app;
end

% ================================================================
% CALLBACKS — DOCTOR
% ================================================================
function refreshDoctorQueue(app)
    app = app.fig.UserData;
    
    if isempty(app.escalatedQueue)
        app.queueList.Items = {'No escalated cases'};
        return;
    end
    
    items = {};
    for i = 1:length(app.escalatedQueue)
        c = app.escalatedQueue{i};
        name = 'Unknown';
        if isfield(c, 'patientInfo') && isfield(c.patientInfo, 'name')
            name = c.patientInfo.name;
        end
        items{i} = sprintf('#%d: %s — %s', i, name, c.grade_result.escalation_reason);
    end
    app.queueList.Items = items;
    app.fig.UserData = app;
end

function loadEscalatedCase(app, selectedValue)
    app = app.fig.UserData;
    if isempty(app.escalatedQueue), return; end
    
    % Parse case index
    idx = sscanf(selectedValue, '#%d');
    if isempty(idx) || idx < 1 || idx > length(app.escalatedQueue), return; end
    
    c = app.escalatedQueue{idx};
    app.currentDocCase = c;
    app.currentDocIdx = idx;
    
    % Display info
    app.docPatientLabel.Text = sprintf('Patient: %s | Age: %d | Eye: %s', ...
        c.patientInfo.name, c.patientInfo.age, c.grade_result.eye);
    app.escReasonLabel.Text = sprintf('⚠️ Escalation: %s', c.grade_result.escalation_reason);
    
    % Display images
    if isfield(c, 'image') && ~isempty(c.image)
        imshow(c.image, 'Parent', app.docImgAxes);
    end
    if isfield(c.grade_result, 'seg_info') && isfield(c.grade_result.seg_info, 'overlay_img')
        imshow(c.grade_result.seg_info.overlay_img, 'Parent', app.docOverlayAxes);
    end
    if isfield(c.grade_result, 'explain') && isfield(c.grade_result.explain, 'gradcam_overlay')
        imshow(c.grade_result.explain.gradcam_overlay, 'Parent', app.docGcamAxes);
    end
    
    % Evidence text
    cfg = app.cfg;
    evidence = format_evidence_chain(c.grade_result, c.grade_result.seg_info, c.grade_result.explain, cfg);
    app.evidenceText.Value = strsplit(evidence, newline);
    
    % Metrics
    app.docMetricsLabel.Text = sprintf(['Grade: %d\npRef: %.3f\n' ...
        'Confidence: %.3f\nAgreement: %s\nDME: %s'], ...
        c.grade_result.grade, c.grade_result.pRef, c.grade_result.confidence, ...
        mat2str(c.grade_result.agreement), mat2str(c.grade_result.dme_suspected));
    
    app.confirmBtn.Enable = 'on';
    app.overrideBtn.Enable = 'on';
    app.fig.UserData = app;
end

function doctorConfirm(app)
    app = app.fig.UserData;
    if ~isfield(app, 'currentDocCase'), return; end
    
    c = app.currentDocCase;
    
    % Log
    logEntry = sprintf('%s,%s,%d,%.3f,%d,CONFIRMED,,%s', ...
        c.patientInfo.name, c.grade_result.eye, c.grade_result.grade, ...
        c.grade_result.pRef, c.grade_result.grade, datestr(now));
    appendToLog(app, logEntry);
    
    % Remove from queue
    app.escalatedQueue(app.currentDocIdx) = [];
    refreshDoctorQueue(app);
    
    uialert(app.fig, 'Grade confirmed and logged.', 'Confirmed', 'Icon', 'success');
    app.confirmBtn.Enable = 'off';
    app.overrideBtn.Enable = 'off';
    app.fig.UserData = app;
end

function doctorOverride(app)
    app = app.fig.UserData;
    if ~isfield(app, 'currentDocCase'), return; end
    
    reason = app.overrideReason.Value;
    if isempty(strtrim(reason))
        uialert(app.fig, 'Reason is mandatory for override.', 'Reason Required');
        return;
    end
    
    c = app.currentDocCase;
    newGrade = sscanf(app.overrideDropdown.Value, 'Grade %d');
    
    % Log
    logEntry = sprintf('%s,%s,%d,%.3f,%d,OVERRIDDEN,%s,%s', ...
        c.patientInfo.name, c.grade_result.eye, c.grade_result.grade, ...
        c.grade_result.pRef, newGrade, reason, datestr(now));
    appendToLog(app, logEntry);
    
    % Remove from queue
    app.escalatedQueue(app.currentDocIdx) = [];
    refreshDoctorQueue(app);
    
    uialert(app.fig, sprintf('Grade overridden to %d. Logged.', newGrade), 'Overridden', 'Icon', 'info');
    app.confirmBtn.Enable = 'off';
    app.overrideBtn.Enable = 'off';
    app.overrideReason.Value = '';
    app.fig.UserData = app;
end

function appendToLog(app, logEntry)
    logFile = fullfile(app.rootDir, 'data', 'screening_log.csv');
    logDir = fileparts(logFile);
    if ~exist(logDir, 'dir'), mkdir(logDir); end
    
    if ~exist(logFile, 'file')
        fid = fopen(logFile, 'w');
        fprintf(fid, 'patient_name,eye,ai_grade,ai_pRef,doctor_grade,action,reason,timestamp\n');
        fclose(fid);
    end
    
    fid = fopen(logFile, 'a');
    fprintf(fid, '%s\n', logEntry);
    fclose(fid);
end

% ================================================================
% CALLBACKS — DISTRICT OFFICER
% ================================================================
function refreshDistrictDashboard(app)
    app = app.fig.UserData;
    cfg = app.cfg;
    
    % Load validation results if available
    valFile = fullfile(cfg.model_dir, 'validation_results.mat');
    if exist(valFile, 'file')
        val = load(valFile);
        
        metricsStr = {};
        if isfield(val, 'metrics')
            m = val.metrics;
            metricsStr{end+1} = '=== Validation Metrics ===';
            metricsStr{end+1} = sprintf('Referable-DR Sensitivity: %.1f%% [%.1f%%, %.1f%%]', ...
                m.sensitivity*100, m.sensitivity_ci(1)*100, m.sensitivity_ci(2)*100);
            metricsStr{end+1} = sprintf('Referable-DR Specificity: %.1f%% [%.1f%%, %.1f%%]', ...
                m.specificity*100, m.specificity_ci(1)*100, m.specificity_ci(2)*100);
            metricsStr{end+1} = sprintf('AUROC: %.4f', m.auroc);
            metricsStr{end+1} = sprintf('QWK: %.4f', m.qwk);
            metricsStr{end+1} = sprintf('ECE: %.4f', m.ece);
        end
        app.metricsText.Value = metricsStr;
        
        % Reliability diagram
        if isfield(val, 'bin_accs') && isfield(val, 'bin_confs')
            bar(app.relDiagAxes, val.bin_confs, val.bin_accs);
            hold(app.relDiagAxes, 'on');
            plot(app.relDiagAxes, [0 1], [0 1], 'r--', 'LineWidth', 2);
            hold(app.relDiagAxes, 'off');
            xlabel(app.relDiagAxes, 'Mean Predicted Confidence');
            ylabel(app.relDiagAxes, 'Fraction of Positives');
            title(app.relDiagAxes, sprintf('Reliability Diagram (ECE=%.4f)', m.ece));
        end
    else
        app.metricsText.Value = {'No validation_results.mat found.', ...
            'Run: results = validate_pipeline(pipeline_config());'};
    end
    
    % Load screening log
    logFile = fullfile(app.rootDir, 'data', 'screening_log.csv');
    if exist(logFile, 'file')
        logData = readtable(logFile);
        nTotal = height(logData);
        nOverrides = sum(strcmp(logData.action, 'OVERRIDDEN'));
        overrideRate = nOverrides / max(nTotal, 1) * 100;
        
        escStr = {};
        escStr{end+1} = '=== Screening Log Summary ===';
        escStr{end+1} = sprintf('Total reviewed: %d', nTotal);
        escStr{end+1} = sprintf('Confirmed: %d', sum(strcmp(logData.action, 'CONFIRMED')));
        escStr{end+1} = sprintf('Overridden: %d (%.1f%%)', nOverrides, overrideRate);
        if overrideRate > 15
            escStr{end+1} = '⚠️ Override rate > 15%! Model investigation recommended.';
        end
        app.escText.Value = escStr;
    end
    
    app.fig.UserData = app;
end

function runSimFromGUI(app)
    app = app.fig.UserData;
    
    params = struct();
    params.population = app.simPopField.Value;
    params.dm_prevalence = app.simDmField.Value;
    params.camp_days_per_month = app.simCampField.Value;
    params.devices_per_camp = app.simDevField.Value;
    params.referral_adherence = app.simAdhSlider.Value;
    
    try
        sim_results = run_simulation(app.cfg, params);
        
        lines = {};
        lines{end+1} = '=== Simulation Results ===';
        lines{end+1} = sprintf('Diabetic population: %s', formatNum(sim_results.diabetic_pop));
        lines{end+1} = sprintf('Patients/month: %s', formatNum(sim_results.patients_per_month));
        lines{end+1} = sprintf('Months to screen: %.1f', sim_results.months_to_screen);
        lines{end+1} = sprintf('Doctor utilization: %.1f%%', sim_results.doctor_utilization * 100);
        lines{end+1} = '';
        lines{end+1} = '=== Treatment Gap ===';
        lines{end+1} = sprintf('Needing treatment/month: %.0f', sim_results.patients_needing_treatment);
        lines{end+1} = sprintf('Actually treated/month: %.0f (%.1f%% adherence)', ...
            sim_results.patients_actually_treated, params.referral_adherence * 100);
        lines{end+1} = sprintf('TREATMENT GAP: %.0f patients/month never get care', sim_results.treatment_gap);
        lines{end+1} = '';
        lines{end+1} = sprintf('BOTTLENECK: %s', sim_results.bottleneck);
        
        app.simResultText.Value = lines;
    catch ME
        app.simResultText.Value = {sprintf('Error: %s', ME.message)};
    end
    
    app.fig.UserData = app;
end

function s = formatNum(n)
    if n >= 1e6
        s = sprintf('%.1fM', n/1e6);
    elseif n >= 1e3
        s = sprintf('%.1fK', n/1e3);
    else
        s = sprintf('%.0f', n);
    end
end

% ================================================================
% CLEANUP
% ================================================================
function closeFig(app)
    app = app.fig.UserData;
    
    % Auto-save any pending results
    if isfield(app, 'leftResult') || isfield(app, 'rightResult')
        try
            saveDir = fullfile(app.rootDir, 'data', 'screening_results');
            if ~exist(saveDir, 'dir'), mkdir(saveDir); end
            save(fullfile(saveDir, sprintf('session_%s.mat', datestr(now, 'yyyymmdd_HHMMSS'))), ...
                'app', '-struct');
        catch
            % Silent fail on auto-save
        end
    end
    
    delete(app.fig);
end
