# LiftLog System Flowchart

This document contains a detailed flowchart of the LiftLog fitness tracking mobile application system, illustrating the complete user journey and system interactions.

## Full System Flowchart (Mermaid)

```mermaid
flowchart TD
    A[App Launch] --> B{Token Exists?}
    B -->|Yes| C[Validate Token via API]
    B -->|No| D[Login Screen]

    C -->|Valid| E[Dashboard Screen]
    C -->|Invalid| F[Remove Token] --> D

    D --> G[User Inputs Credentials]
    G --> H[API Call: POST /api/auth/login]
    H --> I[Backend: Auth Route]
    I --> J{User Exists?}
    J -->|No| K[Return Error: Invalid Credentials]
    J -->|Yes| L{Check Password}
    L -->|Fail| K
    L -->|Pass| M{Check Membership}
    M -->|Expired| N[Return Error: Membership Expired]
    M -->|Active| O{Optional Role Check}
    O -->|Mismatch| P[Return Error: Role Mismatch]
    O -->|Match/None| Q[Generate JWT Token]
    Q --> R[Return Token & User Data]
    R --> S[Store Token Locally]
    S --> E

    E --> T{User Role?}
    T -->|Member| U[Member Dashboard]
    T -->|Trainer| V[Trainer Dashboard]
    T -->|Admin| W[Admin Dashboard]

    U --> X[View Workouts]
    U --> Y[Log Progress]
    U --> Z[View Training Videos]
    U --> AA[Settings]

    V --> BB[Create Workout Template]
    V --> CC[Upload Exercise Video]
    V --> DD[View Member Progress]
    V --> EE[Manage Videos]

    W --> FF[User Management]
    W --> GG[Update Memberships]
    W --> HH[View Reports]

    X --> II[API Call: GET /api/workouts]
    II --> JJ[Backend: Workouts Route]
    JJ --> KK[Verify Token & Role]
    KK --> LL[Query MongoDB: Workouts Collection]
    LL --> MM[Return Workouts Data]
    MM --> NN[Display Workouts List]

    Y --> OO[API Call: POST /api/progress]
    OO --> PP[Backend: Progress Route]
    PP --> QQ[Verify Token]
    QQ --> RR[Create Progress Document]
    RR --> SS[Save to MongoDB: Progress Collection]
    SS --> TT[Return Success]
    TT --> UU[Update UI: Progress Logged]

    Z --> VV[API Call: GET /api/videos]
    VV --> WW[Backend: Videos Route]
    WW --> XX[Verify Token]
    XX --> YY[Query MongoDB: ExerciseVideos Collection]
    YY --> ZZ[Return Videos List]
    ZZ --> AAA[Display Videos]

    BB --> BBB[API Call: POST /api/workouts/template]
    BBB --> CCC[Backend: Workouts Route]
    CCC --> DDD[Check Role: Trainer]
    DDD --> EEE[Create Workout Document]
    EEE --> FFF[Save to MongoDB]
    FFF --> GGG[Return Template Created]
    GGG --> HHH[Update UI]

    CC --> III[API Call: POST /api/presign]
    III --> JJJ[Backend: Presign Route]
    JJJ --> KKK[Generate Supabase Upload URL]
    KKK --> LLL[Return Presigned URL]
    LLL --> MMM[Upload Video to Supabase]
    MMM --> NNN[API Call: POST /api/videos]
    NNN --> OOO[Backend: Videos Route]
    OOO --> PPP[Create ExerciseVideo Document]
    PPP --> QQQ[Save to MongoDB]
    QQQ --> RRR[Return Video Uploaded]
    RRR --> SSS[Update UI]

    DD --> TTT[API Call: GET /api/progress/user/:userId]
    TTT --> UUU[Backend: Progress Route]
    UUU --> VVV[Check Role: Trainer/Admin]
    VVV --> WWW[Query MongoDB: Progress Collection]
    WWW --> XXX[Return User Progress]
    XXX --> YYY[Display Progress Charts]

    FF --> ZZZ[API Call: GET /api/auth/users]
    ZZZ --> AAAA[Backend: Auth Route]
    AAAA --> BBBB[Check Role: Admin]
    BBBB --> CCCC[Query MongoDB: Users Collection]
    CCCC --> DDDD[Return Users List]
    DDDD --> EEEE[Display User Management]

    GG --> FFFF[API Call: PATCH /api/auth/membership/:userId]
    FFFF --> GGGG[Backend: Auth Route]
    GGGG --> HHHH[Check Role: Admin]
    HHHH --> IIII[Update User Document]
    IIII --> JJJJ[Save to MongoDB]
    JJJJ --> KKKK[Return Updated User]
    KKKK --> LLLL[Update UI]

    AA --> MMMM[API Call: GET /api/auth/profile]
    MMMM --> NNNN[Backend: Auth Route]
    NNNN --> OOOO[Verify Token]
    OOOO --> PPPP[Query MongoDB: Users Collection]
    PPPP --> QQQQ[Return Profile Data]
    QQQQ --> RRRR[Display Profile]

    EE --> SSSS[API Call: GET /api/videos/trainer]
    SSSS --> TTTT[Backend: Videos Route]
    TTTT --> UUUU[Check Role: Trainer]
    UUUU --> VVVV[Query MongoDB: Videos by Trainer]
    VVVV --> WWWW[Return Trainer Videos]
    WWWW --> XXXX[Display Manage Videos]

    HH --> YYY[API Call: Various Admin Queries]
    YYY --> ZZZZ[Backend: Multiple Routes]
    ZZZZ --> AAAAA[Aggregate Data from MongoDB]
    AAAAA --> BBBBB[Return Reports Data]
    BBBBB --> CCCCC[Display Reports]

    K --> DDDD[Show Error Message]
    N --> DDDD
    P --> DDDD
    DDDD --> G

    MM -->|Error| EEEE[Handle Error]
    TT -->|Error| FFFF[Handle Error]
    ZZ -->|Error| GGGG[Handle Error]
    GGG -->|Error| HHHH[Handle Error]
    RRR -->|Error| IIII[Handle Error]
    XXX -->|Error| JJJJ[Handle Error]
    DDDD -->|Error| KKKK[Handle Error]
    KKKK -->|Error| LLLL[Handle Error]
    QQQQ -->|Error| MMMM[Handle Error]
    WWWW -->|Error| NNNN[Handle Error]
    BBBBB -->|Error| OOOO[Handle Error]

    EEEE --> U
    FFFF --> U
    GGGG --> Z
    HHHH --> V
    IIII --> CC
    JJJJ --> DD
    KKKK --> W
    LLLL --> GG
    MMMM --> AA
    NNNN --> EE
    OOOO --> HH

    subgraph "Mobile App (Flutter)"
        A
        B
        C
        D
        E
        G
        S
        U
        V
        W
        X
        Y
        Z
        AA
        BB
        CC
        DD
        EE
        FF
        GG
        HH
        NN
        UU
        AAA
        HHH
        SSS
        YYY
        EEEE
        DDDD
        RRRR
        XXXX
        CCCCC
    end

    subgraph "API Service"
        H
        II
        OO
        VV
        BBB
        III
        NNN
        TTT
        ZZZ
        FFFF
        MMMM
        SSSS
        YYY
    end

    subgraph "Backend (Express.js)"
        I
        JJ
        PP
        WW
        CCC
        JJJ
        OOO
        UUU
        AAAA
        GGGG
        NNNN
        TTTT
        ZZZZ
    end

    subgraph "Middleware"
        KK
        QQ
        XX
        DDD
        VVV
        BBBB
        HHHH
        OOOO
        UUUU
    end

    subgraph "Database (MongoDB Atlas)"
        LL
        SS
        YY
        FFF
        QQQ
        WWW
        CCCC
        IIII
        PPPP
        VVVV
        AAAAA
    end

    subgraph "File Storage (Supabase)"
        MMM
    end

    subgraph "External Services"
        KKK
    end

    subgraph "Responses"
        R
        MM
        TT
        ZZ
        GGG
        LLL
        RRR
        XXX
        DDDD
        KKKK
        QQQQ
        WWWW
        BBBBB
    end
```

