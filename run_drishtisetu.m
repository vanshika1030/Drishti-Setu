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
    % DESIGN TOKENS
    % ============================================================
    T.bg       = [0.965 0.973 0.980];   % page background
    T.card     = [1 1 1];                % card surface
    T.header   = [0.086 0.216 0.380];    % deep navy header
    T.accent   = [0.165 0.510 0.820];    % primary blue
    T.success  = [0.086 0.608 0.290];    % green
    T.danger   = [0.816 0.133 0.133];    % red
    T.warning  = [0.886 0.627 0.086];    % amber
    T.textPri  = [0.12 0.14 0.18];       % primary text
    T.textSec  = [0.40 0.44 0.50];       % secondary text
    T.border   = [0.86 0.88 0.92];       % subtle border
    T.axesBg   = [0.07 0.07 0.10];       % dark axes background
    app.T = T;
    
    % ============================================================
    % CREATE MAIN FIGURE
    % ============================================================
    app.fig = uifigure('Name', 'DrishtiSetu — AI-Assisted DR Screening', ...
        'Position', [40 30 1320 840], ...
        'Color', T.bg, ...
        'CloseRequestFcn', @(src,~) closeFig(src));
    
    % ============================================================
    % TOP HEADER BAR
    % ============================================================
    topPanel = uipanel(app.fig, 'Position', [0 792 1320 48], ...
        'BackgroundColor', T.header, 'BorderType', 'none');
    
    uilabel(topPanel, 'Position', [20 8 420 32], ...
        'Text', '🔬 DrishtiSetu — AI-Assisted DR Screening', ...
        'FontSize', 17, 'FontWeight', 'bold', 'FontColor', 'white');
    
    uilabel(topPanel, 'Position', [600 12 200 24], ...
        'Text', 'SIH 2026 · PS-26038 · Offline-First', ...
        'FontSize', 10, 'FontColor', [0.65 0.75 0.85]);
    
    uilabel(topPanel, 'Position', [1010 12 60 24], ...
        'Text', 'Role:', 'FontSize', 13, 'FontColor', 'white', 'FontWeight', 'bold');
    
    app.roleDropdown = uidropdown(topPanel, ...
        'Position', [1070 8 230 30], ...
        'Items', {'Technician (तकनीशियन)', 'Doctor (डॉक्टर)', 'District Officer (जिला अधिकारी)'}, ...
        'Value', 'Technician (तकनीशियन)', ...
        'FontSize', 12, ...
        'ValueChangedFcn', @(dd, ~) switchRole(app, dd.Value));
    
    % ============================================================
    % THREE ROLE PANELS (only one visible at a time)
    % ============================================================
    panelPos = [0 0 1320 792];
    
    % --- TECHNICIAN PANEL ---
    app.techPanel = uipanel(app.fig, 'Position', panelPos, ...
        'BackgroundColor', T.bg, 'BorderType', 'none', ...
        'Visible', 'on');
    app = buildTechnicianPanel(app);
    
    % --- DOCTOR PANEL ---
    app.docPanel = uipanel(app.fig, 'Position', panelPos, ...
        'BackgroundColor', T.bg, 'BorderType', 'none', ...
        'Visible', 'off');
    app = buildDoctorPanel(app);
    
    % --- DISTRICT PANEL ---
    app.distPanel = uipanel(app.fig, 'Position', panelPos, ...
        'BackgroundColor', T.bg, 'BorderType', 'none', ...
        'Visible', 'off');
    app = buildDistrictPanel(app);
    
    % Store app in figure for access in callbacks
    app.fig.UserData = app;
    
    fprintf('DrishtiSetu launched successfully.\n');
    fprintf('Pipeline root: %s\n', rootDir);
    fprintf('Model directory: %s\n', cfg.model_dir);
    
    % Report ONNX model availability
    fprintf('\n=== ONNX Model Status ===\n');
    if isfield(cfg, 'onnx_dr_model') && exist(cfg.onnx_dr_model, 'file')
        fprintf('  [✓] DR Grading:       %s\n', cfg.onnx_dr_model);
    else
        fprintf('  [✗] DR Grading:       NOT FOUND (will use placeholder)\n');
    end
    if isfield(cfg, 'onnx_vessel_model') && exist(cfg.onnx_vessel_model, 'file')
        fprintf('  [✓] Vessel Seg:       %s\n', cfg.onnx_vessel_model);
    else
        fprintf('  [✗] Vessel Seg:       NOT FOUND (will use classical fallback)\n');
    end
    if isfield(cfg, 'onnx_lesion_model') && exist(cfg.onnx_lesion_model, 'file')
        fprintf('  [✓] Lesion Seg:       %s\n', cfg.onnx_lesion_model);
    else
        fprintf('  [✗] Lesion Seg:       NOT FOUND (will use classical fallback)\n');
    end
    fprintf('=========================\n');
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
% TECHNICIAN PANEL — Modern Clinical Layout
% ================================================================
function app = buildTechnicianPanel(app)
    p = app.techPanel;
    T = app.T;
    
    % --- LEFT COLUMN: Patient Info + Controls (card style) ---
    leftBox = uipanel(p, 'Position', [12 10 396 770], ...
        'BackgroundColor', T.card, 'BorderType', 'line', ...
        'BorderColor', T.border, 'Title', '', 'FontSize', 1);

    % Section Header: Patient
    uilabel(leftBox, 'Position', [16 736 360 28], ...
        'Text', '📋  Patient Information', ...
        'FontSize', 15, 'FontWeight', 'bold', 'FontColor', T.header);
    uilabel(leftBox, 'Position', [16 720 360 16], ...
        'Text', 'रोगी जानकारी', ...
        'FontSize', 10, 'FontColor', T.textSec);

    % Consent Section
    uilabel(leftBox, 'Position', [16 696 360 18], ...
        'Text', 'CONSENT', 'FontSize', 9, 'FontWeight', 'bold', 'FontColor', T.textSec);
    app.consentCheck1 = uicheckbox(leftBox, 'Position', [16 674 360 20], ...
        'Text', 'AI-assisted screening (not diagnosis)', 'FontSize', 11, 'FontColor', T.textPri);
    app.consentCheck2 = uicheckbox(leftBox, 'Position', [16 652 360 20], ...
        'Text', 'Data stored locally (DPDP Act)', 'FontSize', 11, 'FontColor', T.textPri);
    
    % Patient fields — compact
    uilabel(leftBox, 'Position', [16 624 90 20], 'Text', 'Name (नाम)', 'FontSize', 11, 'FontColor', T.textSec);
    app.nameField = uieditfield(leftBox, 'Position', [110 621 262 26], 'FontSize', 12);
    
    uilabel(leftBox, 'Position', [16 592 90 20], 'Text', 'Age (उम्र)', 'FontSize', 11, 'FontColor', T.textSec);
    app.ageField = uieditfield(leftBox, 'numeric', 'Position', [110 589 80 26], 'FontSize', 12);
    
    uilabel(leftBox, 'Position', [200 592 55 20], 'Text', 'DM Yrs', 'FontSize', 11, 'FontColor', T.textSec);
    app.dmField = uieditfield(leftBox, 'numeric', 'Position', [260 589 112 26], 'FontSize', 12);
    
    uilabel(leftBox, 'Position', [16 560 90 20], 'Text', 'ABHA ID', 'FontSize', 11, 'FontColor', T.textSec);
    app.abhaField = uieditfield(leftBox, 'Position', [110 557 262 26], 'FontSize', 12);
    
    % Eye selector
    uilabel(leftBox, 'Position', [16 530 90 20], 'Text', 'Eye (आँख)', 'FontSize', 11, 'FontWeight', 'bold', 'FontColor', T.textSec);
    app.eyeGroup = uibuttongroup(leftBox, 'Position', [110 526 262 26], 'BorderType', 'none', 'BackgroundColor', T.card);
    uiradiobutton(app.eyeGroup, 'Position', [2 3 120 20], 'Text', 'Right (दाहिनी)', 'FontSize', 11);
    uiradiobutton(app.eyeGroup, 'Position', [130 3 120 20], 'Text', 'Left (बाएं)', 'FontSize', 11);
    
    % Input mode
    uilabel(leftBox, 'Position', [16 498 90 20], 'Text', 'Input Mode', 'FontSize', 11, 'FontColor', T.textSec);
    app.modeDropdown = uidropdown(leftBox, 'Position', [110 494 262 26], ...
        'Items', {'📷 Still Photo', '🎥 Video Capture'}, 'FontSize', 11);
    
    % ── Load Image Button ──
    app.loadBtn = uibutton(leftBox, 'Position', [16 448 356 40], ...
        'Text', '📂  Load Image / Video', 'FontSize', 14, 'FontWeight', 'bold', ...
        'BackgroundColor', T.accent, 'FontColor', 'white', ...
        'ButtonPushedFcn', @(~,~) loadImage(app));
    
    % Quality Badge
    app.qualityLabel = uilabel(leftBox, 'Position', [16 418 356 26], ...
        'Text', '○  Quality: Not assessed', 'FontSize', 13, ...
        'FontWeight', 'bold', 'HorizontalAlignment', 'center', ...
        'FontColor', T.textSec);
    app.retakeLabel = uilabel(leftBox, 'Position', [16 400 356 18], ...
        'Text', '', 'FontSize', 10, 'HorizontalAlignment', 'center', ...
        'FontColor', T.textSec);
    
    % ── Run Analysis Button ──
    app.runBtn = uibutton(leftBox, 'Position', [16 352 356 42], ...
        'Text', '▶  जाँच शुरू करें  (Run Analysis)', 'FontSize', 15, 'FontWeight', 'bold', ...
        'BackgroundColor', T.success, 'FontColor', 'white', ...
        'Enable', 'off', ...
        'ButtonPushedFcn', @(~,~) runAnalysis(app));
    
    % Progress label (brief status text)
    app.progressLabel = uilabel(leftBox, 'Position', [16 328 356 22], ...
        'Text', '', 'FontSize', 10, 'HorizontalAlignment', 'center', ...
        'FontColor', T.accent);
    
    % ── PIPELINE PROGRESS PANEL (between Run button and Result card) ──
    app.pipelinePanel = uipanel(leftBox, 'Position', [16 196 356 130], ...
        'BackgroundColor', [0.94 0.95 0.97], 'BorderType', 'line', ...
        'BorderColor', T.accent, 'Visible', 'off');
    uilabel(app.pipelinePanel, 'Position', [8 106 200 18], ...
        'Text', '⚙ Pipeline Progress', 'FontSize', 11, 'FontWeight', 'bold', 'FontColor', T.header);
    stepNames = {'Image Standardization', 'Quality Assessment', 'Vessel Segmentation', ...
                 'Lesion Detection (ONNX)', 'DR Grading (ONNX)', 'Explainability', 'Safety Checks'};
    for s = 1:7
        app.stepLabels(s) = uilabel(app.pipelinePanel, 'Position', [10 106-s*14 340 13], ...
            'Text', sprintf('  ○  Step %d: %s', s, stepNames{s}), ...
            'FontSize', 9, 'FontColor', T.textSec);
    end
    app.pipelineGauge = uigauge(app.pipelinePanel, 'linear', ...
        'Position', [10 2 336 14], 'Limits', [0 100], 'Value', 0, ...
        'ScaleColors', {T.accent, T.success}, 'ScaleColorLimits', [0 60; 60 100]);
    
    % ── RESULT CARD ──
    app.resultPanel = uipanel(leftBox, 'Position', [16 76 356 116], ...
        'BackgroundColor', [0.96 0.97 0.98], 'BorderType', 'line', ...
        'BorderColor', T.border);
    
    % Status bar at top of result card
    app.resultStatusBar = uilabel(app.resultPanel, 'Position', [0 90 356 26], ...
        'Text', '  AWAITING ANALYSIS', 'FontSize', 10, 'FontWeight', 'bold', ...
        'FontColor', 'white', 'BackgroundColor', [0.60 0.64 0.70], ...
        'HorizontalAlignment', 'left');
    
    % Main result text
    app.resultLabel = uilabel(app.resultPanel, 'Position', [12 42 332 46], ...
        'Text', 'परिणाम यहाँ दिखेगा', 'FontSize', 18, 'FontWeight', 'bold', ...
        'HorizontalAlignment', 'center', 'FontColor', T.textPri);
    
    % Detail text
    app.resultDetail = uilabel(app.resultPanel, 'Position', [12 4 332 36], ...
        'Text', '', 'FontSize', 11, 'HorizontalAlignment', 'center', ...
        'WordWrap', 'on', 'FontColor', T.textSec);
    
    % ── Action buttons row (bottom of left panel) ──
    app.printBtn = uibutton(leftBox, 'Position', [16 32 170 36], ...
        'Text', '🖨  Print Report', 'FontSize', 12, 'Enable', 'off', ...
        'BackgroundColor', [0.94 0.95 0.96], 'FontColor', T.textPri, ...
        'ButtonPushedFcn', @(~,~) printReport(app));
    app.nextBtn = uibutton(leftBox, 'Position', [200 32 172 36], ...
        'Text', '➡  Next Patient', 'FontSize', 12, ...
        'BackgroundColor', [0.94 0.95 0.96], 'FontColor', T.textPri, ...
        'ButtonPushedFcn', @(~,~) nextPatient(app));
    
    % --- RIGHT COLUMN: Image Display Grid (2x2) ---
    rightBox = uipanel(p, 'Position', [420 10 888 770], ...
        'BackgroundColor', T.card, 'BorderType', 'line', ...
        'BorderColor', T.border, 'Title', '', 'FontSize', 1);
    
    % Section header
    uilabel(rightBox, 'Position', [16 734 300 28], ...
        'Text', '🖼  Fundus Image Analysis', ...
        'FontSize', 15, 'FontWeight', 'bold', 'FontColor', T.header);
    
    % 2x2 image grid with dark axes backgrounds
    axW = 418; axH = 340;
    
    % Top-left: Original Image
    app.imgAxes = uiaxes(rightBox, 'Position', [12 380 axW axH]);
    app.imgAxes.Color = T.axesBg;
    title(app.imgAxes, 'Standardized Image', 'Color', T.textPri, 'FontWeight', 'bold');
    axis(app.imgAxes, 'image'); app.imgAxes.XTick = []; app.imgAxes.YTick = [];
    app.imgAxes.XColor = T.border; app.imgAxes.YColor = T.border;
    
    % Top-right: Quality heatmap
    app.qualAxes = uiaxes(rightBox, 'Position', [12+axW+12 380 axW axH]);
    app.qualAxes.Color = T.axesBg;
    title(app.qualAxes, 'Quality Heatmap (16x16)', 'Color', T.textPri, 'FontWeight', 'bold');
    axis(app.qualAxes, 'image'); app.qualAxes.XTick = []; app.qualAxes.YTick = [];
    app.qualAxes.XColor = T.border; app.qualAxes.YColor = T.border;
    
    % Quality legend label
    app.qualLegendLabel = uilabel(rightBox, 'Position', [12+axW+12 356 axW 22], ...
        'Text', '', 'FontSize', 9, 'FontColor', T.textSec, 'HorizontalAlignment', 'center');
    
    % Bottom-left: Lesion overlay
    app.overlayAxes = uiaxes(rightBox, 'Position', [12 24 axW axH]);
    app.overlayAxes.Color = T.axesBg;
    title(app.overlayAxes, 'Lesion Overlay', 'Color', T.textPri, 'FontWeight', 'bold');
    axis(app.overlayAxes, 'image'); app.overlayAxes.XTick = []; app.overlayAxes.YTick = [];
    app.overlayAxes.XColor = T.border; app.overlayAxes.YColor = T.border;
    
    % Bottom-right: Grad-CAM
    app.gcamAxes = uiaxes(rightBox, 'Position', [12+axW+12 24 axW axH]);
    app.gcamAxes.Color = T.axesBg;
    title(app.gcamAxes, 'Grad-CAM Attention', 'Color', T.textPri, 'FontWeight', 'bold');
    axis(app.gcamAxes, 'image'); app.gcamAxes.XTick = []; app.gcamAxes.YTick = [];
    app.gcamAxes.XColor = T.border; app.gcamAxes.YColor = T.border;
    
    % Grad-CAM explanation label
    app.gcamLegendLabel = uilabel(rightBox, 'Position', [12+axW+12 0 axW 22], ...
        'Text', 'Red/Yellow = High AI attention  |  Blue = Low attention  |  Feature-based explainability', ...
        'FontSize', 9, 'FontColor', T.textSec, 'HorizontalAlignment', 'center');
