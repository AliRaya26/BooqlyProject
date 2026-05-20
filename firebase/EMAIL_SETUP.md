# Email setup (signup verification + welcome)

Browsers cannot call Resend directly (CORS). Booqly uses **one** of these on web:

## Option A — Trigger Email extension (recommended, no CLI deploy)

1. [Firebase Console](https://console.firebase.google.com/) → project **booqlyapp-83777** → **Extensions** → **Install extension**.
2. Search **Trigger Email** → install.
3. Use collection name: **`mail`** (must match the app).
4. Configure SMTP with **Resend**:
   - Host: `smtp.resend.com`
   - Port: `465` (SSL) or `587` (TLS)
   - Username: `resend`
   - Password: your Resend API key (`re_...`)
   - From: use your **verified domain** address (e.g. `noreply@yourdomain.com`) — see **`firebase/RESEND_DOMAIN.md`**
5. **Firestore** → **Rules** → publish `firestore.rules` from this repo (includes `mail` create rules).
6. Restart the Flutter web app and try signup again.

**Send to any signup email:** verify a domain in Resend and set `EMAIL_FROM` — full steps in **`firebase/RESEND_DOMAIN.md`**.

## Option B — Cloud Function (CLI)

1. `firebase login`
2. Copy `functions/.env.example` → `functions/.env` and set `RESEND_API_KEY`.
3. From project root:
   ```bash
   cd functions && npm install && cd ..
   firebase deploy --only functions
   ```
4. Publish `firestore.rules`.

The app tries the Cloud Function first, then the `mail` collection (Option A).

## Android / iOS

Set `RESEND_API_KEY` in `assets/config.env` — the app calls Resend directly (no CORS).