## Flowchart Description

This comprehensive flowchart illustrates the complete LiftLog system from the user's perspective, covering:

1. **App Initialization**: Token validation and navigation to appropriate screens based on authentication status.

2. **Authentication Flow**: Registration and login processes with role-based access control and membership validation.

3. **Role-Based Dashboards**: Different user interfaces for Members, Trainers, and Admins.

4. **Core Features**:
   - **Members**: View workouts, log progress, watch training videos, manage settings.
   - **Trainers**: Create workout templates, upload videos, view member progress, manage content.
   - **Admins**: User management, membership updates, system reports.

5. **API Interactions**: Detailed HTTP requests to backend endpoints for each feature.

6. **Backend Processing**: Route handling, middleware verification, and business logic execution.

7. **Data Operations**: CRUD operations on MongoDB collections (Users, Workouts, Progress, ExerciseVideos).

8. **File Storage**: Video upload process using Supabase presigned URLs.

9. **Error Handling**: Comprehensive error paths and user feedback mechanisms.

The flowchart uses color-coded subgraphs to clearly delineate system components:
- **Mobile App**: User interface and client-side logic
- **API Service**: HTTP request handling
- **Backend**: Server-side processing
- **Middleware**: Authentication and authorization
- **Database**: Data persistence
- **File Storage**: Media file management
- **External Services**: Third-party integrations
- **Responses**: API response handling

This detailed representation provides a complete overview of the system's architecture, data flow, and user interactions, serving as a valuable reference for development, testing, and maintenance.
