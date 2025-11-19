# LiftLog System Diagrams

This document contains textual representations and descriptions of key diagrams for the LiftLog fitness tracking mobile application system.

## Context Diagram

**Description:**  
The Context Diagram shows the LiftLog system in its environment, illustrating the interactions between the system and external entities. The system serves users (members, trainers, and admins) who access it via a mobile app. The backend interacts with MongoDB Atlas for data persistence, Supabase for file storage (e.g., videos), and is deployed on Render. External entities include users, database services, and deployment platforms.

**Textual Representation:**

```
+-------------------+     +-------------------+     +-------------------+
|       User        | --> | LiftLog Mobile App| --> | LiftLog Backend   |
| (Member/Trainer/  |     |   (Flutter)       |     | API (Express)     |
|  Admin)           |     +-------------------+     +-------------------+
+-------------------+                                   |
                                                         |
                                                         v
                                               +-------------------+
                                               |   MongoDB Atlas   |
                                               |   (Database)      |
                                               +-------------------+

                                               +-------------------+
                                               |   Supabase        |
                                               |   (File Storage)  |
                                               +-------------------+

                                               +-------------------+
                                               |   Render          |
                                               |   (Deployment)    |
                                               +-------------------+
```

## Flowchart (Hardware and System)

**Description:**  
This flowchart illustrates the hardware and system-level data flow within LiftLog. It shows how user interactions on the mobile device flow through the system components, including API calls, database operations, and storage interactions. The flow covers authentication, data retrieval/storage, and response handling.

**Textual Representation:**

```
Start
  |
  v
User Action on Mobile Device
  |
  v
Mobile App (Flutter)
  |  (API Request)
  v
Backend Server (Express)
  |  (Process Request)
  v
Authentication Middleware
  |  (Verify Token)
  v
Route Handler
  |  (Business Logic)
  v
Database Interaction (MongoDB)
  |  or
File Storage Interaction (Supabase)
  |  (CRUD Operations)
  v
Response Generation
  |  (JSON Response)
  v
Backend Server
  |  (Send Response)
  v
Mobile App
  |  (Update UI)
  v
End
```

## Database Schema

**Description:**  
The Database Schema represents the data models and their relationships in MongoDB. The system uses Mongoose schemas for User, Workout, Progress, and ExerciseVideo collections. Relationships include references between users and their workouts/progress/videos.

**Textual Representation (ER Diagram Style):**

```
+-------------------+       +-------------------+
|       User        |       |     Workout       |
+-------------------+       +-------------------+
| _id (ObjectId)    |<--1--*| _id (ObjectId)    |
| username          |       | user (ref User)   |
| email             |       | trainer (ref User)|
| password          |       | date              |
| role              |       | title             |
| membershipStart   |       | description       |
| membershipExp     |       | exercises[]       |
| profile           |       | duration          |
|                   |       | caloriesBurned    |
|                   |       | intensity         |
|                   |       | category          |
|                   |       | isPublic          |
+-------------------+       +-------------------+
          |                           |
          | 1..*                      | 1..*
          v                           v
+-------------------+       +-------------------+
|     Progress      |       |  ExerciseVideo    |
+-------------------+       +-------------------+
| _id (ObjectId)    |       | _id (ObjectId)    |
| user (ref User)   |       | title             |
| bmi               |       | description       |
| caloriesIntake    |       | trainer (ref User)|
| calorieDeficit    |       | videoUrl          |
| weight            |       | videoPath         |
| bodyFatPercentage |       | exerciseType      |
| muscleMass        |       | difficulty        |
| date              |       | duration          |
|                   |       | tags[]            |
|                   |       | isPublic          |
|                   |       | status            |
+-------------------+       +-------------------+
```

**Key Relationships:**
- User has many Workouts (as user or trainer)
- User has many Progress entries
- User (trainer) has many ExerciseVideos
- Workout contains embedded Exercises

## Use Case Diagram

**Description:**  
The Use Case Diagram identifies the main actors and their interactions with the system. Actors include Members (regular users), Trainers (content creators), and Admins (system managers). Use cases cover core functionalities like authentication, workout management, progress tracking, and video handling.

**Textual Representation:**

```
+-------------------+     +-------------------+
|     Member        |     |     Trainer       |
+-------------------+     +-------------------+
| - Register        |     | - Register        |
| - Login           |     | - Login           |
| - View Profile    |     | - View Profile    |
| - Create Workout  |     | - Create Workout  |
| - Track Progress  |     | - Upload Video    |
| - View Videos     |     | - Manage Videos   |
| - View Workouts   |     | - View Progress   |
+-------------------+     +-------------------+
          \                   /
           \                 /
            \               /
             \             /
              \           /
               \         /
                \       /
                 \     /
                  \   /
                   \ /
            +-------------------+
            |   LiftLog System  |
            +-------------------+
                   / \
                  /   \
                 /     \
                /       \
               /         \
              /           \
             /             \
            /               \
           /                 \
+-------------------+     +-------------------+
|      Admin         |     |   System         |
+-------------------+     +-------------------+
| - Login           |     | - Authenticate    |
| - Manage Users    |     | - Store Data      |
| - Update Membership|    | - Process Videos  |
| - View Reports    |     | - Generate Reports|
+-------------------+     +-------------------+
```

