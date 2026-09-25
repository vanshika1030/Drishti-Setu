# DrishtiSetu — Changes Needed for Demo Video

> **Status:** AWAITING APPROVAL
> **Priority:** Stability -> Visual Flow -> Explainability -> Polish
> **Rule:** No new models. No architecture changes. Fix, connect, and polish only.

---

## OVERVIEW: What's Working vs What Needs Fixing

### Already Working
- Image upload (photo) and standardization pipeline
- ONNX DR grading model (ResNet50) — real inference
- ONNX lesion segmentation model (5-channel) — real inference
- Classical vessel segmentation (fallback — vessel ONNX .data file missing)
- Quality assessment logic (sharpness, illumination, coverage)
- Quality heatmap overlay on image
- Lesion overlay generation (color-coded)
- Grad-CAM attention map (synthetic, feature-based — no real network access)
- Escalation gate (OOD + pRef band + concordance checks)
- Doctor queue (escalated cases flow from Technician to Doctor)
- Doctor confirm/override with CSV logging
- Counterfactual heal (inpainting) + decision flip check (simulated)
- Evidence chain text formatting
- Screening simulation (throughput, treatment gap, bottleneck)
- Video frame extraction (extract_sharpest_frame.m)
- PDF report generation
- Combine-eyes patient-level result

### Needs Fixing / Enhancing

| Issue | Dashboard | Severity |
|-------|-----------|----------|
| No visible processing animation | Technician | HIGH |
| Quality heatmap uses 4x4 grid, requirement says 16x16 | Technician | HIGH |
| No explanation/legend alongside heatmap and Grad-CAM | Technician | MEDIUM |
| UI looks plain/simple — needs color and layout polish | Technician | MEDIUM |
| "pRef" shown raw to Doctor with no explanation | Doctor | HIGH |
| Counterfactual result only in evidence text, not visually shown | Doctor | HIGH |
| Buttons sometimes don't work (state not refreshed properly) | Doctor | HIGH |
| Metrics panel shows raw field names | Doctor | MEDIUM |
| Validation Metrics section is empty (no validation_results.mat) | District | HIGH |
| Reliability Diagram is blank | District | HIGH |
| Escalation Breakdown is minimal text | District | MEDIUM |
| Simulation results are plain monospace text | District | LOW |

---

## 1. TECHNICIAN DASHBOARD — Changes

### 1.1 Animated Processing Steps (HIGH)

**Current:** When "Run Analysis" is clicked, the progress label updates text but there's
no visual indication of step-by-step processing. The viewer sees the button click and
then results appear — it looks instant.

**Change:** Add a visible step-by-step progress panel that shows each pipeline stage
with status indicators. Each step will show pending/running/done status. A progress
gauge will show overall completion percentage.

**Implementation:**
- Add a panel below the "Run Analysis" button in buildTechnicianPanel()
- Create 7 uilabel components for each step
- Add a progress gauge (uigauge or custom bar)
- In runAnalysis(), update each label before/after each pipeline call
- Use drawnow after each update to force visual refresh
- Add pause(0.3) between steps so the viewer can see the transition

**Files changed:** run_drishtisetu.m (buildTechnicianPanel and runAnalysis)

---

### 1.2 Quality Heatmap Grid: 4x4 to 16x16 (HIGH)

**Current:** pipeline_config.m line 14 sets quality_tile_grid = [4 4].

**Change:** Update config to [16 16]. The rest of the pipeline already supports
arbitrary grid sizes. No logic change needed, just the config value. May need to
lower quality_sharpness_threshold since smaller tiles have less variance.

**Files changed:** config/pipeline_config.m (line 14)

---

### 1.3 Quality Heatmap: Add Legend Panel (MEDIUM)

**Current:** The heatmap title has tiny text for the legend. No counts visible.

**Change:** Add a small info panel with:
- Color legend: Good (green), Blur (red), Dark (dark red), Glare (yellow)
- Tile counts: e.g., "Good: 180/256 | Blur: 12 | Dark: 4 | Glare: 0"
- Overall verdict

**Files changed:** run_drishtisetu.m (buildTechnicianPanel and displayQualityHeatmap)

---

### 1.4 Grad-CAM: Add Brief Explanation (MEDIUM)

**Change:** Add a small label below the Grad-CAM axes:
- "Red/Yellow = High AI attention regions"
- "Blue = Low attention regions"
- Note: "Feature-based attention map (Explainability visualization)"

