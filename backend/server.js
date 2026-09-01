require("dotenv").config();

const express = require("express");
const cors = require("cors");
const crypto = require("crypto");
const path = require("path");
const fs = require("fs");
const { createFleetOperatorsStore } = require("./fleet-operators");
const { mountPwaBrandRoutes } = require("./pwa-brand");

const port = process.env.PORT || 4242;
const secretKey = process.env.STRIPE_SECRET_KEY;
const webhookSecret = String(process.env.STRIPE_WEBHOOK_SECRET || "").trim();
const publicBaseUrl = String(process.env.PUBLIC_BASE_URL || "").trim().replace(/\/$/, "");
const resendApiKey = String(process.env.RESEND_API_KEY || "").trim();
const contactNotifyEmail = String(process.env.CONTACT_NOTIFY_EMAIL || "luckypc81@gmail.com").trim();
const gaMeasurementId = String(process.env.GA_MEASUREMENT_ID || "").trim();

const billingPriceIds = {
  starter: String(process.env.STRIPE_PRICE_STARTER || "").trim(),
  business: String(process.env.STRIPE_PRICE_BUSINESS || "").trim(),
};

function isBillingConfigured() {
  return Boolean(stripe && billingPriceIds.starter && billingPriceIds.business);
}

let stripe = null;
if (secretKey) {
  stripe = require("stripe")(secretKey);
} else {
  console.warn("Hinweis: STRIPE_SECRET_KEY fehlt — Buchungen/Web ok, Kartenzahlung deaktiviert.");
}

const app = express();
const offering = JSON.parse(
  fs.readFileSync(path.join(__dirname, "offering.json"), "utf8")
);

function resolveDataDir() {
  const preferred = process.env.DATA_DIR || path.join(__dirname, "data");
  try {
    fs.mkdirSync(preferred, { recursive: true });
    fs.accessSync(preferred, fs.constants.W_OK);
    return preferred;
  } catch (error) {
    const fallback = path.join(__dirname, "data");
    console.warn(
      `DATA_DIR "${preferred}" nicht nutzbar (${error.code}) — Fallback: ${fallback}`
    );
    fs.mkdirSync(fallback, { recursive: true });
    return fallback;
  }
}

const dataDir = resolveDataDir();
const adminPin = String(process.env.ADMIN_PIN || "").trim();

function seedDataFile(filename) {
  const target = path.join(dataDir, filename);
  const seed = path.join(__dirname, filename);
  if (!fs.existsSync(target) && fs.existsSync(seed)) {
    fs.copyFileSync(seed, target);
  }
  return target;
}

const tenantConfigPath = seedDataFile("tenant-config.json");
const driversConfigPath = seedDataFile("drivers.json");
const bookingsFilePath = path.join(dataDir, "bookings.json");
const callsFilePath = path.join(dataDir, "calls.json");
const operatorsFilePath = path.join(dataDir, "operators.json");
const inquiriesFilePath = path.join(dataDir, "inquiries.json");

const tenantConfig = JSON.parse(fs.readFileSync(tenantConfigPath, "utf8"));
const driversSeed = JSON.parse(fs.readFileSync(driversConfigPath, "utf8"));

const fleet = createFleetOperatorsStore({
  dataDir,
  seedFilePath: path.join(__dirname, "fleet-operators.json"),
});

function isValidTimeZone(timeZone) {
  try {
    Intl.DateTimeFormat(undefined, { timeZone });
    return true;
  } catch {
    return false;
  }
}

function ensureTenantDefaults() {
  let changed = false;
  if (!tenantConfig.country) {
    tenantConfig.country = "DE";
    changed = true;
  }
  if (!tenantConfig.timeZone || !isValidTimeZone(tenantConfig.timeZone)) {
    tenantConfig.timeZone = "Europe/Berlin";
    changed = true;
  }
  if (!tenantConfig.currency) {
    tenantConfig.currency = "eur";
    changed = true;
  }
  if (tenantConfig.nightSurchargeFromHour === undefined) {
    tenantConfig.nightSurchargeFromHour = 22;
    changed = true;
  }
  if (tenantConfig.nightSurchargeToHour === undefined) {
    tenantConfig.nightSurchargeToHour = 6;
    changed = true;
  }
  if (tenantConfig.nightSurchargeEnabled === undefined) {
    tenantConfig.nightSurchargeEnabled = false;
    changed = true;
  }
  if (!tenantConfig.legalStreet) {
    tenantConfig.legalStreet = "";
  }
  if (!tenantConfig.legalCity) {
    tenantConfig.legalCity = "";
  }
  if (!tenantConfig.legalOwner) {
    tenantConfig.legalOwner = "";
  }
  if (!tenantConfig.legalEmail) {
    tenantConfig.legalEmail = "";
  }
  if (!tenantConfig.vatId) {
    tenantConfig.vatId = "";
  }
  if (!tenantConfig.platformCompanyName) {
    tenantConfig.platformCompanyName = "Luckys Taxi App";
  }
  if (!tenantConfig.platformStreet) {
    tenantConfig.platformStreet = "";
  }
  if (!tenantConfig.platformCity) {
    tenantConfig.platformCity = "";
  }
  if (!tenantConfig.platformOwner) {
    tenantConfig.platformOwner = "";
  }
  if (!tenantConfig.platformEmail) {
    tenantConfig.platformEmail = "luckypc81@gmail.com";
  }
  if (!tenantConfig.platformPhone) {
    tenantConfig.platformPhone = "";
  }
  if (!tenantConfig.platformVatId) {
    tenantConfig.platformVatId = "";
  }
  if (changed) saveTenantConfig();
}

/** @type {Array<{driverId:string,name:string,phone:string,vehicle:string,status:string,operatorId?:string}>} */
const drivers = driversSeed.drivers.map((d) => ({ ...d }));

function loadJsonArray(filePath) {
  try {
    if (!fs.existsSync(filePath)) return [];
    const raw = fs.readFileSync(filePath, "utf8");
    const parsed = JSON.parse(raw);
    return Array.isArray(parsed) ? parsed : [];
  } catch (error) {
    console.warn(`Konnte ${filePath} nicht laden:`, error.message);
    return [];
  }
}

function saveJsonArray(filePath, data) {
  fs.mkdirSync(path.dirname(filePath), { recursive: true });
  fs.writeFileSync(filePath, `${JSON.stringify(data, null, 2)}\n`, "utf8");
}

const bookings = loadJsonArray(bookingsFilePath);
const phoneCalls = loadJsonArray(callsFilePath);
/** @type {Array<{operatorId:string,planId:string,email:string,companyName:string,stripeCustomerId:string|null,stripeSubscriptionId:string|null,status:string,createdAt:string,updatedAt:string}>} */
let operators = loadJsonArray(operatorsFilePath);
/** @type {Array<{inquiryId:string,planId:string,email:string,companyName:string,message:string,createdAt:string}>} */
let inquiries = loadJsonArray(inquiriesFilePath);

