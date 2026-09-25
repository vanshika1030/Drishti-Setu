# DrishtiSetu — Fix Tracker

> **Started:** 2026-09-26
> **Total items:** 13
> **Completed:** 13/13

---

## Fix Status

| # | Fix | File(s) | Priority | Status |
|---|-----|---------|----------|--------|
| 1 | Quality grid 4x4 to 16x16 | config/pipeline_config.m | HIGH | DONE |
| 2 | Generate demo validation data | validation/generate_demo_validation_data.m | HIGH | DONE |
| 3 | Real ONNX counterfactual re-grading | explainability/decision_flip_check.m | MEDIUM | DONE |
| 4 | Evidence text formatting | reports/format_evidence_chain.m | MEDIUM | DONE |
| 5 | Technician: animated progress steps | run_drishtisetu.m | HIGH | DONE |
| 6 | Technician: processing animation on load | run_drishtisetu.m | HIGH | DONE |
| 7 | Technician: quality heatmap legend | run_drishtisetu.m | MEDIUM | DONE |
| 8 | Technician: Grad-CAM explanation | run_drishtisetu.m | MEDIUM | DONE |
| 9 | Technician: UI color and layout polish | run_drishtisetu.m | MEDIUM | DONE |
| 10 | Doctor: counterfactual visualization panel | run_drishtisetu.m | HIGH | DONE |
| 11 | Doctor: doctor-friendly metrics | run_drishtisetu.m | HIGH | DONE |
| 12 | Doctor: fix button states | run_drishtisetu.m | HIGH | DONE |
| 13 | District: enhanced escalation breakdown + reliability diagram | run_drishtisetu.m | MEDIUM | DONE |

---

## Change Log

### Fix #1 — Quality grid 4x4 to 16x16
- **File:** `config/pipeline_config.m`
- Changed `quality_tile_grid` from `[4 4]` to `[16 16]`
- Lowered `quality_sharpness_threshold` from 100 to 25 (smaller tiles have less variance)

### Fix #2 — Generate demo validation data
- **File:** `validation/generate_demo_validation_data.m` (NEW)
- Created script that generates realistic validation metrics
- Saves to `models/validation_results.mat` with sensitivity, specificity, AUROC, QWK, ECE, reliability diagram bins
- Clearly marked as DEMO data
- **Ran successfully** — validation_results.mat created

### Fix #3 — Real ONNX counterfactual re-grading
- **File:** `explainability/decision_flip_check.m`
- Now runs real ONNX DR model on the healed image via `run_onnx_inference('dr', ...)`
- Falls back to simulated grade drop if ONNX fails
- Records `inference_method` ('onnx_real' or 'simulated')

### Fix #4 — Evidence text formatting
- **File:** `reports/format_evidence_chain.m`
- Structured with section headers: AI Model Results, Lesion Findings, Safety Checks, Counterfactual Check, Escalation Reason
- Doctor-friendly language: percentages, interpretation hints
- Shows counterfactual inference method (real vs simulated)

### Fix #5 — Technician: animated progress steps
- **File:** `run_drishtisetu.m` (buildTechnicianPanel + runAnalysis)
- Added 7-step pipeline progress panel with step labels and gauge
- Each step shows running/done status with color changes
- Gauge animates from 0% to 100% as steps complete
- Added `updateStep()` and `getStepName()` helper functions

### Fix #6 — Technician: processing animation on load
- **File:** `run_drishtisetu.m` (loadImage)
- 3-step animated sequence: Standardizing -> Quality Assessment -> Heatmap generation
- Each step has descriptive text + drawnow + pause for visibility

### Fix #7 — Technician: quality heatmap legend
- **File:** `run_drishtisetu.m` (displayQualityHeatmap + buildTechnicianPanel)
- Added `qualLegendLabel` below heatmap axes
- Shows tile counts: "Good: 180/256 | Blur: 12 | Dark: 4 | Glare: 0"
- Title updated to show grid dimensions

### Fix #8 — Technician: Grad-CAM explanation
- **File:** `run_drishtisetu.m` (buildTechnicianPanel)
- Added `gcamLegendLabel` below Grad-CAM axes
- Text: "Red/Yellow = High AI attention | Blue = Low attention | Feature-based explainability"

### Fix #9 — Technician: UI polish
- Pipeline progress panel styled with subtle background color
- Step labels use color coding (blue=running, green=done, gray=pending)
- Quality legend and Grad-CAM explanation add context
- Pipeline panel resets on "Next Patient"

### Fix #10 — Doctor: counterfactual visualization panel
- **File:** `run_drishtisetu.m` (buildDoctorPanel + loadEscalatedCase)
- Added counterfactual panel with:
  - Original image axes + Healed image axes (side by side)
  - Arrow (>>) between them
  - Result label showing grade change (e.g., "Grade: 4 -> 3")
  - Description text (supports/doesn't support influence)
  - Disclaimer: "Explainability visualization only. Not a clinical diagnosis."
- Reduced evidence image height from 280px to 220px to fit counterfactual panel
- Evidence text area repositioned and shortened

### Fix #11 — Doctor: doctor-friendly metrics
- **File:** `run_drishtisetu.m` (loadEscalatedCase)
- Replaced raw "pRef: 0.990" with "Referral Probability: 99.0% (>85% = Refer to ophthalmologist)"
- Replaced "Agreement: true" with "Model Agreement: Yes"
- Added "Recommendation:" line from urgency_labels
- Shows DR Severity with grade name (e.g., "Grade 4 (PDR)")

### Fix #12 — Doctor: fix button states
- **File:** `run_drishtisetu.m` (doctorConfirm, doctorOverride)
- Buttons now disabled and fig.UserData saved BEFORE calling refreshDoctorQueue
- Prevents stale state from causing button failures
- refreshDoctorQueue properly resets buttons when queue is empty

### Fix #13 — District: enhanced escalation breakdown + reliability diagram
- **File:** `run_drishtisetu.m` (refreshDistrictDashboard)
- Fixed validation data loading: now checks both 'results' and 'metrics' struct names
- Shows all metrics: sensitivity, specificity, AUROC, accuracy, QWK, ECE, sample count
- Reliability diagram: colored bars, grid lines, proper axes limits
- Enhanced screening log: confirmed/overridden counts with percentages
- Grade distribution breakdown (Grade 0-4 with names)
- Escalation triggers breakdown (OOD, Borderline pRef, Discordant)
- Override rate with threshold indicator
- Error handling for log file reading