end

% ================================================================
% DOCTOR PANEL — Case Review
% ================================================================
function app = buildDoctorPanel(app)
    p = app.docPanel;
    T = app.T;
    
    % Queue list (left sidebar)
    queueBox = uipanel(p, 'Position', [12 10 310 770], ...
        'BackgroundColor', T.card, 'BorderType', 'line', 'BorderColor', T.border, ...
        'Title', '', 'FontSize', 1);
    
    uilabel(queueBox, 'Position', [14 734 280 28], ...
        'Text', '📋  Escalated Queue', ...
        'FontSize', 15, 'FontWeight', 'bold', 'FontColor', T.header);
    
    app.queueList = uilistbox(queueBox, 'Position', [10 50 290 680], ...
        'FontSize', 12, 'Items', {'No escalated cases'}, ...
        'ValueChangedFcn', @(lb, ~) loadEscalatedCase(app, lb.Value));
    
    app.refreshQueueBtn = uibutton(queueBox, 'Position', [10 10 290 32], ...
        'Text', '🔄  Refresh Queue', 'FontSize', 11, ...
        'BackgroundColor', T.accent, 'FontColor', 'white', ...
        'ButtonPushedFcn', @(~,~) refreshDoctorQueue(app));
    
    % Case detail panel (right)
    detailBox = uipanel(p, 'Position', [334 10 974 770], ...
        'BackgroundColor', T.card, 'BorderType', 'line', 'BorderColor', T.border, ...
        'Title', '', 'FontSize', 1);
    
    % Patient info header
    app.docPatientLabel = uilabel(detailBox, 'Position', [16 740 600 24], ...
        'Text', 'Select a case from the queue', ...
        'FontSize', 14, 'FontWeight', 'bold', 'FontColor', T.header);
    
    % Escalation reason badge
    app.escReasonLabel = uilabel(detailBox, 'Position', [16 716 940 22], ...
        'Text', '', 'FontSize', 11, 'FontColor', T.danger, 'FontWeight', 'bold');
    
    % ── Evidence images row (3-up) ──
    imgW = 305; imgH = 190;
    
    app.docImgAxes = uiaxes(detailBox, 'Position', [10 516 imgW imgH]);
    app.docImgAxes.Color = T.axesBg;
    title(app.docImgAxes, 'Enhanced Image', 'Color', T.textPri, 'FontWeight', 'bold');
    axis(app.docImgAxes, 'image'); app.docImgAxes.XTick = []; app.docImgAxes.YTick = [];
    
    app.docOverlayAxes = uiaxes(detailBox, 'Position', [10+imgW+8 516 imgW imgH]);
    app.docOverlayAxes.Color = T.axesBg;
    title(app.docOverlayAxes, 'Lesion Overlay', 'Color', T.textPri, 'FontWeight', 'bold');
    axis(app.docOverlayAxes, 'image'); app.docOverlayAxes.XTick = []; app.docOverlayAxes.YTick = [];
    
    app.docGcamAxes = uiaxes(detailBox, 'Position', [10+imgW*2+16 516 imgW imgH]);
    app.docGcamAxes.Color = T.axesBg;
    title(app.docGcamAxes, 'Grad-CAM', 'Color', T.textPri, 'FontWeight', 'bold');
    axis(app.docGcamAxes, 'image'); app.docGcamAxes.XTick = []; app.docGcamAxes.YTick = [];
    
    % ── COUNTERFACTUAL CONSISTENCY CHECK PANEL ──
    cfPanel = uipanel(detailBox, 'Position', [10 368 944 142], ...
        'BackgroundColor', [0.96 0.97 0.99], 'BorderType', 'line', 'BorderColor', T.accent, ...
        'Title', '', 'FontSize', 1);
    uilabel(cfPanel, 'Position', [10 118 400 20], ...
        'Text', 'Counterfactual Consistency Check', ...
        'FontSize', 12, 'FontWeight', 'bold', 'FontColor', T.header);
    
    cfImgW = 120; cfImgH = 100;
    app.docOrigAxes = uiaxes(cfPanel, 'Position', [10 10 cfImgW cfImgH]);
    app.docOrigAxes.Color = T.axesBg;
    title(app.docOrigAxes, 'Original', 'Color', T.textPri, 'FontSize', 9);
    axis(app.docOrigAxes, 'image'); app.docOrigAxes.XTick = []; app.docOrigAxes.YTick = [];
    
    uilabel(cfPanel, 'Position', [cfImgW+14 50 24 20], ...
        'Text', '>>', 'FontSize', 14, 'FontWeight', 'bold', 'FontColor', T.accent);
    
    app.docHealedAxes = uiaxes(cfPanel, 'Position', [cfImgW+42 10 cfImgW cfImgH]);
    app.docHealedAxes.Color = T.axesBg;
    title(app.docHealedAxes, 'Healed', 'Color', T.textPri, 'FontSize', 9);
    axis(app.docHealedAxes, 'image'); app.docHealedAxes.XTick = []; app.docHealedAxes.YTick = [];
    
    app.cfResultLabel = uilabel(cfPanel, 'Position', [cfImgW*2+60 60 600 52], ...
        'Text', '', 'FontSize', 11, 'FontWeight', 'bold', 'WordWrap', 'on', ...
        'FontColor', T.textPri, 'VerticalAlignment', 'top');
    
    app.cfDisclaimerLabel = uilabel(cfPanel, 'Position', [cfImgW*2+60 10 600 48], ...
        'Text', 'Explainability visualization only. Checks whether identified lesions influence the AI prediction. Not a clinical diagnosis.', ...
        'FontSize', 9, 'FontColor', T.textSec, 'WordWrap', 'on', 'VerticalAlignment', 'top');
    
    % ── EVIDENCE + METRICS ROW (side by side, below counterfactual) ──
    app.evidenceText = uitextarea(detailBox, 'Position', [10 140 600 222], ...
        'FontSize', 10, 'Editable', 'off', 'Value', {'Evidence chain will appear here'}, ...
        'FontName', 'Courier');
    
    % Metrics card (right of evidence, same vertical zone)
    metricsBox = uipanel(detailBox, 'Position', [620 140 334 222], ...
        'BackgroundColor', [0.96 0.97 0.99], 'BorderType', 'line', 'BorderColor', T.border, ...
        'Title', '', 'FontSize', 1);
    uilabel(metricsBox, 'Position', [10 194 200 22], ...
        'Text', 'Clinical Summary', 'FontSize', 12, 'FontWeight', 'bold', 'FontColor', T.header);
    
    % Grade badge (large, colored)
    app.docGradeBadge = uilabel(metricsBox, 'Position', [10 150 314 40], ...
        'Text', '', 'FontSize', 16, 'FontWeight', 'bold', ...
        'FontColor', 'white', 'BackgroundColor', [0.55 0.58 0.63], ...
        'HorizontalAlignment', 'center');
    
    % Referral probability
    app.docRefLabel = uilabel(metricsBox, 'Position', [10 122 314 26], ...
        'Text', '', 'FontSize', 11, 'FontColor', T.textPri);
    
    % Confidence
    app.docConfLabel = uilabel(metricsBox, 'Position', [10 98 314 22], ...
        'Text', '', 'FontSize', 11, 'FontColor', T.textSec);
    
    % Agreement
    app.docAgreeLabel = uilabel(metricsBox, 'Position', [10 74 155 22], ...
        'Text', '', 'FontSize', 11, 'FontColor', T.textPri);
    
    % DME
    app.docDmeLabel = uilabel(metricsBox, 'Position', [170 74 154 22], ...
        'Text', '', 'FontSize', 11, 'FontColor', T.textPri);
    
    % Recommendation
    app.docRecLabel = uilabel(metricsBox, 'Position', [10 6 314 64], ...
        'Text', '', 'FontSize', 11, 'FontWeight', 'bold', 'WordWrap', 'on', ...
        'VerticalAlignment', 'top', 'FontColor', T.header);
    
    % ── Doctor actions bar (bottom) ──
    actionBox = uipanel(detailBox, 'Position', [10 10 944 122], ...
        'BackgroundColor', [0.97 0.98 0.99], 'BorderType', 'line', 'BorderColor', T.border, ...
        'Title', '', 'FontSize', 1);
    
    uilabel(actionBox, 'Position', [14 92 200 24], ...
        'Text', '⚕  Doctor Decision', 'FontSize', 13, 'FontWeight', 'bold', 'FontColor', T.header);
    
    app.confirmBtn = uibutton(actionBox, 'Position', [14 38 200 42], ...
        'Text', '✅  Confirm AI Grade', 'FontSize', 13, 'FontWeight', 'bold', ...
        'BackgroundColor', T.success, 'FontColor', 'white', ...
        'Enable', 'off', ...
        'ButtonPushedFcn', @(~,~) doctorConfirm(app));
    
    uilabel(actionBox, 'Position', [240 68 80 22], 'Text', 'Override to:', 'FontSize', 11, 'FontColor', T.textSec);
    app.overrideDropdown = uidropdown(actionBox, 'Position', [330 64 140 28], ...
        'Items', {'Grade 0', 'Grade 1', 'Grade 2', 'Grade 3', 'Grade 4'}, 'FontSize', 11);
    
    uilabel(actionBox, 'Position', [240 36 80 22], 'Text', 'Reason:', 'FontSize', 11, 'FontColor', T.textSec);
    app.overrideReason = uieditfield(actionBox, 'Position', [330 32 350 28], ...
        'Placeholder', 'Typed reason required for override', 'FontSize', 11);
    
    app.overrideBtn = uibutton(actionBox, 'Position', [700 38 230 42], ...
        'Text', '✏  Override Grade', 'FontSize', 13, 'FontWeight', 'bold', ...
        'BackgroundColor', T.warning, 'FontColor', 'white', ...
        'Enable', 'off', ...
        'ButtonPushedFcn', @(~,~) doctorOverride(app));
