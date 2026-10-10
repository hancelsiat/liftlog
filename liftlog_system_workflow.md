# LiftLog System Workflow & Architecture

This document contains the system architecture and workflow diagrams for the LiftLog application. These diagrams are written using Mermaid.js syntax and can be previewed directly in Markdown viewers that support Mermaid (like GitHub, VS Code, or Notion).

## 1. Input Process Output (IPO) Diagram

```mermaid
graph TD
    subgraph Inputs ["📥 INPUTS"]
        I1(User Registration Data\nUsername, Email, Password, Role)
        I2(Trainer Credentials\nID/Certificate Image)
        I3(Workout Data\nExercises, Sets, Reps)
        I4(Training Videos\nMP4 Files, Metadata)
        I5(Progress Data\nBMI, Calories)
    end

    subgraph Processes ["⚙️ PROCESSES (Render Server)"]
        P1{Input Validation\n& Password Hashing}
        P2{Role-Based\nAccess Control}
        P3{File Processing\n& Upload Streams}
        P4{Database Operations\nCRUD}
        P5{Email Triggering\nOTP/Approvals}
    end

    subgraph Outputs ["📤 OUTPUTS"]
        O1(UI State Updates\nDashboard, Profiles)
        O2(Stored DB Records\nMongoDB Atlas)
        O3(Cloud Storage URLs\nSupabase)
        O4(Transactional Emails\nBrevo API)
        O5(JSON API Responses)
    end

    %% Connections
    I1 --> P1
    I2 --> P3
    I3 --> P4
    I4 --> P3
    I5 --> P4

    P1 --> P4
    P2 --> P4
    P3 --> P4
    P4 --> P5

    P4 --> O1
    P4 --> O2
    P3 --> O3
    P5 --> O4
    P4 --> O5
```

---

## 2. Context Diagram

```mermaid
graph TD
    %% External Entities
    Member((Gym Member))
    Trainer((Fitness Trainer))
    Admin((System Admin))
    
    %% Core System
    System{"LiftLog Backend API\n(Render Cloud)"}
    
    %% External Systems
    DB[(MongoDB Atlas\nData Storage)]
    Storage[(Supabase\nMedia Storage)]
    Emailer[[Brevo Email API]]

    %% Relationships
    Member -->|Registers, Logs Progress, Completes Workouts| System
    System -->|Serves Assigned Workouts, Progress Charts| Member
    
    Trainer -->|Uploads Videos, Assigns Workouts, Manages Clients| System
    System -->|Returns Client List, Video Library| Trainer
    
    Admin -->|Approves/Rejects Trainers, Manages Users| System
    System -->|Provides System Data| Admin

    System <-->|Reads/Writes JSON Data| DB
    System <-->|Uploads/Retrieves Files & Signed URLs| Storage
    System -->|Sends Verification/Approval Emails| Emailer
```

---

## 3. Entity Relationship Diagram (ERD)

```mermaid
erDiagram
    USER ||--o{ WORKOUT : "creates / assigned to"
    USER ||--o{ EXERCISE_VIDEO : "uploads (if trainer)"
    USER ||--o{ PROGRESS : "logs"
    USER ||--o{ USER : "has clients / has trainer"

    USER {
        ObjectId _id PK
        string username
        string email
        string password "Hashed"
        string role "member, trainer, admin"
        boolean isApproved
        boolean isEmailVerified
        string credentialImageUrl
        ObjectId trainer FK
    }

    WORKOUT {
        ObjectId _id PK
        string title
        string description
        boolean isTemplate
        boolean isPublic
        ObjectId user FK "Member ID"
        ObjectId trainer FK "Trainer ID"
        ObjectId assignedTo FK "Member ID"
        date date
        date completedAt
    }

    EXERCISE_VIDEO {
        ObjectId _id PK
        string title
        string description
        ObjectId trainer FK
        string videoUrl "Supabase Signed URL"
        string videoPath
        string thumbnailUrl
        string exerciseType
        string difficulty
        number duration
        boolean isPublic
    }

    PROGRESS {
        ObjectId _id PK
        ObjectId user FK
        number bmi
        number caloriesIntake
        number calorieDeficit
        date date
        date lastBmiUpdate
        date lastCaloriesUpdate
    }
```

---

## 4. System Architecture

```mermaid
graph TD
    subgraph Frontend ["📱 Client Tier (Flutter App)"]
        UI[User Interface\nScreens & Widgets]
        State[State Management\nProvider]
        API_Client[API Service\nDio/HTTP]
        
        UI <--> State
        State <--> API_Client
    end

    subgraph Backend ["⚙️ Application Tier (Render Cloud)"]
        Router[Express.js Routes\nAuth, Workouts, Videos]
        Middleware[Auth & Validation\nJWT, Multer]
        Services[Business Logic\nEmailService, SupabaseClient]
        
        Router <--> Middleware
        Middleware <--> Services
    end

    subgraph Data ["🗄️ Data Tier"]
        MongoDB[("🍃 MongoDB Atlas\n(NoSQL Database)")]
        Supabase[("🪣 Supabase Storage\n(Object Storage)")]
    end

    subgraph ThirdParty ["🔌 Third-Party APIs"]
        Brevo["📧 Brevo\n(Transactional Emails)"]
    end

    %% Network Connections
    API_Client <-->|HTTPS / REST API| Router
    Services <-->|Mongoose / TCP| MongoDB
    Services <-->|HTTPS / SDK| Supabase
    Services -->|HTTPS / API Key| Brevo
```
