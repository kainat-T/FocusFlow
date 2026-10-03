# Focus Flow

A Flutter productivity app built around focused study sessions. Set a timer, pick a subject, let it run — sessions are recorded automatically and available to review any time.

---

## Features

### Timer
- Countdown timer with an animated progress ring that shrinks as time runs down
- Preset durations: **15 min · 25 min · 40 min · 1 hr**
- Custom duration via an hours/minutes picker dialog
- Controls: **Start → Pause / Restart → Resume / Restart**

### Subject Tracking
- Add any number of subjects from a dropdown menu
- Selected subject is shown on the main screen and attached to each recorded session
- Delete subjects individually with the × button in the dropdown
- Subject list and last selection are persisted locally per user account using `shared_preferences`

### Session Recording
- Every completed session (timer reaching zero) is automatically saved to Firestore under `users/{uid}/sessions`
- Stored data: subject, duration in seconds, and completion timestamp

### Sessions Screen
- Real-time list of all completed sessions, grouped by **Today / Yesterday / date**
- Each card shows the subject (or "Focus Session"), completion time, and a duration badge
- Empty state when no sessions have been recorded yet

### Authentication
- Email/password sign-up and sign-in via Firebase Auth
- Re-authentication before account deletion (no "requires recent login" errors)
- `AuthGate` listens to the auth state stream — routes automatically to home or login
- Logout from the sidebar drawer

### Profile Screen
- Displays name, email, and user ID
- Delete account option at the bottom with a password confirmation dialog

### Navigation
- Bottom navigation bar with 5 tabs: **Timer · Stats · Progress · Sessions · Tasks**
- Sidebar drawer: Profile, App Theme, Settings, Logout

---

## Project Structure

```
lib/
├── main.dart                  # App entry, Firebase init, AuthGate as home
├── firebase_options.dart      # FlutterFire-generated platform config
│
├── models/
│   └── session_model.dart     # Session data class with Firestore serialization
│
├── screens/
│   ├── home_screen.dart       # Timer, subject selector, duration picker, nav bar, drawer
│   ├── login_screen.dart      # Email/password sign-in
│   ├── register_screen.dart   # Account creation
│   ├── profile_screen.dart    # User info + delete account
│   └── sessions_screen.dart   # Completed sessions list (real-time stream)
│
├── services/
│   ├── auth_service.dart      # Firebase Auth: register, login, logout, deleteAccount
│   └── session_service.dart   # Firestore: saveSession, getSessions, sessionsStream
│
└── widgets/
    └── auth_gate.dart         # StreamBuilder routing: HomeScreen or LoginScreen
```

---

## Dependencies

| Package | Version | Purpose |
|---|---|---|
| `firebase_core` | ^4.15.0 | Firebase initialization |
| `firebase_auth` | ^6.7.0 | Email/password authentication |
| `cloud_firestore` | ^6.10.0 | Session storage per user |
| `firebase_analytics` | ^12.6.0 | Usage analytics |
| `shared_preferences` | ^2.5.5 | Local persistence for subjects |
| `cupertino_icons` | ^1.0.8 | iOS-style icons |

---

## Getting Started

### Prerequisites
- Flutter SDK `^3.11.0`
- A Firebase project with **Email/Password** sign-in enabled
- `google-services.json` placed in `android/app/`
- `GoogleService-Info.plist` placed in `ios/Runner/`

### Firebase Setup
1. Create a project at [console.firebase.google.com](https://console.firebase.google.com)
2. Enable **Authentication → Sign-in method → Email/Password**
3. Enable **Firestore Database** and set the following security rules:

```js
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /users/{uid} {
      allow read, write: if request.auth != null && request.auth.uid == uid;

      match /sessions/{sessionId} {
        allow read, write: if request.auth != null && request.auth.uid == uid;
      }
    }
  }
}
```

4. Run FlutterFire CLI to regenerate `firebase_options.dart` if needed:
```bash
flutterfire configure
```

### Run

```bash
flutter pub get
flutter run
```

---

## Planned Features

- Weekly study stats screen
- Progress dashboard
- Task management per subject
- App theme switching (light / dark / custom)
- Push notifications for session reminders
