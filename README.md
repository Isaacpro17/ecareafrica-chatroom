# Netrack Chatroom Feature
### Education Care Africa — Parent · Teacher · Student Communication Module

> **PRD Version:** 2.4 — Microservice Architecture  
> **Status:** Development Ready  
> **Pilot Duration:** 2-Day Live Demo

---

## Table of Contents

1. [Project Overview](#1-project-overview)
2. [Architecture Diagram](#2-architecture-diagram)
3. [Folder Structure](#3-folder-structure)
4. [Color System & Design](#4-color-system--design)
5. [Flutter Package — Setup](#5-flutter-package--setup)
6. [Node.js Backend — Setup](#6-nodejs-backend--setup)
7. [PostgreSQL Database — Setup](#7-postgresql-database--setup)
8. [Firebase — Setup](#8-firebase--setup)
9. [Running the System (Day-to-Day)](#9-running-the-system-day-to-day)
10. [Test Shell — Development Workflow](#10-test-shell--development-workflow)
11. [Integrating into the Main Netrack App](#11-integrating-into-the-main-netrack-app)
12. [API Reference](#12-api-reference)
13. [Feature Checklist](#13-feature-checklist)
14. [Troubleshooting](#14-troubleshooting)

---

## 1. Project Overview

The Netrack Chatroom is a **fully independent microservice** that adds real-time
parent–teacher–student messaging to the Netrack Education ERP Flutter app.

| What | Detail |
|------|--------|
| Flutter package | Self-contained — host app passes a JWT and gets a full chatroom |
| Backend | Node.js REST API (Express) — independent process, own database |
| Database | PostgreSQL — 8 dedicated tables, zero shared tables with main system |
| Real-time | Firebase Realtime Database (event signals only — no message content) |
| Push | Firebase Cloud Messaging (FCM) |
| SMS | Always-on via existing Netrack SMS gateway |
| User data | Fetched once via API bridge from main Netrack system, cached 30 min |

### Who uses it

| Role | How they log in | What they can do |
|------|----------------|-----------------|
| **Parent** | JWT from main Netrack app | Chat with child's teachers, receive broadcasts |
| **Teacher** | JWT from main Netrack app | Chat with parents, search by roll number, broadcast to class |
| **Student** | Student ID + OTP to parent's phone | Chat with their subject teachers only |

---

## 2. Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────┐
│                    Flutter Mobile App                           │
│                                                                 │
│   ┌──────────────────────────────────────────────────────────┐  │
│   │              ChatroomWidget (your package)               │  │
│   │  Parent screens │ Teacher screens │ Student screens      │  │
│   │  MessagesProvider │ ThreadsProvider │ PresenceService    │  │
│   └──────────┬───────────────────────────────┬───────────────┘  │
│              │ REST API calls                │ Firebase events  │
└──────────────┼───────────────────────────────┼──────────────────┘
               │                               │
               ▼                               ▼
┌──────────────────────────┐    ┌──────────────────────────────┐
│   Chat Service (Node.js) │    │  Firebase Realtime Database  │
│   Port 3000              │    │  /schools/{id}/threads/{id}  │
│                          │    │  /schools/{id}/presence/{id} │
│  ┌────────────────────┐  │    └──────────────────────────────┘
│  │  JWT Auth          │  │
│  │  Chat Controller   │  │    ┌──────────────────────────────┐
│  │  Broadcast Queue   │  │    │  Firebase Cloud Messaging    │
│  │  SMS Service       │  │    │  Push notifications          │
│  │  Presence Sync     │  │    └──────────────────────────────┘
│  └────────────────────┘  │
│             │             │    ┌──────────────────────────────┐
│             ▼             │    │  SMS Gateway                 │
│  ┌────────────────────┐  │───▶│  Always-on delivery          │
│  │  PostgreSQL DB     │  │    └──────────────────────────────┘
│  │  (chat_* tables)   │  │
│  └────────────────────┘  │    ┌──────────────────────────────┐
│             │             │    │  Main Netrack API            │
│             ▼             │    │  GET /api/internal/          │
│  ┌────────────────────┐  │◀───│  user-context (bridge)       │
│  │  Redis Cache       │  │    │  (called once, cached 30min) │
│  │  (user context)    │  │    └──────────────────────────────┘
│  └────────────────────┘  │
└──────────────────────────┘
```

**Key principle:** Firebase carries only a `message_id` signal. All message
content lives in PostgreSQL. The chat service never touches the main Netrack
database directly.

---

## 3. Folder Structure

```
ChatRoom/
│
├── chatroom_package/          ← Flutter package (the real deliverable)
│   ├── lib/
│   │   ├── chatroom.dart      ← Public API export
│   │   └── src/
│   │       ├── theme/         ← AppColors, AppTheme (brand colors)
│   │       ├── models/        ← UserContext, ChatThread, ChatMessage
│   │       ├── services/      ← API, Auth, Presence, Notifications
│   │       ├── providers/     ← ThreadsProvider, MessagesProvider
│   │       ├── screens/
│   │       │   ├── splash_screen.dart
│   │       │   ├── chat_thread_screen.dart
│   │       │   ├── parent/    ← ParentHome, ChildSelection, TeacherList
│   │       │   ├── teacher/   ← TeacherHome, RollNumberSearch, Broadcast
│   │       │   └── student/   ← StudentLogin, OtpScreen, StudentHome
│   │       └── widgets/
│   │           ├── chatroom_widget.dart   ← Entry point widget
│   │           ├── common/    ← ThreadListTile, OnlineDot, Shimmer, etc.
│   │           └── message/   ← MessageBubble, InputBar, TypingIndicator
│   └── pubspec.yaml
│
├── chat_service/              ← Node.js REST API (independent microservice)
│   ├── src/
│   │   ├── server.js          ← Express app bootstrap
│   │   ├── db/
│   │   │   ├── pool.js        ← PostgreSQL connection pool
│   │   │   └── migrate.js     ← Creates all 8 tables + indexes
│   │   ├── middleware/
│   │   │   └── auth.middleware.js   ← JWT validation, role guards
│   │   ├── routes/            ← chat, auth, student, admin, dev routes
│   │   ├── controllers/       ← chat, auth, status, student controllers
│   │   └── services/
│   │       ├── firebase.service.js      ← Firebase Admin SDK
│   │       ├── notification.service.js  ← FCM push dispatch
│   │       ├── sms.service.js           ← SMS gateway integration
│   │       └── user_context.service.js  ← Bridge + cache logic
│   ├── mock-data/             ← JSON files for USE_MOCK_BRIDGE=true
│   ├── .env.example           ← Copy to .env and fill in values
│   └── package.json
│
├── test_shell/                ← Throwaway Flutter app for development testing
│   ├── lib/
│   │   ├── main.dart          ← Role picker, launches ChatroomWidget
│   │   ├── mock_users.dart    ← Hardcoded test users
│   │   └── firebase_options.dart  ← Replace with your Firebase config
│   └── pubspec.yaml
│
└── README.md                  ← This file
```

---

## 4. Color System & Design

All colors are extracted from the **Education Care Africa logo**.

| Token | Hex | Usage |
|-------|-----|-------|
| `primaryDark` | `#1A237E` | AppBar, headers, primary text |
| `primary` | `#1565C0` | Buttons, sent bubbles, active states |
| `primaryLight` | `#2196F3` | Accents, online indicators |
| `accent` | `#F9A825` | FAB, unread badges, broadcast labels (logo gold) |
| `success` | `#388E3C` | Online dot (logo green) |
| `background` | `#F5F7FA` | Screen backgrounds |
| `surface` | `#FFFFFF` | Cards, received bubbles |

**Design practices applied:**
- `RichText` / `Text` with adaptive `TextStyle` scaling
- `Flexible` + `Expanded` in all row/column layouts
- `Flex` for proportional space distribution
- `SplashScreen` with animated gradient + elastic logo scale
- Material 3 `useMaterial3: true`
- `flutter_animate` for entrance animations (fadeIn, slideX, scale)
- `Shimmer` skeleton loaders on every list
- Minimum 48×48dp touch targets on all interactive elements
- `SafeArea` on all screens
- `MediaQuery` for adaptive padding

---

## 5. Flutter Package — Setup

### Prerequisites
- Flutter SDK ≥ 3.10.0
- Android Studio / VS Code with Flutter plugin
- Android emulator (API 24+) or physical device

### Step 1 — Install dependencies

```bash
cd chatroom_package
flutter pub get
```

### Step 2 — Add to your app's pubspec.yaml

```yaml
dependencies:
  netrack_chatroom:
    path: ../chatroom_package   # local during development
    # OR for production:
    # git:
    #   url: https://github.com/netrack/chatroom_package
    #   ref: v1.0.0
```

### Step 3 — Initialize in main.dart

```dart
import 'package:netrack_chatroom/chatroom.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await ChatroomService.initialize(
    apiBaseUrl: 'https://chat.netrack.com',       // your chat service URL
    firebaseOptions: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(MyApp());
}
```

### Step 4 — Launch the chatroom (10 lines total)

```dart
// From anywhere in the main app — bottom nav, button, etc.
Navigator.push(
  context,
  MaterialPageRoute(
    builder: (_) => ChatroomWidget(
      userToken: authProvider.currentJwt,   // JWT from your auth system
      schoolId: authProvider.schoolId,
      userRole: authProvider.role,          // 'parent' | 'teacher' | 'student'
    ),
  ),
);
```

That is all the main app needs to write. The package handles everything else.

### Android — build.gradle minimum SDK

In `android/app/build.gradle`:
```gradle
android {
    defaultConfig {
        minSdkVersion 24    // Android 7.0 — required by flutter_sound
        targetSdkVersion 34
    }
}
```

### iOS — Info.plist permissions

Add to `ios/Runner/Info.plist`:
```xml
<key>NSMicrophoneUsageDescription</key>
<string>Netrack needs microphone access to record voice messages.</string>
<key>NSPhotoLibraryUsageDescription</key>
<string>Netrack needs photo library access to send images.</string>
<key>NSCameraUsageDescription</key>
<string>Netrack needs camera access to take photos.</string>
```

---

## 6. Node.js Backend — Setup

### Prerequisites
- Node.js ≥ 18.0.0
- npm ≥ 9.0.0
- PostgreSQL ≥ 14
- Redis (optional for pilot — in-memory fallback works)

### Step 1 — Install dependencies

```bash
cd chat_service
npm install
```

### Step 2 — Configure environment

```bash
cp .env.example .env
```

Open `.env` and fill in:

| Variable | What to put |
|----------|-------------|
| `DB_HOST` | Your PostgreSQL host (e.g. `localhost`) |
| `DB_NAME` | `netrack_chat` |
| `DB_USER` | Your PostgreSQL user |
| `DB_PASSWORD` | Your PostgreSQL password |
| `JWT_SECRET` | **Must match** the secret used by the main Netrack auth system |
| `FIREBASE_PROJECT_ID` | Your Firebase project ID |
| `FIREBASE_CLIENT_EMAIL` | Firebase service account email |
| `FIREBASE_PRIVATE_KEY` | Firebase service account private key |
| `FIREBASE_DATABASE_URL` | `https://your-project-default-rtdb.firebaseio.com` |
| `CHAT_SERVICE_KEY` | A strong random secret shared with the main Netrack system |
| `SMS_GATEWAY_URL` | Your SMS provider endpoint |
| `SMS_GATEWAY_API_KEY` | Your SMS provider API key |
| `USE_MOCK_BRIDGE` | `true` during development, `false` in production |

### Step 3 — Run database migrations

```bash
npm run migrate
```

This creates all 8 tables and indexes in your PostgreSQL database.

### Step 4 — Start the server

```bash
# Development (with auto-reload)
npm run dev

# Production
npm start
```

Server starts on `http://localhost:3000`.  
Health check: `GET http://localhost:3000/health`

---

## 7. PostgreSQL Database — Setup

### Create the database and user

```sql
-- Run as postgres superuser
CREATE DATABASE netrack_chat;
CREATE USER chat_user WITH ENCRYPTED PASSWORD 'your_strong_password';
GRANT ALL PRIVILEGES ON DATABASE netrack_chat TO chat_user;
\c netrack_chat
GRANT ALL ON SCHEMA public TO chat_user;
```

### Tables created by migration

| Table | Purpose |
|-------|---------|
| `chat_threads` | Every conversation (direct or broadcast) |
| `chat_messages` | Every message — authoritative store |
| `chat_message_status` | Per-user delivery/seen status |
| `chat_broadcasts` | Broadcast events and delivery stats |
| `chat_active_status` | Online/offline presence (synced from Firebase) |
| `chat_user_device_tokens` | FCM tokens for push notifications |
| `chat_user_context_cache` | Cached user-context from main system bridge |
| `chat_sms_logs` | SMS dispatch audit log |

**Important:** This database has zero foreign keys to the main Netrack database.
All user data arrives via the API bridge and is cached in `chat_user_context_cache`.

---

## 8. Firebase — Setup

### Step 1 — Create a Firebase project

1. Go to [console.firebase.google.com](https://console.firebase.google.com)
2. Create a new project: `netrack-chatroom` (separate from any existing Netrack Firebase project)
3. Enable **Realtime Database** — start in **locked mode**
4. Enable **Cloud Messaging** (FCM)

### Step 2 — Firebase Security Rules

In the Realtime Database console, set these rules:

```json
{
  "rules": {
    "schools": {
      "$school_id": {
        ".read": "auth != null && auth.token.school_id == $school_id",
        ".write": "auth != null && auth.token.school_id == $school_id"
      }
    }
  }
}
```

This enforces school-level isolation at the Firebase layer.

### Step 3 — Service account for backend

1. Firebase Console → Project Settings → Service Accounts
2. Generate new private key → download JSON
3. Copy values into your `.env` file

### Step 4 — Flutter Firebase config

```bash
# Install FlutterFire CLI
dart pub global activate flutterfire_cli

# In the test_shell directory
cd test_shell
flutterfire configure --project=your-firebase-project-id
```

This generates `lib/firebase_options.dart` with your real values.

### Step 5 — Android google-services.json

Download `google-services.json` from Firebase Console and place it at:
```
test_shell/android/app/google-services.json
```

---

## 9. Running the System (Day-to-Day)

Open **3 terminals**:

```bash
# Terminal 1 — Chat service backend
cd chat_service
npm run dev
# → Running on http://localhost:3000

# Terminal 2 — Flutter test shell (Android emulator)
cd test_shell
flutter run
# → Connects to http://10.0.2.2:3000 (emulator → localhost)

# Terminal 3 — (Optional) Second emulator or physical device
# For testing two-way messaging between parent and teacher
flutter run -d <second_device_id>
```

**Emulator note:** Android emulator uses `10.0.2.2` to reach your machine's
`localhost`. iOS simulator uses `localhost` directly. The test shell's
`main.dart` is pre-configured for Android emulator.

---

## 10. Test Shell — Development Workflow

The test shell is a **throwaway Flutter app** that wraps the chatroom package.
It never goes to production.

### What it does

1. Shows a list of mock users (parents, teachers, students)
2. Taps a user → calls `POST /dev/auth/test-token` to get a real JWT
3. Launches `ChatroomWidget` with that JWT
4. You can test every screen without needing the real Netrack app

### Testing two-way messaging

```
Emulator 1:  Log in as "Jane Doe (Parent)"
Emulator 2:  Log in as "David Mugisha (English Teacher)"

→ Parent sends message to David
→ David receives push notification
→ David replies
→ Parent sees double blue ticks (seen status)
```

### Testing student OTP flow

```
Emulator 1:  Log in as "John Doe (Student)"
             Enter student ID: s-001
             → Mock SMS logged in terminal (USE_MOCK_BRIDGE=true)
             Enter OTP shown in terminal
             → Student JWT issued, chatroom opens
```

### Mock data

All mock user context is in `chat_service/mock-data/`. Edit these JSON files
to add more test users, classes, or teachers without touching any real database.

---

## 11. Integrating into the Main Netrack App

When the main Flutter app is ready, integration takes about **30 minutes**.

### What the main team needs to do

**1. Add to pubspec.yaml**
```yaml
dependencies:
  netrack_chatroom:
    path: ../chatroom_package
```

**2. Initialize in main.dart** (see Section 5, Step 3)

**3. Add the chatroom entry point** (see Section 5, Step 4)

**4. Agree on JWT field names** — the only real dependency.

The chat service expects this JWT payload:
```json
{
  "sub": "user-uuid",
  "user_id": "user-uuid",
  "school_id": "school-uuid",
  "role": "parent",
  "exp": 1234567890
}
```

If the main app uses different field names (e.g. `userId` instead of `sub`),
update `auth.middleware.js` to match before integration.

### What the main Netrack backend team needs to build

One endpoint:

```
GET /api/internal/user-context
Headers:
  Authorization: Bearer {user_jwt}
  X-Chat-Service-Key: {shared_secret}
```

Response format is documented in PRD Section 9.3. The chat service calls this
once per session and caches the result for 30 minutes.

---

## 12. API Reference

All endpoints require `Authorization: Bearer {JWT}` except student OTP routes.

### Authentication
| Method | Endpoint | Description |
|--------|----------|-------------|
| POST | `/auth/student/request-otp` | Send OTP to parent phone |
| POST | `/auth/student/verify-otp` | Verify OTP, get student JWT |
| POST | `/dev/auth/test-token` | **Dev only** — get test JWT |

### Threads & Messages
| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/chat/threads` | Get all threads for current user |
| POST | `/chat/threads` | Create or return existing thread |
| GET | `/chat/threads/:id/messages` | Load messages (paginated) |
| POST | `/chat/messages` | Send a message |
| PUT | `/chat/messages/:id` | Edit message (5-min window) |
| PUT | `/chat/messages/:id/read` | Mark as seen |

### Broadcast (Teacher only)
| Method | Endpoint | Description |
|--------|----------|-------------|
| POST | `/chat/broadcast` | Send class broadcast |
| GET | `/chat/broadcast/:id` | Get broadcast delivery stats |

### Search
| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/chat/search?q=&scope=global` | Global search |
| GET | `/chat/search?q=&thread_id=` | In-thread search |
| GET | `/students/search?roll_number=` | Roll number search (teacher) |

### Presence & Status
| Method | Endpoint | Description |
|--------|----------|-------------|
| PUT | `/chat/status/heartbeat` | Update online status (every 30s) |
| GET | `/chat/status/:userId` | Get user online status |

### Error codes
| Code | HTTP | Meaning |
|------|------|---------|
| `UNAUTHORIZED` | 401 | JWT missing or expired |
| `FORBIDDEN` | 403 | Wrong school_id or role |
| `THREAD_NOT_FOUND` | 404 | Thread does not exist |
| `STUDENT_NOT_FOUND` | 404 | Student ID not in database |
| `PARENT_PHONE_MISSING` | 404 | Student found but no parent phone |
| `OTP_INVALID` | 401 | Wrong or expired OTP |
| `EDIT_WINDOW_EXPIRED` | 422 | 5-minute edit window passed |
| `RATE_LIMITED` | 429 | Too many requests |

---

## 13. Feature Checklist

### Parent
- [x] Single child → direct to teacher list
- [x] Multiple children → child selection screen
- [x] Teacher list filtered by child's enrolled subjects
- [x] Teacher cards with online status dot
- [x] 1-on-1 chat thread
- [x] Message states: sending → sent → delivered → seen (ticks)
- [x] Broadcast messages labeled with 📢
- [x] Offline queue with auto-retry
- [x] No phone numbers shown anywhere
- [x] No call button anywhere

### Teacher
- [x] Roll number search with live suggestions
- [x] Parent + student contact cards per student
- [x] Separate Parent Threads / Student Threads tabs
- [x] Class broadcast with class selector
- [x] Broadcast confirmation dialog
- [x] Broadcast success screen with delivery info
- [x] New Broadcast FAB

### Student
- [x] Student ID / Enrollment Number login
- [x] OTP sent to parent's phone
- [x] 6-digit OTP input with auto-advance
- [x] Student JWT with role=student
- [x] Teacher list filtered by enrolled subjects
- [x] Cannot see parent-teacher threads (403 enforced at API)
- [x] Cannot message other students

### System
- [x] Firebase real-time event signals
- [x] Heartbeat presence (30s interval)
- [x] Online/offline dot on all contact cards
- [x] Typing indicator (Firebase)
- [x] FCM push notifications
- [x] SMS always-on delivery
- [x] 5-minute message edit window
- [x] No message deletion (policy enforced — no DELETE endpoint)
- [x] school_id isolation on every query
- [x] User-context cache (30-min TTL)
- [x] Mock bridge for development
- [x] Dev test-token endpoint (dev only)
- [x] All 8 PostgreSQL tables with indexes
- [x] Full-text search index on message content

---

## 14. Troubleshooting

### Flutter: "Could not find package netrack_chatroom"
Run `flutter pub get` in both `chatroom_package/` and `test_shell/`.

### Flutter: Firebase initialization error
Make sure `google-services.json` is in `test_shell/android/app/` and
`firebase_options.dart` has your real project values (run `flutterfire configure`).

### Backend: "JWT_SECRET is not defined"
Copy `.env.example` to `.env` and fill in all values. Never commit `.env`.

### Backend: PostgreSQL connection refused
Check that PostgreSQL is running: `pg_isready -h localhost -p 5432`  
Verify `DB_USER` and `DB_PASSWORD` match what you created in Step 7.

### Backend: "relation chat_threads does not exist"
Run migrations: `npm run migrate`

### Emulator: Cannot reach localhost backend
Use `10.0.2.2` (not `localhost`) in the Flutter app when running on Android
emulator. The test shell's `main.dart` is already configured for this.

### SMS not sending in development
Set `USE_MOCK_BRIDGE=true` in `.env`. Mock SMS messages are printed to the
terminal instead of being sent to a real gateway.

### Messages not appearing in real-time
Check Firebase Realtime Database rules — the user's `school_id` in the JWT
must match the path they are reading/writing. See Section 8, Step 2.

### OTP not received
In development with `USE_MOCK_BRIDGE=true`, the OTP is printed to the
Node.js terminal — check Terminal 1. In production, verify SMS gateway
credentials and credit balance.

---

*Netrack Education ERP — Chatroom Feature v1.0.0*  
*Education Care Africa — Building Africa's Digital Education Future*