function saveOperators() {
  saveJsonArray(operatorsFilePath, operators);
}

function saveInquiries() {
  saveJsonArray(inquiriesFilePath, inquiries);
}

function findOperatorBySubscription(subscriptionId) {
  return operators.find((op) => op.stripeSubscriptionId === subscriptionId);
}

function findOperatorByCustomer(customerId) {
  return operators.find((op) => op.stripeCustomerId === customerId);
}

function upsertOperator(record) {
  const index = operators.findIndex(
    (op) =>
      (record.stripeSubscriptionId && op.stripeSubscriptionId === record.stripeSubscriptionId) ||
      (record.stripeCustomerId && op.stripeCustomerId === record.stripeCustomerId && op.planId === record.planId)
  );
  const now = new Date().toISOString();
  if (index === -1) {
    operators.unshift({
      operatorId: crypto.randomUUID(),
      createdAt: now,
      ...record,
      updatedAt: now,
    });
  } else {
    operators[index] = { ...operators[index], ...record, updatedAt: now };
  }
  saveOperators();
}

function resolvePublicBaseUrl(req) {
  if (publicBaseUrl) return publicBaseUrl;
  const proto = String(req.headers["x-forwarded-proto"] || req.protocol || "http");
  const host = req.get("host");
  return host ? `${proto}://${host}` : `http://127.0.0.1:${port}`;
}

async function geocodePlace(query, country = "DE") {
  const q = String(query || "").trim();
  if (!q) return null;
  const url = new URL("https://nominatim.openstreetmap.org/search");
  url.searchParams.set("format", "json");
  url.searchParams.set("limit", "1");
  url.searchParams.set("countrycodes", String(country || "DE").toLowerCase());
  url.searchParams.set("q", q);
  const response = await fetch(url, {
    headers: { "User-Agent": "LuckysTaxiApp/1.0 (fleet-onboarding)" },
  });
  if (!response.ok) return null;
  const data = await response.json();
  if (!Array.isArray(data) || !data.length) return null;
  return { lat: Number(data[0].lat), lng: Number(data[0].lon) };
}

async function prepareFleetOperatorBody(req) {
  const companyName = String(req.body.companyName || "").trim();
  const centralPhone = String(req.body.centralPhone || "").trim();
  const city = String(req.body.city || "").trim();
  const country = String(req.body.country || "DE").trim().toUpperCase();
  const email = String(req.body.email || req.body.legalEmail || "").trim();

  let centerLat = Number(req.body.centerLat);
  let centerLng = Number(req.body.centerLng);
  if (!Number.isFinite(centerLat) || !Number.isFinite(centerLng)) {
    const geo = await geocodePlace(city || companyName, country);
    if (geo) {
      centerLat = geo.lat;
      centerLng = geo.lng;
    }
  }

  return {
    companyName,
    centralPhone,
    centralPhoneDisplay: req.body.centralPhoneDisplay,
    email,
    legalEmail: email,
    legalCity: city,
    city,
    country,
    dispatchHours: req.body.dispatchHours,
    dispatchNote: req.body.dispatchNote,
    dispatchPin: req.body.dispatchPin,
    postalCodes: req.body.postalCodes,
    postalPrefixes: req.body.postalPrefixes,
    centerLat,
    centerLng,
    radiusKm: req.body.radiusKm,
    status: req.body.status,
    planId: req.body.planId,
    billingEmail: req.body.billingEmail,
    notes: req.body.notes,
    maxDrivers: req.body.maxDrivers,
    slug: req.body.slug,
    brandPrimaryColor: req.body.brandPrimaryColor,
    brandAccentColor: req.body.brandAccentColor,
    logoUrl: req.body.logoUrl,
  };
}

async function sendFleetOnboardingNotification(operator, links) {
  console.log(
    `Neuer Taxi-Betrieb: ${operator.companyName} (${operator.slug}) · ${operator.legalEmail || "keine E-Mail"}`
  );
  console.log(`  Leitstelle: ${links.dispatch}`);

  if (!resendApiKey || !operator.legalEmail) return;

  const response = await fetch("https://api.resend.com/emails", {
    method: "POST",
    headers: {
      Authorization: `Bearer ${resendApiKey}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      from: "Luckys Taxi App <onboarding@resend.dev>",
      to: [operator.legalEmail],
      subject: `Ihr Zugang — ${operator.companyName}`,
      text: [
        `Willkommen bei Luckys Taxi App, ${operator.companyName}!`,
        "",
        "Ihre Links:",
        `Leitstelle: ${links.dispatch}`,
        `Einstellungen: ${links.settings}`,
        `Online-Buchung: ${links.book}`,
        `QR-Code: ${links.qr}`,
        "",
        "Bitte dispatchPin in den Einstellungen setzen und Fahrer anlegen.",
      ].join("\n"),
    }),
  });

  if (!response.ok) {
    const body = await response.text();
    console.warn(`Onboarding-Mail fehlgeschlagen (${response.status}): ${body}`);
  }
}

async function sendContactNotification(inquiry) {
  if (!resendApiKey) {
    console.log(
      `Tarif-Anfrage ${inquiry.inquiryId}: ${inquiry.planId} · ${inquiry.email} · ${inquiry.companyName}`
    );
    return;
  }

  const response = await fetch("https://api.resend.com/emails", {
    method: "POST",
    headers: {
      Authorization: `Bearer ${resendApiKey}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      from: "Luckys Taxi App <onboarding@resend.dev>",
      to: [contactNotifyEmail],
      subject: `Tarif-Anfrage: ${inquiry.planId} — ${inquiry.companyName}`,
      text: [
        `Plan: ${inquiry.planId}`,
        `Firma: ${inquiry.companyName}`,
        `E-Mail: ${inquiry.email}`,
        "",
        inquiry.message || "(keine Nachricht)",
      ].join("\n"),
    }),
  });

  if (!response.ok) {
    const body = await response.text();
    console.warn(`Resend fehlgeschlagen (${response.status}): ${body}`);
  }
}

function saveBookings() {
  saveJsonArray(bookingsFilePath, bookings);
}

function savePhoneCalls() {
  saveJsonArray(callsFilePath, phoneCalls);
}

console.log(`Datenverzeichnis: ${dataDir} · ${bookings.length} Buchung(en), ${phoneCalls.length} Anruf(e)`);
if (adminPin) {
  console.log("Leitstellen-Schutz aktiv (ADMIN_PIN gesetzt).");
} else {
  console.warn("Hinweis: ADMIN_PIN fehlt — settings/dispatch ohne PIN erreichbar.");
}

