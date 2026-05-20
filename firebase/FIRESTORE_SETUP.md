# Firestore setup for reading preferences

## `preferences` collection (one document per user)

Document ID = Firebase Auth **user ID** (same as `users` document ID).

| Field | Type | Example |
|-------|------|---------|
| `userId` | string | `abc123…` |
| `preferredGenres` | array | `["Motivation", "Psychology"]` |
| `readingTheme` | string | `cozy_dark` |
| `readingPace` | string | `steady` |
| `preferencesCompleted` | boolean | `true` |
| `preferencesUpdatedAt` | timestamp | |

Path example: `preferences/uZKMEykuxFgJ4M18dGfIheyFiyh2`

Created on **sign up** (empty) and filled after the preferences onboarding screen.

## Security rules

Publish `firestore.rules` from the project root (includes `preferences/{userId}` read/write for the signed-in user).

## Library suggestions

The **Library** tab loads `preferences/{uid}`, then suggests books from the `books` collection whose `category` matches `preferredGenres`, excluding books already in the user's library.

## Reader feedback

Each catalog book can have reviews at `books/{bookId}/feedbacks/{feedbackId}`.

| Field | Type | Example |
|-------|------|---------|
| `bookId` | string | same as parent book |
| `userName` | string | `Alex K.` |
| `rating` | number | `5` (1–5) |
| `comment` | string | review text |
| `createdAt` | timestamp | |

Seed sample data (5 reviews per book):

```powershell
cd "c:\Users\user\Desktop\Mobile Dev Project\BooqlyProject"
node scripts/seed-feedbacks.cjs
```

Use `--dry-run` to preview or `--force` to replace existing feedback docs. Publish `firestore.rules` after changes.
