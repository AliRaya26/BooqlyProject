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

const NUDGE_MESSAGES = [
  "You have free time — open a book instead of scrolling.",
  "Your calendar just cleared. Perfect moment for a few pages.",
  "Skip the feed. Your current read is waiting.",
  "Free block ahead — trade screen time for story time.",
  "Small reading session now beats endless scrolling later.",
];

const DAY_START_HOUR = 8;
const DAY_END_HOUR = 24;
const NUDGE_INTERVAL_MS = 14 * 60 * 1000;

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

  return `
<!DOCTYPE html>
<html>
<body style="font-family:Georgia,serif;background:#0E0C0A;color:#F5F0E8;padding:32px;margin:0;">
  <div style="max-width:520px;margin:0 auto;">
    <p style="font-size:40px;margin:0 0 8px;">📖</p>
    <h1 style="color:#D4A96A;font-style:italic;margin:0 0 12px;font-weight:600;">A quiet moment, ${greeting}</h1>
    <p style="font-size:17px;line-height:1.6;margin:0 0 16px;">${escapeHtml(message)}</p>
    <div style="background:#1A1713;border:1px solid #2A2520;border-radius:16px;padding:18px 22px;margin:24px 0;">
      <p style="margin:0;color:#888580;font-size:13px;text-transform:uppercase;letter-spacing:1.5px;">Free block</p>
      <p style="margin:6px 0 0;font-size:20px;font-weight:bold;color:#F5F0E8;">${escapeHtml(timeLabel)} · ${slotLabel}</p>
    </div>
    <p style="font-size:15px;line-height:1.6;color:#888580;margin:24px 0 0;">A few pages now beats endlessly scrolling later. Booqly is right where you left off.</p>
    <p style="color:#5a5853;margin-top:32px;font-size:12px;">You're getting this because Free-time nudges are enabled in Booqly settings. Turn them off any time from Settings → Free-time nudges.</p>
  </div>
</body>
</html>`;
}

function findActiveSlot(nowMs, slots) {
  for (const slot of slots) {
    const startMs = Date.parse(slot.start);
    const endMs = Date.parse(slot.end);
    if (Number.isNaN(startMs) || Number.isNaN(endMs)) continue;
    if (nowMs >= startMs && nowMs < endMs) {
      return {
        startMs,
        endMs,
        durationMinutes: Math.max(1, Math.round((endMs - startMs) / 60000)),
      };
    }
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

      const lastNudgeAt = data.lastNudgeAt?.toDate?.();
      if (lastNudgeAt && nowMs - lastNudgeAt.getTime() < NUDGE_INTERVAL_MS) {
        skipped++;
        continue;
      }

      const message =
        NUDGE_MESSAGES[Math.floor(Math.random() * NUDGE_MESSAGES.length)];
      const title =
        activeSlot.durationMinutes >= 60
          ? `About ${activeSlot.durationMinutes} minutes free`
          : `${activeSlot.durationMinutes} min of free time`;
      const timeLabel = formatTimeLabel(new Date(activeSlot.startMs), timeZone);
      const email =
        typeof data.email === "string" ? data.email.trim().toLowerCase() : "";
      const firstName =
        typeof data.firstName === "string" ? data.firstName : "";
      const fcmToken =
        typeof data.fcmToken === "string" ? data.fcmToken.trim() : "";

      const updates = {
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
        try {
          await deliverViaGmail({
            to: email,
            subject: `${activeSlot.durationMinutes} min of free time — open a book instead`,
            html: buildNudgeEmailHtml({
              firstName,
              message,
              timeLabel,
              slotMinutes: activeSlot.durationMinutes,
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
