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
        'Text', '📊  Metrics', 'FontSize', 12, 'FontWeight', 'bold', 'FontColor', T.header);
    app.docMetricsLabel = uilabel(metricsBox, 'Position', [10 6 314 188], ...
        'Text', '', 'FontSize', 11, 'WordWrap', 'on', 'VerticalAlignment', 'top', ...
        'FontColor', T.textPri);
    
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
    
    % Left: Metrics
    metricsBox = uipanel(p, 'Position', [12 400 644 380], ...
        'BackgroundColor', T.card, 'BorderType', 'line', 'BorderColor', T.border, ...
        'Title', '', 'FontSize', 1);
    uilabel(metricsBox, 'Position', [14 348 300 24], ...
        'Text', '📊  Validation Metrics', 'FontSize', 14, 'FontWeight', 'bold', 'FontColor', T.header);
    app.metricsText = uitextarea(metricsBox, 'Position', [10 10 624 336], ...
        'FontSize', 11, 'Editable', 'off', ...
        'Value', {'Metrics will load from validation_results.mat', ...
                  'Run validate_pipeline(pipeline_config()) to generate.'});
    
    % Right: Reliability diagram
    reliabilityBox = uipanel(p, 'Position', [668 400 640 380], ...
        'BackgroundColor', T.card, 'BorderType', 'line', 'BorderColor', T.border, ...
        'Title', '', 'FontSize', 1);
    uilabel(reliabilityBox, 'Position', [14 348 300 24], ...
        'Text', '📈  Reliability Diagram', 'FontSize', 14, 'FontWeight', 'bold', 'FontColor', T.header);
    app.relDiagAxes = uiaxes(reliabilityBox, 'Position', [10 10 620 330]);
    title(app.relDiagAxes, 'Reliability Diagram');
    
    % Left bottom: Escalation
    escBox = uipanel(p, 'Position', [12 10 644 380], ...
        'BackgroundColor', T.card, 'BorderType', 'line', 'BorderColor', T.border, ...
        'Title', '', 'FontSize', 1);
    uilabel(escBox, 'Position', [14 348 300 24], ...
        'Text', '🔔  Escalation Breakdown', 'FontSize', 14, 'FontWeight', 'bold', 'FontColor', T.header);
    app.escText = uitextarea(escBox, 'Position', [10 10 624 336], ...
        'FontSize', 11, 'Editable', 'off', ...
        'Value', {'Escalation breakdown and ablation results will appear here.'});
    
    % Right bottom: Simulation
    simBox = uipanel(p, 'Position', [668 10 640 380], ...
        'BackgroundColor', T.card, 'BorderType', 'line', 'BorderColor', T.border, ...
        'Title', '', 'FontSize', 1);
    uilabel(simBox, 'Position', [14 348 300 24], ...
        'Text', '⚙  Screening Simulation', 'FontSize', 14, 'FontWeight', 'bold', 'FontColor', T.header);
    
    uilabel(simBox, 'Position', [15 310 150 22], 'Text', 'Population:', 'FontSize', 11, 'FontColor', T.textSec);
    app.simPopField = uieditfield(simBox, 'numeric', 'Position', [170 308 100 24], 'Value', 500000);
    
    uilabel(simBox, 'Position', [15 280 150 22], 'Text', 'DM Prevalence:', 'FontSize', 11, 'FontColor', T.textSec);
    app.simDmField = uieditfield(simBox, 'numeric', 'Position', [170 278 100 24], 'Value', 0.12);
    
    uilabel(simBox, 'Position', [15 250 150 22], 'Text', 'Camp days/month:', 'FontSize', 11, 'FontColor', T.textSec);
    app.simCampField = uieditfield(simBox, 'numeric', 'Position', [170 248 100 24], 'Value', 4);
    
    uilabel(simBox, 'Position', [15 220 150 22], 'Text', 'Devices/camp:', 'FontSize', 11, 'FontColor', T.textSec);
    app.simDevField = uieditfield(simBox, 'numeric', 'Position', [170 218 100 24], 'Value', 3);
    
    uilabel(simBox, 'Position', [290 310 170 22], 'Text', 'Referral adherence:', 'FontSize', 11, 'FontColor', T.textSec);
    app.simAdhSlider = uislider(simBox, 'Position', [290 295 270 3], ...
        'Limits', [0.11 0.57], 'Value', 0.145);
    app.simAdhLabel = uilabel(simBox, 'Position', [565 288 50 22], 'Text', '14.5%', 'FontSize', 10, 'FontColor', T.textSec);
    app.simAdhSlider.ValueChangedFcn = @(s,~) set(app.simAdhLabel, 'Text', sprintf('%.1f%%', s.Value*100));
    
    app.runSimBtn = uibutton(simBox, 'Position', [290 242 280 32], ...
        'Text', '▶  Run Simulation', 'FontSize', 12, 'FontWeight', 'bold', ...
        'BackgroundColor', T.accent, 'FontColor', 'white', ...
        'ButtonPushedFcn', @(~,~) runSimFromGUI(app));
    
    app.simResultText = uitextarea(simBox, 'Position', [15 10 600 200], ...
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
        app.docMetricsLabel.Text = '';
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
    
    metricLines = {};
    metricLines{end+1} = sprintf('DR Severity: Grade %d (%s)', c.grade_result.grade, grade_name);
    metricLines{end+1} = '';
    metricLines{end+1} = sprintf('Referral Probability: %.1f%%', c.grade_result.pRef * 100);
    metricLines{end+1} = '(>85% = Refer to ophthalmologist)';
    metricLines{end+1} = '';
    metricLines{end+1} = sprintf('AI Confidence: %.1f%%', c.grade_result.confidence * 100);
    metricLines{end+1} = '(How certain the AI is)';
    metricLines{end+1} = '';
    metricLines{end+1} = sprintf('Model Agreement: %s', agree_str);
    metricLines{end+1} = '';
    metricLines{end+1} = sprintf('Macular Edema: %s', dme_str);
    metricLines{end+1} = '';
    metricLines{end+1} = sprintf('Recommendation: %s', rec);
    app.docMetricsLabel.Text = strjoin(metricLines, newline);
    
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
    
    % Load validation results if available
    valFile = fullfile(cfg.model_dir, 'validation_results.mat');
    if exist(valFile, 'file')
        val = load(valFile);
        
        % The generate_demo_validation_data saves under 'results' struct
        m = [];
        if isfield(val, 'results')
            m = val.results;
        elseif isfield(val, 'metrics')
            m = val.metrics;
        end
        
        metricsStr = {};
        if ~isempty(m)
            metricsStr{end+1} = '=== Validation Metrics ===';
            metricsStr{end+1} = '';
            if isfield(m, 'sensitivity') && isfield(m, 'sensitivity_ci')
                metricsStr{end+1} = sprintf('Sensitivity: %.1f%% [%.1f%%, %.1f%%]', ...
                    m.sensitivity*100, m.sensitivity_ci(1)*100, m.sensitivity_ci(2)*100);
            end
            if isfield(m, 'specificity') && isfield(m, 'specificity_ci')
                metricsStr{end+1} = sprintf('Specificity: %.1f%% [%.1f%%, %.1f%%]', ...
                    m.specificity*100, m.specificity_ci(1)*100, m.specificity_ci(2)*100);
            end
            if isfield(m, 'auroc')
                metricsStr{end+1} = sprintf('AUROC: %.4f', m.auroc);
            end
            if isfield(m, 'accuracy')
                metricsStr{end+1} = sprintf('Accuracy: %.1f%%', m.accuracy*100);
            end
            if isfield(m, 'qwk')
                metricsStr{end+1} = sprintf('QWK (Kappa): %.4f', m.qwk);
            end
            if isfield(m, 'ece')
                metricsStr{end+1} = sprintf('ECE: %.4f', m.ece);
            end
            if isfield(m, 'n_samples')
                metricsStr{end+1} = '';
                metricsStr{end+1} = sprintf('Validated on %d samples', m.n_samples);
            end
            if isfield(m, 'is_demo_data') && m.is_demo_data
                metricsStr{end+1} = '(Demo data for display)';
            end
        end
        app.metricsText.Value = metricsStr;
        
        % Reliability diagram
        if ~isempty(m) && isfield(m, 'bin_accs') && isfield(m, 'bin_confs')
            cla(app.relDiagAxes);
            bar(app.relDiagAxes, m.bin_confs, m.bin_accs, 0.6, 'FaceColor', [0.27 0.51 0.71]);
            hold(app.relDiagAxes, 'on');
            plot(app.relDiagAxes, [0 1], [0 1], 'r--', 'LineWidth', 2);
            hold(app.relDiagAxes, 'off');
            xlabel(app.relDiagAxes, 'Mean Predicted Confidence');
            ylabel(app.relDiagAxes, 'Fraction of Positives');
            grid(app.relDiagAxes, 'on');
            xlim(app.relDiagAxes, [0 1]);
            ylim(app.relDiagAxes, [0 1]);
            if isfield(m, 'ece')
                title(app.relDiagAxes, sprintf('Reliability Diagram (ECE=%.4f)', m.ece));
            else
                title(app.relDiagAxes, 'Reliability Diagram');
            end
        elseif isfield(val, 'bin_accs') && isfield(val, 'bin_confs')
            cla(app.relDiagAxes);
            bar(app.relDiagAxes, val.bin_confs, val.bin_accs, 0.6, 'FaceColor', [0.27 0.51 0.71]);
            hold(app.relDiagAxes, 'on');
            plot(app.relDiagAxes, [0 1], [0 1], 'r--', 'LineWidth', 2);
            hold(app.relDiagAxes, 'off');
            xlabel(app.relDiagAxes, 'Mean Predicted Confidence');
            ylabel(app.relDiagAxes, 'Fraction of Positives');
            grid(app.relDiagAxes, 'on');
            title(app.relDiagAxes, 'Reliability Diagram');
        end
    else
        app.metricsText.Value = {'No validation_results.mat found.', ...
            'Run: generate_demo_validation_data()'};
    end
    
    % Load screening log — enhanced breakdown
    logFile = fullfile(app.rootDir, 'data', 'screening_log.csv');
    if exist(logFile, 'file')
        try
            logData = readtable(logFile);
            nTotal = height(logData);
            nConfirmed = sum(strcmp(logData.action, 'CONFIRMED'));
            nOverrides = sum(strcmp(logData.action, 'OVERRIDDEN'));
            overrideRate = nOverrides / max(nTotal, 1) * 100;
            
            escStr = {};
            escStr{end+1} = '=== Screening Log Summary ===';
            escStr{end+1} = sprintf('Total cases reviewed: %d', nTotal);
            escStr{end+1} = sprintf('  Confirmed by doctor: %d (%.0f%%)', nConfirmed, nConfirmed/max(nTotal,1)*100);
            escStr{end+1} = sprintf('  Overridden by doctor: %d (%.0f%%)', nOverrides, overrideRate);
            escStr{end+1} = '';
            
            if overrideRate > 15
                escStr{end+1} = 'WARNING: Override rate > 15%! Model investigation recommended.';
            else
                escStr{end+1} = sprintf('Override rate: %.1f%% (threshold: <15%%)', overrideRate);
            end
            escStr{end+1} = '';
            
            % Grade distribution
            escStr{end+1} = '=== Grade Distribution ===';
            grade_labels = {'No DR', 'Mild NPDR', 'Moderate NPDR', 'Severe NPDR', 'PDR'};
            if ismember('ai_grade', logData.Properties.VariableNames)
                for g = 0:4
                    cnt = sum(logData.ai_grade == g);
                    escStr{end+1} = sprintf('Grade %d (%s): %d cases', g, grade_labels{g+1}, cnt);
                end
            end
            escStr{end+1} = '';
            
            % Escalation triggers
            escStr{end+1} = '=== Escalation Triggers ===';
            if ismember('reason', logData.Properties.VariableNames)
                ood_count = sum(contains(string(logData.reason), 'OOD', 'IgnoreCase', true));
                border_count = sum(contains(string(logData.reason), 'Borderline', 'IgnoreCase', true));
                discord_count = sum(contains(string(logData.reason), 'Discordant', 'IgnoreCase', true));
                escStr{end+1} = sprintf('  OOD detected: %d', ood_count);
                escStr{end+1} = sprintf('  Borderline pRef: %d', border_count);
                escStr{end+1} = sprintf('  Discordant findings: %d', discord_count);
            else
                escStr{end+1} = '  (Trigger details not available in log)';
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