end

% ================================================================
% DISTRICT OFFICER PANEL
% ================================================================
function app = buildDistrictPanel(app)
    p = app.distPanel;
    T = app.T;
    
    % ── TAB GROUP for organized sections ──
    app.distTabGroup = uitabgroup(p, 'Position', [0 0 1320 792]);
    
    % ══════════════════════════════════════════════════════
    % TAB 1: SCREENING SIMULATION (Hero Tab)
    % ══════════════════════════════════════════════════════
    simTab = uitab(app.distTabGroup, 'Title', '  Screening Simulation  ', ...
        'BackgroundColor', T.bg);
    
    % -- Top: KPI Cards Row --
    kpiW = 300; kpiH = 82;
    kpiY = 648;
    kpiColors = {[0.165 0.510 0.820], [0.086 0.608 0.290], ...
                 [0.886 0.627 0.086], [0.816 0.133 0.133]};
    kpiTitles = {'Months to Screen All', 'Patients / Month', ...
                 'Doctor Utilization', 'Treatment Gap'};
    
    for k = 1:4
        kx = 12 + (k-1)*(kpiW+12);
        kpiPanel = uipanel(simTab, 'Position', [kx kpiY kpiW kpiH], ...
            'BackgroundColor', kpiColors{k}, 'BorderType', 'none');
        uilabel(kpiPanel, 'Position', [12 54 280 22], ...
            'Text', kpiTitles{k}, 'FontSize', 11, 'FontColor', [1 1 1]);
        app.kpiValues(k) = uilabel(kpiPanel, 'Position', [12 4 280 48], ...
            'Text', '--', 'FontSize', 30, 'FontWeight', 'bold', ...
            'FontColor', [1 1 1]);
    end
    
    % -- Left: Parameter Controls --
    paramBox = uipanel(simTab, 'Position', [12 8 300 628], ...
        'BackgroundColor', T.card, 'BorderType', 'line', 'BorderColor', T.border, ...
        'Title', '', 'FontSize', 1);
    uilabel(paramBox, 'Position', [12 596 280 24], ...
        'Text', 'Simulation Parameters', 'FontSize', 13, ...
        'FontWeight', 'bold', 'FontColor', T.header);
    
    pY = 560;
    uilabel(paramBox, 'Position', [12 pY 130 20], 'Text', 'Population:', 'FontSize', 11, 'FontColor', T.textSec);
    app.simPopField = uieditfield(paramBox, 'numeric', 'Position', [150 pY-2 130 26], ...
        'Value', 500000, 'FontSize', 11);
    pY = pY - 36;
    uilabel(paramBox, 'Position', [12 pY 130 20], 'Text', 'DM Prevalence:', 'FontSize', 11, 'FontColor', T.textSec);
    app.simDmField = uieditfield(paramBox, 'numeric', 'Position', [150 pY-2 130 26], ...
        'Value', 0.12, 'FontSize', 11);
    pY = pY - 36;
    uilabel(paramBox, 'Position', [12 pY 130 20], 'Text', 'Camp days/month:', 'FontSize', 11, 'FontColor', T.textSec);
    app.simCampField = uieditfield(paramBox, 'numeric', 'Position', [150 pY-2 130 26], ...
        'Value', 4, 'FontSize', 11);
    pY = pY - 36;
    uilabel(paramBox, 'Position', [12 pY 130 20], 'Text', 'Devices/camp:', 'FontSize', 11, 'FontColor', T.textSec);
    app.simDevField = uieditfield(paramBox, 'numeric', 'Position', [150 pY-2 130 26], ...
        'Value', 3, 'FontSize', 11);
    pY = pY - 36;
    uilabel(paramBox, 'Position', [12 pY 130 20], 'Text', 'Referral adherence:', 'FontSize', 11, 'FontColor', T.textSec);
    pY = pY - 28;
    app.simAdhSlider = uislider(paramBox, 'Position', [20 pY+10 230 3], ...
        'Limits', [0.05 0.60], 'Value', 0.145);
    app.simAdhLabel = uilabel(paramBox, 'Position', [210 pY-12 70 22], ...
        'Text', '14.5%', 'FontSize', 11, 'FontWeight', 'bold', 'FontColor', T.accent);
    app.simAdhSlider.ValueChangedFcn = @(s,~) set(app.simAdhLabel, 'Text', sprintf('%.1f%%', s.Value*100));
    
    pY = pY - 48;
    app.runSimBtn = uibutton(paramBox, 'Position', [12 pY 268 42], ...
        'Text', 'Run Simulation', 'FontSize', 14, 'FontWeight', 'bold', ...
        'BackgroundColor', T.accent, 'FontColor', 'white', ...
        'ButtonPushedFcn', @(~,~) runSimFromGUI(app));
    
    pY = pY - 38;
    uilabel(paramBox, 'Position', [12 pY 268 16], 'Text', 'BOTTLENECK:', ...
        'FontSize', 9, 'FontWeight', 'bold', 'FontColor', T.textSec);
    app.bottleneckLabel = uilabel(paramBox, 'Position', [12 pY-28 268 26], ...
        'Text', 'Run simulation first', 'FontSize', 12, 'FontWeight', 'bold', ...
        'FontColor', 'white', 'BackgroundColor', [0.55 0.58 0.63], ...
        'HorizontalAlignment', 'center');
    
    app.simResultText = uitextarea(paramBox, 'Position', [12 10 268 pY-60], ...
        'FontSize', 9, 'Editable', 'off', ...
        'Value', {'Click Run Simulation to see detailed results.'});
    
    % -- Center: Sweep Matrix Heatmap (the star visual) --
    sweepBox = uipanel(simTab, 'Position', [324 8 646 628], ...
        'BackgroundColor', T.card, 'BorderType', 'line', 'BorderColor', T.border, ...
        'Title', '', 'FontSize', 1);
    uilabel(sweepBox, 'Position', [12 596 600 24], ...
        'Text', 'Coverage Heatmap: Months to Screen All Diabetics', ...
        'FontSize', 13, 'FontWeight', 'bold', 'FontColor', T.header);
    uilabel(sweepBox, 'Position', [12 576 600 18], ...
        'Text', 'Camp Days x Devices -> Months needed (lower = better, green = good)', ...
        'FontSize', 10, 'FontColor', T.textSec);
    app.sweepAxes = uiaxes(sweepBox, 'Position', [35 30 580 540]);
    
    % -- Right: Treatment Gap Chart --
    gapBox = uipanel(simTab, 'Position', [982 8 296 628], ...
        'BackgroundColor', T.card, 'BorderType', 'line', 'BorderColor', T.border, ...
        'Title', '', 'FontSize', 1);
    uilabel(gapBox, 'Position', [12 596 270 24], ...
        'Text', 'Treatment Gap', ...
        'FontSize', 13, 'FontWeight', 'bold', 'FontColor', T.header);
    app.treatmentAxes = uiaxes(gapBox, 'Position', [20 260 256 320]);
    
    app.gapInfoLabel = uilabel(gapBox, 'Position', [12 10 272 240], ...
        'Text', '', 'FontSize', 11, 'WordWrap', 'on', 'VerticalAlignment', 'top', ...
        'FontColor', T.textPri);
    
    % ══════════════════════════════════════════════════════
    % TAB 2: MODEL VALIDATION
    % ══════════════════════════════════════════════════════
    valTab = uitab(app.distTabGroup, 'Title', '  Model Validation  ', ...
        'BackgroundColor', T.bg);
    
    % KPI Cards row
    valKpiW = 295; valKpiH = 90;
    valNames = {'Sensitivity', 'Specificity', 'AUROC', 'QWK (Kappa)'};
    valColors = {[0.165 0.510 0.820], [0.086 0.608 0.290], ...
                 [0.50 0.28 0.65], [0.886 0.627 0.086]};
    
    for k = 1:4
        kx = 12 + (k-1)*(valKpiW+16);
        vkpi = uipanel(valTab, 'Position', [kx 640 valKpiW valKpiH], ...
            'BackgroundColor', valColors{k}, 'BorderType', 'none');
        uilabel(vkpi, 'Position', [12 62 270 22], ...
            'Text', valNames{k}, 'FontSize', 12, 'FontColor', [1 1 1]);
        app.valKpiValues(k) = uilabel(vkpi, 'Position', [12 4 270 56], ...
            'Text', '--', 'FontSize', 34, 'FontWeight', 'bold', ...
            'FontColor', [1 1 1]);
    end
    
    % Reliability Diagram (large, left)
    relBox = uipanel(valTab, 'Position', [12 8 820 620], ...
        'BackgroundColor', T.card, 'BorderType', 'line', 'BorderColor', T.border, ...
        'Title', '', 'FontSize', 1);
    uilabel(relBox, 'Position', [12 588 400 24], ...
        'Text', 'Reliability Diagram (Calibration)', ...
        'FontSize', 13, 'FontWeight', 'bold', 'FontColor', T.header);
    app.relDiagAxes = uiaxes(relBox, 'Position', [40 30 740 550]);
    title(app.relDiagAxes, 'Reliability Diagram');
    
    % Detailed Metrics panel (right)
    valInfoBox = uipanel(valTab, 'Position', [844 8 434 620], ...
        'BackgroundColor', T.card, 'BorderType', 'line', 'BorderColor', T.border, ...
        'Title', '', 'FontSize', 1);
    uilabel(valInfoBox, 'Position', [12 588 400 24], ...
        'Text', 'Detailed Metrics', ...
        'FontSize', 13, 'FontWeight', 'bold', 'FontColor', T.header);
    app.metricsText = uitextarea(valInfoBox, 'Position', [10 10 414 572], ...
        'FontSize', 11, 'Editable', 'off', ...
        'Value', {'Validation metrics load automatically.'});
    
    % ══════════════════════════════════════════════════════
    % TAB 3: ESCALATION & OVERSIGHT
    % ══════════════════════════════════════════════════════
    escTab = uitab(app.distTabGroup, 'Title', '  Escalation & Oversight  ', ...
        'BackgroundColor', T.bg);
    
    % -- Top: Escalation KPI Cards --
    escKpiW = 230; escKpiH = 72;
    escKpiColors = {[0.165 0.510 0.820], [0.086 0.608 0.290], ...
                    [0.886 0.627 0.086], [0.816 0.133 0.133], [0.50 0.28 0.65]};
    escKpiTitles = {'Total Reviewed', 'Confirmed', 'Overridden', 'Override Rate', 'Avg AI Confidence'};
    
    for k = 1:5
        kx = 12 + (k-1)*(escKpiW+12);
        ekpi = uipanel(escTab, 'Position', [kx 660 escKpiW escKpiH], ...
            'BackgroundColor', escKpiColors{k}, 'BorderType', 'none');
        uilabel(ekpi, 'Position', [10 46 220 20], ...
            'Text', escKpiTitles{k}, 'FontSize', 10, 'FontColor', [1 1 1]);
        app.escKpiValues(k) = uilabel(ekpi, 'Position', [10 4 220 42], ...
            'Text', '--', 'FontSize', 26, 'FontWeight', 'bold', ...
            'FontColor', [1 1 1]);
    end
    
    % Grade Distribution: AI Grade vs Doctor Grade (left)
    gradeBox = uipanel(escTab, 'Position', [12 305 640 345], ...
        'BackgroundColor', T.card, 'BorderType', 'line', 'BorderColor', T.border, ...
        'Title', '', 'FontSize', 1);
    uilabel(gradeBox, 'Position', [12 315 580 24], ...
        'Text', 'AI Grade vs Doctor Final Grade', ...
        'FontSize', 13, 'FontWeight', 'bold', 'FontColor', T.header);
    app.gradeDistAxes = uiaxes(gradeBox, 'Position', [30 20 580 290]);
    app.gradeDistAxes.XColor = [0.15 0.15 0.15];
    app.gradeDistAxes.YColor = [0.15 0.15 0.15];
    
    % Doctor Decision Breakdown (right)
    overrideBox = uipanel(escTab, 'Position', [664 305 614 345], ...
        'BackgroundColor', T.card, 'BorderType', 'line', 'BorderColor', T.border, ...
        'Title', '', 'FontSize', 1);
    uilabel(overrideBox, 'Position', [12 315 580 24], ...
        'Text', 'Doctor Decision Breakdown', ...
        'FontSize', 13, 'FontWeight', 'bold', 'FontColor', T.header);
    app.overrideAxes = uiaxes(overrideBox, 'Position', [30 20 554 290]);
    app.overrideAxes.XColor = [0.15 0.15 0.15];
    app.overrideAxes.YColor = [0.15 0.15 0.15];
    
    % Escalation Log Details (bottom full width)
    escLogBox = uipanel(escTab, 'Position', [12 8 1266 290], ...
        'BackgroundColor', T.card, 'BorderType', 'line', 'BorderColor', T.border, ...
        'Title', '', 'FontSize', 1);
    uilabel(escLogBox, 'Position', [12 258 400 24], ...
        'Text', 'Escalation Details & Triggers', ...
        'FontSize', 13, 'FontWeight', 'bold', 'FontColor', T.header);
    app.escText = uitextarea(escLogBox, 'Position', [10 10 1246 244], ...
        'FontSize', 11, 'Editable', 'off', ...
        'Value', {'Escalation data will appear after patients are processed.'});
    
    % ── Set dark axis colors on all axes for readability ──
    darkAxis = [0.15 0.15 0.15];
    allAxes = {app.sweepAxes, app.treatmentAxes, app.relDiagAxes};
    for ai = 1:length(allAxes)
        allAxes{ai}.XColor = darkAxis;
        allAxes{ai}.YColor = darkAxis;
    end
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
    
    % Step 1: Standardize — with visible progress
    app.progressLabel.Text = '🔧 Step 1/3: Standardizing image (CLAHE + resize)...';
    drawnow; pause(0.3);
    [app.stdImage, app.retinaMask, app.fovProps] = standardize_for_pipeline(app.currentImage);
    
    % Display
    imshow(app.stdImage, 'Parent', app.imgAxes);
    title(app.imgAxes, 'Standardized Image', 'Color', app.T.textPri, 'FontWeight', 'bold');
    app.progressLabel.Text = '✓ Standardized (1024×1024, CLAHE enhanced)';
    drawnow; pause(0.4);
    
    % Step 2: Quality check
    app.progressLabel.Text = '🔍 Step 2/3: Assessing quality (16×16 tile grid)...';
    drawnow; pause(0.3);
    [pass_flag, feedback, quality_info] = assess_quality(app.stdImage, app.retinaMask);
    
    % Step 3: Display quality heatmap
    app.progressLabel.Text = '📊 Step 3/3: Generating quality heatmap...';
    drawnow; pause(0.2);
    displayQualityHeatmap(app, quality_info);
    
    if pass_flag
        app.qualityLabel.Text = '●  Quality: PASS';
        app.qualityLabel.FontColor = app.T.success;
        app.retakeLabel.Text = '';
        app.runBtn.Enable = 'on';
        app.retakeCount = 0;
    else
        app.retakeCount = app.retakeCount + 1;
        if app.retakeCount >= app.maxRetakes
            app.qualityLabel.Text = '●  UNGRADEABLE — Auto-referring';
            app.qualityLabel.FontColor = app.T.danger;
            app.retakeLabel.Text = sprintf('3/3 retakes failed: %s', feedback);
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
            app.resultStatusBar.Text = '  ● UNGRADEABLE';
            app.resultStatusBar.BackgroundColor = app.T.danger;
            app.resultLabel.Text = 'Ungradeable (अनिश्चित)';
            app.resultLabel.FontColor = app.T.danger;
            app.resultPanel.BackgroundColor = [0.98 0.94 0.94];
            app.resultDetail.Text = sprintf('Reason: %s. Referred to hospital.', feedback);
            app.printBtn.Enable = 'on';
        else
            app.qualityLabel.Text = sprintf('●  Quality: FAIL (%d/%d)', app.retakeCount, app.maxRetakes);
            app.qualityLabel.FontColor = app.T.danger;
            app.retakeLabel.Text = sprintf('%s — Please retake.', feedback);
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
    
    % Show pipeline progress panel
    app.pipelinePanel.Visible = 'on';
    for s = 1:7
        app.stepLabels(s).Text = sprintf('  ○  Step %d: %s', s, getStepName(s));
        app.stepLabels(s).FontColor = app.T.textSec;
    end
    app.pipelineGauge.Value = 0;
    drawnow;
    
    % === Step 1: Image Standardization (already done in loadImage) ===
    updateStep(app, 1, 'running'); drawnow; pause(0.3);
    updateStep(app, 1, 'done');
    app.pipelineGauge.Value = 14; drawnow; pause(0.2);
    
    % === Step 2: Quality Assessment (already done in loadImage) ===
    updateStep(app, 2, 'running'); drawnow; pause(0.3);
    updateStep(app, 2, 'done');
    app.pipelineGauge.Value = 28; drawnow; pause(0.2);
    
    % === Step 3: Vessel Segmentation ===
    updateStep(app, 3, 'running');
    app.progressLabel.Text = 'Segmenting vessels...';
    drawnow;
    [all_masks, lesion_counts, seg_info] = segment_all(app.stdImage, app.retinaMask, cfg);
    updateStep(app, 3, 'done');
    app.pipelineGauge.Value = 42; drawnow; pause(0.2);
    
    % Display overlay
    if isfield(seg_info, 'overlay_img') && ~isempty(seg_info.overlay_img)
        imshow(seg_info.overlay_img, 'Parent', app.overlayAxes);
    end
    title(app.overlayAxes, sprintf('Lesion Overlay (%s)', seg_info.method_used), ...
        'Color', app.T.textPri, 'FontWeight', 'bold');
    
    % === Step 4: Lesion Detection ===
    updateStep(app, 4, 'running');
    app.progressLabel.Text = 'Detecting lesions (ONNX)...';
    drawnow; pause(0.3);
    updateStep(app, 4, 'done');
    app.pipelineGauge.Value = 56; drawnow; pause(0.2);
    
    % === Step 5: DR Grading ===
    updateStep(app, 5, 'running');
    app.progressLabel.Text = 'DR Grading (ResNet50 ONNX)...';
    drawnow;
    grade_result = grade_dr_ensemble(app.stdImage, app.retinaMask, seg_info, cfg);
    
    % Add segmentation results to grade_result
    grade_result.lesion_counts = lesion_counts;
    grade_result.seg_info = seg_info;
    grade_result.all_masks = all_masks;
    updateStep(app, 5, 'done');
    app.pipelineGauge.Value = 70; drawnow; pause(0.2);
    
    % === Step 6: Explainability ===
    updateStep(app, 6, 'running');
    app.progressLabel.Text = 'Generating Grad-CAM + Counterfactual...';
    drawnow;
    explain_result = explain_prediction(app.stdImage, app.retinaMask, grade_result, seg_info, cfg);
    grade_result.explain = explain_result;
    
    % Display Grad-CAM
    if isfield(explain_result, 'gradcam_overlay') && ~isempty(explain_result.gradcam_overlay)
        imshow(explain_result.gradcam_overlay, 'Parent', app.gcamAxes);
    end
    title(app.gcamAxes, 'Grad-CAM Attention', 'Color', app.T.textPri, 'FontWeight', 'bold');
    updateStep(app, 6, 'done');
    app.pipelineGauge.Value = 85; drawnow; pause(0.2);
    
    % === Step 7: Safety Checks ===
    updateStep(app, 7, 'running');
    app.progressLabel.Text = 'Running safety checks (OOD, DME, concordance)...';
    drawnow; pause(0.4);
    updateStep(app, 7, 'done');
    app.pipelineGauge.Value = 100; drawnow; pause(0.3);
    
    % Step 4: Display result
    elapsed = toc;
    model_source = 'Classical';
    if isfield(grade_result, 'model_source')
        model_source = grade_result.model_source;
    end
    app.progressLabel.Text = sprintf('✓ Complete in %.1f s  [Model: %s | Seg: %s]', ...
        elapsed, model_source, seg_info.method_used);
    
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
    
    % If escalated, add to queue — store images for Doctor view
    if strcmp(grade_result.decision, 'ESCALATE')
        caseData = struct();
        caseData.patientInfo = getPatientInfo(app);
        caseData.grade_result = grade_result;
        caseData.image = app.stdImage;
        % Store overlay and gradcam for Doctor view
        if isfield(seg_info, 'overlay_img')
            caseData.overlay_img = seg_info.overlay_img;
        end
        if isfield(explain_result, 'gradcam_overlay')
            caseData.gradcam_overlay = explain_result.gradcam_overlay;
        end
        caseData.timestamp = datestr(now);
        app.escalatedQueue{end+1} = caseData;
    end
    
    app.printBtn.Enable = 'on';
    app.fig.UserData = app;
