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
    const html = `
<!DOCTYPE html>
<html>
<body style="font-family:Georgia,serif;background:#0E0C0A;color:#F5F0E8;padding:32px;">
  <h1 style="color:#D4A96A;">Reset your password</h1>
  <p>You asked to reset your Booqly password.</p>
  <p><a href="${safeHref}" style="display:inline-block;background:#D4A96A;color:#0E0C0A;padding:12px 20px;border-radius:10px;text-decoration:none;font-weight:bold;">Reset password</a></p>
  <p style="color:#888580;font-size:14px;">This link expires in about an hour. If you did not request a reset, you can ignore this email.</p>
  <p style="color:#888580;font-size:12px;word-break:break-all;">Or copy this link:<br>${escapeHtml(resetLink)}</p>
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
      ? `~${(slotMinutes / 60).toFixed(slotMinutes % 60 === 0 ? 0 : 1)} hours`
      : `${slotMinutes} minutes`;
  const safeMessage = escapeHtml(message);
  const safeTime = escapeHtml(timeLabel);

  return `<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="utf-8"/>
  <meta name="viewport" content="width=device-width,initial-scale=1"/>
  <title>Time to read — Booqly</title>
</head>
<body style="margin:0;padding:0;background:#0E0C0A;font-family:Georgia,'Times New Roman',serif;color:#F5F0E8;-webkit-font-smoothing:antialiased;">
  <!-- preview text -->
  <div style="display:none;max-height:0;overflow:hidden;font-size:1px;color:#0E0C0A;">${safeMessage} — ${slotLabel} just opened up in your day.</div>
  <table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0" style="background:#0E0C0A;">
    <tr><td align="center" style="padding:32px 16px;">
      <table role="presentation" width="540" cellpadding="0" cellspacing="0" border="0"
             style="max-width:540px;width:100%;background:#1A1713;border:1px solid #2A2520;border-radius:24px;overflow:hidden;">
        <!-- gold bar -->
        <tr><td bgcolor="#D4A96A" height="5" style="height:5px;line-height:5px;font-size:0;">&nbsp;</td></tr>
        <!-- book emoji -->
        <tr><td align="center" style="padding:40px 32px 0;">
          <table role="presentation" cellpadding="0" cellspacing="0" border="0">
            <tr><td align="center" width="80" height="80" style="width:80px;height:80px;background:#2C200F;border-radius:40px;font-size:40px;line-height:80px;text-align:center;">
              &#128214;
            </td></tr>
          </table>
        </td></tr>
        <!-- headline -->
        <tr><td align="center" style="padding:16px 32px 0;">
          <h1 style="margin:0;font-family:Georgia,serif;font-style:italic;font-size:32px;font-weight:700;color:#D4A96A;letter-spacing:0.3px;line-height:1.15;">
            A quiet moment, ${greeting}
          </h1>
        </td></tr>
        <!-- message -->
        <tr><td style="padding:16px 36px 0;">
          <p style="margin:0;font-size:17px;line-height:1.7;color:#E0D8CC;text-align:center;">
            ${safeMessage}
          </p>
        </td></tr>
        <!-- free-block card -->
        <tr><td style="padding:24px 36px 0;">
          <table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0"
                 style="background:#0E0C0A;border:1px solid #2A2520;border-radius:16px;padding:20px 24px;">
            <tr><td>
              <p style="margin:0;color:#888580;font-size:11px;letter-spacing:2px;text-transform:uppercase;">Your free block</p>
              <p style="margin:8px 0 0;font-family:Georgia,serif;font-size:22px;font-weight:bold;color:#F5F0E8;line-height:1.2;">
                ${safeTime}&nbsp;&nbsp;·&nbsp;&nbsp;${slotLabel}
              </p>
              <p style="margin:10px 0 0;font-size:14px;color:#888580;line-height:1.5;">
                That's enough time for a solid chapter. More than enough to remember why you love reading.
              </p>
            </td></tr>
          </table>
        </td></tr>
        <!-- quote -->
        <tr><td style="padding:24px 36px 0;">
          <table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0">
            <tr><td style="padding:0 0 0 16px;border-left:3px solid #D4A96A;">
              <p style="margin:0;font-family:Georgia,serif;font-style:italic;color:#C8BFB4;font-size:15px;line-height:1.65;">
                &ldquo;Not all those who wander are lost — but readers always know exactly where they are.&rdquo;
              </p>
            </td></tr>
          </table>
        </td></tr>
        <!-- divider -->
        <tr><td style="padding:28px 36px 0;">
          <div style="height:1px;background:#2A2520;">&nbsp;</div>
        </td></tr>
        <!-- footer -->
        <tr><td align="center" style="padding:18px 36px 32px;">
          <p style="margin:0;color:#888580;font-size:13px;line-height:1.7;">
            Happy reading,<br/>
            <span style="color:#D4A96A;font-style:italic;font-family:Georgia,serif;">— The Booqly team</span>
          </p>
          <p style="margin:14px 0 0;color:#4a4844;font-size:11px;line-height:1.5;">
            You're getting this because free-time nudges are on in Booqly.<br/>
            Turn them off anytime: Profile → Settings → Free-time nudges.
          </p>
        </td></tr>
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
