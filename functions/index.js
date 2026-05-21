const { onCall, HttpsError } = require("firebase-functions/v2/https");
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

    if (typeof to !== "string" || !emailPattern.test(to.trim())) {
      throw new HttpsError("invalid-argument", "Invalid recipient email.");
    }
    if (typeof subject !== "string" || subject.trim().length === 0) {
      throw new HttpsError("invalid-argument", "Subject is required.");
    }
    if (typeof html !== "string" || html.trim().length === 0) {
      throw new HttpsError("invalid-argument", "Email body is required.");
    }

    return deliverViaGmail({ to, subject, html });
  },
);

exports.sendPasswordResetEmail = onCall(
  {
    region: "us-central1",
    cors: true,
  },
  async (request) => {
    const email =
      typeof request.data?.email === "string"
        ? request.data.email.trim()
        : "";

    if (!emailPattern.test(email)) {
      throw new HttpsError("invalid-argument", "Invalid email address.");
    }

    let user;
    try {
      user = await admin.auth().getUserByEmail(email);
    } catch (err) {
      if (err.code === "auth/user-not-found") {
        throw new HttpsError(
          "not-found",
          "No Booqly account found for this email.",
        );
      }
      console.error("getUserByEmail", err);
      throw new HttpsError("internal", "Could not look up account.");
    }

    const hasPassword = user.providerData.some(
      (provider) => provider.providerId === "password",
    );
    if (!hasPassword) {
      throw new HttpsError(
        "failed-precondition",
        "This account uses Google sign-in. Log in with Continue with Google.",
      );
    }

    let resetLink;
    try {
      resetLink = await admin.auth().generatePasswordResetLink(email);
    } catch (err) {
      console.error("generatePasswordResetLink", err);
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
