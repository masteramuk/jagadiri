# JagaDiri Development Working Plan

This document outlines the agreed-upon phased approach for the JagaDiri application's cloud storage integration.

## Core Principle

*   **Profile and Application Settings:** Will be stored in the user's local storage (e.g., `shared_preferences`) on their mobile device.
*   **Health Data:** Will be stored in the user's preferred cloud drive (Google Drive or OneDrive), ensuring data ownership and minimizing application-side storage costs.

## Phase 1: Google Drive Integration (MVP Focus)

**Goal:** Implement full functionality for storing user health data in their personal Google Drive.

**Details:**
1.  **User-Specified Folder:** The application will provide a mechanism (e.g., a text input for a folder ID) for the user to specify an existing Google Drive folder where their health data spreadsheets will reside.
2.  **Separate Spreadsheets:** Instead of tabs within a single spreadsheet, the application will create two distinct Google Sheets within the user-specified folder:
    *   `JagaDiri - Sugar Data` (for blood sugar measurements)
    *   `JagaDiri - BP & Pulse Data` (for blood pressure and pulse rate measurements)
3.  **Local Storage of IDs:** The IDs of these two newly created Google Sheets will be stored securely in the user's local storage (`shared_preferences`) for quick retrieval and access.
4.  **User's Google Drive:** All interactions will occur with the Google Drive account of the currently signed-in user, not a developer's account.

**Implementation Steps:**
*   Modify `ProfileSettingsScreen` to allow input and saving of a Google Drive folder ID.
*   Update `GoogleSheetsService` to:
    *   Accept a `folderId` for spreadsheet creation.
    *   Create two separate spreadsheets within the specified `folderId`.
    *   Store the IDs of these two spreadsheets in `shared_preferences`.
    *   Adapt data read/write operations to target the correct spreadsheet based on data type (sugar or BP).

## Phase 2: OneDrive Integration (Future Enhancement)

**Goal:** Extend cloud storage options to include Microsoft OneDrive.

**Details:**
*   **Microsoft Graph API:** Integrate with the Microsoft Graph API for authentication and file management within OneDrive.
*   **Separate UI Flow:** Develop a distinct user interface for OneDrive folder selection and authentication.
*   **Excel File Management:** Implement logic to create and manage Excel files (or other OneDrive-compatible spreadsheet formats) for sugar and BP data.
*   **User Choice:** Allow users to select their preferred cloud storage provider (Google Drive or OneDrive) from the application settings.

This phased approach ensures a deliverable MVP with Google Drive support while providing a clear roadmap for future expansion to OneDrive.
