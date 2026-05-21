# Google sign-up / sign-in for **any** Gmail

If only one Google account works (e.g. your own), the Firebase/Google OAuth app is almost always in **Testing** mode. In that mode Google only allows accounts listed under **Test users**.

## Fix (recommended): allow all Google accounts

1. Open [OAuth consent screen](https://console.cloud.google.com/apis/credentials/consent?project=booqlyapp-83777) for project **booqlyapp-83777**.
2. Under **Publishing status**, click **Publish app** and move to **Production**.
3. Complete any required app verification if Google asks (basic `email` / `profile` scopes are usually quick).
4. In [Firebase → Authentication → Sign-in method](https://console.firebase.google.com/project/booqlyapp-83777/authentication/providers), ensure **Google** is enabled.
5. Hot restart the app (**R**) and try **Sign up with Google** with another Gmail.

## Alternative (development only): add more test users

On the same OAuth consent screen, while status is **Testing**, add each Gmail under **Test users**. This does not scale for real users — use Production for release.

## Web (Chrome)

- **Authentication → Settings → Authorized domains** must include `localhost` (and your production domain when deployed).
- Run on a fixed port so OAuth origins match: `.\scripts\run-web.ps1` (port **54141**).

## Mobile (Android / iOS)

`assets/config.env` must include the Firebase **Web client ID** (starts with `87414724762-`):

```env
GOOGLE_WEB_CLIENT_ID=87414724762-....apps.googleusercontent.com
```

The app passes this as `serverClientId` for Google Sign-In + Firebase Auth on mobile.

### Android: SHA-1 must match **this PC’s debug keystore**

If you see *“Google sign-in is not set up for this Android build”*, Firebase has the wrong SHA-1 (or none) for `com.example.booqly`.

1. [Firebase → Project settings → Your apps → Android](https://console.firebase.google.com/project/booqlyapp-83777/settings/general) (`com.example.booqly`).
2. Under **SHA certificate fingerprints**, add **both** if missing:
   - **Debug (this machine / `flutter run`):**  
     `F9:1B:F9:D5:DF:E7:1D:9F:CE:83:C9:C0:43:C7:CB:17:65:F0:F4:9E`
   - Any other machine: run `cd android` then `.\gradlew signingReport` and copy that variant’s SHA-1.
3. [Authentication → Sign-in method](https://console.firebase.google.com/project/booqlyapp-83777/authentication/providers) → enable **Google**.
4. Download a new **`google-services.json`** → replace `android/app/google-services.json`.  
   Under `oauth_client` → `android_info` → `certificate_hash` should be  
   `f91bf9d5dfe71d9fce83c9c043c7cb1765f0f49e` (same SHA-1, no colons).  
   If it still shows `dfb13c0d...`, the wrong fingerprint is registered — add the debug SHA above.
5. Rebuild (not just hot reload):  
   `flutter clean` then `flutter run -d <your-tablet>`.

## Still failing?

Check the debug console for `AuthService.signInWithGoogle:` — the message after that line is the real error (access denied, wrong password provider, Firestore rules, etc.).
