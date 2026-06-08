const { onCall, HttpsError } = require("firebase-functions/v2/https");
const { onSchedule } = require("firebase-functions/v2/scheduler");
const { defineString } = require("firebase-functions/params");
const admin = require("firebase-admin");
const nodemailer = require("nodemailer");

if (!admin.apps.length) {
  admin.initializeApp();
}

const gmailUser = defineString("GMAIL_USER");
const gmailAppPassword = defineString("GMAIL_APP_PASSWORD");
const emailFrom = defineString("EMAIL_FROM", {
  default: "Booqly <noreply@booqly.app>",
});

const emailPattern =
  /^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$/;

function escapeHtml(value) {
  return String(value)
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;");
}

let cachedTransporter = null;
let cachedUser = null;
let cachedPassword = null;

function getTransporter() {
  const user = gmailUser.value()?.trim();
  // Gmail shows the App Password with spaces; strip them so users can paste
  // it as-is.
  const pass = gmailAppPassword.value()?.replace(/\s+/g, "");

  if (!user || !pass) {
    throw new HttpsError(
      "failed-precondition",
      "GMAIL_USER / GMAIL_APP_PASSWORD are not set on Firebase Functions. " +
        "Create a Gmail App Password (myaccount.google.com/apppasswords) " +
        "and redeploy.",
    );
  }

  if (cachedTransporter && cachedUser === user && cachedPassword === pass) {
    return cachedTransporter;
  }

  cachedTransporter = nodemailer.createTransport({
    service: "gmail",
    auth: { user, pass },
  });
  cachedUser = user;
  cachedPassword = pass;
  return cachedTransporter;
}

async function deliverViaGmail({ to, subject, html }) {
  const transporter = getTransporter();

  try {
    await transporter.sendMail({
      from: emailFrom.value(),
      to: to.trim(),
      subject: subject.trim(),
      html: html.trim(),
    });
    return { success: true };
  } catch (err) {
    console.error("Gmail send error", err);
    const message =
      err && typeof err.message === "string" ? err.message : String(err);

    // Gmail returns 535-5.7.8 when the app password is wrong; surface a
    // helpful error so the caller can fix it.
    if (/Invalid login|Username and Password not accepted|535/i.test(message)) {
      throw new HttpsError(
        "failed-precondition",
        "Gmail rejected the App Password. Recreate it at " +
          "myaccount.google.com/apppasswords and redeploy.",
      );
    }

    throw new HttpsError(
      "internal",
      `Gmail could not deliver the email: ${message.slice(0, 200)}`,
    );
  }
}

exports.sendAuthEmail = onCall(
  {
    region: "us-central1",
    cors: true,
  },
  async (request) => {
    const { to, subject, html } = request.data || {};
    const callerUid = request.auth?.uid || "anonymous";

    if (typeof to !== "string" || !emailPattern.test(to.trim())) {
      console.warn(`sendAuthEmail: invalid recipient "${to}" (uid=${callerUid})`);
      throw new HttpsError("invalid-argument", "Invalid recipient email.");
    }
    if (typeof subject !== "string" || subject.trim().length === 0) {
      throw new HttpsError("invalid-argument", "Subject is required.");
    }
    if (typeof html !== "string" || html.trim().length === 0) {
      throw new HttpsError("invalid-argument", "Email body is required.");
    }

    console.log(
      `sendAuthEmail: to="${to.trim()}" subject="${subject.trim()}" ` +
        `htmlLen=${html.length} uid=${callerUid}`,
    );
    const result = await deliverViaGmail({ to, subject, html });
    console.log(`sendAuthEmail: sent OK to "${to.trim()}"`);
    return result;
  },
);