end

function displayResult(app, result)
    cfg = app.cfg;
    grade = result.grade;
    T = app.T;
    
    if grade < 0
        app.resultStatusBar.Text = '  ● UNGRADEABLE';
        app.resultStatusBar.BackgroundColor = T.danger;
        app.resultLabel.Text = 'Ungradeable (अनिश्चित)';
        app.resultLabel.FontColor = T.danger;
        app.resultPanel.BackgroundColor = [0.98 0.94 0.94];
        app.resultDetail.Text = 'Referred to hospital';
        app.resultDetail.FontColor = T.textSec;
        return;
    end
    
    hindi_grades = cfg.icdr_hindi;
    
    if grade <= 1
        statusColor = T.success;
        statusBg = [0.93 0.98 0.93];
        statusText = '  ● NO/MILD DR';
    elseif grade == 2
        statusColor = T.warning;
        statusBg = [0.99 0.97 0.92];
        statusText = '  ● MODERATE DR';
    else
        statusColor = T.danger;
        statusBg = [0.98 0.94 0.94];
        statusText = sprintf('  ● SEVERE (Grade %d)', grade);
    end
    
    app.resultStatusBar.Text = statusText;
    app.resultStatusBar.BackgroundColor = statusColor;
    app.resultPanel.BackgroundColor = statusBg;
    
    if strcmp(result.decision, 'ESCALATE')
        app.resultStatusBar.Text = '  ⚠ ESCALATED — Doctor Review';
        app.resultStatusBar.BackgroundColor = T.warning;
        app.resultLabel.Text = sprintf('Grade %d — Doctor review needed', grade);
        app.resultLabel.FontColor = T.textPri;
        app.resultDetail.Text = sprintf('Reason: %s', result.escalation_reason);
        app.resultDetail.FontColor = T.danger;
    else
        app.resultLabel.Text = sprintf('%s  (Grade %d)', hindi_grades{grade+1}, grade);
        app.resultLabel.FontColor = T.textPri;
        urgency = cfg.urgency_labels{min(grade+1, length(cfg.urgency_labels))};
        detailText = urgency;
        if isfield(result, 'dme_suspected') && result.dme_suspected
            detailText = [detailText '  ·  ⚠ DME suspected'];
        end
        app.resultDetail.Text = detailText;
        app.resultDetail.FontColor = T.textSec;
    end