const BOOKING_STATUSES = new Set([
  "confirmed",
  "accepted",
  "assigned",
  "completed",
  "cancelled",
]);
const DRIVER_STATUSES = new Set(["available", "busy", "offline"]);
const DRIVER_LOCATION_MAX_AGE_MS = 2 * 60 * 1000;

function generateTrackingPin() {
  return String(Math.floor(100000 + Math.random() * 900000));
}

function ensureDriverTrackingFields(driver) {
  if (!driver.trackingPin) {
    driver.trackingPin = generateTrackingPin();
    return true;
  }
  return false;
}

function driverHasFreshLocation(driver) {
  if (!driver || !Number.isFinite(driver.lastLat) || !Number.isFinite(driver.lastLng)) {
    return false;
  }
  if (!driver.lastLocationAt) return false;
  return Date.now() - new Date(driver.lastLocationAt).getTime() <= DRIVER_LOCATION_MAX_AGE_MS;
}

function publicDriverTracking(driver) {
  const fresh = driverHasFreshLocation(driver);
  return {
    name: driver.name,
    vehicle: driver.vehicle || "",
    phone: driver.phone,
    latitude: fresh ? driver.lastLat : null,
    longitude: fresh ? driver.lastLng : null,
    locationUpdatedAt: driver.lastLocationAt || null,
  };
}

function operatorSlugFromRequest(req) {
  const querySlug = String(req.query.operator || req.query.o || "").trim().toLowerCase();
  if (querySlug) return querySlug;
  const headerSlug = String(req.headers["x-operator-slug"] || "").trim().toLowerCase();
  if (headerSlug) return headerSlug;
  const bodySlug = String(req.body?.operator || req.body?.operatorSlug || "").trim().toLowerCase();
  return bodySlug || "";
}

function resolveFleetOperatorFromRequest(req) {
  const slug = operatorSlugFromRequest(req);
  if (!slug) return null;
  return fleet.findBySlug(slug);
}

function defaultFleetOperator() {
  return fleet.list()[0] || null;
}

function migrateLegacyBookings() {
  if (!fleet.enabled()) return;
  const fallback = defaultFleetOperator();
  if (!fallback) return;
  let changed = false;
  for (const booking of bookings) {
    if (!booking.operatorId) {
      booking.operatorId = fallback.operatorId;
      changed = true;
    }
  }
  if (changed) saveBookings();
}

function migrateLegacyDrivers() {
  let changed = false;
  for (const driver of drivers) {
    if (ensureDriverTrackingFields(driver)) {
      changed = true;
    }
  }
  if (!fleet.enabled()) {
    if (changed) saveDriversConfig();
    return;
  }
  const fallback = defaultFleetOperator();
  if (!fallback) {
    if (changed) saveDriversConfig();
    return;
  }
  for (const driver of drivers) {
    if (!driver.operatorId) {
      driver.operatorId = fallback.operatorId;
      changed = true;
    }
  }
  if (changed) saveDriversConfig();
}

function authRequiredForRequest(req) {
  if (adminPin) return true;
  const operator = resolveFleetOperatorFromRequest(req);
  if (operator && fleet.pinRequiredForOperator(operator)) return true;
  if (!operator && fleet.anyOperatorPinRequired()) return true;
  return false;
}

function verifyRequestPin(req, pin) {
  const operatorSlug = operatorSlugFromRequest(req);
  return fleet.verifyPin(pin, operatorSlug, adminPin);
}

function filterBookingsForRequest(req) {
  const operator = resolveFleetOperatorFromRequest(req);
  if (operator) {
    return bookings.filter((b) => b.operatorId === operator.operatorId);
  }
  if (fleet.enabled()) return [];
  return bookings;
}

function filterDriversForRequest(req) {
  const operator = resolveFleetOperatorFromRequest(req);
  if (operator) {
    return drivers.filter((d) => d.operatorId === operator.operatorId);
  }
  if (fleet.enabled()) return [];
  return drivers;
}

function bookingMatchesRequest(req, booking) {
  const operator = resolveFleetOperatorFromRequest(req);
  if (!operator) return !fleet.enabled();
  return booking.operatorId === operator.operatorId;
}

function driverMatchesRequest(req, driver) {
  const operator = resolveFleetOperatorFromRequest(req);
  if (!operator) return !fleet.enabled();
  return driver.operatorId === operator.operatorId;
}

const PLATFORM_CONFIG_KEYS = [
  "platformCompanyName",
  "platformStreet",
  "platformCity",
  "platformOwner",
  "platformEmail",
  "platformPhone",
  "platformVatId",
];

function platformPublicConfig() {
  return {
    platformCompanyName: tenantConfig.platformCompanyName || "Luckys Taxi App",
    platformStreet: tenantConfig.platformStreet || "",
    platformCity: tenantConfig.platformCity || "",
    platformOwner: tenantConfig.platformOwner || "",
    platformEmail: tenantConfig.platformEmail || "luckypc81@gmail.com",
    platformPhone: tenantConfig.platformPhone || "",
    platformVatId: tenantConfig.platformVatId || "",
  };
}

function withPlatformFields(config) {
  if (!config) return platformPublicConfig();
  return { ...config, ...platformPublicConfig() };
}

function applyPlatformPatch(body) {
  let changed = false;
  for (const key of PLATFORM_CONFIG_KEYS) {
    if (body[key] !== undefined) {
      tenantConfig[key] = String(body[key]).trim();
      changed = true;
    }
  }
  if (changed) saveTenantConfig();
  return changed;
}

function configForRequest(req) {
  const operator = resolveFleetOperatorFromRequest(req);
  if (operator) return withPlatformFields(fleet.toPublicConfig(operator));
  if (fleet.enabled()) return platformPublicConfig();
  return withPlatformFields(tenantConfig);
}

function operatorConfigForNightSurcharge(operatorOrNull) {
  if (operatorOrNull) return operatorOrNull;
  return tenantConfig;
}

function findDriver(driverId) {
  return drivers.find((d) => d.driverId === driverId);
}

migrateLegacyBookings();
migrateLegacyDrivers();

function findBooking(bookingId) {
  return bookings.find((b) => b.bookingId === bookingId);
}

function releaseDriver(driverId) {
  const driver = findDriver(driverId);
  if (!driver) return;
  if (driver.status === "busy") {
    driver.status = "available";
  }
  driver.activeBookingId = null;
  driver.lastLat = null;
  driver.lastLng = null;
  driver.lastLocationAt = null;
}

function releaseDriverFromBooking(booking) {
  if (booking?.assignedDriverId) {
    releaseDriver(booking.assignedDriverId);
  }
}

