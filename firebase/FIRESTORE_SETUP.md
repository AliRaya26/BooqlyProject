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
