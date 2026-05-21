# Booqly — apply full setup (checklist)

## Already in the repo (code)

- [x] Email verification + welcome (`email_service.dart`)
- [x] Web email via Cloud Function + Firestore `mail` fallback
- [x] Google sign-up on signup page
- [x] Google Calendar `clientId` fix on web
- [x] `assets/config.env` + `functions/.env` + `web/index.html` OAuth client

## You do in consoles (one time)

### A. Google sign-in (web “Continue with Google”)

1. [Firebase → Authentication → Sign-in method](https://console.firebase.google.com/project/booqlyapp-83777/authentication/providers) → enable **Google**.
2. **Authentication → Settings → Authorized domains** → ensure **localhost** is listed.
3. [OAuth consent screen → Publish app](https://console.cloud.google.com/apis/credentials/consent?project=booqlyapp-83777) to **Production** so **any** Gmail can sign in (not only Test users). See `GOOGLE_SIGNIN_SETUP.md`.

The app uses Firebase **signInWithPopup** on web (not the OAuth Web client in `config.env`). Hot restart (**R**) after enabling.

### B. Google Calendar linking — project **booqlyapp-83777**

Use the Web client ID in `config.env` (must start with **`87414724762-`** for booqlyapp-83777).  
**Do not** use IDs from other GCP projects (`982263059367-...`, `268491125783-...`).

After updating `config.env`, run `.\scripts\sync-google-oauth.ps1` so `web/index.html` stays in sync.

1. [Enable Calendar API](https://console.cloud.google.com/apis/library/calendar-json.googleapis.com?project=booqlyapp-83777)
2. [OAuth consent screen](https://console.cloud.google.com/apis/credentials/consent?project=booqlyapp-83777) → add scope `calendar.readonly`. For **sign-in for everyone**, publish the app (see `GOOGLE_SIGNIN_SETUP.md`). Test users alone only allow listed Gmail accounts.
3. [Credentials → Web client](https://console.cloud.google.com/apis/credentials?project=booqlyapp-83777) → **Authorized JavaScript origins** (add all of these):
   ```
   http://localhost:54141
   http://127.0.0.1:54141
   ```
   Google matches the **exact** origin (including port). `http://localhost` alone does **not** cover `http://localhost:57238`.

   **Recommended:** always run web on port **54141** so you do not re-add origins every run:
   ```powershell
   .\scripts\run-web.ps1
   ```
   Or: `flutter run -d chrome --web-hostname=localhost --web-port=54141`

   If you use another port, add that exact URL too (e.g. `http://localhost:57238`).

Details: `GOOGLE_CALENDAR_SETUP.md`

### C. Firebase — project **booqlyapp-83777**

1. **Authentication** → enable **Email/Password** (Google: see section A)
2. **Firestore** → **Rules** → publish `firestore.rules` from this repo
3. **Web email** (pick one):
   - Run `.\scripts\deploy-email.ps1` after `firebase login`, **or**
   - Install **Trigger Email** extension, collection `mail`, SMTP = Resend

Details: `EMAIL_SETUP.md`

### D. Resend — send to **any** signup email

1. [resend.com/domains](https://resend.com/domains) → verify your domain
2. Set in **both** `assets/config.env` and `functions/.env`:
   ```env
   EMAIL_FROM=Booqly <noreply@yourdomain.com>
   ```
3. Redeploy: `.\scripts\deploy-email.ps1`

Details: `RESEND_DOMAIN.md`

## Run the app

```powershell
cd "c:\Users\user\Desktop\Mobile Dev Project\BooqlyProject"
.\scripts\run-web.ps1
```

Press **R** after changing `config.env`.

## Quick test

| Feature | Test |
|--------|------|
| Google sign-up | Sign up → **Sign up with Google** |
| Email code | Sign up → use email on verified Resend domain |
| Calendar | Settings → **Link** → complete popup |