function saveTenantConfig() {
  fs.writeFileSync(tenantConfigPath, `${JSON.stringify(tenantConfig, null, 2)}\n`, "utf8");
}

function applyPlatformSeedIfEmpty() {
  const seedPath = path.join(__dirname, "tenant-config.json");
  if (!fs.existsSync(seedPath) || path.resolve(seedPath) === path.resolve(tenantConfigPath)) {
    return;
  }
  let seed;
  try {
    seed = JSON.parse(fs.readFileSync(seedPath, "utf8"));
  } catch {
    return;
  }
  let changed = false;
  for (const key of PLATFORM_CONFIG_KEYS) {
    const seedValue = String(seed[key] || "").trim();
    if (seedValue && !String(tenantConfig[key] || "").trim()) {
      tenantConfig[key] = seedValue;
      changed = true;
    }
  }
  if (changed) saveTenantConfig();
}

ensureTenantDefaults();
applyPlatformSeedIfEmpty();

function saveDriversConfig() {
  const payload = {
    drivers: drivers.map((driver) => {
      ensureDriverTrackingFields(driver);
      return {
        driverId: driver.driverId,
        name: driver.name,
        phone: driver.phone,
        vehicle: driver.vehicle,
        status: driver.status,
        trackingPin: driver.trackingPin,
        ...(driver.operatorId ? { operatorId: driver.operatorId } : {}),
      };
    }),
  };
  fs.writeFileSync(driversConfigPath, `${JSON.stringify(payload, null, 2)}\n`, "utf8");
}

function requireAdmin(req, res, next) {
  if (!authRequiredForRequest(req)) return next();
  const header = String(req.headers.authorization || "");
  const bearer = header.startsWith("Bearer ") ? header.slice(7).trim() : "";
  const pinHeader = String(req.headers["x-admin-pin"] || "").trim();
  const pin = bearer || pinHeader;
  if (verifyRequestPin(req, pin)) return next();
  return res.status(401).json({ error: "Unauthorized — PIN required" });
}

app.use(cors());

app.post("/api/billing/webhook", express.raw({ type: "application/json" }), async (req, res) => {
  if (!stripe || !webhookSecret) {
    return res.status(503).json({ error: "Billing webhook not configured" });
  }

  const signature = req.headers["stripe-signature"];
  if (!signature) {
    return res.status(400).json({ error: "Missing stripe-signature" });
  }

  let event;
  try {
    event = stripe.webhooks.constructEvent(req.body, signature, webhookSecret);
  } catch (error) {
    console.warn("Webhook-Signatur ungültig:", error.message);
    return res.status(400).json({ error: "Invalid signature" });
  }

  try {
    switch (event.type) {
      case "checkout.session.completed": {
        const session = event.data.object;
        if (session.mode !== "subscription") break;
        const planId = String(session.metadata?.planId || "").trim();
        const companyName = String(session.metadata?.companyName || "").trim();
        const email = String(session.customer_details?.email || session.customer_email || "").trim();
        upsertOperator({
          planId: planId || "unknown",
          email,
          companyName,
          stripeCustomerId: session.customer ? String(session.customer) : null,
          stripeSubscriptionId: session.subscription ? String(session.subscription) : null,
          status: "active",
        });
        console.log(`Abo gestartet: ${planId} · ${email}`);
        break;
      }
      case "customer.subscription.updated":
      case "customer.subscription.deleted": {
        const subscription = event.data.object;
        const existing =
          findOperatorBySubscription(subscription.id) ||
          findOperatorByCustomer(String(subscription.customer || ""));
        upsertOperator({
          planId: existing?.planId || String(subscription.metadata?.planId || "unknown"),
          email: existing?.email || "",
          companyName: existing?.companyName || "",
          stripeCustomerId: String(subscription.customer || existing?.stripeCustomerId || ""),
          stripeSubscriptionId: subscription.id,
          status: subscription.status || "unknown",
        });
        break;
      }
      case "invoice.paid":
      case "invoice.payment_failed": {
        const invoice = event.data.object;
        console.log(`Rechnung ${event.type}: ${invoice.id} · ${invoice.customer_email || "—"}`);
        break;
      }
      default:
        break;
    }
    res.json({ received: true });
  } catch (error) {
    console.error("Webhook-Fehler:", error);
    res.status(500).json({ error: "Webhook handler failed" });
  }
});

app.use(express.json());
app.use(express.static(path.join(__dirname, "..", "web")));

app.get("/health", (_req, res) => {
  res.json({
    ok: true,
    stripe: Boolean(stripe),
    billing: isBillingConfigured(),
    dataDir,
    bookings: bookings.length,
    operators: operators.length,
    fleetOperators: fleet.list().length,
    multiTenant: fleet.enabled(),
    authRequired: Boolean(adminPin) || fleet.anyOperatorPinRequired(),
    analytics: Boolean(gaMeasurementId),
  });
});

app.get("/api/public/analytics", (_req, res) => {
  res.json({ gaMeasurementId: gaMeasurementId || null });
});

app.get("/api/auth/required", (req, res) => {
  res.json({ required: authRequiredForRequest(req) });
});

app.post("/api/auth/verify", (req, res) => {
  if (!authRequiredForRequest(req)) return res.json({ ok: true });
  const pin = String(req.body.pin || "").trim();
  if (verifyRequestPin(req, pin)) return res.json({ ok: true });
  return res.status(401).json({ error: "PIN ungültig" });
});

app.get("/api/offering", (_req, res) => {
  res.json(offering);
});

app.get("/api/billing/config", (_req, res) => {
  res.json({
    enabled: isBillingConfigured(),
    plans: offering.operators?.plans?.map((plan) => ({
      id: plan.id,
      name: plan.name,
      priceEuroPerMonth: plan.priceEuroPerMonth,
      checkoutAvailable: Boolean(billingPriceIds[plan.id]),
    })) || [],
    contactEmail: offering.operators?.contactEmail || contactNotifyEmail,
  });
});

