# Roulette Reminders

<p align="center">
  <img src="roulettereminderslogo.png" alt="Roulette Reminders logo" width="220">
</p>

Roulette Reminders is a Flutter task manager with a casino-inspired reward loop. It combines Firebase authentication, Firestore-backed todos, file attachments, recurring reminders, and a roulette-style chip system that rewards completed work.

Live app: https://todo-spring-2026-385ef.web.app/

## What the app does

- Signs users in with Firebase email/password authentication.
- Stores todos in Cloud Firestore, scoped per user.
- Supports list and calendar views for planning work.
- Lets users search, sort, and filter tasks by status and priority.
- Adds due dates with local reminder notifications.
- Supports recurring tasks, subtasks, categories, notes, and locations.
- Uploads task attachments to Firebase Storage.
- Awards roulette spins and House Chips when tasks are completed.
- Adds risk/reward mechanics with table bets and per-task "Boss Bets."
- Shows a daily overview panel summarizing workload, overdue items, and focus areas.

## Tech stack

- Flutter with Material 3
- Firebase Authentication
- Cloud Firestore
- Firebase Storage
- `flutter_local_notifications`
- `timezone` and `flutter_timezone`
- `file_picker`
- `url_launcher`
- `confetti`

## Core flow

1. The app initializes Firebase and local notifications in [`lib/main.dart`](lib/main.dart).
2. [`AuthWrapper`](lib/screens/auth_wrapper.dart) routes users to sign-in/sign-up or the main app based on auth state.
3. [`HomeScreen`](lib/screens/home_screen.dart) shows the task table, calendar, overview stats, and roulette vault.
4. [`TodoDetailScreen`](lib/screens/todo_detail_screen.dart) handles editing, attachments, due dates, repeat settings, and Boss Bets.
5. [`TodoService`](lib/services/todo_service.dart) updates completion state, recurring task spawning, chip rewards, and reminder scheduling.

## Firebase collections

### `todos`

Each todo can include:

- `text`, `description`, `category`, `location`
- `createdAt`, `completedAt`, `dueAt`
- `priority`, `repeatFrequency`
- `subTodos`
- `attachments`
- `bossBet`
- `userId`

### `casinoProfiles`

Each user profile tracks:

- `balance`
- `pendingSpins`
- `spinsEarned`
- `lifetimeWinnings`
- `lastPayout`
- `updatedAt`

## Project structure

```text
lib/
├── main.dart
├── firebase_options.dart
├── todo.dart
├── screens/
│   ├── auth_wrapper.dart
│   ├── home_screen.dart
│   ├── sign_in_screen.dart
│   ├── sign_up_screen.dart
│   └── todo_detail_screen.dart
├── services/
│   ├── auth_service.dart
│   ├── casino_service.dart
│   ├── daily_overview_service.dart
│   ├── notification_service.dart
│   └── todo_service.dart
└── widgets/
    ├── chip_bet_dialog.dart
    ├── responsive_frame.dart
    └── roulette_spin_dialog.dart
```

## Getting started

### Prerequisites

- A Flutter SDK compatible with the project's Dart SDK constraint (`^3.10.7`)
- A Firebase project
- FlutterFire CLI if you need to regenerate Firebase config

### 1. Install dependencies

```bash
flutter pub get
```

### 2. Configure Firebase

This repository already contains:

- [`lib/firebase_options.dart`](lib/firebase_options.dart)
- [`android/app/google-services.json`](android/app/google-services.json)

If you are using your own Firebase project, or if you want to support more platforms, regenerate the config:

```bash
flutterfire configure
```

At minimum, enable these Firebase products:

- Authentication with Email/Password
- Cloud Firestore
- Firebase Storage

### 3. Deploy Firestore indexes

The repository includes [`firestore.indexes.json`](firestore.indexes.json). Deploy it if your Firebase project does not already have the required index:

```bash
firebase deploy --only firestore:indexes
```

### 4. Run the app

Android:

```bash
flutter run -d android
```

Web:

```bash
flutter run -d chrome
```

## Platform notes

- Firebase is currently configured in code for Android and web.
- iOS, macOS, Windows, and Linux are not configured in [`lib/firebase_options.dart`](lib/firebase_options.dart). Running there will fail until you add FlutterFire config for those targets.
- Local due-date notifications are disabled on web by design in [`NotificationService`](lib/services/notification_service.dart).
- On Android, the app requests notification permission and exact alarm permission. If exact alarms are unavailable, it falls back to inexact scheduling.

## Important implementation notes

- Authentication behavior is documented further in [`AUTHENTICATION.md`](AUTHENTICATION.md).
- Completing a recurring task automatically creates the next occurrence.
- Completing a task can award a roulette spin.
- Boss Bets lock chips onto a task and pay out only if the task is completed before the due date.
- Deleting a task also attempts to remove its stored attachments and scheduled reminder.

## Why this project is different

Most todo apps stop at CRUD. Roulette Reminders adds a game loop:

- finish work
- earn spins
- win chips
- risk chips on future deadlines

That makes the app useful both as a task board and as an experiment in motivation design.
