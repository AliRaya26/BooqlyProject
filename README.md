# Booqly

**Booqly** is a cross-platform mobile reading companion built with **Flutter**. It helps users discover books, organize a personal library, track reading progress, read PDFs in-app, and stay motivated with streaks and statistics.

The app uses a dark, book-inspired UI (warm gold accents on deep charcoal backgrounds) and **Firebase** for authentication and cloud data.

---

## Table of Contents

- [Features](#features)
- [Tech Stack](#tech-stack)
- [Project Structure](#project-structure)
- [App Flow](#app-flow)
- [Firebase Data Model](#firebase-data-model)
- [Getting Started](#getting-started)
- [Planned / In Progress](#planned--in-progress)

---

## Features

### Authentication

| Feature | Description |
|--------|-------------|
| **Welcome screen** | Onboarding with illustration and “Get started” CTA |
| **Sign up** | Email/password registration; first and last name stored in Firestore |
| **Sign in** | Email/password login via Firebase Auth |
| **User profile in Firestore** | `users/{uid}` document with name, email, and `createdAt` |

### Home Dashboard

| Feature | Description |
|--------|-------------|
| **Continue reading** | Highlights the current book with page progress and a “Resume reading” action |
| **Reading streak** | Weekly calendar showing completed days, today, and upcoming days |
| **Want to read** | Horizontal list of books to read later |
| **Monthly stats** | Books read, pages, hours, average pages/day, and a weekly bar chart |
| **Bottom navigation** | Home, Library, Add (FAB), Explore, Profile |
| **Add book sheet** | Quick actions: search by title, scan ISBN (planned), manual entry (planned) |

> **Note:** Home streak and monthly stats currently use **sample UI data**. Library, search, and book detail screens are backed by **Firebase**.

### Library

| Feature | Description |
|--------|-------------|
| **Three tabs** | Reading · Want to read · Completed |
| **Category filters** | All, Motivation, Programming, Finance, Psychology, Productivity, Philosophy |
| **Realtime sync** | Firestore listener updates the grid when library data changes |
| **Progress display** | Progress bar and percentage on Reading and Completed tabs |
| **Favorites indicator** | Heart badge on covers for favorited books |
| **Multi-select & delete** | Long-press to select; bulk remove from library with confirmation |
| **Book detail** | Tap a cover to open full book information |

### Search & Discovery

| Feature | Description |
|--------|-------------|
| **Search by title** | Live filter by title or author |
| **Category grouping** | Results grouped by book category |
| **Realtime catalog** | Books loaded from the global `books` collection |
| **Hero transitions** | Animated cover when opening book details |

### Book Detail & Reading

| Feature | Description |
|--------|-------------|
| **Book metadata** | Cover, title, author, category, description, page count |
| **Reading progress** | Slider and +/- controls to update current page; syncs to Firestore |
| **Start / continue reading** | Opens in-app PDF reader |
| **Want to read** | Add or remove from the want-to-read list |
| **Favorites** | Add or remove from `users/{uid}/favorites` |
| **Mark as completed** | Sets progress to 100% with a congratulations dialog |
| **PDF reader** | Full-screen viewer using Syncfusion (`SfPdfViewer.network`) |

### Placeholder Screens

- **Explore** and **Profile** tabs show placeholder text (not yet implemented).

---

## Tech Stack

| Layer | Technology |
|-------|------------|
| Framework | [Flutter](https://flutter.dev) (Dart SDK ^3.11.1) |
| Backend | [Firebase](https://firebase.google.com) — Auth, Cloud Firestore |
| Typography | [google_fonts](https://pub.dev/packages/google_fonts) (Outfit, Cormorant Garamond, Merriweather, Amiko) |
| PDF viewing | [syncfusion_flutter_pdfviewer](https://pub.dev/packages/syncfusion_flutter_pdfviewer), [flutter_pdfview](https://pub.dev/packages/flutter_pdfview) |
| Networking / files | [http](https://pub.dev/packages/http), [path_provider](https://pub.dev/packages/path_provider) |

**Supported platforms:** Android, iOS, Web, Windows, macOS, Linux (standard Flutter multi-platform layout).

---

## Project Structure

```
BooqlyProject/
├── lib/
│   ├── main.dart                 # App entry: Firebase init, theme, WelcomePage
│   ├── firebase_options.dart     # Generated Firebase platform config
│   │
│   ├── models/
│   │   └── book_model.dart       # BookModel — maps Firestore ↔ Dart
│   │
│   ├── services/
│   │   ├── auth_service.dart     # Sign up, sign in, sign out
│   │   ├── book_service.dart     # Global books catalog (stream + fetch)
│   │   ├── library_service.dart  # Add/get books in user library
│   │   └── user_book_service.dart# User-specific book entries & progress
│   │
│   ├── Pages/
│   │   ├── WelcomePage.dart      # Onboarding landing screen
│   │   ├── LoginPage.dart        # Email/password login
│   │   ├── SignupPage.dart       # Registration
│   │   ├── HomePage.dart         # Dashboard, nav, add-book sheet, theme colors
│   │   ├── LibraryPage.dart      # Personal library (tabs, filters, grid)
│   │   ├── SearchByTitlePage.dart# Search & browse catalog by category
│   │   ├── BookDetailPage.dart   # Book info, progress, favorites, actions
│   │   └── pdf_reader_page.dart  # In-app PDF viewer
│   │
│   └── assets/
│       └── images/               # Static images (e.g. welcome book illustration)
│
├── android/                      # Android native project + google-services.json
├── ios/                          # iOS native project
├── web/                          # Web build config
├── windows/ | macos/ | linux/    # Desktop platform runners
├── test/
│   └── widget_test.dart          # Widget tests
├── pubspec.yaml                  # Dependencies and asset declarations
└── firebase.json                 # Firebase project configuration
```

### Key files explained

| File | Role |
|------|------|
| `main.dart` | Initializes Firebase, applies dark theme (`#0E0C0A`), starts at `WelcomePage` |
| `HomePage.dart` | Defines `AppColors`, bottom nav, home sections, and the “Add a book” bottom sheet |
| `LibraryPage.dart` | Listens to `users/{uid}/library` and joins with `books/{bookId}` for full metadata |
| `BookDetailPage.dart` | Central hub for reading actions, progress, favorites, and completion |
| `book_model.dart` | Data class with `fromMap` / `toMap` for Firestore documents |

---

## App Flow

```
WelcomePage
    └── LoginPage ──► HomePage ◄── SignupPage
                          │
          ┌───────────────┼───────────────┐
          ▼               ▼               ▼
      Home tab        Library tab     Add (FAB)
      (dashboard)         │               │
                          │         SearchByTitlePage
                          │               │
                          ▼               ▼
                    BookDetailPage ◄──────┘
                          │
                          ▼
                    PdfReaderPage
```

1. User opens the app → **Welcome** → **Login** or **Sign up**.
2. After auth → **Home** with bottom navigation.
3. **Add (+)** → search by title (or future ISBN / manual entry).
4. Select a book → **Book detail** → adjust progress, favorite, or **Start reading**.
5. **Library** tab shows books grouped by status with filters and bulk delete.

---

## Firebase Data Model

```
Firestore
├── books/{bookId}
│   ├── title, author, description, category
│   ├── coverUrl, pdfUrl, totalPages
│
├── users/{uid}
│   ├── firstName, lastName, email, createdAt
│   │
│   ├── library/{bookId}          # User's reading lists
│   │   ├── status                  # "reading" | "want_to_read" | "completed"
│   │   ├── progress, currentPage, totalPages
│   │   ├── addedAt, completedAt
│   │
│   ├── favorites/{bookId}        # Favorited books
│   │   ├── bookId, addedAt
│   │
│   └── userBooks/{bookId}        # Alternate user book storage (UserBookService)
│       ├── title, author, coverUrl, status, progress, ...
```

**Authentication:** Firebase Auth (email/password).

---

## Getting Started

### Prerequisites

- [Flutter SDK](https://docs.flutter.dev/get-started/install) (compatible with Dart ^3.11.1)
- A [Firebase](https://console.firebase.google.com) project with:
  - **Authentication** → Email/Password enabled
  - **Cloud Firestore** with the collections above
  - Flutter app registered (Android/iOS configs in `firebase_options.dart` and `google-services.json`)

### Setup

```bash
# Clone the repository
git clone https://github.com/AliRaya26/BooqlyProject.git
cd BooqlyProject

# Install dependencies
flutter pub get

# Run on a connected device or emulator
flutter run
```

### Firebase configuration

If you use your own Firebase project, regenerate platform options:

```bash
dart pub global activate flutterfire_cli
flutterfire configure
```

Ensure the `books` collection contains documents with at least: `title`, `author`, `description`, `category`, `coverUrl`, `pdfUrl`, and `totalPages`.

---

## Planned / In Progress

| Item | Status |
|------|--------|
| Scan ISBN barcode | UI placeholder in add-book sheet |
| Manual book entry | UI placeholder in add-book sheet |
| Explore tab | Placeholder screen |
| Profile tab | Placeholder screen |
| Forgot password | Link shown on login; not wired up |
| Home dashboard live data | Streak & monthly stats use mock data |
| Resume reading from home | Button not yet linked to PDF reader |

---

## Authors

**AliRaya26** — Mobile Development (Flutter)

---

## License

Private repository. All rights reserved unless otherwise specified by the project owner.