app.post("/api/billing/checkout", async (req, res) => {
  if (!isBillingConfigured()) {
    return res.status(503).json({ error: "Stripe Billing not configured" });
  }

  const planId = String(req.body.planId || "").trim();
  const email = String(req.body.email || "").trim();
  const companyName = String(req.body.companyName || "").trim();
  const priceId = billingPriceIds[planId];

  if (!priceId) {
    return res.status(400).json({ error: "Invalid planId" });
  }
  if (!email || !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)) {
    return res.status(400).json({ error: "Valid email required" });
  }
  if (!companyName) {
    return res.status(400).json({ error: "companyName required" });
  }

  try {
    const baseUrl = resolvePublicBaseUrl(req);
    const session = await stripe.checkout.sessions.create({
      mode: "subscription",
      customer_email: email,
      line_items: [{ price: priceId, quantity: 1 }],
      success_url: `${baseUrl}/billing-success.html?session_id={CHECKOUT_SESSION_ID}`,
      cancel_url: `${baseUrl}/index.html#operators`,
      metadata: { planId, companyName },
      subscription_data: {
        metadata: { planId, companyName },
      },
      billing_address_collection: "required",
      tax_id_collection: { enabled: true },
    });

    res.json({ url: session.url });
  } catch (error) {
    console.error(error);
    res.status(500).json({ error: error.message || "Checkout failed" });
  }
});

app.get("/api/billing/operators", requireAdmin, (_req, res) => {
  res.json({ operators });
});

app.post("/api/contact", async (req, res) => {
  const planId = String(req.body.planId || "general").trim();
  const email = String(req.body.email || "").trim();
  const companyName = String(req.body.companyName || "").trim();
  const message = String(req.body.message || "").trim();

  if (!email || !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)) {
    return res.status(400).json({ error: "Valid email required" });
  }
  if (!companyName) {
    return res.status(400).json({ error: "companyName required" });
  }

  const inquiry = {
    inquiryId: crypto.randomUUID(),
    planId,
    email,
    companyName,
    message,
    createdAt: new Date().toISOString(),
  };

  inquiries.unshift(inquiry);
  saveInquiries();

  try {
    await sendContactNotification(inquiry);
    res.status(201).json({ ok: true, inquiryId: inquiry.inquiryId });
  } catch (error) {
    console.error(error);
    res.status(500).json({ error: "Inquiry saved but notification failed" });
  }
});

app.get("/api/contact/inquiries", requireAdmin, (_req, res) => {
  res.json({ inquiries });
});

app.get("/api/operators/resolve", (req, res) => {
  const latitude = Number(req.query.lat ?? req.query.latitude);
  const longitude = Number(req.query.lng ?? req.query.longitude);
  const postalCode = String(req.query.postalCode || req.query.plz || "").trim();
  const hasCoords = Number.isFinite(latitude) && Number.isFinite(longitude);
  const hasPlz = Boolean(fleet.normalizePostalCode(postalCode));

  if (!fleet.enabled()) {
    return res.json({
      operatorId: null,
      slug: null,
      companyName: tenantConfig.companyName,
      config: tenantConfig,
    });
  }

  if (!hasCoords && !hasPlz) {
    return res.status(400).json({ error: "lat/lng or postalCode required" });
  }

  const hintSlug = String(req.query.operator || req.query.o || "").trim();
  const operator = fleet.resolveForBooking(
    hasCoords ? latitude : Number.NaN,
    hasCoords ? longitude : Number.NaN,
    hintSlug,
    postalCode
  );
  if (!operator) {
    return res.status(404).json({
      error: "Kein Taxi-Betrieb in Ihrer Nähe — bitte Zentrale anrufen.",
    });
  }

  res.json({
    operatorId: operator.operatorId,
    slug: operator.slug,
    companyName: operator.companyName,
    config: fleet.toPublicConfig(operator),
  });
});

app.get("/api/operators", (_req, res) => {
  if (!fleet.enabled()) {
    return res.json({ operators: [] });
  }
  res.json({ operators: fleet.list().map((op) => fleet.toPublicSummary(op)) });
});

app.get("/api/fleet/operators", requireAdmin, (req, res) => {
  const baseUrl = resolvePublicBaseUrl(req);
  res.json({
    operators: fleet.list(true).map((op) => fleet.toAdminSummary(op, baseUrl)),
  });
});

app.post("/api/fleet/operators", requireAdmin, async (req, res) => {
  try {
    const input = await prepareFleetOperatorBody(req);
    const status = String(req.body.status || "active").trim().toLowerCase();
    input.status = ["pending", "active", "suspended"].includes(status) ? status : "active";

    const operator = fleet.createOperator(input);
    const links = fleet.onboardingLinks(operator.slug, resolvePublicBaseUrl(req));

    if (operator.status === "active") {
      await sendFleetOnboardingNotification(operator, links);
    }

    res.status(201).json({
      operator: fleet.toAdminSummary(operator, resolvePublicBaseUrl(req)),
      config: fleet.toPublicConfig(operator),
      links,
    });
  } catch (error) {
    res.status(400).json({ error: error.message || "Create failed" });
  }
});

app.patch("/api/fleet/operators/:slug", requireAdmin, async (req, res) => {
  try {
    const slug = String(req.params.slug || "").trim().toLowerCase();
    const existing = fleet.findBySlug(slug);
    if (!existing) {
      return res.status(404).json({ error: "Operator not found" });
    }

    const wasActive = existing.status === "active";
    const patch = { ...req.body };
    const updated = fleet.updateOperator(slug, patch);
    if (!updated) {
      return res.status(404).json({ error: "Operator not found" });
    }

    const links = fleet.onboardingLinks(updated.slug, resolvePublicBaseUrl(req));
    if (!wasActive && updated.status === "active") {
      await sendFleetOnboardingNotification(updated, links);
    }

    res.json({
      operator: fleet.toAdminSummary(updated, resolvePublicBaseUrl(req)),
      config: fleet.toPublicConfig(updated),
      links,
    });
  } catch (error) {
    res.status(400).json({ error: error.message || "Update failed" });
  }
});

app.post("/api/fleet/register", async (req, res) => {
  try {
    const input = await prepareFleetOperatorBody(req);
    input.status = "pending";
    input.planId = String(req.body.planId || "starter").trim().toLowerCase();

    const operator = fleet.createOperator(input);

    if (resendApiKey && contactNotifyEmail) {
      await sendContactNotification({
        inquiryId: `lead-${operator.slug}`,
        planId: operator.planId || "starter",
        email: operator.legalEmail || "keine E-Mail",
        companyName: operator.companyName,
        message: `Neue Registrierungsanfrage (pending). Slug: ${operator.slug}. PLZ: ${(operator.serviceArea?.postalPrefixes || []).join(", ")}`,
        createdAt: new Date().toISOString(),
      });
    } else {
      console.log(
        `Neue Registrierungsanfrage (pending): ${operator.companyName} (${operator.slug})`
      );
    }

    res.status(201).json({
      operator: fleet.toPublicSummary(operator),
      message:
        "Anfrage eingegangen. Wir prüfen Ihre Daten und schalten Ihren Betrieb frei.",
    });
  } catch (error) {
    res.status(400).json({ error: error.message || "Registration failed" });
  }
});

