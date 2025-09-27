# Current Task: Report Generation Refactor

**Status:** In Progress

**Objective:** Refactor the report generation flow to improve user experience and work around PDF chart rendering issues.

**Key Changes:**
1.  **Intermediate Report Screen:** Instead of direct file generation, a new screen (`generated_report_viewer_screen.dart`) will display the report content first.
2.  **UI-First Approach:** The report, including charts, will be rendered as standard Flutter widgets on this new screen.
3.  **Delayed File Generation:** From the new viewer screen, users will have options to "Save as PDF" (initially without charts) and "Save as Excel".
4.  **Code Simplification:** Removing the complex `RenderRepaintBoundary` capture logic from the initial report selection screen.

---
*Previous Plan Below*
---
### STEP 1: 📊 CHART GENERATION — `IndividualHealthTrend_ChartGenerator`
- Generate 3 line charts: Glucose, BP (Systolic & Diastolic on same chart), Pulse.
- Use `syncfusion_flutter_charts`.
- Charts must be wrapped in `RepaintBoundary`, rendered to `ui.Image`, ready to embed in PDF via `pw.Image(pw.MemoryImage(...))`.
- Include titles, date X-axis, value Y-axis, grid, legend (for BP), tooltips.
- Input: `List<SugarRecord>`, `List<BPRecord>`, `int days = 30`
- Output: `List<ui.Image>` (3 charts)

---

### STEP 2: 🧠 SMART MEDICAL NLG — `IndividualHealthTrend_HealthAnalyzer`
- Generate 3–5 paragraph natural language summary with:
  - Glucose: classify by ADA (normal/prediabetic/diabetic) based on meal context. Flag hypo/hyper.
  - BP: classify per AHA (normal/elevated/stage1/stage2/crisis). Flag instability if daily range >20mmHg.
  - Pulse: bradycardia/tachycardia, correlation with BP/stress.
  - Trend detection (7/14/30 days): rising, falling, stable.
  - Fluctuation detection: e.g., “Your glucose varies >60 mg/dL daily — consider consistent carb timing.”
  - Personalization: if userProfile.sugarScenario is 'Type 1 Diabetic' → tailor advice.
  - At least 20 unique, empathetic, actionable NLG templates with emojis.
  - End with 1–2 wellness tips (e.g., “💧 Morning hydration can reduce BP surge.”)
- Input: `List<SugarRecord>`, `List<BPRecord>`, `UserProfile`
- Output: `String analysisText`

---

### STEP 3: 🤖 REAL TINY ML (DistilGPT-2 .tflite) — `IndividualHealthTrend_EnhancedAnalysisService`
- Use existing model: `assets/models/distilgpt2.tflite`
- DO train new model if necessary and able to run on mobile or use as-is and improve prompt engineering.
- Load model using `tflite_flutter` package.
- Input to model: structured prompt string combining:
  - User’s sugarScenario
  - Last 7 days avg glucose, BP, pulse
  - Trend direction (rising/falling)
  - Fluctuation level (high/medium/low)
  Example prompt: “User is Type 2 Diabetic. Avg glucose: 142 mg/dL, trending up, high fluctuation. BP: 138/88, stable. Pulse: 82, normal. Provide 1-sentence medical insight.”
- Model output: generated text → append to NLG analysis as “🧠 AI Insight: [generated text]”
- If model fails or not loaded → fallback to rule-based insight (no crash).
- Method: `Future<IndividualHealthTrend_AnalysisResult> getEnhancedAnalysis(...)`

---
📄 Enhanced PDF Generation Plan for Health Reports

✅ Phase 1: Chart Integration

Chart Types to Include

•  Glucose Trend: Line chart with meal context markers
•  Blood Pressure Trend: Dual line chart (Systolic & Diastolic)
•  Pulse Trend: Line chart with stress correlation markers

🧠 Phase 2: Smart Medical NLG Summary

Input

•  List<SugarRecord>
•  List<BPRecord>
•  UserProfile

Output

•  String analysisText with:
⁠◦  ADA classification (glucose)
⁠◦  AHA classification (BP)
⁠◦  Pulse interpretation (bradycardia/tachycardia)
⁠◦  Trend detection (7/14/30 days)
⁠◦  Fluctuation detection
⁠◦  Personalized advice (based on sugarScenario)
⁠◦  20+ empathetic, actionable NLG templates with emojis
⁠◦  1–2 wellness tips

Implementation

•  Create SmartNLGService class
•  Use rule-based logic + templates
•  Modularize by metric (glucose, BP, pulse)
•  Append to PDF below each chart

🤖 Phase 3: Tiny ML Integration (Optional but Powerful)

Model

•  assets/models/distilgpt2.tflite

Input Prompt Example
User is Type 2 Diabetic. Avg glucose: 142 mg/dL, trending up, high fluctuation. BP: 138/88, stable. Pulse: 82, normal. Provide 1-sentence medical insight.

Output
AI-generated insight appended to NLG summary:
•  “🧠 AI Insight: [generated text]”
Implementation
•  Create EnhancedAnalysisService class
•  Load model with tflite_flutter
•  Fallback to rule-based if model fails
•  Method: Future<IndividualHealthTrend_AnalysisResult> getEnhancedAnalysis(...)
•  Integrate output into PDF generation flow
--
📦 Final PDF Structure

1.  Header: User profile + date range
2.  Summary: Averages, min/max, BMI
3.  Charts + NLG:
    ⁠◦  Glucose chart + summary + AI insight
    ⁠◦  BP chart + summary + AI insight
    ⁠◦  Pulse chart + summary + AI insight
4.  Detailed Data Tables: BP and Sugar records
