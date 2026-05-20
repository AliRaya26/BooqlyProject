# Google Calendar linking (Settings → Link)

## 1. Google Cloud Console

Project linked to Firebase **booqlyapp-83777**:

1. [APIs & Services → Library](https://console.cloud.google.com/apis/library) → enable **Google Calendar API**.
2. [OAuth consent screen](https://console.cloud.google.com/apis/credentials/consent) → add scope:
   - `https://www.googleapis.com/auth/calendar.readonly`
3. If the app is in **Testing**, add your Google account under **Test users**.

## 2. OAuth Web client

[Credentials](https://console.cloud.google.com/apis/credentials) → your **Web client** (same ID as `GOOGLE_WEB_CLIENT_ID` in `config.env`).

**Authorized JavaScript origins** — add these (exact match, port included):

```
http://localhost:54141
http://127.0.0.1:54141
```

Run the app on that port: `.\scripts\run-web.ps1` (or `--web-port=54141`).  
If you use a random port from plain `flutter run`, add that URL too (e.g. `http://localhost:57238`) or you will see **no registered origin** / `invalid_client`.

**Authorized redirect URIs** (if required):

```
http://localhost:54141
```

## 3. App config

`assets/config.env`:

```env
GOOGLE_WEB_CLIENT_ID=87414724762-YOUR_WEB_CLIENT.apps.googleusercontent.com
```

Restart the app after editing (**R** or stop and `flutter run -d chrome`).

## 4. Link in the app

Settings → **Google Calendar** → **Link** → complete the Google popup (do not close it early).

---

**Still failing?** Check the terminal for `CalendarService.linkAccount:` — the message after that line is the real error.