app.get("/api/config", (req, res) => {
  const config = configForRequest(req);
  if (!config) {
    return res.status(400).json({
      error: "operator query required (z. B. ?operator=mannheim)",
    });
  }
  res.json(config);
});

mountPwaBrandRoutes(app, { configForRequest });

app.patch("/api/config", requireAdmin, (req, res) => {
  applyPlatformPatch(req.body);

  const slug = operatorSlugFromRequest(req);
  if (fleet.enabled()) {
    if (!slug) {
      return res.json(platformPublicConfig());
    }

    const patch = {};
    const allowed = [
      "companyName",
      "centralPhone",
      "centralPhoneDisplay",
      "dispatchHours",
      "dispatchNote",
      "legalStreet",
      "legalCity",
      "legalOwner",
      "legalEmail",
      "vatId",
      "brandPrimaryColor",
      "brandAccentColor",
      "logoUrl",
    ];

    for (const key of allowed) {
      if (req.body[key] !== undefined) {
        patch[key] = String(req.body[key]).trim();
      }
    }

    if (req.body.nightSurchargeEnabled !== undefined) {
      patch.nightSurchargeEnabled = Boolean(
        req.body.nightSurchargeEnabled === true ||
          req.body.nightSurchargeEnabled === "true" ||
          req.body.nightSurchargeEnabled === "on"
      );
    }
    if (req.body.nightSurchargeFromHour !== undefined) {
      const h = Number(req.body.nightSurchargeFromHour);
      if (Number.isInteger(h) && h >= 0 && h <= 23) {
        patch.nightSurchargeFromHour = h;
      }
    }
    if (req.body.nightSurchargeToHour !== undefined) {
      const h = Number(req.body.nightSurchargeToHour);
      if (Number.isInteger(h) && h >= 0 && h <= 23) {
        patch.nightSurchargeToHour = h;
      }
    }
    if (req.body.country !== undefined) {
      const country = String(req.body.country).trim().toUpperCase();
      if (/^[A-Z]{2}$/.test(country)) patch.country = country;
    }
    if (req.body.timeZone !== undefined) {
      const timeZone = String(req.body.timeZone).trim();
      try {
        Intl.DateTimeFormat(undefined, { timeZone });
        patch.timeZone = timeZone;
      } catch {
        return res.status(400).json({ error: "Invalid timeZone" });
      }
    }
    if (req.body.currency !== undefined) {
      const currency = String(req.body.currency).trim().toLowerCase();
      if (/^[a-z]{3}$/.test(currency)) patch.currency = currency;
    }
    if (req.body.dispatchPin !== undefined) {
      patch.dispatchPin = String(req.body.dispatchPin).trim();
    }
    if (
      req.body.postalCodes !== undefined ||
      req.body.postalPrefixes !== undefined ||
      req.body.radiusKm !== undefined
    ) {
      patch.postalCodes = req.body.postalCodes;
      patch.postalPrefixes = req.body.postalPrefixes;
      patch.radiusKm = req.body.radiusKm;
    }

    try {
      const updated = fleet.updateOperator(slug, patch);
      console.log(`Fleet-Config aktualisiert: ${updated.companyName} (${slug})`);
      return res.json(withPlatformFields(fleet.toPublicConfig(updated)));
    } catch (error) {
      return res.status(400).json({ error: error.message || "Update failed" });
    }
  }

  const allowed = [
    "companyName",
    "centralPhone",
    "centralPhoneDisplay",
    "dispatchHours",
    "dispatchNote",
    "legalStreet",
    "legalCity",
    "legalOwner",
    "legalEmail",
    "vatId",
    "platformCompanyName",
    "platformStreet",
    "platformCity",
    "platformOwner",
    "platformEmail",
    "platformPhone",
    "platformVatId",
  ];

  for (const key of allowed) {
    if (req.body[key] !== undefined) {
      tenantConfig[key] = String(req.body[key]).trim();
    }
  }

  if (req.body.nightSurchargeEnabled !== undefined) {
    tenantConfig.nightSurchargeEnabled = Boolean(
      req.body.nightSurchargeEnabled === true ||
        req.body.nightSurchargeEnabled === "true" ||
        req.body.nightSurchargeEnabled === "on"
    );
  }
  if (req.body.nightSurchargeFromHour !== undefined) {
    const h = Number(req.body.nightSurchargeFromHour);
    if (Number.isInteger(h) && h >= 0 && h <= 23) {
      tenantConfig.nightSurchargeFromHour = h;
    }
  }
  if (req.body.nightSurchargeToHour !== undefined) {
    const h = Number(req.body.nightSurchargeToHour);
    if (Number.isInteger(h) && h >= 0 && h <= 23) {
      tenantConfig.nightSurchargeToHour = h;
    }
  }

  if (req.body.country !== undefined) {
    const country = String(req.body.country).trim().toUpperCase();
    if (/^[A-Z]{2}$/.test(country)) {
      tenantConfig.country = country;
    }
  }
  if (req.body.timeZone !== undefined) {
    const timeZone = String(req.body.timeZone).trim();
    if (!isValidTimeZone(timeZone)) {
      return res.status(400).json({ error: "Invalid timeZone" });
    }
    tenantConfig.timeZone = timeZone;
  }
  if (req.body.currency !== undefined) {
    const currency = String(req.body.currency).trim().toLowerCase();
    if (/^[a-z]{3}$/.test(currency)) {
      tenantConfig.currency = currency;
    }
  }

  if (!tenantConfig.companyName) {
    return res.status(400).json({ error: "companyName required" });
  }
  if (!tenantConfig.centralPhone) {
    return res.status(400).json({ error: "centralPhone required" });
  }

  saveTenantConfig();
  console.log(`Config aktualisiert: ${tenantConfig.companyName} · ${tenantConfig.centralPhoneDisplay || tenantConfig.centralPhone}`);
  res.json(tenantConfig);
});

app.get("/api/drivers", requireAdmin, (req, res) => {
  res.json({ drivers: filterDriversForRequest(req) });
});

app.post("/api/drivers", requireAdmin, (req, res) => {
  const name = String(req.body.name || "").trim();
  const phone = String(req.body.phone || "").trim();
  const vehicle = String(req.body.vehicle || "").trim();

  if (!name || !phone) {
    return res.status(400).json({ error: "name and phone required" });
  }

  const operator = resolveFleetOperatorFromRequest(req) || defaultFleetOperator();
  if (fleet.enabled() && !operator) {
    return res.status(400).json({ error: "operator query required" });
  }

  if (operator) {
    const limit = fleet.driverLimitFor(operator);
    if (limit !== null) {
      const count = drivers.filter((d) => d.operatorId === operator.operatorId).length;
      if (count >= limit) {
        return res.status(403).json({
          error: `Fahrer-Limit erreicht (${limit} im Tarif ${operator.planId || "starter"}). Business-Tarif für mehr Fahrer.`,
        });
      }
    }
  }

  const driver = {
    driverId: crypto.randomUUID(),
    name,
    phone,
    vehicle,
    status: "available",
    trackingPin: generateTrackingPin(),
    activeBookingId: null,
    lastLat: null,
    lastLng: null,
    lastLocationAt: null,
    ...(operator ? { operatorId: operator.operatorId } : {}),
  };

  drivers.push(driver);
  saveDriversConfig();
  res.status(201).json(driver);
});

