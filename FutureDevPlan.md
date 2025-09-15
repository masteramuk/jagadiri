# Future Development Plan

This document outlines the future development plans for the JagaDiri application, focusing on advanced AI-powered features.

## Hybrid AI Analysis Model

To provide users with the most advanced and accurate health analysis while maintaining security and a good user experience, a hybrid model will be implemented. This will consist of two parts: the core on-device functionality and an on-demand cloud-based enhancement.

### 1. On-Device Analysis (Phase 1 - Current Focus)

- **Rule-Based Engine:** A deterministic, rule-based engine will provide core analysis of health data (BP, Sugar, etc.). This is the foundation of the analysis, ensuring safety, reliability, and offline availability.
- **On-Device SLM:** A Small Language Model (SLM) running on-device will be used to enhance the output of the rule-based engine, making it more conversational and providing more dynamic, yet still constrained, insights.

### 2. On-Demand Cloud-Based RAG (Phase 2 - Future Implementation)

This phase will be implemented to provide deeper, more contextual analysis for users who want it and have an internet connection.

- **Backend Proxy:** A secure backend server (e.g., using Google Cloud Functions, AWS Lambda, or Firebase Functions) will be created. This backend will be the only component that holds the API keys for third-party services, ensuring the mobile app remains secure.
- **Retrieval-Augmented Generation (RAG):**
    - When a user requests a "deeper insight", the app will make a request to the secure backend proxy.
    - The backend will use a powerful, large language model (e.g., Gemini API) with its search grounding capabilities enabled (a built-in RAG feature).
    - This will allow the model to access and process real-time, reputable health information from the internet to generate a comprehensive and up-to-date analysis.
- **User Interface:**
    - The UI will feature a button or link, such as "Get Deeper Insights (Internet Required)", to trigger this on-demand analysis.
    - The results from the cloud-based analysis will be clearly distinguished from the standard on-device analysis.
