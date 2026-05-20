# Send verification email to any signup address

Resend **does not allow** `onboarding@resend.dev` to mail arbitrary users. That sender is for testing to **your own** Resend login email only.

To send to **any** email (e.g. `ayastudies19@gmail.com`), you must use a **verified domain**.

## Steps (one-time, ~15 minutes)

### 1. Get a domain

Use any domain you control (e.g. `booqly.app`, `yourname.com`). Add it in [Resend → Domains](https://resend.com/domains).

### 2. Add DNS records

Resend shows TXT/MX records. Add them at your domain registrar (GoDaddy, Namecheap, Cloudflare, etc.). Wait until Resend shows **Verified**.

### 3. Update `EMAIL_FROM` everywhere

Use an address **on that domain** (the mailbox does not need to exist):

```env
EMAIL_FROM=Booqly <noreply@yourdomain.com>
```

Update in **all** of these:

| Location | File / place |
|----------|----------------|
| Flutter app | `assets/config.env` |
| Cloud Function | `functions/.env` |
| Firebase extension | Trigger Email → SMTP **From** (if you use it) |

Replace `yourdomain.com` with your real verified domain.

### 4. Redeploy / restart

```powershell
firebase login
cd "c:\Users\user\Desktop\Mobile Dev Project\BooqlyProject"
.\scripts\deploy-email.ps1
```

Restart the app: `flutter run -d chrome`

### 5. Test

Sign up with **any** email. The code should arrive within a minute (check spam).

---

**Web (Chrome):** You still need either `deploy-email.ps1` or the **Trigger Email** extension with the **same** `EMAIL_FROM` and Resend API key — see `firebase/EMAIL_SETUP.md`.

**Limits:** Resend free tier allows 3,000 emails/month to any recipient **after** domain verification.
