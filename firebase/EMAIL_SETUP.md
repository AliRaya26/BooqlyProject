# Email setup (signup verification, welcome, book completed)

Booqly sends all transactional email through a Firebase Cloud Function that
uses **Gmail SMTP** via [nodemailer](https://nodemailer.com/). No paid plan, no
custom domain. The function works on Android, iOS **and** web — the Flutter
app calls the `sendAuthEmail` callable directly.

## One-time setup (~5 minutes)

### 1. Create a Gmail App Password

1. Go to <https://myaccount.google.com/security>.
2. Make sure **2-Step Verification** is **ON** for the account you want to
   send from. App passwords cannot be created without it.
3. Go to <https://myaccount.google.com/apppasswords>.
4. Type a name like `Booqly` and click **Create**.
5. Copy the 16-character password (e.g. `wzpx tflk hijm qrst`). It is only
   shown once. Spaces are stripped automatically — paste it as-is.

### 2. Fill in `functions/.env`

Copy `functions/.env.example` to `functions/.env` (already done in this repo)
and set:

```env
GMAIL_USER=your.address@gmail.com
GMAIL_APP_PASSWORD=PASTE_16_CHAR_APP_PASSWORD_HERE
EMAIL_FROM=Booqly <your.address@gmail.com>
```

`EMAIL_FROM` **must** use the same Gmail address as `GMAIL_USER` — Gmail
rewrites the `From:` header otherwise. The display name (`Booqly`) is yours.

> Never commit `functions/.env`. It is gitignored.

### 3. Deploy

```powershell
firebase login          # only if not already
.\scripts\deploy-email.ps1
```

This installs `nodemailer`, deploys `sendAuthEmail` + `sendPasswordResetEmail`
to `booqlyapp-83777`, and publishes `firestore.rules`.

### 4. Test

- Mobile (Android/iOS): tap **Mark as Completed** on any book. A green
  snackbar should say `Congratulations email sent to <address>.` within ~3s.
- Web: sign up with any email; the verification code arrives in seconds.

## Limits

- Free Gmail accounts: **~500 outgoing recipients / day**. Plenty for a demo
  project. If you need more, verify a domain at <https://resend.com/domains>
  and switch `deliverViaGmail` back to a provider like Resend.
- Gmail will **silently rewrite** `From:` if it does not match `GMAIL_USER`.

## Troubleshooting

| Symptom in the app snackbar / debug log | Fix |
|---|---|
| `Gmail rejected the App Password` | The 16-char password is wrong or revoked. Generate a fresh one and redeploy. |
| `GMAIL_USER / GMAIL_APP_PASSWORD are not set` | `functions/.env` is missing the keys. Fill it in and redeploy. |
| `Email could not be sent. Set GMAIL_USER…` | Same as above. |
| Email never arrives but no error | Check the spam folder. Gmail-to-Gmail is usually instant; Gmail-to-Outlook can take ~30s. |
| Cloud Function logs say `Daily user sending limit exceeded` | You hit Gmail's ~500/day cap. Wait 24h or switch to a domain-verified provider. |

## Rotating / revoking the password

Open <https://myaccount.google.com/apppasswords>, delete the `Booqly` entry,
create a new one, paste it into `functions/.env`, run
`.\scripts\deploy-email.ps1`.
