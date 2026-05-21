# Booqly

**Booqly** is a cross-platform mobile reading companion built with **Flutter**. It helps users discover books, organize a personal library, track reading progress, read PDFs in-app, chat with an AI reading assistant, and stay motivated with calendar-aware reading reminders.

The app uses a dark, book-inspired UI (warm gold accents on deep charcoal backgrounds) and is powered by **Firebase** (Auth, Firestore, Cloud Functions), **Google Gemini** for the AI assistant, **Google Calendar** for free-time detection, and **Gmail SMTP** (via Cloud Functions + nodemailer) for transactional email.

---

## Table of Contents

- [Features](#features)
- [Tech Stack](#tech-stack)
- [Project Structure](#project-structure)
- [App Flow](#app-flow)
- [Firebase Data Model](#firebase-data-model)
- [Getting Started](#getting-started)
- [Environment Configuration](#environment-configuration)
- [Planned / In Progress](#planned--in-progress)

---

## Features

### Authentication

| Feature | Description |
|--------|-------------|
| **Welcome screen** | Onboarding with illustration and "Get started" CTA |
| **Email / password sign up** | First/last name + email + password; user profile saved to `users/{uid}` |
| **Google sign-in / sign-up** | One-tap Google auth on web (Firebase popup) and mobile (`google_sign_in`) |
| **Email verification** | 6-digit verification code emailed via the `sendAuthEmail` Cloud Function (Gmail SMTP) on sign-up |
| **Welcome email** | Branded welcome message sent after successful sign-up |
| **Forgot password** | Inline dialog on login → password reset link delivered by `sendPasswordResetEmail` Cloud Function |
| **Registered-email detection** | `email_index/{emailLower}` lookup prevents duplicate accounts and routes Google-only users back to "Continue with Google" |

### Reading Preferences (Onboarding)

| Feature | Description |
|--------|-------------|
| **Genre selection** | Pick 3+ genres from a Firestore-backed catalog (Motivation, Programming, Finance, Psychology, Productivity, Philosophy, Fiction, Science, History, …) |
| **Reading theme** | Choose a visual mood (e.g. Cozy Dark, Library Lamp, Minimal Ink) |
| **Reading pace** | Set your pace (e.g. Light, Steady, Marathon) |
| **Personalized library** | Selected genres seed the initial Want-to-Read list from the global catalog |
| **Persisted** | Saved to `preferences/{uid}` and re-used by the AI assistant for recommendations |

### Home Dashboard

| Feature | Description |
|--------|-------------|
| **Continue reading** | Live card for the user's current book with page progress and "Resume reading" |
| **Reading streak** | Weekly calendar showing completed, today, and upcoming days |
| **Want to read** | Horizontal carousel of books queued for later, sourced from Firestore |
| **Monthly stats** | Books read, pages, hours, average pages/day, and weekly bar chart (sample UI data) |
| **Bottom navigation** | Home · Library · Add (FAB) · Ask AI · Settings |
| **Add book sheet** | Quick actions: search by title, scan ISBN (planned), manual entry (planned) |

> **Note:** Continue reading, Want-to-Read, and Library data are backed by Firestore. The weekly streak and monthly stats panels currently use sample UI data.

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
| **Start / continue reading** | Opens the in-app PDF reader |
| **Want to read** | Add or remove from the want-to-read list |
| **Favorites** | Add or remove from `users/{uid}/favorites` |
| **Mark as completed** | Sets progress to 100% with a congratulations dialog |
| **Reader reviews** | Star rating + comments stored in `books/{bookId}/feedbacks` (seeded demo set on first view) |
| **PDF reader** | Full-screen viewer using Syncfusion (`SfPdfViewer.network`) |

### AI Book Chat ("Ask AI")

| Feature | Description |
|--------|-------------|
| **Powered by Gemini** | Conversational assistant grounded in your library, catalog, preferences, and reviews |
| **Recommendations** | Suggests next reads based on your genres, current shelf, and ratings |
| **Rating / review lookup** | Ask "What's the rating for Atomic Habits?" — returns the average and recent comments |
| **Image upload** | Snap or pick a book cover (`image_picker`) and Gemini identifies the title and checks if you own it |
| **Smart book matching** | Fuzzy title/author matcher (`BookLookupService`) finds books across your library and the catalog |
| **Suggested prompts** | One-tap chips to start common questions |

### Settings

| Feature | Description |
|--------|-------------|
| **Google Calendar linking** | Read-only Calendar access used to detect free time between events |
| **Reading reminders** | Local notifications scheduled during free calendar windows (≥25 min) to nudge a reading session |
| **Reminder toggle** | Enable/disable motivation reminders |
| **Sign out** | Clears Firebase Auth session and returns to Welcome |

---

## Tech Stack

| Layer | Technology |
|-------|------------|
| Framework | [Flutter](https://flutter.dev) (Dart SDK ^3.11.1) |
| Backend | [Firebase](https://firebase.google.com) — Auth, Cloud Firestore, Cloud Functions (Node.js) |
| AI | [Google Gemini](https://ai.google.dev) via REST (`gemini_chat_service.dart`) |
| Email | Gmail SMTP via [nodemailer](https://nodemailer.com) inside Firebase Cloud Functions, with Firestore `mail` Trigger-Email fallback on web |
| Google services | [google_sign_in](https://pub.dev/packages/google_sign_in), [googleapis](https://pub.dev/packages/googleapis) (Calendar), [extension_google_sign_in_as_googleapis_auth](https://pub.dev/packages/extension_google_sign_in_as_googleapis_auth) |
| Notifications | [flutter_local_notifications](https://pub.dev/packages/flutter_local_notifications), [timezone](https://pub.dev/packages/timezone), [flutter_timezone](https://pub.dev/packages/flutter_timezone), [permission_handler](https://pub.dev/packages/permission_handler) |
| Typography | [google_fonts](https://pub.dev/packages/google_fonts) (Outfit, Cormorant Garamond, Merriweather, Amiko) |
| PDF viewing | [syncfusion_flutter_pdfviewer](https://pub.dev/packages/syncfusion_flutter_pdfviewer), [flutter_pdfview](https://pub.dev/packages/flutter_pdfview) |
| Storage / utilities | [shared_preferences](https://pub.dev/packages/shared_preferences), [path_provider](https://pub.dev/packages/path_provider), [http](https://pub.dev/packages/http), [flutter_dotenv](https://pub.dev/packages/flutter_dotenv), [image_picker](https://pub.dev/packages/image_picker) |

**Supported platforms:** Android, iOS, Web, Windows, macOS, Linux (standard Flutter multi-platform layout). The Google Calendar linking flow is currently optimized for web and Android.

---

## Project Structure

```
BooqlyProject/
├── lib/
│   ├── main.dart                       # App entry: env, Firebase, theme, motivation service
│   ├── firebase_options.dart           # Generated Firebase platform config
│   │
│   ├── models/
│   │   ├── book_model.dart             # Book ↔ Firestore mapping
│   │   ├── chat_message.dart           # AI chat message
│   │   ├── feedback_model.dart         # Review + BookFeedbackSummary
│   │   ├── free_time_slot.dart         # Calendar free-time slot
│   │   └── reading_preferences_model.dart
│   │
│   ├── services/
│   │   ├── auth_service.dart           # Email/password + Google + verification
│   │   ├── book_service.dart           # Global books catalog (stream + fetch)
│   │   ├── library_service.dart        # Add/get books in user library
│   │   ├── user_book_service.dart      # User-specific book entries
│   │   ├── preferences_service.dart    # Reading preferences (read/write/seed)
│   │   ├── feedback_service.dart       # Book reviews & average ratings
│   │   ├── feedback_seed_service.dart  # First-run seed of demo reviews
│   │   ├── book_lookup_service.dart    # Fuzzy book match for AI chat
│   │   ├── gemini_chat_service.dart    # Gemini REST client + chat context
│   │   ├── email_service.dart          # Verification + welcome + password reset
│   │   ├── calendar_service.dart       # Google Calendar OAuth + free-time
│   │   ├── reading_motivation_service.dart # Schedules local reading reminders
│   │   └── google_oauth_config.dart    # Web OAuth client config from dotenv
│   │
│   ├── Pages/
│   │   ├── WelcomePage.dart
│   │   ├── LoginPage.dart              # Email/password + Google + forgot password
│   │   ├── SignupPage.dart             # Email/password + Google + verification code
│   │   ├── ReadingPreferencesPage.dart # Genre / theme / pace onboarding
│   │   ├── HomePage.dart               # Dashboard, bottom nav, add-book sheet
│   │   ├── LibraryPage.dart            # Personal library (tabs, filters, grid)
│   │   ├── SearchByTitlePage.dart      # Search & browse catalog
│   │   ├── BookDetailPage.dart         # Book info, progress, favorites, reviews
│   │   ├── BookChatPage.dart           # AI chat with Gemini + image picker
│   │   ├── SettingsPage.dart           # Calendar link, reminders, sign out
│   │   └── pdf_reader_page.dart        # In-app PDF viewer
│   │
│   ├── widgets/
│   │   ├── auth_scaffold.dart          # Shared auth layout
│   │   └── calendar_link_web_*.dart    # Web-only Google sign-in helpers
│   │
│   └── assets/
│       └── images/                     # Static images (welcome illustration, etc.)
│
├── assets/
│   ├── config.env                      # GEMINI_API_KEY, GOOGLE_WEB_CLIENT_ID, EMAIL_FROM
│   └── config.env.example              # Template for env file
│
├── functions/                          # Firebase Cloud Functions (Node.js)
│   ├── index.js                        # sendAuthEmail, sendPasswordResetEmail
│   ├── package.json
│   └── .env.example                    # GMAIL_USER, GMAIL_APP_PASSWORD, EMAIL_FROM
│
├── firebase/                           # Setup docs + seed data
│   ├── SETUP.md                        # End-to-end checklist
│   ├── EMAIL_SETUP.md
│   ├── FIRESTORE_SETUP.md
│   ├── GOOGLE_CALENDAR_SETUP.md
│   ├── GOOGLE_SIGNIN_SETUP.md
│   └── seed/reading_preferences.json   # Seed for app_config/reading_preferences
│
├── scripts/                            # PowerShell helpers (Windows dev)
│   ├── run-web.ps1                     # Launch web build on fixed port 54141
│   ├── deploy-email.ps1                # Deploy Cloud Functions
│   ├── login-firebase.ps1
│   ├── sync-env.ps1                    # Sync assets/config.env ↔ functions/.env
│   ├── sync-google-oauth.ps1           # Sync OAuth client ID into web/index.html
│   └── seed-feedbacks.cjs              # Seed demo reviews into Firestore
│
├── android/                            # Android native + google-services.json
├── ios/                                # iOS native
├── web/                                # Web build (OAuth client embedded)
├── windows/ | macos/ | linux/          # Desktop platform runners
├── test/widget_test.dart
├── firebase.json
├── firestore.rules                     # Security rules (books, feedbacks, users, mail, …)
├── pubspec.yaml
└── README.md
```

### Key files explained

| File | Role |
|------|------|
| `main.dart` | Loads `assets/config.env`, initializes Firebase + Firestore persistence, primes Google Fonts, boots `ReadingMotivationService`, then launches `WelcomePage`. |
| `HomePage.dart` | Defines `AppColors`, the four-tab `_BottomNav` (Home / Library / Ask AI / Settings) plus the central Add FAB, and the "Add a book" bottom sheet. |
| `BookChatPage.dart` | Gemini-powered chat with library/catalog/preferences/feedback context and book-cover image input. |
| `SettingsPage.dart` | Google Calendar linking, reading-reminder toggle, and sign out. |
| `ReadingPreferencesPage.dart` | Post-signup onboarding for genres, theme, and pace; seeds the initial Want-to-Read list. |
| `BookDetailPage.dart` | Central hub for reading actions, progress, favorites, completion, and reviews. |
| `email_service.dart` | Calls `sendAuthEmail` Cloud Function with HTML for verification codes, welcome, book-completed, and password reset (Gmail SMTP on the backend). |
| `calendar_service.dart` | Google OAuth + Calendar v3 read access; computes ≥25 min free slots. |
| `reading_motivation_service.dart` | Schedules local notifications during free calendar windows. |
| `functions/index.js` | `sendAuthEmail` and `sendPasswordResetEmail` callable functions backed by Gmail SMTP (nodemailer). |
| `firestore.rules` | Auth-gated rules for books, feedbacks, users, preferences, email_index, and the `mail` queue. |

---

## App Flow

```
WelcomePage
    └── LoginPage ──► HomePage ◄── SignupPage
                          ▲             │
                          │             ▼
                          │     ReadingPreferencesPage (first-time)
                          │
       ┌──────────────────┼──────────────────┐
       ▼                  ▼                  ▼
   Home tab           Library tab        Ask AI tab        Settings tab
   (dashboard)            │             (Gemini chat)      (calendar +
                          │                                 reminders)
              Add (FAB) ──┴──► SearchByTitlePage
                                  │
                                  ▼
                            BookDetailPage
                                  │
                                  ▼
                            PdfReaderPage
```

1. User opens the app → **Welcome** → **Login** or **Sign up** (email or **Continue with Google**).
2. New sign-ups verify a 6-digit code emailed via the `sendAuthEmail` Cloud Function (Gmail SMTP), then complete **Reading Preferences** onboarding.
3. After auth → **Home** with bottom navigation (Home · Library · Add · Ask AI · Settings).
4. **Add (+)** → search by title (or future ISBN scan / manual entry).
5. Select a book → **Book detail** → adjust progress, favorite, leave a review, or **Start reading**.
6. **Library** tab shows books grouped by status with category filters and bulk delete.
7. **Ask AI** answers questions about your library, ratings, and recommendations — and can identify books from photos.
8. **Settings** links Google Calendar and toggles reading reminders that fire during free time.

---

## Firebase Data Model

```
Firestore
├── books/{bookId}
│   ├── title, author, description, category
│   ├── coverUrl, pdfUrl, totalPages
│   └── feedbacks/{feedbackId}             # Reader reviews (fb_1 … fb_5 seeded)
│       ├── userName, rating (1–5), comment, createdAt
│
├── app_config/reading_preferences          # Catalog of genres, themes, paces
│
├── preferences/{userId}                    # Per-user reading preferences
│   ├── preferredGenres, readingTheme, readingPace
│   ├── preferencesCompleted, preferencesUpdatedAt
│
├── users/{uid}
│   ├── firstName, lastName, email, createdAt
│   │
│   ├── library/{bookId}                    # Reading lists
│   │   ├── status                            # "reading" | "want_to_read" | "completed"
│   │   ├── progress, currentPage, totalPages
│   │   ├── addedAt, completedAt
│   │
│   ├── favorites/{bookId}                  # Favorited books
│   │   ├── bookId, addedAt
│   │
│   └── userBooks/{bookId}                  # Alternate per-user book entries
│       ├── title, author, coverUrl, status, progress, ...
│
├── email_index/{emailLower}                # Lookup for sign-up / Google routing
│   ├── uid, provider, createdAt
│
└── mail/{docId}                            # Trigger Email queue (web fallback)
    ├── to, message: { subject, html }
```

**Authentication:** Firebase Auth — Email/Password and Google providers.

**Cloud Functions** (region `us-central1`):

| Callable | Purpose |
|----------|---------|
| `sendAuthEmail` | Sends arbitrary transactional HTML email via Gmail SMTP (verification, welcome, book-completed) |
| `sendPasswordResetEmail` | Generates a Firebase password reset link and emails it via Gmail SMTP |

---

## Getting Started

### Prerequisites

- [Flutter SDK](https://docs.flutter.dev/get-started/install) (compatible with Dart ^3.11.1)
- [Node.js](https://nodejs.org/) 20+ (for Cloud Functions)
- [Firebase CLI](https://firebase.google.com/docs/cli) (`npm i -g firebase-tools`)
- A [Firebase](https://console.firebase.google.com) project with:
  - **Authentication** → Email/Password **and** Google enabled
  - **Cloud Firestore** with the rules in `firestore.rules` published
  - **Cloud Functions** (Blaze plan required to deploy)
- A Gmail account with 2-Step Verification enabled and a 16-character **App Password** (see `firebase/EMAIL_SETUP.md`)
- A [Google Cloud](https://console.cloud.google.com) project with the **Calendar API** enabled and an **OAuth 2.0 Web client** for the same Firebase project
- A [Google AI Studio](https://aistudio.google.com/app/apikey) Gemini API key

### Setup

```powershell
# Clone the repository
git clone https://github.com/AliRaya26/BooqlyProject.git
cd BooqlyProject

# Install Flutter dependencies
flutter pub get

# Install Cloud Functions dependencies
cd functions
npm install
cd ..

# Run on a connected device or emulator (mobile / desktop)
flutter run

# Or run on web on a stable port (matches OAuth origins in Google Console)
./scripts/run-web.ps1
```

### Firebase configuration

If you use your own Firebase project, regenerate platform options:

```bash
dart pub global activate flutterfire_cli
flutterfire configure
```

Then publish Firestore rules and deploy the Cloud Functions:

```powershell
firebase deploy --only firestore:rules
./scripts/deploy-email.ps1
```

Ensure the `books` collection contains documents with at least: `title`, `author`, `description`, `category`, `coverUrl`, `pdfUrl`, and `totalPages`. Seed `app_config/reading_preferences` from `firebase/seed/reading_preferences.json`.

Full step-by-step instructions live in [`firebase/SETUP.md`](firebase/SETUP.md) along with topic-specific guides for email, Google Sign-In, and Calendar.

---

## Environment Configuration

Two `.env` files drive the integrations. Copy the provided examples and fill them in:

```powershell
Copy-Item assets/config.env.example assets/config.env
Copy-Item functions/.env.example functions/.env
```

`assets/config.env` (loaded at app startup — bundled into the APK, so **no secrets here**):

```env
GEMINI_API_KEY=...                # Google AI Studio key for the AI chat
GOOGLE_WEB_CLIENT_ID=...          # OAuth 2.0 Web client for Calendar linking
```

`functions/.env` (used by deployed Cloud Functions — server-side only):

```env
GMAIL_USER=your.address@gmail.com
GMAIL_APP_PASSWORD=abcdabcdabcdabcd        # 16-char app password from myaccount.google.com/apppasswords
EMAIL_FROM=Booqly <your.address@gmail.com> # must match GMAIL_USER
```

Use `./scripts/sync-env.ps1` to verify `functions/.env` has the required Gmail keys and `./scripts/sync-google-oauth.ps1` after changing the web client ID so `web/index.html` stays aligned.

---

## Planned / In Progress

| Item | Status |
|------|--------|
| Scan ISBN barcode | UI placeholder in add-book sheet |
| Manual book entry | UI placeholder in add-book sheet |
| Home dashboard live data | Streak & monthly stats still use mock data |
| Resume reading from home card | Button not yet wired to PDF reader |
| iOS Calendar linking polish | Flow works on web/Android; iOS needs additional URL scheme config |
| Push notifications (FCM) | Reading reminders are local only today |

---

## Authors

**AliRaya26** — Mobile Development (Flutter)

---

## License

Private repository. All rights reserved unless otherwise specified by the project owner.
