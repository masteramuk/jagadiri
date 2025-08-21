# JagaDirie: Your 3-in-1 Health Companion 🩺

## 1. Project Overview

**JagaDiri** is a modern and intuitive mobile application designed to simplify the monitoring of key health metrics related to **diabetes, heart disease, and high cholesterol**. The app focuses on tracking **blood sugar**, **blood pressure (BP)**, and **pulse rate**, providing users with a clear, at-a-glance view of their health trends.

Built to be lightweight and user-friendly, JagaDiri stores all data securely in **Google Sheets**, making it easy to manage and access. Its modern Material UX ensures a smooth, engaging experience on **iOS, Android, and Huawei OS**, helping users take proactive steps toward better health.

## 2. Key Features

-   **Intuitive Dashboard:** A central screen displaying max, min, and average values for sugar and BP, along with a clear indicator of whether your health is **improving** or **deteriorating**.
-   **Diabetes Tracker:** A dedicated section for logging and viewing blood sugar levels throughout the day (before/after meals). It lists the last 20 records and provides a quick **good/bad** status for each entry.
-   **BP & Pulse Monitor:** A separate screen to track blood pressure (systolic and diastolic) and pulse rate. Data is categorized by time of day, with a status indicator for **good**, **normal**, or **bad** readings.
-   **Personalized Reporting:** Generate and download detailed reports of your health data in **PDF** and **Excel** formats for easy sharing with healthcare professionals.
-   **User-Centric Settings:** Customize your app experience with profile settings, theme options (including dark mode), and metric unit preferences.
-   **Cross-Platform & Lightweight:** Built on **Flutter**, MetriCare offers a high-performance experience on a single codebase across multiple platforms.

## 3. Technology Stack

-   **Framework:** **Flutter** for its speed, single codebase, and native performance on iOS, Android, and Huawei OS.
-   **Data Storage:** **Google Sheets** acts as the backend, providing a simple, scalable, and secure way to store user-specific data via the Google Sheets API.
-   **State Management:** **Provider** or **Riverpod** will be used for efficient and predictable state management.
-   **UI/UX:** **Material 3 (M3)** for a consistent and modern design language.
-   **API Integration:** The **`googleapis`** and **`google_sheets_api`** packages will facilitate seamless interaction with Google Sheets.
-   **Report Generation:** The **`pdf`** and **`printing`** packages will handle PDF creation, while the **`excel`** package will manage Excel file generation.

## 4. Development & Contribution

### Getting Started

1.  **Install Flutter:** Follow the official installation guide for your OS.
2.  **Clone the repository:**
    ```bash
    git clone [https://github.com/your-username/metricare-app.git](https://github.com/your-username/metricare-app.git)
    cd metricare-app
    ```
3.  **Run the app:**
    ```bash
    flutter pub get
    flutter run
    ```

### Project Structure
lib/
├── main.dart             # App entry point
├── models/               # Data structures (e.g., sugar_record.dart, bp_record.dart)
├── services/             # Google Sheets API integration
├── screens/              # All UI screens
│   ├── dashboard_screen.dart
│   ├── sugar_data_screen.dart
│   ├── bp_data_screen.dart
│   ├── reports_screen.dart
│   └── profile_settings_screen.dart
├── widgets/              # Reusable UI components
└── utils/                # Helper functions, constants, etc.

