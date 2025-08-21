# JagaDiri Development Plan 🚀

## 1. Project Scoping & Phased Development

The development of **JagaDiri** will follow a structured, phased approach to ensure a robust and well-tested final product.

-   **Phase 1: Minimum Viable Product (MVP)** - Establish the core data tracking and display features.
-   **Phase 2: Enhancements & Advanced Features** - Introduce reporting, search, and refined UI elements.
-   **Phase 3: Optimization & Final Polishing** - Focus on performance, full customization, and platform-specific improvements.

## 2. Technical Roadmap

### Phase 1: MVP (Estimated: 4-6 weeks)

| Task | Description | Estimated Time | Status |
| :--- | :--- | :--- | :--- |
| **Project & Git Setup** | Initialize the Flutter project and configure the repository with a clear folder structure. | 2 days | `Pending` |
| **Google Sheets API Integration** | Set up Google Cloud, enable the Sheets API, and create the service class to handle data read/write operations. | 1 week | `Pending` |
| **User Onboarding & Profile** | Build the `Profile & Settings` screen. Implement logic to create a dedicated Google Sheet for each new user. | 1 week | `Pending` |
| **Screen 1: Dashboard** | Develop the main dashboard UI. Implement data fetching to display key metrics (min, max, avg) and trend indicators. | 1.5 weeks | `Pending` |
| **Screen 2: Diabetes Tracker** | Create the UI for the sugar tracking screen, including the data list and a form for adding new entries. | 1.5 weeks | `Pending` |
| **Screen 3: BP & Pulse Monitor** | Build the UI for the BP and pulse rate screen, with data listing and a form for new entries. | 1.5 weeks | `Pending` |
| **Basic Indicator Logic** | Implement simple logic to determine **good/bad** and **improving/deteriorating** status based on predefined health ranges. | 3 days | `Pending` |
| **Initial Testing & Bug Fixes** | Conduct internal testing on all core functionalities to ensure stability. | 1 week | `Pending` |

### Phase 2: Enhancements (Estimated: 3-4 weeks)

| Task | Description | Estimated Time | Status |
| :--- | :--- | :--- | :--- |
| **Search & Filter Functionality** | Add a search feature to filter data by date range on both the Sugar and BP screens. | 1 week | `Pending` |
| **Advanced Trend Analysis** | Develop a more sophisticated trend analysis system (e.g., using moving averages) for more accurate feedback. | 1 week | `Pending` |
| **Reporting Module** | Implement the `Reports` screen with functionality to generate and download PDF and Excel reports. | 2 weeks | `Pending` |
| **UI/UX Refinements** | Enhance the overall user experience with smooth animations, better error handling, and visual consistency. | 1 week | `Pending` |

### Phase 3: Optimization & Polishing (Estimated: 2-3 weeks)

| Task | Description | Estimated Time | Status |
| :--- | :--- | :--- | :--- |
| **Performance Optimization** | Profile and optimize app performance, focusing on data fetching speed and UI rendering. | 1 week | `Pending` |
| **Theming & Customization** | Add the ability for users to switch themes (e.g., light/dark mode) and adjust other preferences in the `Settings` screen. | 1 week | `Pending` |
| **Comprehensive Testing** | Conduct a final round of end-to-end testing on various devices and platforms (iOS, Android, Huawei). | 1 week | `Pending` |
| **Deployment Preparation** | Prepare the application for submission to the Google Play Store, Apple App Store, and Huawei AppGallery. | 1 week | `Pending` |

## 3. Core Logic & Data Structure

### Data Models

-   **`SugarRecord`:** A class representing a single sugar entry with fields for `date`, `time`, multiple meal-time values, and a `status` indicator.
-   **`BPRecord`:** A class for BP entries, including `date`, `time`, `timeName`, `systolic`, `diastolic`, `pulseRate`, and a `status`.

### Google Sheets Integration

-   Each user will have their own dedicated Google Sheet, identified by a unique ID, ensuring data privacy.
-   The sheet will be organized into separate tabs: **`Sugar Data`**, **`BP Data`**, and **`Profile`**.

### Indicator Logic

-   **Dashboard Trend:** The app will analyze the average of the last 7 days and compare it to the average of the previous period (e.g., the 7 days before that). This comparison will drive the **improving/deteriorating** trend indicator.
-   **Individual Record Status:** Predefined clinical ranges will be used to classify each data point as **good**, **normal**, or **bad**, providing immediate feedback to the user.

## 4. Risks & Mitigation

| Risk | Mitigation Strategy |
| :--- | :--- |
| **Google Sheets API limitations** | Implement efficient data fetching and caching to minimize API calls and avoid rate limits. |
| **UI/UX inconsistencies** | Stick strictly to the **Material 3** design system, use a shared component library, and maintain a consistent visual hierarchy. |
| **Data security & privacy** | Utilize secure Google OAuth 2.0 for authentication. User data is stored in their private Google Sheets, not on a public server. |
| **Platform-specific bugs** | Rely on Flutter's robust cross-platform capabilities and conduct thorough testing on all target platforms (iOS, Android, Huawei OS). |
