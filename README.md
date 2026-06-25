# PrepSwipe Flutter App

A production-ready competitive exam preparation app with Instagram-style swipe navigation.

## Stack
- Flutter (latest stable)
- Firebase Auth (Google Sign-In)
- Provider (state management)
- Space Grotesk font throughout
- Material 3 / Light grey design system

## Project Structure

```
lib/
├── main.dart                  # Entry point, Firebase init, providers
├── models/
│   ├── question_model.dart    # Question & QuestionOption
│   └── user_model.dart        # UserProfile & AnalyticsSummary
├── providers/
│   ├── auth_provider.dart     # Firebase Auth + Google Sign-In
│   ├── quiz_provider.dart     # Question loading, selection, submission
│   └── analytics_provider.dart # Analytics + rank fetching
├── screens/
│   ├── main_shell.dart        # Bottom nav shell (4 tabs)
│   ├── home_screen.dart       # Welcome + swipeable quiz
│   ├── analytics_screen.dart  # Overview / Subjects / Rank tabs
│   ├── settings_screen.dart   # Profile setup + exam selection
│   └── profile_screen.dart    # User info + sign out
├── services/
│   └── api_service.dart       # All backend API calls
├── utils/
│   ├── app_theme.dart         # Colors, ThemeData
│   └── constants.dart         # Base URL, exam list, collection mapping
└── widgets/
    └── ps_card.dart           # PSCard, PSButton, PSBadge, PSLoader, etc.
```

## Setup

### 1. Firebase
1. Create a Firebase project at console.firebase.google.com
2. Add an Android app (package name: `com.prepswipe.app`)
3. Download `google-services.json` → place in `android/app/`
4. Enable Google Sign-In in Firebase Auth console
5. Add your SHA-1 fingerprint to Firebase (for Google Sign-In)

### 2. Update main.dart
Replace the placeholder Firebase options in `lib/main.dart`:
```dart
options: const FirebaseOptions(
  apiKey: 'YOUR_API_KEY',         // From Firebase console
  appId: 'YOUR_APP_ID',
  messagingSenderId: 'YOUR_SENDER_ID',
  projectId: 'YOUR_PROJECT_ID',
  storageBucket: 'YOUR_STORAGE_BUCKET',
),
```

### 3. Android Configuration
In `android/app/build.gradle`:
```gradle
android {
    compileSdkVersion 34
    defaultConfig {
        applicationId "com.prepswipe.app"
        minSdkVersion 21
        targetSdkVersion 34
    }
}

dependencies {
    implementation platform('com.google.firebase:firebase-bom:33.0.0')
    implementation 'com.google.firebase:firebase-auth'
    implementation 'com.google.android.gms:play-services-auth:21.0.0'
}
```

Add to top of `android/app/build.gradle`:
```gradle
apply plugin: 'com.google.gms.google-services'
```

In `android/build.gradle` dependencies:
```gradle
classpath 'com.google.gms:google-services:4.4.1'
```

### 4. Run
```bash
flutter pub get
flutter run
```

## Backend API Used

| Endpoint | Method | Auth | Description |
|---|---|---|---|
| `/health` | GET | No | Health check |
| `/questions` | GET | Bearer | Fetch questions by exam/collection |
| `/attempt/submit` | POST | Bearer | Submit attempt + update analytics |
| `/user/profile` | GET | Bearer | Get profile + analytics |
| `/user/profile` | PATCH | Bearer | Update profile (userId, examType) |
| `/user/overall-rank` | GET | Bearer | Get user's rank |
| `/leaderboard/global` | GET | No | Global leaderboard |

## Key Features

### Swipe Navigation
- `PageView` with `Axis.vertical` — pure Instagram/TikTok feel
- Auto-loads more questions when near end (5 from last)
- Session tracking with UUID per quiz session

### Analytics Auto-Refresh
- After every submission, `AnalyticsProvider.invalidate()` is called
- Next visit to Analytics tab triggers fresh fetch
- Pull-to-refresh on all tabs

### Exam → Collection Mapping
| Exam | Collection |
|---|---|
| UPSC, BPSC, JPSC, NDA etc. | `pcsquestions` |
| SSC, IBPS, SBI, RRB etc. | `bookquestions` |

## Font
Uses **Space Grotesk** via `google_fonts` package — applied across all text throughout the app for a consistent, modern tech-industry look.

## Design System
- Background: `#F5F5F7` (light grey)
- Surface: `#FFFFFF`
- Accent: `#5856D6` (indigo/purple)
- Green: `#34C759`, Red: `#FF3B30`, Gold: `#FF9500`
- All cards: `16px` border radius, subtle `1px` border
- No shadows unless `elevation` is explicitly set