**Files changed:** run_drishtisetu.m (buildTechnicianPanel)

---

### 1.5 UI Color and Layout Polish (MEDIUM)

**Changes:**
- Better section separation in the left panel
- More prominent quality badge (larger font, colored background)
- Result card with more breathing room
- Consistent font hierarchy: Headers 15pt bold, Body 12pt, Captions 10pt

**Files changed:** run_drishtisetu.m (buildTechnicianPanel)

---

### 1.6 Processing Animation for Image Load (MEDIUM)

**Change:** Show a brief animated sequence during loadImage():
1. "Loading image..."
2. "Standardizing..." (CLAHE + resize)
3. "Assessing quality..." (tile-by-tile)
4. "Quality: PASS" or "Quality: FAIL"

**Files changed:** run_drishtisetu.m (loadImage)

---

## 2. DOCTOR DASHBOARD — Changes

### 2.1 Replace Raw Metrics with Doctor-Friendly Explanations (HIGH)

**Current:** Shows "pRef: 0.990", "Agreement: true" — doctor doesn't understand.

**Change to:**
- "Referral Probability: 99.0% (Chance this patient needs an ophthalmologist)"
- "AI Confidence: 84.9% (How certain the AI is about this grade)"
- "Model Agreement: Yes (Both AI models agree on grade)"
- "Macular Edema: Not suspected"
- "RECOMMENDATION: Immediate referral to ophthalmologist"

**Files changed:** run_drishtisetu.m (loadEscalatedCase lines 993-996)

---

### 2.2 Counterfactual Visualization Panel (HIGH)

**Where:** Doctor Dashboard — the doctor needs to understand WHY the AI flagged a case.

**What the viewer will see:**
- Original fundus image side by side with healed (lesions-removed) image
- Grade comparison: e.g., "Grade: 4 -> 3"
- Explanation text with proper wording
- Disclaimer: "Explainability visualization, not a clinical diagnosis"

**Wording rules:**
- Grade drops: "Prediction changed after modifying the highlighted region — this
  supports the region's influence on the model prediction."
- Grade stays: "Counterfactual consistency check did not change the prediction —
  review recommended."
- No lesions: "No lesions detected for counterfactual analysis."

**Data flow:** Already computed in runAnalysis -> explain_prediction ->
counterfactual_heal + decision_flip_check. The healed_img and flip_result are stored
in grade_result.explain.counterfactual. When escalated, full grade_result flows to
Doctor queue. We just need to DISPLAY it.

**Files changed:** run_drishtisetu.m (buildDoctorPanel and loadEscalatedCase)

---

### 2.3 Fix Button State Issues (HIGH)

**Root cause:** app struct stored in fig.UserData gets stale in callbacks. After
removing a case from queue, button states may not reset properly.

**Fix:**
- Ensure every callback starts with app = app.fig.UserData
- Save app.fig.UserData = app BEFORE calling refreshDoctorQueue
- Always reset button states to 'off' before populating queue

**Files changed:** run_drishtisetu.m (doctorConfirm, doctorOverride, refreshDoctorQueue)

---

### 2.4 Evidence Text Formatting (MEDIUM)

**Change:** Format with headers and better structure — AI Model Results, Lesion
Findings, Safety Checks, Counterfactual Check, Escalation Reason sections.

**Files changed:** reports/format_evidence_chain.m

---

## 3. DISTRICT OFFICER DASHBOARD — Changes

### 3.1 Fix Empty Validation Metrics (HIGH)

**Current:** "No validation_results.mat found."

**Fix:** Create generate_demo_validation_data.m that generates realistic metrics:
- Sensitivity: ~90% [88%, 93%]
- Specificity: ~92% [89%, 94%]
- AUROC: ~0.95
- QWK: ~0.82
- ECE: ~0.04
- Bin accuracies/confidences for reliability diagram

Clearly marked as DEMO data.

**Files changed:** New file validation/generate_demo_validation_data.m

---

### 3.2 Fix Empty Reliability Diagram (HIGH)

Once 3.1 generates data, existing code automatically populates the diagram.
Additional polish: grid lines, proper labels, colored bars.

**Files changed:** run_drishtisetu.m (refreshDistrictDashboard)

---

### 3.3 Enhance Escalation Breakdown (MEDIUM)

Add grade distribution, escalation trigger breakdown, and override rate analysis.

**Files changed:** run_drishtisetu.m (refreshDistrictDashboard)