app.put("/api/drivers/:id", requireAdmin, (req, res) => {
  const driver = findDriver(req.params.id);
  if (!driver) {
    return res.status(404).json({ error: "Driver not found" });
  }
  if (!driverMatchesRequest(req, driver)) {
    return res.status(404).json({ error: "Driver not found" });
  }

  if (req.body.name !== undefined) {
    driver.name = String(req.body.name).trim();
  }
  if (req.body.phone !== undefined) {
    driver.phone = String(req.body.phone).trim();
  }
  if (req.body.vehicle !== undefined) {
    driver.vehicle = String(req.body.vehicle).trim();
  }

  if (!driver.name || !driver.phone) {
    return res.status(400).json({ error: "name and phone required" });
  }

  saveDriversConfig();
  res.json(driver);
});

app.delete("/api/drivers/:id", requireAdmin, (req, res) => {
  const index = drivers.findIndex((d) => d.driverId === req.params.id);
  if (index === -1) {
    return res.status(404).json({ error: "Driver not found" });
  }
  if (!driverMatchesRequest(req, drivers[index])) {
    return res.status(404).json({ error: "Driver not found" });
  }

  const removed = drivers.splice(index, 1)[0];
  saveDriversConfig();
  res.json(removed);
});

app.patch("/api/drivers/:id/status", requireAdmin, (req, res) => {
  const driver = findDriver(req.params.id);
  if (!driver) {
    return res.status(404).json({ error: "Driver not found" });
  }
  if (!driverMatchesRequest(req, driver)) {
    return res.status(404).json({ error: "Driver not found" });
  }

  const status = String(req.body.status || "").trim();
  if (!DRIVER_STATUSES.has(status)) {
    return res.status(400).json({ error: "Invalid status" });
  }

  driver.status = status;
  saveDriversConfig();
  res.json(driver);
});

app.post("/api/bookings", (req, res) => {
  const latitude = Number(req.body.latitude);
  const longitude = Number(req.body.longitude);
  const addressLine = String(req.body.addressLine || "").trim();

  if (!Number.isFinite(latitude) || !Number.isFinite(longitude)) {
    return res.status(400).json({ error: "latitude and longitude required" });
  }
  if (!addressLine) {
    return res.status(400).json({ error: "addressLine required" });
  }

  const hintSlug = String(
    req.body.operatorSlug || req.body.operator || req.query.operator || req.query.o || ""
  ).trim();
  const postalCode = String(req.body.postalCode || req.body.postalCodes || "").trim();

  let fleetOperator = null;
  if (fleet.enabled()) {
    fleetOperator = fleet.resolveForBooking(latitude, longitude, hintSlug, postalCode);
    if (!fleetOperator) {
      return res.status(404).json({
        error: "Kein Taxi-Betrieb in Ihrer Nähe — bitte Zentrale anrufen.",
      });
    }
  }

  const destinationAddressLine = String(req.body.destinationAddressLine || "").trim();
  const configSource = operatorConfigForNightSurcharge(fleetOperator);

  const nightEnabled = Boolean(configSource.nightSurchargeEnabled);
  const fromHour = Number(configSource.nightSurchargeFromHour ?? 22);
  const toHour = Number(configSource.nightSurchargeToHour ?? 6);
  const timeZone = configSource.timeZone || "Europe/Berlin";
  const pickup = new Date(req.body.pickupDate || Date.now());
  const pickupHour = Number(
    new Intl.DateTimeFormat("en-GB", {
      hour: "numeric",
      hour12: false,
      timeZone,
    }).format(pickup)
  );
  const nightSurchargeApplies =
    nightEnabled &&
    (fromHour > toHour
      ? pickupHour >= fromHour || pickupHour < toHour
      : pickupHour >= fromHour && pickupHour < toHour);

  const booking = {
    bookingId: crypto.randomUUID(),
    ...(fleetOperator ? { operatorId: fleetOperator.operatorId } : {}),
    pickupDate: req.body.pickupDate || new Date().toISOString(),
    latitude,
    longitude,
    addressLine,
    destinationAddressLine: destinationAddressLine || null,
    paymentMethod: req.body.paymentMethod || "Unbekannt",
    passengerEmail: String(req.body.passengerEmail || req.body.receiptEmail || "").trim() || null,
    totalAmount: Number(req.body.totalAmount) || 0,
    tariffAmount: Number(req.body.tariffAmount) || 0,
    tipAmount: Number(req.body.tipAmount) || 0,
    nightSurchargeApplies,
    status: "confirmed",
    assignedDriverId: null,
    createdAt: new Date().toISOString(),
  };

  bookings.unshift(booking);
  saveBookings();
  const operatorLabel = fleetOperator ? ` [${fleetOperator.slug}]` : "";
  console.log(`Buchung ${booking.bookingId}${operatorLabel}: ${addressLine}${destinationAddressLine ? ` → ${destinationAddressLine}` : ""}`);
  res.status(201).json({
    bookingId: booking.bookingId,
    operatorId: booking.operatorId || null,
    operatorSlug: fleetOperator?.slug || null,
  });
});

app.get("/api/bookings", requireAdmin, (req, res) => {
  res.json({ bookings: filterBookingsForRequest(req) });
});

app.get("/api/bookings/:id", requireAdmin, (req, res) => {
  const booking = findBooking(req.params.id);
  if (!booking) {
    return res.status(404).json({ error: "Booking not found" });
  }
  if (!bookingMatchesRequest(req, booking)) {
    return res.status(404).json({ error: "Booking not found" });
  }
  res.json(booking);
});

app.patch("/api/bookings/:id/status", requireAdmin, (req, res) => {
  const booking = findBooking(req.params.id);
  if (!booking) {
    return res.status(404).json({ error: "Booking not found" });
  }
  if (!bookingMatchesRequest(req, booking)) {
    return res.status(404).json({ error: "Booking not found" });
  }

  const status = String(req.body.status || "").trim();
  if (!BOOKING_STATUSES.has(status)) {
    return res.status(400).json({ error: "Invalid status" });
  }

  if (status === "completed" || status === "cancelled") {
    releaseDriverFromBooking(booking);
    booking.assignedDriverId = null;
  }

  booking.status = status;
  booking.updatedAt = new Date().toISOString();
  saveBookings();
  res.json(booking);
});

