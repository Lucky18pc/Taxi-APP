#!/usr/bin/env node
/**
 * Phase 6 — Stripe Payment Testing (Testkarten)
 *
 *   STRIPE_SECRET_KEY=sk_test_… ADMIN_PIN=testpin \
 *     node scripts/test-phase6-stripe-payments.js
 *
 * Ohne Key: Skip mit dokumentierten Testkarten (Exit 0).
 */

const DEFAULT_BASE = process.env.BASE_URL || "http://127.0.0.1:4242";
const OPERATOR = process.env.OPERATOR_SLUG || "mannheim";
const DRIVER_KEY =
  process.env.DRIVER_API_KEY || "luckys-fahrer-pilot-k7m2p9qx";

function parseArgs(argv) {
  const out = { base: DEFAULT_BASE };
  for (let i = 2; i < argv.length; i += 1) {
    if (argv[i] === "--base") out.base = argv[++i];
  }
  return out;
}

async function api(base, method, path, { body, headers } = {}) {
  const res = await fetch(`${base}${path}`, {
    method,
    headers: {
      "Content-Type": "application/json",
      ...(headers || {}),
    },
    body: body ? JSON.stringify(body) : undefined,
  });
  const json = await res.json().catch(() => ({}));
  if (!res.ok) {
    const err = new Error(json.error || `${method} ${path} → ${res.status}`);
    err.status = res.status;
    err.body = json;
    throw err;
  }
  return json;
}

async function main() {
  const opts = parseArgs(process.argv);
  const secret = String(process.env.STRIPE_SECRET_KEY || "").trim();
  const adminPin = process.env.ADMIN_PIN || "testpin";

  console.log("=== Phase-6 Stripe Payment Testing ===");
  console.log(`Base: ${opts.base}`);

  const config = await api(opts.base, "GET", "/api/stripe/config");
  console.log(
    `  paymentsEnabled=${config.paymentsEnabled} publishableKey=${config.publishableKey ? "set" : "null"}`
  );

  const catalog = {
    success: ["4242424242424242", "pm_card_visa"],
    decline: ["4000000000000002", "pm_card_chargeDeclined"],
    insufficientFunds: [
      "4000000000009995",
      "pm_card_visa_chargeDeclinedInsufficientFunds",
    ],
  };

  if (!secret || !secret.startsWith("sk_")) {
    console.log(
      JSON.stringify(
        {
          skip: true,
          reason: "STRIPE_SECRET_KEY fehlt — Stripe-Testkarten übersprungen",
          expectedCards: catalog,
          config,
        },
        null,
        2
      )
    );
    console.log("OK — Stripe-Test übersprungen (kein sk_test Key).");
    return;
  }

  let Stripe;
  try {
    Stripe = require("/workspace/backend/node_modules/stripe");
  } catch {
    Stripe = require("stripe");
  }
  const stripe = Stripe(secret);

  const booking = await api(opts.base, "POST", "/api/bookings", {
    body: {
      latitude: 49.4797,
      longitude: 8.4699,
      addressLine: "Stripe Test Abholung",
      paymentMethod: "Karte",
      totalAmount: 0,
      autoDispatch: false,
    },
  });
  const bookingId = booking.bookingId;

  const driver = await api(opts.base, "POST", `/api/drivers?operator=${OPERATOR}`, {
    body: {
      name: "Stripe Test Fahrer",
      phone: "+491701112233",
      vehicle: "MA-PAY 1",
      operator: OPERATOR,
    },
    headers: { Authorization: `Bearer ${adminPin}` },
  });

  await api(opts.base, "PATCH", `/api/bookings/${bookingId}/assign?operator=${OPERATOR}`, {
    body: { driverId: driver.driverId },
    headers: { Authorization: `Bearer ${adminPin}` },
  });

  const completed = await api(
    opts.base,
    "PATCH",
    `/api/driver/bookings/${bookingId}/complete?operator=${OPERATOR}`,
    {
      body: { driverUid: driver.driverId, totalAmount: 15.5 },
      headers: {
        "X-Driver-Key": DRIVER_KEY,
        Authorization: `Bearer ${DRIVER_KEY}`,
      },
    }
  );

  const payToken = completed.paymentAccessToken;
  const payUrl = completed.payUrl;

  const cases = [];

  async function runCardCase(label, paymentMethod, expectSuccess) {
    const pi = await stripe.paymentIntents.create({
      amount: 1550,
      currency: "eur",
      automatic_payment_methods: { enabled: true, allow_redirects: "never" },
      metadata: { product: "taxi", phase6: label, bookingId },
    });
    try {
      const confirmed = await stripe.paymentIntents.confirm(pi.id, {
        payment_method: paymentMethod,
      });
      const ok = expectSuccess
        ? confirmed.status === "succeeded"
        : confirmed.status !== "succeeded";
      cases.push({
        label,
        paymentMethod,
        expectSuccess,
        status: confirmed.status,
        ok,
        paymentIntentId: pi.id,
      });
    } catch (error) {
      const declined = Boolean(error.code || error.type);
      cases.push({
        label,
        paymentMethod,
        expectSuccess,
        status: "error",
        ok: expectSuccess ? false : declined,
        error: error.message,
        code: error.code,
        paymentIntentId: pi.id,
      });
    }
  }

  await runCardCase("success_visa", "pm_card_visa", true);
  await runCardCase("decline_generic", "pm_card_chargeDeclined", false);
  await runCardCase(
    "decline_insufficient",
    "pm_card_visa_chargeDeclinedInsufficientFunds",
    false
  );

  let bookingIntent = null;
  if (payToken) {
    try {
      bookingIntent = await api(opts.base, "POST", `/api/pay/${bookingId}/intent`, {
        body: { token: payToken },
      });
      // Erfolgspfad: Intent mit Test-PM bestätigen
      if (bookingIntent.paymentIntentId) {
        try {
          const confirmed = await stripe.paymentIntents.confirm(
            bookingIntent.paymentIntentId,
            { payment_method: "pm_card_visa" }
          );
          bookingIntent.confirmStatus = confirmed.status;
          bookingIntent.confirmOk = confirmed.status === "succeeded";
        } catch (error) {
          bookingIntent.confirmError = error.message;
          bookingIntent.confirmOk = false;
        }
      }
    } catch (error) {
      bookingIntent = { error: error.message };
    }
  }

  const allOk = cases.every((c) => c.ok);
  console.log(
    JSON.stringify(
      {
        ok: allOk,
        expectedCards: catalog,
        config,
        bookingId,
        payUrl: payUrl || null,
        bookingIntent,
        cases,
      },
      null,
      2
    )
  );
  if (!allOk) process.exit(1);
  console.log("OK — Stripe Testkarten (Erfolg + Fehler) validiert.");
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
