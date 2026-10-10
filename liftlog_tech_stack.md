# LiftLog Technology Stack

This document outlines the complete technology stack, programming languages, databases, servers, and third-party services used to build the LiftLog application.

## 1. Frontend (Mobile App)
- **Framework:** Flutter
- **Programming Language:** Dart
- **State Management:** Provider
- **Key Libraries:**
  - `http` & `dio` (API network requests)
  - `fl_chart` (Rendering progress charts and graphs)
  - `video_player` (Streaming training videos)
  - `file_picker` (Selecting trainer credentials and videos)
  - `shared_preferences` (Local storage for auth tokens)

## 2. Backend (REST API Server)
- **Runtime Environment:** Node.js
- **Framework:** Express.js
- **Programming Language:** JavaScript
- **Key Libraries:**
  - `mongoose` (MongoDB object modeling)
  - `multer` (Handling file uploads/multipart form data)
  - `fluent-ffmpeg` (Processing videos and generating thumbnails)
  - `jsonwebtoken` (Generating and verifying auth tokens)
  - `bcryptjs` (Hashing passwords for security)

## 3. Databases & Storage
- **Primary Database:** MongoDB (Hosted on MongoDB Atlas)
  - **Type:** NoSQL Database
  - **Usage:** Stores structured data like User Profiles, Workout Templates, Progress Logs (BMI/Calories), and Video Metadata.
- **Media Storage:** Supabase
  - **Type:** Cloud Object Storage (AWS S3 alternative)
  - **Usage:** Stores large binary files such as `.mp4` training videos and `.jpg`/`.png` trainer credential images.

## 4. Cloud Infrastructure & Hosting
- **Backend Hosting:** Render
  - **Usage:** Hosts the Node.js/Express backend server. It handles incoming HTTP requests from the Flutter app, processes logic, and communicates with MongoDB and Supabase.
- **Environment Management:** `.env` files (dotenv) for securely injecting API keys and connection strings into the Render environment.

## 5. Third-Party APIs & Services
- **Email Service:** Brevo (formerly Sendinblue)
  - **Usage:** Uses HTTP REST API to send transactional emails (OTP codes, Trainer Approval/Rejection notices, Registration Success). Chosen to bypass Render's strict SMTP port blocking.
- **Google Drive API (Optional/Legacy):** Used for fetching user videos directly from Google Drive during the upload process.

## 6. Version Control & Development Tools
- **Version Control:** Git
- **Code Repository:** GitHub
- **IDE / Editor:** Visual Studio Code (VS Code)
- **Testing:** Postman (API Testing), Flutter Widget Tester
