const { onCall, HttpsError } = require("firebase-functions/v2/https");
const { defineString } = require("firebase-functions/params");
const admin = require("firebase-admin");

if (!admin.apps.length) {
  admin.initializeApp();
}

const resendApiKey = defineString("RESEND_API_KEY");
const emailFrom = defineString("EMAIL_FROM", {
  default: "Booqly <noreply@yourdomain.com>",
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

async function deliverViaResend({ to, subject, html }) {
  const apiKey = resendApiKey.value();
  if (!apiKey) {
    throw new HttpsError(
      "failed-precondition",
      "RESEND_API_KEY is not set on Firebase Functions.",
    );
  }

  const response = await fetch("https://api.resend.com/emails", {
    method: "POST",
    headers: {
      Authorization: `Bearer ${apiKey}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      from: emailFrom.value(),
      to: [to.trim()],
      subject: subject.trim(),
      html: html.trim(),
    }),
  });

  if (!response.ok) {
    const body = await response.text();
    console.error("Resend error", response.status, body);
    let detail = `Resend returned ${response.status}.`;
    try {
      const parsed = JSON.parse(body);
      if (parsed?.message) detail = parsed.message;
    } catch (_) {
      if (body) detail = body.slice(0, 200);
    }
    throw new HttpsError("failed-precondition", detail);
  }

  return { success: true };
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

    return deliverViaResend({ to, subject, html });
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

    await deliverViaResend({
      to: email,
      subject: "Reset your Booqly password",
      html,
    });

    return { success: true };
  },
);