**Main Use Cases:**
- Authentication: Register, Login, Update Profile
- Workout Management: Create, View, Edit Workouts
- Progress Tracking: Log Progress, View Charts
- Video Management: Upload, View, Manage Videos
- User Management: Admin functions for user oversight

## Architecture Diagram

**Description:**  
The Architecture Diagram shows the layered architecture of LiftLog. It follows a client-server model with a mobile frontend, RESTful API backend, and distributed data storage. The system uses microservices-like separation with clear boundaries between presentation, application, and data layers.

**Textual Representation:**

```
+-------------------+
|   Presentation    |
|   Layer           |
+-------------------+
| - Flutter Mobile  |
|   App             |
| - UI Components   |
| - State Mgmt      |
|   (Provider)      |
+-------------------+
          |
          | HTTP/HTTPS
          v
+-------------------+
| Application Layer |
+-------------------+
| - Express.js API  |
| - Routes          |
| - Middleware      |
| - Business Logic  |
+-------------------+
          |
          | Database Queries
          v
+-------------------+
|    Data Layer     |
+-------------------+
| - MongoDB Atlas   |
|   (Documents)     |
| - Supabase        |
|   (File Storage)  |
+-------------------+
          |
          | Deployment
          v
+-------------------+
| Infrastructure    |
+-------------------+
| - Render          |
|   (Hosting)       |
| - Environment     |
|   Variables       |
+-------------------+
```

**Architecture Components:**
- **Presentation Layer:** Flutter app with screens, providers for state management
- **Application Layer:** Express server with RESTful routes, authentication middleware
- **Data Layer:** MongoDB for structured data, Supabase for video files
- **Infrastructure:** Render for deployment, environment configuration

## Wireframe Diagrams

**Description:**  
Wireframes provide low-fidelity representations of key user interface screens. These show the layout and main elements without detailed styling. The wireframes cover primary user flows including authentication, dashboard, workout management, and video features.

### 1. Login Screen
```
+-------------------+
|   LiftLog         |
|   [Logo]          |
+-------------------+
| Email:            |
| [input field]     |
+-------------------+
| Password:         |
| [input field]     |
+-------------------+
| [Login Button]    |
+-------------------+
| [Register Link]   |
+-------------------+
```

### 2. Dashboard Screen
```
+-------------------+
| Dashboard         | [Profile Icon]
+-------------------+
| Welcome, User!    |
+-------------------+
| Today's Workout   |
| [Card: Title]     |
| [Progress Bar]    |
+-------------------+
| Recent Progress   |
| [Chart Icon]      |
+-------------------+
| Training Videos   |
| [Video Thumbnail] |
+-------------------+
| [Navigation Bar]  |
| Home | Workouts | |
| Progress | Videos |
+-------------------+
```

### 3. Workout Creation Screen
```
+-------------------+
| Create Workout    | [Save] [Cancel]
+-------------------+
| Title:            |
| [input field]     |
+-------------------+
| Description:      |
| [textarea]        |
+-------------------+
| Add Exercise      |
| [Button]          |
+-------------------+
| Exercise List     |
| - Exercise 1      |
|   Sets: [ ] Reps: [ ] |
|   Weight: [ ]     |
| - Exercise 2      |
|   ...             |
+-------------------+
```

### 4. Progress Tracking Screen
```
+-------------------+
| Progress          | [Add Entry]
+-------------------+
| Weight Chart      |
| [Line Graph]       |
+-------------------+
| BMI: 24.5         |
| Calories: 2200    |
+-------------------+
| Recent Entries    |
| Date | Weight | BMI |
| 2023-10-01 | 70kg | 24.5 |
| 2023-09-28 | 71kg | 24.8 |
+-------------------+
```

### 5. Video Upload Screen
```
+-------------------+
| Upload Video      |
+-------------------+
| Select Video      |
| [File Picker]     |
+-------------------+
| Title:            |
| [input field]     |
+-------------------+
| Description:      |
| [textarea]        |
+-------------------+
| Exercise Type:    |
| [dropdown]        |
+-------------------+
| Difficulty:       |
| [radio buttons]   |
+-------------------+
| Tags:             |
| [tag input]       |
+-------------------+
| [Upload Button]   |
+-------------------+
```

These diagrams provide a comprehensive overview of the LiftLog system's structure, functionality, and user interface. They serve as documentation for reviewers to understand the system's design and implementation.