end

function displayQualityHeatmap(app, quality_info)
    if ~isfield(quality_info, 'quality_map'), return; end
    
    qmap = quality_info.quality_map;
    [rows, cols] = size(qmap);
    
    % Get the image size from the standardized image for overlay
    if isfield(app, 'stdImage') && ~isempty(app.stdImage)
        [imgH, imgW, ~] = size(app.stdImage);
        tileH = floor(imgH / rows);
        tileW = floor(imgW / cols);
        
        % Create semi-transparent overlay on the actual image
        base_img = im2double(app.stdImage);
        overlay = zeros(imgH, imgW, 3);
        alpha_mask = zeros(imgH, imgW);
        
        for r = 1:rows
            for c = 1:cols
                r1 = (r-1)*tileH+1; r2 = min(r*tileH, imgH);
                c1 = (c-1)*tileW+1; c2 = min(c*tileW, imgW);
                
                status = qmap{r,c};
                if isempty(status) || strcmp(status, '')
                    continue;  % skip non-retina tiles
                elseif strcmp(status, 'good')
                    color = [0.2 0.9 0.2]; a = 0.25;
                elseif strcmp(status, 'blur')
                    color = [1.0 0.2 0.2]; a = 0.40;
                elseif strcmp(status, 'dark')
                    color = [0.7 0.1 0.1]; a = 0.40;
                elseif strcmp(status, 'glare')
                    color = [1.0 0.9 0.2]; a = 0.35;
                else
                    color = [0.5 0.5 0.5]; a = 0.20;
                end
                
                for ch = 1:3
                    overlay(r1:r2, c1:c2, ch) = color(ch);
                end
                alpha_mask(r1:r2, c1:c2) = a;
                
                % Draw grid lines
                overlay(r1, c1:c2, :) = 1; alpha_mask(r1, c1:c2) = 0.5;
                overlay(r2, c1:c2, :) = 1; alpha_mask(r2, c1:c2) = 0.5;
                overlay(r1:r2, c1, :) = 1; alpha_mask(r1:r2, c1) = 0.5;
                overlay(r1:r2, c2, :) = 1; alpha_mask(r1:r2, c2) = 0.5;
            end
        end
        
        % Blend: result = base * (1 - alpha) + overlay * alpha
        alpha3 = repmat(alpha_mask, [1 1 3]);
        blended = base_img .* (1 - alpha3) + overlay .* alpha3;
        heatmap_result = im2uint8(blended);
    else
        % Fallback: simple color grid if no image available
        pxPerTile = 80;
        heatmap_result = zeros(rows * pxPerTile, cols * pxPerTile, 3, 'uint8');
        for r = 1:rows
            for c = 1:cols
                r1 = (r-1)*pxPerTile+1; r2 = r*pxPerTile;
                c1 = (c-1)*pxPerTile+1; c2 = c*pxPerTile;
                status = qmap{r,c};
                if isempty(status) || strcmp(status, ''), color = uint8([60 60 70]);
                elseif strcmp(status, 'good'), color = uint8([40 180 40]);
                elseif strcmp(status, 'blur'), color = uint8([200 50 50]);
                elseif strcmp(status, 'dark'), color = uint8([100 30 30]);
                elseif strcmp(status, 'glare'), color = uint8([220 200 40]);
                else, color = uint8([120 120 120]); end
                for ch = 1:3, heatmap_result(r1:r2, c1:c2, ch) = color(ch); end
                % Grid lines
                heatmap_result(r1, c1:c2, :) = 40;
                heatmap_result(r1:r2, c1, :) = 40;
            end
        end
    end
    
    imshow(heatmap_result, 'Parent', app.qualAxes);
    title(app.qualAxes, sprintf('Quality Heatmap (%dx%d grid)', rows, cols), ...
        'Color', app.T.textPri, 'FontWeight', 'bold');
    
    % Update legend label with tile counts
    if isfield(app, 'qualLegendLabel')
        good_n = sum(cellfun(@(x) strcmp(x, 'good'), qmap(:)));
        blur_n = sum(cellfun(@(x) strcmp(x, 'blur'), qmap(:)));
        dark_n = sum(cellfun(@(x) strcmp(x, 'dark'), qmap(:)));
        glare_n = sum(cellfun(@(x) strcmp(x, 'glare'), qmap(:)));
        total_n = good_n + blur_n + dark_n + glare_n;
        app.qualLegendLabel.Text = sprintf('Good: %d/%d | Blur: %d | Dark: %d | Glare: %d', ...
            good_n, total_n, blur_n, dark_n, glare_n);
    end
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
    T = app.T;
    
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
    app.qualityLabel.Text = '○  Quality: Not assessed';
    app.qualityLabel.FontColor = T.textSec;
    app.retakeLabel.Text = '';
    app.resultStatusBar.Text = '  AWAITING ANALYSIS';
    app.resultStatusBar.BackgroundColor = [0.60 0.64 0.70];
    app.resultLabel.Text = 'परिणाम यहाँ दिखेगा';
    app.resultLabel.FontColor = T.textPri;
    app.resultPanel.BackgroundColor = [0.96 0.97 0.98];
    app.resultDetail.Text = '';
    app.progressLabel.Text = '';
    app.runBtn.Enable = 'off';
    app.printBtn.Enable = 'off';
    
    % Reset pipeline progress panel
    if isfield(app, 'pipelinePanel')
        app.pipelinePanel.Visible = 'off';
        app.pipelineGauge.Value = 0;
    end
    if isfield(app, 'qualLegendLabel')
        app.qualLegendLabel.Text = '';
    end
    
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
        % Clear the detail panel
        app.docPatientLabel.Text = 'No escalated cases in queue';
        app.escReasonLabel.Text = '';
        cla(app.docImgAxes); cla(app.docOverlayAxes); cla(app.docGcamAxes);
        app.evidenceText.Value = {'No cases to review'};
        app.docGradeBadge.Text = '';
        app.docGradeBadge.BackgroundColor = [0.55 0.58 0.63];
        app.docRefLabel.Text = '';
        app.docConfLabel.Text = '';
        app.docAgreeLabel.Text = '';
        app.docDmeLabel.Text = '';
        app.docRecLabel.Text = '';
        app.confirmBtn.Enable = 'off';
        app.overrideBtn.Enable = 'off';
        app.fig.UserData = app;
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
    app.queueList.Value = items{1};  % Explicitly select first
    app.fig.UserData = app;
    
    % Auto-load the first case (since ValueChangedFcn won't fire on auto-select)
    loadEscalatedCase(app, items{1});
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
    
    % Debug: log available data
    fprintf('Loading case #%d for doctor review:\n', idx);
    fprintf('  image: %s\n', mat2str(isfield(c, 'image') && ~isempty(c.image)));
    fprintf('  overlay_img (direct): %s\n', mat2str(isfield(c, 'overlay_img')));
    fprintf('  gradcam_overlay (direct): %s\n', mat2str(isfield(c, 'gradcam_overlay')));
    if isfield(c, 'grade_result')
        fprintf('  grade_result.seg_info.overlay_img: %s\n', ...
            mat2str(isfield(c.grade_result, 'seg_info') && isfield(c.grade_result.seg_info, 'overlay_img')));
        fprintf('  grade_result.explain.gradcam_overlay: %s\n', ...
            mat2str(isfield(c.grade_result, 'explain') && isfield(c.grade_result.explain, 'gradcam_overlay')));
    end
    
    % Display info
    app.docPatientLabel.Text = sprintf('Patient: %s  |  Age: %d  |  Eye: %s', ...
        c.patientInfo.name, c.patientInfo.age, c.grade_result.eye);
    app.escReasonLabel.Text = sprintf('⚠  Escalation: %s', c.grade_result.escalation_reason);
    
    % Display images — use direct stored images for reliability
    if isfield(c, 'image') && ~isempty(c.image)
        imshow(c.image, 'Parent', app.docImgAxes);
        title(app.docImgAxes, 'Enhanced Image', 'Color', app.T.textPri, 'FontWeight', 'bold');
    end
    
    % Overlay — check direct storage first, then nested path
    if isfield(c, 'overlay_img') && ~isempty(c.overlay_img)
        imshow(c.overlay_img, 'Parent', app.docOverlayAxes);
        title(app.docOverlayAxes, 'Lesion Overlay', 'Color', app.T.textPri, 'FontWeight', 'bold');
    elseif isfield(c, 'grade_result') && isfield(c.grade_result, 'seg_info') && isfield(c.grade_result.seg_info, 'overlay_img')
        imshow(c.grade_result.seg_info.overlay_img, 'Parent', app.docOverlayAxes);
        title(app.docOverlayAxes, 'Lesion Overlay', 'Color', app.T.textPri, 'FontWeight', 'bold');
    end
    
    % Grad-CAM — check direct storage first, then nested path
    if isfield(c, 'gradcam_overlay') && ~isempty(c.gradcam_overlay)
        imshow(c.gradcam_overlay, 'Parent', app.docGcamAxes);
        title(app.docGcamAxes, 'Grad-CAM', 'Color', app.T.textPri, 'FontWeight', 'bold');
    elseif isfield(c, 'grade_result') && isfield(c.grade_result, 'explain') && isfield(c.grade_result.explain, 'gradcam_overlay')
        imshow(c.grade_result.explain.gradcam_overlay, 'Parent', app.docGcamAxes);
        title(app.docGcamAxes, 'Grad-CAM', 'Color', app.T.textPri, 'FontWeight', 'bold');
    end
    
    % === COUNTERFACTUAL VISUALIZATION ===
    if isfield(c, 'image') && ~isempty(c.image)
        imshow(c.image, 'Parent', app.docOrigAxes);
        title(app.docOrigAxes, 'Original', 'Color', app.T.textPri, 'FontSize', 10);
    end
    
    % Display healed image and result text
    cfShown = false;
    if isfield(c.grade_result, 'explain') && isfield(c.grade_result.explain, 'counterfactual')
        cf = c.grade_result.explain.counterfactual;
        if isfield(cf, 'healed_img') && ~isempty(cf.healed_img)
            imshow(cf.healed_img, 'Parent', app.docHealedAxes);
            title(app.docHealedAxes, 'Healed', 'Color', app.T.textPri, 'FontSize', 10);
            cfShown = true;
        end
        if isfield(cf, 'flip_result')
            fr = cf.flip_result;
            if isfield(fr, 'description')
                app.cfResultLabel.Text = sprintf('Grade: %d -> %d\n%s', ...
                    fr.original_grade, fr.healed_grade, fr.description);
            else
                app.cfResultLabel.Text = sprintf('Grade: %d -> %d', ...
                    fr.original_grade, fr.healed_grade);
            end
            if isfield(fr, 'grade_dropped') && fr.grade_dropped
                app.cfResultLabel.FontColor = app.T.success;
            else
                app.cfResultLabel.FontColor = app.T.warning;
            end
        end
    end
    if ~cfShown
        app.cfResultLabel.Text = 'No counterfactual data available for this case.';
        app.cfResultLabel.FontColor = app.T.textSec;
    end
    
    % Evidence text
    cfg = app.cfg;
    evidence = format_evidence_chain(c.grade_result, c.grade_result.seg_info, c.grade_result.explain, cfg);
    app.evidenceText.Value = strsplit(evidence, newline);
    
    % Metrics — Doctor-friendly format
    grade_names = app.cfg.icdr_labels;
    grade_name = 'Unknown';
    if c.grade_result.grade >= 0 && c.grade_result.grade <= 4
        grade_name = grade_names{c.grade_result.grade + 1};
    end
    
    agree_str = 'No';
    if isfield(c.grade_result, 'agreement') && c.grade_result.agreement
        agree_str = 'Yes';
    end
    
    dme_str = 'Not suspected';
    if isfield(c.grade_result, 'dme_suspected') && c.grade_result.dme_suspected
        dme_str = 'SUSPECTED';
    end
    
    rec = app.cfg.urgency_labels{min(c.grade_result.grade + 1, 5)};
    
    % Populate individual KPI cards
    % Grade badge with severity color
    gradeColors = {[0.30 0.69 0.29], [0.60 0.80 0.20], [0.99 0.75 0.18], ...
                   [0.96 0.49 0.00], [0.84 0.15 0.16]};
    if c.grade_result.grade >= 0 && c.grade_result.grade <= 4
        app.docGradeBadge.BackgroundColor = gradeColors{c.grade_result.grade + 1};
    end
    app.docGradeBadge.Text = sprintf('Grade %d  —  %s', c.grade_result.grade, grade_name);
    
    % Referral probability with interpretation
    pRefPct = c.grade_result.pRef * 100;
    if pRefPct > 85
        app.docRefLabel.Text = sprintf('Referral: %.0f%%  (REFER)', pRefPct);
        app.docRefLabel.FontColor = app.T.danger;
    else
        app.docRefLabel.Text = sprintf('Referral: %.0f%%  (Monitor)', pRefPct);
        app.docRefLabel.FontColor = app.T.success;
    end
    
    % Confidence
    app.docConfLabel.Text = sprintf('AI Confidence: %.1f%%', c.grade_result.confidence * 100);
    
    % Agreement
    if strcmp(agree_str, 'Yes')
        app.docAgreeLabel.Text = 'Agreement: Yes';
        app.docAgreeLabel.FontColor = app.T.success;
    else
        app.docAgreeLabel.Text = 'Agreement: No';
        app.docAgreeLabel.FontColor = app.T.danger;
    end
    
    % DME
    if strcmp(dme_str, 'SUSPECTED')
        app.docDmeLabel.Text = 'DME: SUSPECTED';
        app.docDmeLabel.FontColor = app.T.danger;
    else
        app.docDmeLabel.Text = 'DME: None';
        app.docDmeLabel.FontColor = app.T.success;
    end
    
    % Recommendation
    app.docRecLabel.Text = sprintf('Rec: %s', rec);
    
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
    app.confirmBtn.Enable = 'off';
    app.overrideBtn.Enable = 'off';
    app.fig.UserData = app;
    
    refreshDoctorQueue(app);
    
    uialert(app.fig, 'Grade confirmed and logged.', 'Confirmed', 'Icon', 'success');
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
    app.confirmBtn.Enable = 'off';
    app.overrideBtn.Enable = 'off';
    app.overrideReason.Value = '';
    app.fig.UserData = app;
    
    refreshDoctorQueue(app);
    
    uialert(app.fig, sprintf('Grade overridden to %d. Logged.', newGrade), 'Overridden', 'Icon', 'info');
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
    T = app.T;
    
    % ── Load validation results (Tab 2: Validation) ──
    valFile = fullfile(cfg.model_dir, 'validation_results.mat');
    if exist(valFile, 'file')
        val = load(valFile);
        
        m = [];
        if isfield(val, 'results')
            m = val.results;
        elseif isfield(val, 'metrics')
            m = val.metrics;
        end
        
        if ~isempty(m)
            % Populate Validation KPI Cards
            if isfield(m, 'sensitivity')
                app.valKpiValues(1).Text = sprintf('%.1f%%', m.sensitivity*100);
            end
            if isfield(m, 'specificity')
                app.valKpiValues(2).Text = sprintf('%.1f%%', m.specificity*100);
            end
            if isfield(m, 'auroc')
                app.valKpiValues(3).Text = sprintf('%.3f', m.auroc);
            end
            if isfield(m, 'qwk')
                app.valKpiValues(4).Text = sprintf('%.3f', m.qwk);
            end
            
            % Detailed metrics text
            metricsStr = {};
            metricsStr{end+1} = '---- Model Validation Report ----';
            metricsStr{end+1} = '';
            if isfield(m, 'sensitivity') && isfield(m, 'sensitivity_ci')
                metricsStr{end+1} = sprintf('Sensitivity: %.2f%%', m.sensitivity*100);
                metricsStr{end+1} = sprintf('  95%% CI: [%.1f%%, %.1f%%]', m.sensitivity_ci(1)*100, m.sensitivity_ci(2)*100);
            end
            if isfield(m, 'specificity') && isfield(m, 'specificity_ci')
                metricsStr{end+1} = sprintf('Specificity: %.2f%%', m.specificity*100);
                metricsStr{end+1} = sprintf('  95%% CI: [%.1f%%, %.1f%%]', m.specificity_ci(1)*100, m.specificity_ci(2)*100);
            end
            metricsStr{end+1} = '';
            if isfield(m, 'auroc')
                metricsStr{end+1} = sprintf('AUROC: %.4f', m.auroc);
            end
            if isfield(m, 'accuracy')
                metricsStr{end+1} = sprintf('Accuracy: %.1f%%', m.accuracy*100);
            end
            if isfield(m, 'f1_score')
                metricsStr{end+1} = sprintf('F1 Score: %.2f%%', m.f1_score*100);
            end
            if isfield(m, 'qwk')
                metricsStr{end+1} = sprintf('QWK (Kappa): %.4f', m.qwk);
                if m.qwk >= 0.80
                    metricsStr{end+1} = '  Interpretation: Almost perfect agreement';
                elseif m.qwk >= 0.60
                    metricsStr{end+1} = '  Interpretation: Substantial agreement';
                end
            end
            if isfield(m, 'ece')
                metricsStr{end+1} = sprintf('ECE: %.4f', m.ece);
                if m.ece < 0.05
                    metricsStr{end+1} = '  Interpretation: Well-calibrated';
                end
            end
            metricsStr{end+1} = '';
            if isfield(m, 'npv')
                metricsStr{end+1} = sprintf('NPV: %.2f%%', m.npv*100);
            end
            if isfield(m, 'ppv')
                metricsStr{end+1} = sprintf('PPV (Precision): %.2f%%', m.ppv*100);
            end
            metricsStr{end+1} = '';
            if isfield(m, 'n_samples')
                metricsStr{end+1} = sprintf('Validated on %d samples', m.n_samples);
            end
            if isfield(m, 'dataset')
                metricsStr{end+1} = sprintf('Dataset: %s', m.dataset);
            end
            app.metricsText.Value = metricsStr;
            
            % Reliability diagram
            if isfield(m, 'bin_accs') && isfield(m, 'bin_confs')
                cla(app.relDiagAxes);
                nBins = length(m.bin_confs);
                binW = 0.8 / nBins;
                
                % Gradient color bars
                cmap = parula(nBins);
                hold(app.relDiagAxes, 'on');
                for bi = 1:nBins
                    bar(app.relDiagAxes, m.bin_confs(bi), m.bin_accs(bi), binW, ...
                        'FaceColor', cmap(bi,:), 'EdgeColor', [0.3 0.3 0.3]);
                end
                plot(app.relDiagAxes, [0 1], [0 1], 'r--', 'LineWidth', 2);
                hold(app.relDiagAxes, 'off');
                xlabel(app.relDiagAxes, 'Mean Predicted Confidence');
                ylabel(app.relDiagAxes, 'Fraction of Positives');
                grid(app.relDiagAxes, 'on');
                xlim(app.relDiagAxes, [0 1]);
                ylim(app.relDiagAxes, [0 1]);
                if isfield(m, 'ece')
                    title(app.relDiagAxes, sprintf('Reliability Diagram (ECE = %.4f)', m.ece));
                else
                    title(app.relDiagAxes, 'Reliability Diagram');
                end
            end
        end
    else
        app.metricsText.Value = {'No validation_results.mat found.', ...
            'Run: generate_demo_validation_data()'};
    end
    
    % ── Load screening log (Tab 3: Escalation) ──
    logFile = fullfile(app.rootDir, 'data', 'screening_log.csv');
    darkAxis = [0.15 0.15 0.15];
    if exist(logFile, 'file')
        try
            logData = readtable(logFile);
            nTotal = height(logData);
            nConfirmed = sum(strcmp(logData.action, 'CONFIRMED'));
            nOverrides = sum(strcmp(logData.action, 'OVERRIDDEN'));
            overrideRate = nOverrides / max(nTotal, 1) * 100;
            
            % Average AI confidence
            avgConf = 0;
            if ismember('ai_pRef', logData.Properties.VariableNames)
                avgConf = mean(logData.ai_pRef) * 100;
            end
            
            % ── Populate Escalation KPI Cards ──
            app.escKpiValues(1).Text = sprintf('%d', nTotal);
            app.escKpiValues(2).Text = sprintf('%d', nConfirmed);
            app.escKpiValues(3).Text = sprintf('%d', nOverrides);
            app.escKpiValues(4).Text = sprintf('%.1f%%', overrideRate);
            app.escKpiValues(5).Text = sprintf('%.1f%%', avgConf);
            
            % Color-code override rate card
            if overrideRate > 15
                app.escKpiValues(4).Parent.BackgroundColor = [0.816 0.133 0.133];
            elseif overrideRate > 5
                app.escKpiValues(4).Parent.BackgroundColor = [0.886 0.627 0.086];
            else
                app.escKpiValues(4).Parent.BackgroundColor = [0.086 0.608 0.290];
            end
            
            % ── Grade Distribution: AI vs Doctor (grouped bar) ──
            if ismember('ai_grade', logData.Properties.VariableNames) && ...
               ismember('doctor_grade', logData.Properties.VariableNames)
                cla(app.gradeDistAxes);
                aiCounts = zeros(1, 5);
                docCounts = zeros(1, 5);
                for g = 0:4
                    aiCounts(g+1) = sum(logData.ai_grade == g);
                    docCounts(g+1) = sum(logData.doctor_grade == g);
                end
                
                groupData = [aiCounts; docCounts]';
                b = bar(app.gradeDistAxes, 1:5, groupData, 'grouped');
                b(1).FaceColor = [0.27 0.51 0.71]; % AI = blue
                b(2).FaceColor = [0.30 0.69 0.29]; % Doctor = green
                
                % Add count labels on top of bars
                hold(app.gradeDistAxes, 'on');
                for g = 1:5
                    if aiCounts(g) > 0
                        text(app.gradeDistAxes, g - 0.15, aiCounts(g) + 0.3, ...
                            sprintf('%d', aiCounts(g)), 'HorizontalAlignment', 'center', ...
                            'FontSize', 10, 'FontWeight', 'bold', 'Color', [0.2 0.4 0.6]);
                    end
                    if docCounts(g) > 0
                        text(app.gradeDistAxes, g + 0.15, docCounts(g) + 0.3, ...
                            sprintf('%d', docCounts(g)), 'HorizontalAlignment', 'center', ...
                            'FontSize', 10, 'FontWeight', 'bold', 'Color', [0.2 0.55 0.2]);
                    end
                end
                hold(app.gradeDistAxes, 'off');
                
                set(app.gradeDistAxes, 'XTick', 1:5, ...
                    'XTickLabel', {'G0 No DR', 'G1 Mild', 'G2 Mod', 'G3 Severe', 'G4 PDR'});
                ylabel(app.gradeDistAxes, 'Number of Cases');
                legend(app.gradeDistAxes, {'AI Prediction', 'Doctor Final'}, 'Location', 'northwest');
                
                % Check agreement
                nAgree = sum(logData.ai_grade == logData.doctor_grade);
                agreeRate = nAgree / max(nTotal, 1) * 100;
                title(app.gradeDistAxes, sprintf('Grade Comparison (AI-Doctor agreement: %.0f%%)', agreeRate), ...
                    'Color', darkAxis);
                grid(app.gradeDistAxes, 'on');
                app.gradeDistAxes.XColor = darkAxis;
                app.gradeDistAxes.YColor = darkAxis;
            end
            
            % ── Doctor Decision Breakdown (vertical bars) ──
            cla(app.overrideAxes);
            if nTotal > 0
                b = bar(app.overrideAxes, [1 2], [nConfirmed, nOverrides], 0.5);
                b.FaceColor = 'flat';
                b.CData = [T.success; T.warning];
                
                % Add count labels on top
                hold(app.overrideAxes, 'on');
                text(app.overrideAxes, 1, nConfirmed + 0.3, sprintf('%d', nConfirmed), ...
                    'HorizontalAlignment', 'center', 'FontSize', 14, 'FontWeight', 'bold', ...
                    'Color', [0.1 0.45 0.1]);
                text(app.overrideAxes, 2, max(nOverrides, 0) + 0.3, sprintf('%d', nOverrides), ...
                    'HorizontalAlignment', 'center', 'FontSize', 14, 'FontWeight', 'bold', ...
                    'Color', [0.7 0.4 0.0]);
                hold(app.overrideAxes, 'off');
                
                set(app.overrideAxes, 'XTick', [1 2], ...
                    'XTickLabel', {'Confirmed by Doctor', 'Overridden by Doctor'});
                ylabel(app.overrideAxes, 'Number of Cases');
                title(app.overrideAxes, sprintf('Doctor Decisions — Override rate: %.1f%%', overrideRate), ...
                    'Color', darkAxis);
                grid(app.overrideAxes, 'on');
                
                % Interpretation text
                if overrideRate == 0
                    % Add annotation for 100% agreement
                    text(app.overrideAxes, 1.5, nConfirmed * 0.6, ...
                        {'100% AI-Doctor', 'Agreement'}, ...
                        'HorizontalAlignment', 'center', 'FontSize', 12, ...
                        'FontWeight', 'bold', 'Color', T.success);
                end
            else
                title(app.overrideAxes, 'No doctor decisions yet', 'Color', darkAxis);
            end
            app.overrideAxes.XColor = darkAxis;
            app.overrideAxes.YColor = darkAxis;
            
            % ── Escalation Log Text ──
            escStr = {};
            escStr{end+1} = '=== Screening Log Summary ===';
            escStr{end+1} = sprintf('Total escalated cases reviewed by doctor: %d', nTotal);
            escStr{end+1} = sprintf('  Confirmed (AI grade accepted): %d (%.0f%%)', ...
                nConfirmed, nConfirmed/max(nTotal,1)*100);
            escStr{end+1} = sprintf('  Overridden (doctor changed grade): %d (%.0f%%)', ...
                nOverrides, overrideRate);
            escStr{end+1} = '';
            
            if overrideRate > 15
                escStr{end+1} = 'WARNING: Override rate > 15%! Model may need recalibration.';
            elseif overrideRate == 0
                escStr{end+1} = 'Override rate: 0.0% — Doctor agrees with AI on all cases. Model performing well.';
            else
                escStr{end+1} = sprintf('Override rate: %.1f%% (threshold: <15%% — acceptable)', overrideRate);
            end
            escStr{end+1} = '';
            
            % AI-Doctor agreement
            if ismember('ai_grade', logData.Properties.VariableNames) && ...
               ismember('doctor_grade', logData.Properties.VariableNames)
                nAgree = sum(logData.ai_grade == logData.doctor_grade);
                escStr{end+1} = sprintf('=== AI-Doctor Agreement: %d/%d (%.0f%%) ===', ...
                    nAgree, nTotal, nAgree/max(nTotal,1)*100);
                if nAgree == nTotal
                    escStr{end+1} = '  Doctor confirmed AI predictions on every case.';
                end
                escStr{end+1} = '';
            end
            
            % Grade breakdown
            grade_labels = {'No DR', 'Mild NPDR', 'Moderate NPDR', 'Severe NPDR', 'PDR'};
            if ismember('ai_grade', logData.Properties.VariableNames)
                escStr{end+1} = '=== Grade Breakdown (Escalated Cases) ===';
                for g = 0:4
                    cnt = sum(logData.ai_grade == g);
                    if cnt > 0
                        escStr{end+1} = sprintf('  Grade %d (%s): %d cases', g, grade_labels{g+1}, cnt);
                    end
                end
                escStr{end+1} = '';
            end
            
            % Escalation triggers
            escStr{end+1} = '=== Why Cases Were Escalated ===';
            if ismember('reason', logData.Properties.VariableNames)
                ood_count = sum(contains(string(logData.reason), 'OOD', 'IgnoreCase', true));
                border_count = sum(contains(string(logData.reason), 'Borderline', 'IgnoreCase', true));
                discord_count = sum(contains(string(logData.reason), 'Discordant', 'IgnoreCase', true));
                escStr{end+1} = sprintf('  Out-of-Distribution (OOD): %d cases', ood_count);
                escStr{end+1} = sprintf('  Borderline referral probability: %d cases', border_count);
                escStr{end+1} = sprintf('  Discordant findings (grade vs lesion count): %d cases', discord_count);
                other_count = nTotal - ood_count - border_count - discord_count;
                if other_count > 0
                    escStr{end+1} = sprintf('  Other safety triggers: %d cases', other_count);
                end
            else
                escStr{end+1} = '  (Detailed trigger data not available)';
            end
            
            app.escText.Value = escStr;
        catch ME
            app.escText.Value = {sprintf('Error reading log: %s', ME.message)};
        end
    else
        app.escText.Value = {'No screening log found yet.', 'Process patients to generate data.'};
    end
    
    app.fig.UserData = app;
end

function runSimFromGUI(app)
    app = app.fig.UserData;
    T = app.T;
    
    params = struct();
    params.population = app.simPopField.Value;
    params.dm_prevalence = app.simDmField.Value;
    params.camp_days_per_month = app.simCampField.Value;
    params.devices_per_camp = app.simDevField.Value;
    params.referral_adherence = app.simAdhSlider.Value;
    
    try
        sim_results = run_simulation(app.cfg, params);
        
        % ── Update KPI Cards ──
        app.kpiValues(1).Text = sprintf('%.1f mo', sim_results.months_to_screen);
        app.kpiValues(2).Text = formatNum(sim_results.patients_per_month);
        app.kpiValues(3).Text = sprintf('%.0f%%', sim_results.doctor_utilization * 100);
        app.kpiValues(4).Text = formatNum(round(sim_results.treatment_gap));
        
        % Color code doctor utilization
        if sim_results.doctor_utilization > 1.0
            app.kpiValues(3).Parent.BackgroundColor = [0.816 0.133 0.133]; % red
        elseif sim_results.doctor_utilization > 0.8
            app.kpiValues(3).Parent.BackgroundColor = [0.886 0.627 0.086]; % amber
        else
            app.kpiValues(3).Parent.BackgroundColor = [0.086 0.608 0.290]; % green
        end
        
        % ── Bottleneck Indicator ──
        app.bottleneckLabel.Text = sim_results.bottleneck;
        if contains(sim_results.bottleneck, 'Doctor')
            app.bottleneckLabel.BackgroundColor = T.danger;
        else
            app.bottleneckLabel.BackgroundColor = T.warning;
        end
        
        % ── Sweep Matrix Heatmap ──
        if isfield(sim_results, 'sweep_matrix')
            cla(app.sweepAxes);
            camp_days_sweep = 2:2:20;
            devices_sweep = 1:5;
            
            imagesc(app.sweepAxes, devices_sweep, camp_days_sweep, sim_results.sweep_matrix);
            colorbar(app.sweepAxes);
            
            % Custom green-yellow-red colormap (green=fast, red=slow)
            nColors = 256;
            greenToRed = zeros(nColors, 3);
            for ci = 1:nColors
                t = (ci-1)/(nColors-1);
                if t < 0.5
                    greenToRed(ci,:) = [2*t, 0.75+0.25*(1-2*t), 0.15*(1-2*t)];
                else
                    greenToRed(ci,:) = [1, 0.75*(1-2*(t-0.5)), 0];
                end
            end
            colormap(app.sweepAxes, flipud(greenToRed));
            
            xlabel(app.sweepAxes, 'Devices per Camp');
            ylabel(app.sweepAxes, 'Camp Days per Month');
            title(app.sweepAxes, 'Months to Screen All Diabetics');
            set(app.sweepAxes, 'YDir', 'normal');
            set(app.sweepAxes, 'XTick', devices_sweep, 'YTick', camp_days_sweep);
            
            % Add text labels on each cell
            hold(app.sweepAxes, 'on');
            for i = 1:length(camp_days_sweep)
                for j = 1:length(devices_sweep)
                    val = sim_results.sweep_matrix(i,j);
                    if val > median(sim_results.sweep_matrix(:))
                        tc = [1 1 1];
                    else
                        tc = [0 0 0];
                    end
                    text(app.sweepAxes, devices_sweep(j), camp_days_sweep(i), ...
                        sprintf('%.0f', val), 'HorizontalAlignment', 'center', ...
                        'FontSize', 10, 'FontWeight', 'bold', 'Color', tc);
                end
            end
            hold(app.sweepAxes, 'off');
        end
        
        % ── Treatment Gap Bar Chart ──
        cla(app.treatmentAxes);
        treated = round(sim_results.patients_actually_treated);
        gap = round(sim_results.treatment_gap);
        total_need = round(sim_results.patients_needing_treatment);
        
        b = bar(app.treatmentAxes, [1 2 3], [total_need, treated, gap]);
        b.FaceColor = 'flat';
        b.CData = [T.accent; T.success; T.danger];
        set(app.treatmentAxes, 'XTick', [1 2 3], ...
            'XTickLabel', {'Need Care', 'Treated', 'Gap'});
        ylabel(app.treatmentAxes, 'Patients');
        title(app.treatmentAxes, 'Treatment Access');
        grid(app.treatmentAxes, 'on');
        
        % Gap info text
        gapStr = {};
        gapStr{end+1} = 'Key Findings:';
        gapStr{end+1} = '';
        gapStr{end+1} = sprintf('Diabetic Pop: %s', formatNum(sim_results.diabetic_pop));
        gapStr{end+1} = sprintf('Need treatment: %s', formatNum(total_need));
        gapStr{end+1} = sprintf('Actually treated: %s', formatNum(treated));
        gapStr{end+1} = sprintf('Adherence: %.1f%%', params.referral_adherence*100);
        gapStr{end+1} = '';
        gapStr{end+1} = sprintf('GAP: %s patients', formatNum(gap));
        gapStr{end+1} = 'never get care!';
        gapStr{end+1} = '';
        gapStr{end+1} = sprintf('Patients/day: %d', round(sim_results.patients_per_camp_day));
        gapStr{end+1} = sprintf('Escalated/day: %d', round(sim_results.escalated_per_day));
        app.gapInfoLabel.Text = strjoin(gapStr, newline);
        
        % Summary text
        lines = {};
        lines{end+1} = '=== Detailed Results ===';
        lines{end+1} = sprintf('Diabetic pop: %s', formatNum(sim_results.diabetic_pop));
        lines{end+1} = sprintf('Patients/month: %s', formatNum(sim_results.patients_per_month));
        lines{end+1} = sprintf('Months to screen: %.1f', sim_results.months_to_screen);
        lines{end+1} = sprintf('Doctor util: %.1f%%', sim_results.doctor_utilization*100);
        lines{end+1} = sprintf('Bottleneck: %s', sim_results.bottleneck);
        lines{end+1} = '';
        lines{end+1} = sprintf('Treatment gap: %s/mo', formatNum(gap));
        app.simResultText.Value = lines;
        
        drawnow;
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
function closeFig(fig)
    app = fig.UserData;
    
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
    
    delete(fig);
end

% ================================================================
% HELPER FUNCTIONS — Pipeline Progress
% ================================================================
function updateStep(app, stepNum, status)
    app = app.fig.UserData;
    T = app.T;
    name = getStepName(stepNum);
    switch status
        case 'running'
            app.stepLabels(stepNum).Text = sprintf('  >> Step %d: %s ...', stepNum, name);
            app.stepLabels(stepNum).FontColor = T.accent;
            app.stepLabels(stepNum).FontWeight = 'bold';
        case 'done'
            app.stepLabels(stepNum).Text = sprintf('  [done] Step %d: %s', stepNum, name);
            app.stepLabels(stepNum).FontColor = T.success;
            app.stepLabels(stepNum).FontWeight = 'normal';
        otherwise
            app.stepLabels(stepNum).Text = sprintf('  o  Step %d: %s', stepNum, name);
            app.stepLabels(stepNum).FontColor = T.textSec;
            app.stepLabels(stepNum).FontWeight = 'normal';
    end
    app.fig.UserData = app;
end

function name = getStepName(stepNum)
    names = {'Image Standardization', 'Quality Assessment', 'Vessel Segmentation', ...
             'Lesion Detection (ONNX)', 'DR Grading (ONNX)', 'Explainability', 'Safety Checks'};
    if stepNum >= 1 && stepNum <= length(names)
        name = names{stepNum};
    else
        name = 'Unknown';
    end
end
