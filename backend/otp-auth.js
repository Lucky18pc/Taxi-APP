/**
 * Phase-1 OTP per SMS (Twilio) — optional, parallel zum E-Mail-Login.
 * Native Apps können alternativ Firebase Phone Authentication nutzen (Client-seitig).
 */

const crypto = require("crypto");

const OTP_TTL_MS = 10 * 60 * 1000;
const OTP_LENGTH = 6;
const DEV_OTP_WHEN_UNCONFIGURED = String(process.env.OTP_DEV_CODE || "").trim();

/** @type {Map<string, { codeHash: string, expiresAt: number, attempts: number }>} */
const pendingOtps = new Map();

function normalizePhone(raw) {
  const digits = String(raw || "").replace(/[^\d+]/g, "").trim();
  if (!digits) return "";
  if (digits.startsWith("00")) return `+${digits.slice(2)}`;
  if (digits.startsWith("0") && !digits.startsWith("+")) {
    // DE-Mobil: 0176… → +49176…
    return `+49${digits.slice(1)}`;
  }
  if (!digits.startsWith("+") && digits.length >= 10) {
    return `+${digits}`;
  }
  return digits;
}

function isTwilioConfigured() {
  return Boolean(
    process.env.TWILIO_ACCOUNT_SID &&
      process.env.TWILIO_AUTH_TOKEN &&
      process.env.TWILIO_FROM_NUMBER
  );
}

function otpConfigured() {
  return isTwilioConfigured() || Boolean(DEV_OTP_WHEN_UNCONFIGURED) || !process.env.RENDER;
}

function hashCode(code) {
  return crypto.createHash("sha256").update(String(code)).digest("hex");
}

function generateCode() {
  return String(Math.floor(10 ** (OTP_LENGTH - 1) + Math.random() * 9 * 10 ** (OTP_LENGTH - 1)));
}

async function sendSmsTwilio(to, body) {
  const sid = process.env.TWILIO_ACCOUNT_SID;
  const token = process.env.TWILIO_AUTH_TOKEN;
  const from = process.env.TWILIO_FROM_NUMBER;
  const auth = Buffer.from(`${sid}:${token}`).toString("base64");
  const params = new URLSearchParams({ To: to, From: from, Body: body });
  const res = await fetch(
    `https://api.twilio.com/2010-04-01/Accounts/${sid}/Messages.json`,
    {
      method: "POST",
      headers: {
        Authorization: `Basic ${auth}`,
        "Content-Type": "application/x-www-form-urlencoded",
      },
      body: params.toString(),
    }
  );
  const data = await res.json().catch(() => ({}));
  if (!res.ok) {
    const msg = data.message || data.error_message || `Twilio HTTP ${res.status}`;
    throw new Error(msg);
  }
  return data;
}

/**
 * @param {import("express").Express} app
 */
function mountOtpRoutes(app) {
  app.get("/api/auth/otp/status", (_req, res) => {
    res.json({
      twilioConfigured: isTwilioConfigured(),
      otpEnabled: otpConfigured(),
      firebasePhoneAuthHint:
        "Native iOS: Firebase Phone Authentication parallel nutzen (kein Backend nötig).",
      provider: isTwilioConfigured() ? "twilio" : DEV_OTP_WHEN_UNCONFIGURED ? "dev-code" : "local-dev",
    });
  });

  app.post("/api/auth/otp/request", async (req, res) => {
    if (!otpConfigured()) {
      return res.status(503).json({
        error: "SMS-OTP nicht konfiguriert (TWILIO_* oder OTP_DEV_CODE setzen)",
      });
    }

    const phone = normalizePhone(req.body.phone || req.body.msisdn);
    if (!phone || phone.length < 10) {
      return res.status(400).json({ error: "Gültige Handynummer erforderlich (+49…)" });
    }

    const code = isTwilioConfigured()
      ? generateCode()
      : DEV_OTP_WHEN_UNCONFIGURED || generateCode();

    pendingOtps.set(phone, {
      codeHash: hashCode(code),
      expiresAt: Date.now() + OTP_TTL_MS,
      attempts: 0,
    });

    try {
      if (isTwilioConfigured()) {
        await sendSmsTwilio(
          phone,
          `Luckys Taxi Code: ${code} (gültig 10 Min.)`
        );
        return res.json({ ok: true, phone, delivery: "sms" });
      }

      // Lokal / ohne Twilio: Code nur loggen, nie in Prod-Response
      console.log(`[otp-dev] ${phone} → ${code}`);
      const payload = { ok: true, phone, delivery: "dev" };
      if (!process.env.RENDER) {
        payload.devCode = code;
      }
      return res.json(payload);
    } catch (error) {
      pendingOtps.delete(phone);
      console.error("OTP send failed:", error);
      return res.status(502).json({ error: error.message || "SMS fehlgeschlagen" });
    }
  });

  app.post("/api/auth/otp/verify", (req, res) => {
    const phone = normalizePhone(req.body.phone || req.body.msisdn);
    const code = String(req.body.code || req.body.otp || "").trim();
    if (!phone || !code) {
      return res.status(400).json({ error: "phone und code erforderlich" });
    }

    const entry = pendingOtps.get(phone);
    if (!entry) {
      return res.status(401).json({ error: "Kein aktiver Code — erneut anfordern" });
    }
    if (Date.now() > entry.expiresAt) {
      pendingOtps.delete(phone);
      return res.status(401).json({ error: "Code abgelaufen" });
    }
    entry.attempts += 1;
    if (entry.attempts > 5) {
      pendingOtps.delete(phone);
      return res.status(429).json({ error: "Zu viele Versuche" });
    }
    if (entry.codeHash !== hashCode(code)) {
      return res.status(401).json({ error: "Code ungültig" });
    }

    pendingOtps.delete(phone);
    const sessionToken = crypto.randomBytes(24).toString("hex");
    res.json({
      ok: true,
      phone,
      sessionToken,
      verifiedAt: new Date().toISOString(),
      note: "Session-Token für Web-PWA; native Apps bevorzugen Firebase Phone Auth ID-Token.",
    });
  });
}

module.exports = {
  mountOtpRoutes,
  normalizePhone,
  isTwilioConfigured,
  otpConfigured,
};
