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

🎯 TASK: Generate the following 3 Dart classes:

1. `IndividualHealthTrend_ChartGenerator`
2. `IndividualHealthTrend_HealthAnalyzer`
3. `IndividualHealthTrend_EnhancedAnalysisService`

→ Returns from `getEnhancedAnalysis`:
```dart
class IndividualHealthTrend_AnalysisResult {
  final List<ui.Image> chartImages; // 3 charts: glucose, bp, pulse
  final String analysisText;       // NLG + AI Insight combined
}
'''