exports.sendPasswordResetEmail = onCall(
  {
    region: "us-central1",
    cors: true,
  },
  async (request) => {
    const rawEmail =
      typeof request.data?.email === "string"
        ? request.data.email.trim()
        : "";
    // Lowercase for the lookup. Firebase Auth normalizes emails to lowercase,
    // and Google sign-up can hand the client a mixed-case address, so we
    // defensively normalize here too.
    const email = rawEmail.toLowerCase();

    if (!emailPattern.test(email)) {
      console.warn(`sendPasswordResetEmail: invalid email "${rawEmail}"`);
      throw new HttpsError("invalid-argument", "Invalid email address.");
    }

    console.log(`sendPasswordResetEmail: looking up "${email}"`);

    // Verify the account exists. Note: we intentionally do NOT block Google-
    // only accounts here. Firebase Auth's generatePasswordResetLink works for
    // any user with an email — for a Google-only account, completing the link
    // adds a password to it, which is a valid recovery path.
    try {
      await admin.auth().getUserByEmail(email);
    } catch (err) {
      if (err.code === "auth/user-not-found") {
        console.warn(`sendPasswordResetEmail: no user for "${email}"`);
        throw new HttpsError(
          "not-found",
          "No Booqly account found for this email.",
        );
      }
      console.error("getUserByEmail", err);
      throw new HttpsError("internal", "Could not look up account.");
    }

    let resetLink;
    try {
      resetLink = await admin.auth().generatePasswordResetLink(email);
    } catch (err) {
      console.error("generatePasswordResetLink", err);
      // Be specific about the no-account case so the client can fall back to
      // Firebase's native reset email instead of bubbling a hard error.
      if (err && err.code === "auth/user-not-found") {
        throw new HttpsError(
          "not-found",
          "No Booqly account found for this email.",
        );
      }
      throw new HttpsError(
        "internal",
        "Could not create a password reset link.",
      );
    }

    const safeHref = resetLink.replace(/"/g, "&quot;");
    const html = `<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="utf-8"/>
  <meta name="viewport" content="width=device-width,initial-scale=1"/>
  <title>Reset your password — Booqly</title>
</head>
<body style="margin:0;padding:0;background:#F4F1EC;font-family:'Helvetica Neue',Arial,sans-serif;color:#1A1713;">
  <div style="display:none;max-height:0;overflow:hidden;font-size:1px;color:#F4F1EC;">Reset your Booqly password — this link expires in 1 hour.</div>
  <table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0" style="background:#F4F1EC;">
    <tr><td align="center" style="padding:40px 16px 48px;">
      <table role="presentation" width="520" cellpadding="0" cellspacing="0" border="0"
             style="max-width:520px;width:100%;background:#FFFFFF;border-radius:20px;overflow:hidden;box-shadow:0 4px 24px rgba(0,0,0,0.08);">
        <!-- header -->
        <tr>
          <td style="background:#1A1713;padding:36px 40px;">
            <p style="margin:0;font-size:11px;letter-spacing:3px;text-transform:uppercase;color:#D4A96A;font-weight:600;">Booqly</p>
            <h1 style="margin:10px 0 0;font-size:26px;font-weight:700;color:#F5F0E8;line-height:1.2;font-family:Georgia,serif;">
              Password reset request
            </h1>
          </td>
        </tr>
        <!-- body -->
        <tr>
          <td style="padding:36px 40px 0;">
            <p style="margin:0;font-size:16px;line-height:1.75;color:#3D3830;">
              Hi there,<br/><br/>
              We received a request to reset the password for your Booqly account. Click the button below to choose a new one.
            </p>
          </td>
        </tr>
        <!-- CTA -->
        <tr>
          <td style="padding:32px 40px 0;text-align:center;">
            <a href="${safeHref}"
               style="display:inline-block;background:#D4A96A;color:#1A1713;font-size:15px;font-weight:700;padding:16px 40px;border-radius:12px;text-decoration:none;letter-spacing:0.3px;">
              Reset my password
            </a>
          </td>
        </tr>
        <!-- fallback link -->
        <tr>
          <td style="padding:24px 40px 0;">
            <p style="margin:0;font-size:13px;color:#9A9390;line-height:1.6;">
              Button not working? Copy and paste this link into your browser:
            </p>
            <p style="margin:8px 0 0;font-size:12px;color:#B89860;word-break:break-all;line-height:1.5;">
              ${escapeHtml(resetLink)}
            </p>
          </td>
        </tr>
        <!-- notice -->
        <tr>
          <td style="padding:24px 40px 0;">
            <table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0"
                   style="background:#FBF8F3;border:1px solid #EDE8DF;border-radius:12px;">
              <tr>
                <td style="padding:16px 20px;">
                  <p style="margin:0;font-size:13px;color:#7A7570;line-height:1.6;">
                    ⏱ &nbsp;This link expires in <strong style="color:#3D3830;">1 hour</strong>.<br/>
                    🔒 &nbsp;If you didn't request this, you can safely ignore this email — your password won't change.
                  </p>
                </td>
              </tr>
            </table>
          </td>
        </tr>
        <!-- divider -->
        <tr><td style="padding:28px 40px 0;"><div style="height:1px;background:#EDE8DF;">&nbsp;</div></td></tr>
        <!-- footer -->
        <tr>
          <td style="padding:24px 40px 36px;">
            <p style="margin:0;font-size:13px;color:#7A7570;line-height:1.6;">
              Stay well,<br/>
              <span style="color:#B89860;font-style:italic;font-family:Georgia,serif;font-weight:600;">— The Booqly Team</span>
            </p>
          </td>
        </tr>
      </table>
    </td></tr>
  </table>
</body>
</html>`;

    await deliverViaGmail({
      to: email,
      subject: "Reset your Booqly password",
      html,
    });

    return { success: true };
  },
);

// ─── Email verification ───────────────────────────────────────────────────────

exports.sendVerificationEmail = onCall(
  { region: "us-central1", cors: true },
  async (request) => {
    const uid = request.auth?.uid;
    if (!uid) throw new HttpsError("unauthenticated", "Must be signed in.");

    let userRecord;
    try {
      userRecord = await admin.auth().getUser(uid);
    } catch (err) {
      throw new HttpsError("not-found", "User not found.");
    }

    if (userRecord.emailVerified) {
      return { success: true, alreadyVerified: true };
    }

    const email = userRecord.email;
    if (!email) throw new HttpsError("failed-precondition", "No email on account.");

    let verifyLink;
    try {
      verifyLink = await admin.auth().generateEmailVerificationLink(email);
    } catch (err) {
      console.error("generateEmailVerificationLink", err);
      throw new HttpsError("internal", "Could not generate verification link.");
    }

    const firstName = (userRecord.displayName || "Reader").split(" ")[0];
    const safeFirst = escapeHtml(firstName);
    const safeHref = verifyLink.replace(/"/g, "&quot;");
    const safeLink = escapeHtml(verifyLink);

    const html = `<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="utf-8"/>
  <meta name="viewport" content="width=device-width,initial-scale=1"/>
  <title>Verify your email — Booqly</title>
</head>
<body style="margin:0;padding:0;background:#F4F1EC;font-family:'Helvetica Neue',Arial,sans-serif;color:#1A1713;">
  <div style="display:none;max-height:0;overflow:hidden;font-size:1px;color:#F4F1EC;">One tap to verify your Booqly account and start reading.</div>
  <table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0" style="background:#F4F1EC;">
    <tr><td align="center" style="padding:40px 16px 48px;">
      <table role="presentation" width="520" cellpadding="0" cellspacing="0" border="0"
             style="max-width:520px;width:100%;background:#FFFFFF;border-radius:20px;overflow:hidden;box-shadow:0 4px 24px rgba(0,0,0,0.08);">
        <!-- header -->
        <tr>
          <td style="background:#1A1713;padding:36px 40px;">
            <p style="margin:0;font-size:11px;letter-spacing:3px;text-transform:uppercase;color:#D4A96A;font-weight:600;">Booqly</p>
            <h1 style="margin:10px 0 0;font-size:26px;font-weight:700;color:#F5F0E8;line-height:1.2;font-family:Georgia,serif;">
              Welcome, ${safeFirst}! 🎉<br/>Verify your email to begin.
            </h1>
          </td>
        </tr>
        <!-- body -->
        <tr>
          <td style="padding:36px 40px 0;">
            <p style="margin:0;font-size:16px;line-height:1.75;color:#3D3830;">
              Thanks for joining Booqly — your personal reading companion.<br/><br/>
              Just one step left: confirm your email address so we can keep your account safe and send you reading nudges at the right time.
            </p>
          </td>
        </tr>
        <!-- CTA -->
        <tr>
          <td style="padding:32px 40px 0;text-align:center;">
            <a href="${safeHref}"
               style="display:inline-block;background:#D4A96A;color:#1A1713;font-size:15px;font-weight:700;padding:16px 44px;border-radius:12px;text-decoration:none;letter-spacing:0.3px;">
              Verify my email
            </a>
          </td>
        </tr>
        <!-- fallback -->
        <tr>
          <td style="padding:24px 40px 0;">
            <p style="margin:0;font-size:13px;color:#9A9390;line-height:1.6;">
              Button not working? Copy and paste this link into your browser:
            </p>
            <p style="margin:8px 0 0;font-size:12px;color:#B89860;word-break:break-all;line-height:1.5;">${safeLink}</p>
          </td>
        </tr>
        <!-- notice -->
        <tr>
          <td style="padding:24px 40px 0;">
            <table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0"
                   style="background:#FBF8F3;border:1px solid #EDE8DF;border-radius:12px;">
              <tr>
                <td style="padding:16px 20px;">
                  <p style="margin:0;font-size:13px;color:#7A7570;line-height:1.6;">
                    🔒 &nbsp;If you didn't create a Booqly account, you can safely ignore this email.
                  </p>
                </td>
              </tr>
            </table>
          </td>
        </tr>
        <!-- divider -->
        <tr><td style="padding:28px 40px 0;"><div style="height:1px;background:#EDE8DF;">&nbsp;</div></td></tr>
        <!-- footer -->
        <tr>
          <td style="padding:24px 40px 36px;">
            <p style="margin:0;font-size:13px;color:#7A7570;line-height:1.6;">
              Happy reading,<br/>
              <span style="color:#B89860;font-style:italic;font-family:Georgia,serif;font-weight:600;">— The Booqly Team</span>
            </p>
          </td>
        </tr>
      </table>
    </td></tr>
  </table>
</body>
</html>`;

    await deliverViaGmail({
      to: email,
      subject: `${safeFirst}, verify your Booqly account`,
      html,
    });

    console.log(`sendVerificationEmail: sent to "${email}" uid=${uid}`);
    return { success: true };
  },
);

// ─── Nudge content ────────────────────────────────────────────────────────────

const NUDGE_MESSAGES = [
  "Your calendar just cleared — your book has been patiently waiting.",
  "No meetings, no pings, no obligations. Just you and a good read right now.",
  "This gap in your day is a gift. Spend it with your book, not your feed.",
  "You have free time. Open Booqly before the notifications pull you back.",
  "A quiet pocket in your day — the best chapters get read exactly like this.",
  "Instead of scrolling, how about a chapter? Your future self will be grateful.",
  "Your calendar opened up. A few pages before it fills back in?",
  "Trade the feed for your book. You always feel better after reading.",
  "Free time detected. Your reading streak is waiting to grow.",
  "Right now there's nothing you have to do. That's rare — use it wisely.",
  "The scroll can wait. Your book cannot (it's been 23 hours).",
  "A calm moment, just for you. The story is right where you left it.",
];

const NUDGE_TITLES_BY_MINUTES = {
  30: "30 minutes free — time for a chapter 📖",
  45: "45 quiet minutes ahead 📖",
  60: "An hour to yourself — open a book 📖",
};

function nudgeTitle(minutes) {
  if (minutes >= 90) return `${Math.round(minutes / 60 * 2) / 2}h free — your book is waiting 📖`;
  if (minutes >= 60) return "An hour to yourself — open a book 📖";
  if (minutes >= 45) return "45 quiet minutes ahead 📖";
  return `${minutes} minutes free — time for a chapter 📖`;
}

const DAY_START_HOUR = 8;
const DAY_END_HOUR = 24;
const MIN_SLOT_MINUTES = 30;   // minimum free slot: 30 minutes
const MAX_SLOT_MINUTES = 1440; // maximum free slot: 24 hours

function dayKeyInTimeZone(date, timeZone) {
  return new Intl.DateTimeFormat("en-CA", {
    timeZone,
    year: "numeric",
    month: "2-digit",
    day: "2-digit",
  }).format(date);
}

function hourInTimeZone(date, timeZone) {
  const parts = new Intl.DateTimeFormat("en-US", {
    timeZone,
    hour: "numeric",
    hour12: false,
  }).formatToParts(date);
  const hourPart = parts.find((part) => part.type === "hour");
  return Number(hourPart?.value ?? "0");
}

function formatTimeLabel(date, timeZone) {
  return new Intl.DateTimeFormat("en-US", {
    timeZone,
    hour: "numeric",
    minute: "2-digit",
    hour12: true,
  }).format(date);
}

function buildNudgeEmailHtml({ firstName, message, timeLabel, slotMinutes }) {
  const greeting = firstName && firstName.trim() ? escapeHtml(firstName.trim()) : "Reader";
  const slotLabel =
    slotMinutes >= 60
      ? `${(slotMinutes / 60).toFixed(slotMinutes % 60 === 0 ? 0 : 1)} hr`
      : `${slotMinutes} min`;
  const safeMessage = escapeHtml(message);
  const safeTime = escapeHtml(timeLabel);

  return `<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="utf-8"/>
  <meta name="viewport" content="width=device-width,initial-scale=1"/>
  <title>Time to read — Booqly</title>
</head>
<body style="margin:0;padding:0;background:#F4F1EC;font-family:'Helvetica Neue',Arial,sans-serif;color:#1A1713;">
  <!-- preview -->
  <div style="display:none;max-height:0;overflow:hidden;font-size:1px;color:#F4F1EC;">You have ${slotLabel} free — ${safeTime}. Time to pick up where you left off.</div>

  <table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0" style="background:#F4F1EC;">
    <tr><td align="center" style="padding:40px 16px 48px;">

      <table role="presentation" width="560" cellpadding="0" cellspacing="0" border="0"
             style="max-width:560px;width:100%;background:#FFFFFF;border-radius:20px;overflow:hidden;box-shadow:0 4px 24px rgba(0,0,0,0.08);">

        <!-- ── HEADER BAND ── -->
        <tr>
          <td style="background:#1A1713;padding:36px 40px 32px;">
            <table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0">
              <tr>
                <td>
                  <p style="margin:0;font-size:11px;letter-spacing:3px;text-transform:uppercase;color:#D4A96A;font-weight:600;">Booqly</p>
                  <h1 style="margin:10px 0 0;font-size:28px;font-weight:700;color:#F5F0E8;line-height:1.2;font-family:Georgia,serif;">
                    Your reading window<br/>is open, ${greeting}.
                  </h1>
                </td>
                <td width="56" style="vertical-align:top;padding-left:16px;">
                  <div style="width:56px;height:56px;background:#2C200F;border-radius:14px;font-size:28px;line-height:56px;text-align:center;">&#128214;</div>
                </td>
              </tr>
            </table>
          </td>
        </tr>

        <!-- ── TIME SLOT CARD ── -->
        <tr>
          <td style="padding:32px 40px 0;">
            <table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0"
                   style="background:#FBF8F3;border:1px solid #EDE8DF;border-radius:14px;">
              <tr>
                <td style="padding:20px 24px;">
                  <p style="margin:0;font-size:10px;letter-spacing:2.5px;text-transform:uppercase;color:#B89860;font-weight:700;">Free Block</p>
                  <p style="margin:8px 0 0;font-size:26px;font-weight:700;color:#1A1713;line-height:1.1;font-family:Georgia,serif;">
                    ${safeTime}
                  </p>
                  <p style="margin:6px 0 0;font-size:14px;color:#7A7570;font-weight:500;">${slotLabel} available</p>
                </td>
                <td width="80" style="padding:0 24px 0 0;text-align:right;vertical-align:middle;">
                  <div style="display:inline-block;background:#D4A96A;border-radius:50%;width:48px;height:48px;line-height:48px;text-align:center;font-size:22px;">&#9201;</div>
                </td>
              </tr>
            </table>
          </td>
        </tr>

        <!-- ── MESSAGE ── -->
        <tr>
          <td style="padding:28px 40px 0;">
            <p style="margin:0;font-size:16px;line-height:1.75;color:#3D3830;">
              ${safeMessage}
            </p>
          </td>
        </tr>

        <!-- ── QUOTE ── -->
        <tr>
          <td style="padding:28px 40px 0;">
            <table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0">
              <tr>
                <td style="border-left:3px solid #D4A96A;padding:4px 0 4px 20px;">
                  <p style="margin:0;font-size:14px;font-style:italic;color:#8A8078;line-height:1.7;font-family:Georgia,serif;">
                    &ldquo;A reader lives a thousand lives before he dies. The man who never reads lives only one.&rdquo;
                  </p>
                  <p style="margin:8px 0 0;font-size:12px;color:#B0A89E;font-weight:600;letter-spacing:0.5px;">— George R.R. Martin</p>
                </td>
              </tr>
            </table>
          </td>
        </tr>

        <!-- ── DIVIDER ── -->
        <tr>
          <td style="padding:32px 40px 0;">
            <div style="height:1px;background:#EDE8DF;">&nbsp;</div>
          </td>
        </tr>

        <!-- ── FOOTER ── -->
        <tr>
          <td style="padding:24px 40px 36px;">
            <table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0">
              <tr>
                <td>
                  <p style="margin:0;font-size:13px;color:#7A7570;line-height:1.6;">
                    Happy reading,<br/>
                    <span style="color:#B89860;font-style:italic;font-family:Georgia,serif;font-weight:600;">— The Booqly Team</span>
                  </p>
                </td>
                <td align="right" style="vertical-align:bottom;">
                  <p style="margin:0;font-size:22px;">📚</p>
                </td>
              </tr>
            </table>
            <p style="margin:20px 0 0;font-size:11px;color:#C0B8B0;line-height:1.6;">
              You're receiving this because free-time nudges are enabled in Booqly.<br/>
              To turn them off: <span style="color:#B89860;">Profile → Settings → Free-time nudges</span>.
            </p>
          </td>
        </tr>

      </table>
    </td></tr>
  </table>
</body>
</html>`;
}

function findActiveSlot(nowMs, slots) {
  for (const slot of slots) {
    const startMs = Date.parse(slot.start);
    const endMs = Date.parse(slot.end);
    if (Number.isNaN(startMs) || Number.isNaN(endMs)) continue;
    if (nowMs < startMs || nowMs >= endMs) continue;

    const totalMinutes = Math.round((endMs - startMs) / 60000);
    const remainingMinutes = Math.round((endMs - nowMs) / 60000);

    // Only qualify slots between 30 min and 24 hours total duration
    if (totalMinutes < MIN_SLOT_MINUTES) continue;
    if (totalMinutes > MAX_SLOT_MINUTES) continue;
    if (remainingMinutes < MIN_SLOT_MINUTES) continue;

    return {
      startMs,
      endMs,
      startIso: slot.start,
      durationMinutes: totalMinutes,
      remainingMinutes,
    };
  }
  return null;
}

async function sendNudgePush({ token, title, body }) {
  try {
    await admin.messaging().send({
      token,
      notification: { title, body },
      android: {
        priority: "high",
        notification: {
          channelId: "booqly_reading_motivation",
        },
      },
      apns: {
        payload: {
          aps: {
            sound: "default",
          },
        },
      },
    });
    return true;
  } catch (err) {
    const code = err && err.code ? String(err.code) : "";
    if (
      code.includes("registration-token-not-registered") ||
      code.includes("invalid-registration-token")
    ) {
      return "invalid-token";
    }
    console.warn(`sendNudgePush failed for token ${token.slice(0, 8)}…`, err);
    return false;
  }
}

exports.sendReadingNudges = onSchedule(
  {
    schedule: "every 15 minutes",
    region: "us-central1",
    timeZone: "UTC",
  },
  async () => {
    const db = admin.firestore();
    const now = new Date();
    const nowMs = now.getTime();

    const snapshot = await db
      .collection("users")
      .where("motivationRemindersEnabled", "==", true)
      .get();

    if (snapshot.empty) {
      console.log("sendReadingNudges: no users with reminders enabled");
      return;
    }

    let sent = 0;
    let skipped = 0;

    for (const doc of snapshot.docs) {
      const data = doc.data() || {};
      const timeZone =
        typeof data.timezone === "string" && data.timezone.trim()
          ? data.timezone.trim()
          : "UTC";

      const hour = hourInTimeZone(now, timeZone);
      if (hour < DAY_START_HOUR || hour >= DAY_END_HOUR) {
        skipped++;
        continue;
      }

      const todayKey = dayKeyInTimeZone(now, timeZone);
      if (data.freeSlotsDate !== todayKey) {
        skipped++;
        continue;
      }

      const slots = Array.isArray(data.freeSlotsToday) ? data.freeSlotsToday : [];
      const activeSlot = findActiveSlot(nowMs, slots);
      if (!activeSlot) {
        skipped++;
        continue;
      }

      // Send only ONCE per slot — skip if this slot's start was already nudged
      const lastNudgedSlotStart =
        typeof data.lastNudgedSlotStart === "string"
          ? data.lastNudgedSlotStart
          : "";
      if (lastNudgedSlotStart === activeSlot.startIso) {
        skipped++;
        continue;
      }

      const message =
        NUDGE_MESSAGES[Math.floor(Math.random() * NUDGE_MESSAGES.length)];
      const title = nudgeTitle(activeSlot.remainingMinutes);
      const timeLabel = formatTimeLabel(new Date(activeSlot.startMs), timeZone);
      const email =
        typeof data.email === "string" ? data.email.trim().toLowerCase() : "";
      const firstName =
        typeof data.firstName === "string" ? data.firstName : "";
      const fcmToken =
        typeof data.fcmToken === "string" ? data.fcmToken.trim() : "";

      // Mark this slot as notified immediately to prevent duplicates
      const updates = {
        lastNudgedSlotStart: activeSlot.startIso,
        lastNudgeAt: admin.firestore.FieldValue.serverTimestamp(),
      };

      if (fcmToken) {
        const pushResult = await sendNudgePush({
          token: fcmToken,
          title,
          body: message,
        });
        if (pushResult === "invalid-token") {
          updates.fcmToken = admin.firestore.FieldValue.delete();
        }
      }

      if (email && emailPattern.test(email)) {
        const emailSubject =
          activeSlot.remainingMinutes >= 60
            ? `An hour to yourself, ${firstName || "Reader"} — open a book 📖`
            : `${activeSlot.remainingMinutes} minutes free — your book is waiting 📖`;
        try {
          await deliverViaGmail({
            to: email,
            subject: emailSubject,
            html: buildNudgeEmailHtml({
              firstName,
              message,
              timeLabel,
              slotMinutes: activeSlot.remainingMinutes,
            }),
          });
        } catch (err) {
          console.warn(`sendReadingNudges: email failed for ${doc.id}`, err);
        }
      }

      await doc.ref.set(updates, { merge: true });
      sent++;
    }

    console.log(
      `sendReadingNudges: processed=${snapshot.size} sent=${sent} skipped=${skipped}`,
    );
  },
);

// ── notifyNewFollower ──────────────────────────────────────────────────────────
// Called from the Flutter app whenever a user follows someone.
// Sends a push notification to the followed user's FCM token.
exports.notifyNewFollower = onCall(
  { region: "us-central1" },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "You must be signed in.");
    }

    const followedUid = request.data?.followedUid;
    if (!followedUid || typeof followedUid !== "string") {
      throw new HttpsError("invalid-argument", "followedUid is required.");
    }

    const followerUid = request.auth.uid;
    if (followerUid === followedUid) return { sent: false };

    const db = admin.firestore();

    const [followerSnap, followedSnap] = await Promise.all([
      db.collection("users").doc(followerUid).get(),
      db.collection("users").doc(followedUid).get(),
    ]);

    if (!followerSnap.exists || !followedSnap.exists) {
      return { sent: false, reason: "user_not_found" };
    }

    const followerData = followerSnap.data();
    const firstName = (followerData.firstName || "").trim();
    const lastName  = (followerData.lastName  || "").trim();
    const followerName = [firstName, lastName].filter(Boolean).join(" ") || "Someone";

    const fcmToken = followedSnap.data()?.fcmToken;
    if (!fcmToken) return { sent: false, reason: "no_fcm_token" };

    try {
      await admin.messaging().send({
        token: fcmToken,
        notification: {
          title: "New follower on Booqly 📚",
          body: `${followerName} started following you!`,
        },
        android: {
          notification: {
            icon: "ic_launcher",
            color: "#D4A96A",
            channelId: "booqly_reading_motivation",
          },
        },
        data: {
          type: "new_follower",
          followerUid,
          followerName,
        },
      });
      console.log(`notifyNewFollower: sent to ${followedUid} from ${followerUid}`);
      return { sent: true };
    } catch (err) {
      // Token stale — clean it up so we don't keep trying
      if (
        err.code === "messaging/registration-token-not-registered" ||
        err.code === "messaging/invalid-registration-token"
      ) {
        await db
          .collection("users")
          .doc(followedUid)
          .update({ fcmToken: admin.firestore.FieldValue.delete() });
      }
      console.warn(`notifyNewFollower: FCM send failed: ${err.message}`);
      return { sent: false, error: err.message };
    }
  },
);
