# Jagadiri App Development Plan

## Current Status:
Approximately 50% complete. Data capture for blood sugar, BP, pulse, and profile settings (height, weight, BMI) are implemented. The reports screen is a placeholder.

## Next Major Feature: Reports Screen

**Goal:** Develop a comprehensive reports screen capable of generating five distinct health reports in both PDF and Excel formats, based on user-selected date ranges.

### Phase 1: Setup & Core Dependencies
-   **Update `pubspec.yaml`:** Add `pdf`, `excel`, `fl_chart`, `intl`, `path_provider`, `open_filex`, `share_plus`. (Potentially `googleapis`, `googleapis_auth` for direct Google Sheets API).
-   **Google Sheets Integration Strategy:** Extend `lib/services/database_service.dart` to fetch data from Google Sheets. This will involve handling authentication and parsing data into existing Dart models.
-   **Data Models Review:** Ensure `BPRecord`, `SugarRecord`, `UserProfile` are sufficient for reporting needs.

### Phase 2: UI Implementation (`lib/screens/reports_screen.dart`)
-   **Design `ReportsScreen`:** Include a date range picker, five buttons for report types, loading indicators, and message displays.
-   **State Management:** Utilize `Provider` for managing selected dates, loading states, and generated file paths.

### Phase 3: Data Fetching & Processing
-   **Extend `DatabaseService`:** Add methods to fetch `SugarRecord`, `BPRecord`, and `UserProfile` data within a specified date range.
-   **Create `lib/utils/report_utils.dart`:** Implement helper functions for data aggregation, daily averages, health status classification (e.g., normal, high), BMI calculation, and risk assessment logic.

### Phase 4: Report Generation Logic (`lib/utils/report_generator.dart`)
-   **Dedicated Functions:** Create separate functions for each of the five report types for both PDF and Excel generation (e.g., `generateIndividualTrendsPdf`, `generateIndividualTrendsExcel`).
-   **PDF Generation:** Use the `pdf` package to construct documents, including text, tables, and embedded charts (rendered as images from `fl_chart`).
-   **Excel Generation:** Use the `excel` package to create workbooks, sheets, and populate cells with raw and processed data.
-   **File Handling:** Implement saving generated files to device storage (`path_provider`) and providing options to open (`open_filex`) or share (`share_plus`) them.

### Phase 5: Integration & Testing
-   **Connect UI:** Link `ReportsScreen` buttons to the report generation logic.
-   **Error Handling:** Implement comprehensive error handling for all stages.
-   **Testing:** Conduct unit, widget, and integration tests for data processing, UI, and report generation flows.

## Potential Challenges:
-   Google Sheets API complexity (authentication, rate limits).
-   Performance with large datasets (use pagination, Isolates).
-   Complex PDF layouts and embedding dynamic charts (render charts to images).
-   File saving/sharing permissions and cross-platform compatibility.