---

## 4. COUNTERFACTUAL RE-GRADING — Use Real ONNX

### Current (simulated):
```matlab
healed_grade = max(0, original_grade - 1);  % Always drops by 1
```

### Change (real inference):
Run the ONNX DR model on the healed image via run_onnx_inference('dr', ...).
Since the ONNX model already works via Python, this is a small change that makes
the counterfactual check genuinely use the AI model.

**Files changed:** explainability/decision_flip_check.m

---

## 5. FULL FILE LIST

| File | Changes | Priority |
|------|---------|----------|
| config/pipeline_config.m | Quality grid 4x4 to 16x16 | HIGH |
| run_drishtisetu.m buildTechnicianPanel | Progress panel, legend, UI polish | HIGH |
| run_drishtisetu.m loadImage | Animated processing steps | HIGH |
| run_drishtisetu.m runAnalysis | Step-by-step progress updates | HIGH |
| run_drishtisetu.m displayQualityHeatmap | Add tile count info | MEDIUM |
| run_drishtisetu.m buildDoctorPanel | Counterfactual panel, layout | HIGH |
| run_drishtisetu.m loadEscalatedCase | Doctor-friendly metrics, counterfactual | HIGH |
| run_drishtisetu.m refreshDistrictDashboard | Enhanced breakdown, styling | MEDIUM |
| reports/format_evidence_chain.m | Structured formatting | MEDIUM |
| explainability/decision_flip_check.m | Real ONNX re-grading | MEDIUM |
| validation/generate_demo_validation_data.m | NEW — demo validation metrics | HIGH |

---

## 6. GENUINE vs DEMO/SIMULATION

| Component | Status | Notes |
|-----------|--------|-------|
| DR Grading (ONNX ResNet50) | GENUINE | Real model inference via Python |
| Lesion Segmentation (ONNX) | GENUINE | Real model inference via Python |
| Vessel Segmentation | CLASSICAL FALLBACK | Real CV processing |
| Quality Assessment (16x16) | GENUINE | Real sharpness/illumination |
| Image Standardization | GENUINE | Real image processing |
| Grad-CAM | SIMULATION | Feature-based attention map |
| Counterfactual Heal | GENUINE | Real inpainting |
| Counterfactual Re-grading | WILL BE GENUINE | After fix: real ONNX re-grade |
| OOD Detection | GENUINE | JSD + confidence thresholds |
| DME Check | GENUINE | Distance-based analysis |
| Escalation Gate | GENUINE | Multi-criteria safety gate |
| Validation Metrics | DEMO DATA | Pre-generated realistic metrics |
| Screening Simulation | GENUINE | Mathematical model |
| Video Frame Extraction | GENUINE | Real sharpness analysis |

---

## 7. DEMO FLOW (19 Steps)

**Act 1: Technician (steps 1-14)**
1. Open app
2. Check consent boxes
3. Enter patient info
4. Select eye
5. Load image (visible processing animation)
6. See standardized image + 16x16 quality heatmap with legend
7. Click Run Analysis (progress panel animates through 7 steps)
8. See lesion overlay + Grad-CAM with explanations
9. See grade result in Hindi
10. If escalated, see "Doctor Review" banner
11. Print report
12. Next patient

**Act 2: Doctor (steps 15-18)**
13. Switch to Doctor role
14. See escalated case in queue
15. Click case — see images, counterfactual panel, metrics, evidence
16. Confirm or override grade

**Act 3: District Officer (steps 19-23)**
17. Switch to District Officer role
18. See validation metrics + reliability diagram
19. See escalation breakdown + run simulation

---

## 8. APPROVAL CHECKLIST

- [ ] Technician: Animated progress steps during processing
- [ ] Technician: 16x16 quality heatmap with legend
- [ ] Technician: Grad-CAM explanation labels
- [ ] Technician: UI color and spacing polish
- [ ] Doctor: Counterfactual panel with original vs healed comparison
- [ ] Doctor: Doctor-friendly metrics (no raw "pRef")
- [ ] Doctor: Fix button state issues
- [ ] Doctor: Structured evidence text
- [ ] District: Generate demo validation data
- [ ] District: Fix reliability diagram
- [ ] District: Enhanced escalation breakdown
- [ ] Counterfactual: Real ONNX re-grading on healed image
- [ ] Overall: Processing animations visible to viewer

**Once approved, I will implement all changes in priority order.**
