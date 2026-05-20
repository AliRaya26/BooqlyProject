const { onCall, HttpsError } = require("firebase-functions/v2/https");
const { defineString } = require("firebase-functions/params");

const resendApiKey = defineString("RESEND_API_KEY");
const emailFrom = defineString("EMAIL_FROM", {
  default: "Booqly <noreply@yourdomain.com>",
});

const emailPattern =
  /^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$/;

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
  },
);