app.patch("/api/bookings/:id/assign", requireAdmin, (req, res) => {
  const booking = findBooking(req.params.id);
  if (!booking) {
    return res.status(404).json({ error: "Booking not found" });
  }
  if (!bookingMatchesRequest(req, booking)) {
    return res.status(404).json({ error: "Booking not found" });
  }

  const driverId = req.body.driverId ? String(req.body.driverId).trim() : null;

  if (driverId === null || driverId === "") {
    releaseDriverFromBooking(booking);
    booking.assignedDriverId = null;
    booking.updatedAt = new Date().toISOString();
    saveBookings();
    return res.json(booking);
  }

  const driver = findDriver(driverId);
  if (!driver) {
    return res.status(404).json({ error: "Driver not found" });
  }
  if (!driverMatchesRequest(req, driver)) {
    return res.status(404).json({ error: "Driver not found" });
  }
  if (driver.status === "offline") {
    return res.status(400).json({ error: "Driver is offline" });
  }

  const previousId = booking.assignedDriverId;
  if (previousId && previousId !== driverId) {
    releaseDriver(previousId);
  }

  booking.assignedDriverId = driverId;
  booking.status = "assigned";
  driver.status = "busy";
  driver.activeBookingId = booking.bookingId;
  booking.updatedAt = new Date().toISOString();

  console.log(`Buchung ${booking.bookingId} → Fahrer ${driver.name}`);
  saveBookings();
  res.json(booking);
});

/** Fahrer sendet GPS-Standort (Web/PWA oder spätere Fahrer-App). */
app.post("/api/drivers/:id/location", (req, res) => {
  const driver = findDriver(req.params.id);
  if (!driver) {
    return res.status(404).json({ error: "Driver not found" });
  }

  const pin = String(req.body.trackingPin || "").trim();
  if (!pin || pin !== String(driver.trackingPin || "")) {
    return res.status(401).json({ error: "Invalid tracking PIN" });
  }

  const latitude = Number(req.body.latitude);
  const longitude = Number(req.body.longitude);
  if (!Number.isFinite(latitude) || !Number.isFinite(longitude)) {
    return res.status(400).json({ error: "latitude and longitude required" });
  }

  const bookingId = String(req.body.bookingId || "").trim();
  if (bookingId && driver.activeBookingId && driver.activeBookingId !== bookingId) {
    return res.status(403).json({ error: "Not assigned to this booking" });
  }

  driver.lastLat = latitude;
  driver.lastLng = longitude;
  driver.lastLocationAt = new Date().toISOString();
  if (driver.status === "offline") {
    driver.status = "busy";
  }

  res.json({
    ok: true,
    driverId: driver.driverId,
    activeBookingId: driver.activeBookingId || null,
    updatedAt: driver.lastLocationAt,
  });
});

/** Fahrgast verfolgt zugewiesenes Taxi (öffentlich per Buchungs-ID). */
app.get("/api/public/bookings/:id/tracking", (req, res) => {
  const booking = findBooking(req.params.id);
  if (!booking) {
    return res.status(404).json({ error: "Booking not found" });
  }

  const driver = booking.assignedDriverId ? findDriver(booking.assignedDriverId) : null;
  const payload = {
    bookingId: booking.bookingId,
    status: booking.status,
    pickup: {
      latitude: booking.latitude,
      longitude: booking.longitude,
      addressLine: booking.addressLine,
    },
    driver: driver ? publicDriverTracking(driver) : null,
    hasDriverLocation: driver ? driverHasFreshLocation(driver) : false,
  };

  res.json(payload);
});

app.post("/api/drivers/:id/tracking-pin", requireAdmin, (req, res) => {
  const driver = findDriver(req.params.id);
  if (!driver) {
    return res.status(404).json({ error: "Driver not found" });
  }
  if (!driverMatchesRequest(req, driver)) {
    return res.status(404).json({ error: "Driver not found" });
  }

  driver.trackingPin = generateTrackingPin();
  saveDriversConfig();
  res.json({ driverId: driver.driverId, trackingPin: driver.trackingPin });
});

/** VoIP-Stufe C: eingehender Anruf (Twilio/Sipgate-Webhook-Vorbereitung). */
app.post("/api/calls/incoming", (req, res) => {
  const from = String(req.body.from || "Unbekannt").trim();
  const note = String(req.body.note || "").trim();

  const call = {
    callId: crypto.randomUUID(),
    from,
    note,
    status: "ringing",
    receivedAt: new Date().toISOString(),
  };

  phoneCalls.unshift(call);
  savePhoneCalls();
  console.log(`Anruf ${call.callId}: ${from}`);
  res.status(201).json(call);
});

app.get("/api/calls", requireAdmin, (_req, res) => {
  res.json({ calls: phoneCalls });
});

app.patch("/api/calls/:id/status", requireAdmin, (req, res) => {
  const call = phoneCalls.find((item) => item.callId === req.params.id);
  if (!call) {
    return res.status(404).json({ error: "Call not found" });
  }

  const status = String(req.body.status || "").trim();
  if (!["ringing", "accepted", "completed", "missed"].includes(status)) {
    return res.status(400).json({ error: "Invalid status" });
  }

  call.status = status;
  call.updatedAt = new Date().toISOString();
  savePhoneCalls();
  res.json(call);
});

app.post("/create-payment-intent", async (req, res) => {
  if (!stripe) {
    return res.status(503).json({ error: "Stripe not configured (STRIPE_SECRET_KEY missing)" });
  }

  try {
    const amount = Number(req.body.amount);
    const currency = (req.body.currency || "eur").toLowerCase();
    const receiptEmail = String(req.body.receiptEmail || req.body.passengerEmail || "").trim();

    if (!Number.isInteger(amount) || amount < 50) {
      return res.status(400).json({ error: "amount must be an integer >= 50 (cents)" });
    }

    const params = {
      amount,
      currency,
      automatic_payment_methods: { enabled: true },
    };

    if (receiptEmail && /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(receiptEmail)) {
      params.receipt_email = receiptEmail;
    }

    const paymentIntent = await stripe.paymentIntents.create(params);

    res.json({ clientSecret: paymentIntent.client_secret });
  } catch (error) {
    console.error(error);
    res.status(500).json({ error: error.message || "PaymentIntent failed" });
  }
});

const host = process.env.HOST || "0.0.0.0";

app.listen(port, host, () => {
  const publicUrl = process.env.PUBLIC_BASE_URL || `http://${host}:${port}`;
  console.log(`TaxiApp backend listening on ${publicUrl}`);
});
