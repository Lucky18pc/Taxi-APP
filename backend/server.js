require("dotenv").config();

const express = require("express");
const cors = require("cors");
const crypto = require("crypto");
const path = require("path");
const fs = require("fs");
const { createFleetOperatorsStore } = require("./fleet-operators");
const { mountPwaBrandRoutes } = require("./pwa-brand");
const {
  createUploadMiddleware,
  saveDocumentFile,
  resolveAbsolutePath,
  deleteDocumentFile,
  pickComplianceTextFields,
  pickDriverComplianceFields,
  OPERATOR_DOC_FIELDS,
  DRIVER_DOC_FIELDS,
} = require("./compliance-uploads");
const { generateSecret, verifyTotp, otpauthUrl } = require("./totp");
const QRCode = require("qrcode");

const port = process.env.PORT || 4242;
const secretKey = process.env.STRIPE_SECRET_KEY;
const stripePublishableKey = String(process.env.STRIPE_PUBLISHABLE_KEY || "").trim();
const stripeTerminalLocationId = String(process.env.STRIPE_TERMINAL_LOCATION_ID || "").trim();
const webhookSecret = String(process.env.STRIPE_WEBHOOK_SECRET || "").trim();
const publicBaseUrl = String(process.env.PUBLIC_BASE_URL || "").trim().replace(/\/$/, "");
const resendApiKey = String(process.env.RESEND_API_KEY || "").trim();
const contactNotifyEmail = String(process.env.CONTACT_NOTIFY_EMAIL || "kontakt@luckystaxiapp.de").trim();
const resendFromEmail = String(
  process.env.RESEND_FROM || "Code & Grow <onboarding@resend.dev>"
).trim();
const requireAdminPin =
  String(process.env.REQUIRE_ADMIN_PIN || "").trim() === "1" ||
  Boolean(process.env.RENDER);
const gaMeasurementId = String(process.env.GA_MEASUREMENT_ID || "").trim();

const billingPriceIds = {
  starter: String(process.env.STRIPE_PRICE_STARTER || "").trim(),
  business: String(process.env.STRIPE_PRICE_BUSINESS || "").trim(),
  fleet: String(process.env.STRIPE_PRICE_FLEET || "").trim(),
};

/** Stripe-Konto = nur Luckys Taxi (nicht Collection Shop). Siehe docs/STRIPE-ZWEI-KONTEN.md */
const STRIPE_PRODUCT_META = Object.freeze({
  product: "taxi",
  productName: "Luckys Taxi App",
});

function isBillingConfigured() {
  return Boolean(stripe && Object.values(billingPriceIds).some(Boolean));
}

function isCardPaymentMethod(method) {
  const s = String(method || "").toLowerCase();
  return s.includes("karte") || s.includes("card") || s === "stripe";
}

function resolvePublicBase(req) {
  if (publicBaseUrl) return publicBaseUrl;
  const proto = String(req.headers["x-forwarded-proto"] || req.protocol || "https")
    .split(",")[0]
    .trim();
  const host = String(req.headers["x-forwarded-host"] || req.headers.host || "")
    .split(",")[0]
    .trim();
  if (!host) return "";
  return `${proto}://${host}`;
}

function eurosToCents(euros) {
  return Math.round(Number(euros) * 100);
}

function buildPayUrl(req, booking) {
  const base = resolvePublicBase(req);
  if (!base || !booking?.paymentAccessToken || !booking?.bookingId) return null;
  return `${base}/pay.html?b=${encodeURIComponent(booking.bookingId)}&t=${encodeURIComponent(booking.paymentAccessToken)}`;
}

function markBookingPaid(booking, paymentIntentId) {
  if (!booking) return false;
  booking.paymentStatus = "paid";
  booking.paymentIntentId = paymentIntentId || booking.paymentIntentId || null;
  booking.paidAt = new Date().toISOString();
  booking.updatedAt = booking.paidAt;
  return true;
}

/** Vermittlung nur bei App/Web/QR — Straße/Zentrale ohne Plattform-Buchung: false. */
function normalizeMediationChannel(raw) {
  const value = String(raw || "web").trim().toLowerCase();
  if (["app", "ios", "android", "iphone"].includes(value)) return "app";
  if (["qr", "qrcode", "qr-code"].includes(value)) return "qr";
  if (["street", "strasse", "zentrale", "dispatch_street", "phone"].includes(value)) {
    return "street";
  }
  return "web";
}

function shouldApplyBrokerageFee(booking) {
  const raw = String(booking?.mediationChannel || booking?.bookingSource || "web")
    .trim()
    .toLowerCase();
  if (!raw || raw === "street" || raw === "zentrale" || raw === "dispatch_street") {
    return false;
  }
  const allowed = offering.operators?.brokerageFeeAppliesTo || ["app", "web", "qr"];
  return allowed.map((x) => String(x).toLowerCase()).includes(raw) || raw === "online";
}

function resolveRideFeeBreakdown(amountCents, { applyBrokerage }) {
  const ops = offering.operators || {};
  const plan = (ops.plans || []).find((p) => p.id === "fleet") || ops.plans?.[0];
  const platformRaw = Number(ops.platformFeePercent ?? plan?.cardPlatformFeePercent);
  const brokerageRaw = Number(ops.brokerageFeePercent ?? plan?.brokerageFeePercent);
  const platformFeePercent = Number.isFinite(platformRaw) ? platformRaw : 1.9;
  const brokerageFeePercent =
    applyBrokerage && Number.isFinite(brokerageRaw) ? brokerageRaw : 0;
  const totalFeePercent = platformFeePercent + brokerageFeePercent;
  const platformFeeCents = Math.max(0, Math.round((amountCents * platformFeePercent) / 100));
  const brokerageFeeCents = Math.max(0, Math.round((amountCents * brokerageFeePercent) / 100));
  let applicationFeeCents = platformFeeCents + brokerageFeeCents;
  if (applicationFeeCents >= amountCents) {
    applicationFeeCents = Math.max(0, amountCents - 1);
  }
  return {
    platformFeePercent,
    brokerageFeePercent,
    totalFeePercent,
    platformFeeCents,
    brokerageFeeCents,
    applicationFeeCents,
  };
}

async function ensureRidePaymentIntent(booking, { receiptEmail, channel = "online" } = {}) {
  const amountCents = eurosToCents(booking.totalAmount);
  const wantTerminal = channel === "terminal";
  if (!stripe) {
    const err = new Error("Stripe not configured");
    err.code = "stripe_missing";
    throw err;
  }
  if (!Number.isInteger(amountCents) || amountCents < 50) {
    const err = new Error("amount must be >= 0.50 EUR");
    err.code = "invalid_amount";
    throw err;
  }
  if (booking.paymentStatus === "paid") {
    return { alreadyPaid: true };
  }

  if (!booking.paymentAccessToken) {
    booking.paymentAccessToken = crypto.randomBytes(16).toString("hex");
  }

  const sameChannel = (booking.paymentChannel || "online") === (wantTerminal ? "terminal" : "online");
  if (booking.paymentIntentId && sameChannel) {
    try {
      const existing = await stripe.paymentIntents.retrieve(booking.paymentIntentId);
      if (existing.status === "succeeded") {
        markBookingPaid(booking, existing.id);
        saveBookings();
        return { alreadyPaid: true };
      }
      if (
        existing.amount === amountCents &&
        ["requires_payment_method", "requires_confirmation", "requires_action", "processing"].includes(
          existing.status
        )
      ) {
        booking.paymentStatus = "pending";
        booking.paymentAmountCents = amountCents;
        saveBookings();
        return { clientSecret: existing.client_secret, paymentIntentId: existing.id };
      }
    } catch (error) {
      console.warn("PaymentIntent retrieve:", error.message);
    }
  }

  const fleetOp = booking.operatorId ? fleet.findById(booking.operatorId) : null;
  const planId = String(fleetOp?.planId || "fleet").trim() || "fleet";
  const fees = resolveRideFeeBreakdown(amountCents, {
    applyBrokerage: shouldApplyBrokerageFee(booking),
  });
  const {
    platformFeePercent,
    brokerageFeePercent,
    totalFeePercent,
    platformFeeCents,
    brokerageFeeCents,
    applicationFeeCents,
  } = fees;
  const connectAccountId = String(fleetOp?.stripeConnectAccountId || "").trim();

  const metadata = {
    ...STRIPE_PRODUCT_META,
    bookingId: booking.bookingId,
    operatorId: booking.operatorId || "",
    channel: wantTerminal ? "terminal" : "online",
    mediationChannel: String(booking.mediationChannel || "web"),
    platformFeePercent: String(platformFeePercent),
    platformFeeCents: String(platformFeeCents),
    brokerageFeePercent: String(brokerageFeePercent),
    brokerageFeeCents: String(brokerageFeeCents),
    totalFeePercent: String(totalFeePercent),
    applicationFeeCents: String(applicationFeeCents),
  };

  const params = wantTerminal
    ? {
        amount: amountCents,
        currency: "eur",
        payment_method_types: ["card_present"],
        capture_method: "automatic",
        metadata,
      }
    : {
        amount: amountCents,
        currency: "eur",
        automatic_payment_methods: { enabled: true },
        metadata,
      };

  // Stripe Connect: Geld an Betrieb, Plattform- + Vermittlungsgebühr einbehalten
  if (connectAccountId && applicationFeeCents > 0 && applicationFeeCents < amountCents) {
    params.application_fee_amount = applicationFeeCents;
    params.transfer_data = { destination: connectAccountId };
  }

  const email = String(receiptEmail || booking.passengerEmail || "").trim();
  if (!wantTerminal && email && /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)) {
    params.receipt_email = email;
  }

  const paymentIntent = await stripe.paymentIntents.create(params);
  booking.paymentIntentId = paymentIntent.id;
  booking.paymentChannel = wantTerminal ? "terminal" : "online";
  booking.paymentStatus = "pending";
  booking.paymentAmountCents = amountCents;
  booking.platformFeePercent = platformFeePercent;
  booking.platformFeeCents = platformFeeCents;
  booking.brokerageFeePercent = brokerageFeePercent;
  booking.brokerageFeeCents = brokerageFeeCents;
  booking.totalFeePercent = totalFeePercent;
  booking.applicationFeeCents = applicationFeeCents;
  booking.stripeConnectAccountId = connectAccountId || null;
  booking.updatedAt = new Date().toISOString();
  saveBookings();
  return { clientSecret: paymentIntent.client_secret, paymentIntentId: paymentIntent.id };
}

function isTerminalConfigured() {
  return Boolean(stripe && stripeTerminalLocationId);
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
  // DATEN_DIR = häufiger Tippfehler in der Render-UI; /var/data = Persistent Disk.
  const fromEnv = String(process.env.DATA_DIR || process.env.DATEN_DIR || "").trim();
  const candidates = [];
  if (fromEnv) candidates.push(fromEnv);
  if (process.env.RENDER || process.env.RENDER_SERVICE_ID) {
    candidates.push("/var/data");
  }
  candidates.push(path.join(__dirname, "data"));

  const tried = [];
  for (const preferred of candidates) {
    try {
      fs.mkdirSync(preferred, { recursive: true });
      fs.accessSync(preferred, fs.constants.W_OK);
      if (fromEnv && preferred !== fromEnv) {
        console.warn(`DATA_DIR: "${fromEnv}" nicht nutzbar — nutze ${preferred}`);
      } else if (process.env.DATEN_DIR && !process.env.DATA_DIR && preferred === fromEnv) {
        console.warn('Hinweis: Env heißt "DATEN_DIR" — bitte in Render in DATA_DIR umbenennen.');
      }
      return preferred;
    } catch (error) {
      tried.push(`${preferred} (${error.code || error.message})`);
    }
  }
  const fallback = path.join(__dirname, "data");
  console.warn(`DATA_DIR: keine Variante nutzbar [${tried.join("; ")}] — Fallback ${fallback}`);
  fs.mkdirSync(fallback, { recursive: true });
  return fallback;
}

const dataDir = resolveDataDir();
console.log(`Datenverzeichnis: ${dataDir}`);
if (
  (process.env.RENDER || process.env.RENDER_SERVICE_ID) &&
  dataDir.includes("/opt/render/project")
) {
  console.warn(
    "WARNUNG: Kein Persistent Disk — Sessions/MFA gehen bei jedem Deploy verloren. In Render DATA_DIR=/var/data setzen und Disk auf /var/data mounten."
  );
}
const adminPin = String(process.env.ADMIN_PIN || "").trim();

/** Shared secret für Fahrer-App-Endpunkte. Auf Render per DRIVER_API_KEY überschreiben. */
const DEFAULT_DRIVER_API_KEY = "luckys-fahrer-pilot-k7m2p9qx";
const driverApiKey = String(process.env.DRIVER_API_KEY || DEFAULT_DRIVER_API_KEY).trim();

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
    tenantConfig.platformCompanyName = "Code & Grow";
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
    tenantConfig.platformEmail = "kontakt@luckystaxiapp.de";
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

/**
 * Nach Stripe-Abo: Fleet-Mandant anlegen/aktivieren (Leitstelle unter eigenem Slug).
 * Servicegebiet muss Admin später eingrenzen — zunächst DE-weit (PLZ-Präfixe 0–9).
 */
async function provisionFleetFromSubscription(record) {
  const companyName = String(record.companyName || "").trim();
  const email = String(record.email || "").trim();
  const rawPlan = String(record.planId || "fleet").trim().toLowerCase();
  const planId = ["fleet", "business", "starter"].includes(rawPlan) ? rawPlan : "fleet";
  const stripeCustomerId = record.stripeCustomerId ? String(record.stripeCustomerId) : "";
  const stripeSubscriptionId = record.stripeSubscriptionId
    ? String(record.stripeSubscriptionId)
    : "";

  if (!companyName && !email) return null;

  let existing =
    (stripeSubscriptionId && fleet.findByStripeSubscription(stripeSubscriptionId)) ||
    (stripeCustomerId && fleet.findByStripeCustomer(stripeCustomerId)) ||
    (email && fleet.findByBillingEmail(email));

  if (existing) {
    fleet.updateOperator(existing.slug, {
      status: record.status === "active" || record.status === "trialing" ? "active" : existing.status,
      planId,
      billingEmail: email || existing.billingEmail,
      stripeCustomerId: stripeCustomerId || existing.stripeCustomerId,
      stripeSubscriptionId: stripeSubscriptionId || existing.stripeSubscriptionId,
      notes: existing.notes || "Aus Stripe-Abo übernommen — Servicegebiet prüfen.",
    });
    return fleet.findBySlug(existing.slug);
  }

  if (record.status && !["active", "trialing"].includes(String(record.status))) {
    return null;
  }

  const dispatchPin = String(crypto.randomInt(100000, 999999));
  const operator = fleet.createOperator({
    companyName: companyName || email.split("@")[0] || "Taxi-Betrieb",
    centralPhone: String(tenantConfig.centralPhone || "+490000000000").trim(),
    centralPhoneDisplay: String(tenantConfig.centralPhoneDisplay || "Zentrale").trim(),
    billingEmail: email,
    legalEmail: email,
    planId,
    status: "active",
    allowEmptyServiceArea: false,
    postalPrefixes: ["0", "1", "2", "3", "4", "5", "6", "7", "8", "9"],
    notes:
      "Automatisch nach Stripe-Checkout. Bitte Servicegebiet (PLZ) und Leitstellen-Nummer in Admin anpassen.",
    stripeCustomerId,
    stripeSubscriptionId,
    dispatchPin,
  });

  const baseUrl = publicBaseUrl || "https://luckystaxiapp.de";
  const links = fleet.onboardingLinks(operator.slug, baseUrl);
  try {
    await sendFleetOnboardingNotification(operator, links);
  } catch (error) {
    console.warn("Onboarding-Mail nach Abo:", error.message);
  }
  console.log(
    `Fleet-Mandant aus Abo: ${operator.slug} · PIN ${dispatchPin} · ${email}`
  );
  return operator;
}

function resolvePublicBaseUrl(req) {
  if (publicBaseUrl) return publicBaseUrl;
  const proto = String(req.headers["x-forwarded-proto"] || req.protocol || "http");
  const host = req.get("host");
  return host ? `${proto}://${host}` : `http://127.0.0.1:${port}`;
}

async function geocodePlace(query, country = "DE") {
  const result = await nominatimSearch(query, { countrycodes: country, limit: 1 });
  if (!result?.length) return null;
  return { lat: Number(result[0].lat), lng: Number(result[0].lon) };
}

const NOMINATIM_UA = "LuckysTaxiApp/1.0 (https://luckystaxiapp.de; kontakt@luckystaxiapp.de)";
const NOMINATIM_BASE = String(process.env.GEOCODING_BASE_URL || "https://nominatim.openstreetmap.org").replace(/\/$/, "");
let nominatimChain = Promise.resolve();
let nominatimLastAt = 0;

/** Serialisiert Anfragen und hält ≤1/s an den öffentlichen Nominatim-Dienst (Policy). */
function enqueueNominatim(fn) {
  const run = nominatimChain.then(async () => {
    const wait = Math.max(0, 1100 - (Date.now() - nominatimLastAt));
    if (wait) await new Promise((r) => setTimeout(r, wait));
    nominatimLastAt = Date.now();
    return fn();
  });
  nominatimChain = run.then(
    () => undefined,
    () => undefined
  );
  return run;
}

async function nominatimFetch(path, params) {
  const url = new URL(`${NOMINATIM_BASE}${path}`);
  Object.entries(params).forEach(([k, v]) => {
    if (v != null && v !== "") url.searchParams.set(k, String(v));
  });
  const response = await enqueueNominatim(() =>
    fetch(url, {
      headers: {
        Accept: "application/json",
        "User-Agent": NOMINATIM_UA,
      },
    })
  );
  if (!response.ok) {
    const err = new Error(`Geocoding HTTP ${response.status}`);
    err.status = response.status;
    throw err;
  }
  return response.json();
}

async function nominatimSearch(query, { countrycodes = "de", limit = 1 } = {}) {
  const q = String(query || "").trim().slice(0, 200);
  if (q.length < 3) return [];
  const data = await nominatimFetch("/search", {
    format: "json",
    limit: Math.min(Number(limit) || 1, 3),
    countrycodes: String(countrycodes || "de").toLowerCase(),
    q,
    addressdetails: 0,
  });
  return Array.isArray(data) ? data : [];
}

async function nominatimReverse(lat, lon) {
  const latitude = Number(lat);
  const longitude = Number(lon);
  if (!Number.isFinite(latitude) || !Number.isFinite(longitude)) return null;
  if (Math.abs(latitude) > 90 || Math.abs(longitude) > 180) return null;
  return nominatimFetch("/reverse", {
    format: "json",
    lat: latitude.toFixed(6),
    lon: longitude.toFixed(6),
    addressdetails: 1,
    "accept-language": "de",
    zoom: 18,
  });
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
    stripeConnectAccountId: req.body.stripeConnectAccountId,
    slug: req.body.slug,
    brandPrimaryColor: req.body.brandPrimaryColor,
    brandAccentColor: req.body.brandAccentColor,
    logoUrl: req.body.logoUrl,
    ...pickComplianceTextFields(req.body),
  };
}

const upload = createUploadMiddleware();

function filesFromRequest(req) {
  if (!req.files) return {};
  if (Array.isArray(req.files)) {
    const map = {};
    for (const f of req.files) {
      map[f.fieldname] = f;
    }
    return map;
  }
  const map = {};
  for (const [key, value] of Object.entries(req.files)) {
    map[key] = Array.isArray(value) ? value[0] : value;
  }
  return map;
}

function applyOperatorDocumentUploads(operator, req) {
  const files = filesFromRequest(req);
  if (!operator.documents) operator.documents = {};
  let changed = false;
  for (const field of OPERATOR_DOC_FIELDS) {
    const file = files[field];
    if (!file) continue;
    const prev = operator.documents[field];
    const meta = saveDocumentFile(dataDir, operator.operatorId, field, file);
    if (prev) deleteDocumentFile(dataDir, prev);
    operator.documents[field] = meta;
    changed = true;
  }
  return changed;
}

function applyDriverDocumentUploads(driver, operatorId, req) {
  const files = filesFromRequest(req);
  if (!driver.documents) driver.documents = {};
  let changed = false;
  for (const field of DRIVER_DOC_FIELDS) {
    const file = files[field];
    if (!file) continue;
    const prev = driver.documents[field];
    const meta = saveDocumentFile(dataDir, operatorId || "drivers", `driver-${field}`, file);
    if (prev) deleteDocumentFile(dataDir, prev);
    driver.documents[field] = meta;
    changed = true;
  }
  return changed;
}

function driverCompliancePublic(driver) {
  const docs = driver.documents || {};
  const docMeta = (m) =>
    m && m.id
      ? {
          present: true,
          id: m.id,
          originalName: m.originalName || "",
          mimeType: m.mimeType || "",
          uploadedAt: m.uploadedAt || null,
        }
      : { present: false };
  return {
    taxiNumber: driver.taxiNumber || "",
    pScheinNumber: driver.pScheinNumber || "",
    pScheinValidUntil: driver.pScheinValidUntil || "",
    licenseNumber: driver.licenseNumber || "",
    documents: {
      pScheinDocument: docMeta(docs.pScheinDocument),
      licenseDocument: docMeta(docs.licenseDocument),
      photo: docMeta(docs.photo),
    },
  };
}

function createDriverFromBody(body, operator, req, { status = "available" } = {}) {
  const name = String(body.name || body.driverName || "").trim();
  const phone = String(body.phone || body.driverPhone || "").trim();
  if (!name || !phone) return null;

  const driver = {
    driverId: crypto.randomUUID(),
    name,
    phone,
    vehicle: String(body.vehicle || body.driverVehicle || "").trim(),
    taxiNumber: String(body.taxiNumber || body.driverTaxiNumber || "").trim(),
    pScheinNumber: String(body.pScheinNumber || body.driverPScheinNumber || "").trim(),
    pScheinValidUntil: String(body.pScheinValidUntil || body.driverPScheinValidUntil || "").trim(),
    licenseNumber: String(body.licenseNumber || body.driverLicenseNumber || "").trim(),
    documents: {},
    status: DRIVER_STATUSES.has(status) ? status : "available",
    trackingPin: generateTrackingPin(),
    activeBookingId: null,
    lastLat: null,
    lastLng: null,
    lastLocationAt: null,
    registeredAt: new Date().toISOString(),
    ...(operator ? { operatorId: operator.operatorId } : {}),
  };

  if (req) {
    const files = filesFromRequest(req);
    const mapped = {};
    if (files.driverPScheinDocument) mapped.pScheinDocument = files.driverPScheinDocument;
    if (files.driverLicenseDocument) mapped.licenseDocument = files.driverLicenseDocument;
    if (files.driverPhoto) mapped.photo = files.driverPhoto;
    if (files.pScheinDocument && !mapped.pScheinDocument) mapped.pScheinDocument = files.pScheinDocument;
    if (files.licenseDocument && !mapped.licenseDocument) mapped.licenseDocument = files.licenseDocument;
    if (files.photo && !mapped.photo) mapped.photo = files.photo;
    const fakeReq = { files: mapped };
    applyDriverDocumentUploads(driver, operator?.operatorId, fakeReq);
  }

  return driver;
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
      from: resendFromEmail,
      to: [operator.legalEmail],
      subject: `Ihr Zugang — ${operator.companyName}`,
      text: [
        `Willkommen bei Luckys Taxi App (Code & Grow), ${operator.companyName}!`,
        "",
        "Ihre Links:",
        `Leitstelle: ${links.dispatch}`,
        `Einstellungen: ${links.settings}`,
        `Online-Buchung: ${links.book}`,
        `QR-Code: ${links.qr}`,
        "",
        operator.dispatchPin
          ? `Leitstellen-PIN (bitte ändern): ${operator.dispatchPin}`
          : "Bitte dispatchPin in den Einstellungen setzen.",
        "Fahrer unter Einstellungen anlegen.",
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
      from: resendFromEmail,
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
} else if (requireAdminPin) {
  console.error(
    "KRITISCH: ADMIN_PIN fehlt auf Render — Admin-/Leitstellen-Schreib-APIs antworten mit 503."
  );
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
const DRIVER_STATUSES = new Set(["available", "busy", "offline", "pending"]);
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

/** Plattform-Admin MFA (TOTP) — nur ADMIN_PIN, nicht Betriebs-PIN. */
const adminMfaPath = path.join(dataDir, "admin-mfa.json");
const adminSessionsPath = path.join(dataDir, "admin-sessions.json");
const ADMIN_SESSION_TTL_MS = 12 * 60 * 60 * 1000;
/** @type {Map<string, { expires: number }>} */
const adminSessions = new Map();

function loadAdminMfa() {
  try {
    if (!fs.existsSync(adminMfaPath)) {
      return { enabled: false, secret: null, enabledAt: null, pendingSecret: null };
    }
    const raw = JSON.parse(fs.readFileSync(adminMfaPath, "utf8"));
    return {
      enabled: Boolean(raw.enabled && raw.secret),
      secret: raw.secret ? String(raw.secret) : null,
      enabledAt: raw.enabledAt || null,
      pendingSecret: raw.pendingSecret ? String(raw.pendingSecret) : null,
    };
  } catch {
    return { enabled: false, secret: null, enabledAt: null, pendingSecret: null };
  }
}

function saveAdminMfa(state) {
  fs.writeFileSync(adminMfaPath, `${JSON.stringify(state, null, 2)}\n`, "utf8");
}

function loadAdminSessionsFromDisk() {
  try {
    if (!fs.existsSync(adminSessionsPath)) return;
    const raw = JSON.parse(fs.readFileSync(adminSessionsPath, "utf8"));
    const now = Date.now();
    for (const [token, meta] of Object.entries(raw.sessions || {})) {
      if (meta && Number(meta.expires) > now) {
        adminSessions.set(token, { expires: Number(meta.expires) });
      }
    }
  } catch {
    /* ignore */
  }
}

function saveAdminSessionsToDisk() {
  purgeExpiredAdminSessions();
  const sessions = {};
  for (const [token, meta] of adminSessions.entries()) {
    sessions[token] = { expires: meta.expires };
  }
  fs.writeFileSync(
    adminSessionsPath,
    `${JSON.stringify({ sessions }, null, 2)}\n`,
    "utf8"
  );
}

let adminMfa = loadAdminMfa();
loadAdminSessionsFromDisk();

function createAdminSession() {
  const token = crypto.randomBytes(32).toString("hex");
  adminSessions.set(token, { expires: Date.now() + ADMIN_SESSION_TTL_MS });
  saveAdminSessionsToDisk();
  return token;
}

function purgeExpiredAdminSessions() {
  const now = Date.now();
  for (const [token, meta] of adminSessions.entries()) {
    if (!meta || meta.expires <= now) adminSessions.delete(token);
  }
}

function isValidAdminSession(token) {
  if (!token) return false;
  purgeExpiredAdminSessions();
  let meta = adminSessions.get(token);
  if (!meta) {
    // Andere Render-Instanz / frischer Worker: Sessions von Disk nachladen.
    loadAdminSessionsFromDisk();
    meta = adminSessions.get(token);
  }
  return Boolean(meta && meta.expires > Date.now());
}

function isPlatformAdminPin(pin) {
  return Boolean(adminPin && pin && pin === adminPin);
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
    platformCompanyName: tenantConfig.platformCompanyName || "Code & Grow",
    platformStreet: tenantConfig.platformStreet || "",
    platformCity: tenantConfig.platformCity || "",
    platformOwner: tenantConfig.platformOwner || "",
    platformEmail: tenantConfig.platformEmail || "kontakt@luckystaxiapp.de",
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
  if (!driverId) return null;
  return drivers.find((d) => d.driverId === driverId || d.firebaseUid === driverId) || null;
}

function findDriverByFirebaseUid(firebaseUid) {
  const uid = String(firebaseUid || "").trim();
  if (!uid) return null;
  return drivers.find((d) => d.firebaseUid === uid) || null;
}

/** Fleet-Fahrer für Firebase-Auth-UID anlegen oder wiederverwenden (Tracking-Brücke). */
function ensureAppDriverFromFirebase({ firebaseUid, name, req }) {
  const uid = String(firebaseUid || "").trim();
  if (!uid) return null;

  let driver = findDriverByFirebaseUid(uid);
  const displayName = String(name || "").trim() || "Fahrer";
  const operator = resolveFleetOperatorFromRequest(req) || defaultFleetOperator();

  if (!driver) {
    driver = {
      driverId: crypto.randomUUID(),
      name: displayName,
      phone: "fahrer-app",
      vehicle: "Taxi (App)",
      status: "available",
      trackingPin: generateTrackingPin(),
      firebaseUid: uid,
      activeBookingId: null,
      lastLat: null,
      lastLng: null,
      lastLocationAt: null,
      ...(operator ? { operatorId: operator.operatorId } : {}),
    };
    drivers.push(driver);
  } else {
    driver.name = displayName;
    driver.firebaseUid = uid;
    if (operator && !driver.operatorId) {
      driver.operatorId = operator.operatorId;
    }
    ensureDriverTrackingFields(driver);
  }

  saveDriversConfig();
  return driver;
}

function driverOwnsBooking(booking, firebaseUid) {
  const uid = String(firebaseUid || "").trim();
  if (!booking || !uid) return false;
  if (booking.assignedDriverId === uid) return true;
  if (booking.assignedFirebaseUid === uid) return true;
  const driver = findDriver(booking.assignedDriverId);
  return Boolean(driver && driver.firebaseUid === uid);
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
  if (!booking) return;
  if (booking.assignedDriverId) {
    releaseDriver(booking.assignedDriverId);
  }
  if (booking.assignedFirebaseUid) {
    const byUid = findDriverByFirebaseUid(booking.assignedFirebaseUid);
    if (byUid) releaseDriver(byUid.driverId);
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
        ...(driver.firebaseUid ? { firebaseUid: driver.firebaseUid } : {}),
        ...(driver.operatorId ? { operatorId: driver.operatorId } : {}),
      };
    }),
  };
  fs.writeFileSync(driversConfigPath, `${JSON.stringify(payload, null, 2)}\n`, "utf8");
}

/** Fahrer-App: Bearer oder X-Driver-Key muss DRIVER_API_KEY treffen. */
function requireDriverApp(req, res, next) {
  if (!driverApiKey) {
    return res.status(503).json({ error: "DRIVER_API_KEY not configured" });
  }
  const header = String(req.headers.authorization || "");
  const bearer = header.startsWith("Bearer ") ? header.slice(7).trim() : "";
  const keyHeader = String(req.headers["x-driver-key"] || "").trim();
  const key = bearer || keyHeader;
  if (key && key === driverApiKey) return next();
  return res.status(401).json({ error: "Unauthorized — DRIVER_API_KEY required" });
}

function requireAdmin(req, res, next) {
  if (requireAdminPin && !adminPin) {
    return res.status(503).json({
      error: "ADMIN_PIN missing — set ADMIN_PIN on Render before using admin APIs",
    });
  }
  if (!authRequiredForRequest(req)) return next();
  const header = String(req.headers.authorization || "");
  const bearer = header.startsWith("Bearer ") ? header.slice(7).trim() : "";
  const pinHeader = String(req.headers["x-admin-pin"] || "").trim();
  const bodyPin = String(req.body?.pin || "").trim();

  if (isValidAdminSession(bearer) || isValidAdminSession(pinHeader)) return next();

  // Session kann nach Deploy tot sein — PIN aus Header, Bearer oder Body.
  const pin =
    (bodyPin && verifyRequestPin(req, bodyPin) && bodyPin) ||
    (pinHeader && verifyRequestPin(req, pinHeader) && pinHeader) ||
    (bearer && verifyRequestPin(req, bearer) && bearer) ||
    "";
  if (!pin) {
    return res.status(401).json({ error: "Unauthorized — PIN required" });
  }

  adminMfa = loadAdminMfa();
  // Plattform-ADMIN_PIN bei aktivem MFA: Session nach TOTP nötig (Betriebs-PIN unberührt).
  if (isPlatformAdminPin(pin) && adminMfa.enabled) {
    return res.status(401).json({
      error: "MFA erforderlich — bitte erneut anmelden und Authenticator-Code eingeben.",
      mfaRequired: true,
    });
  }

  return next();
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
        const billingRecord = {
          planId: planId || "unknown",
          email,
          companyName,
          stripeCustomerId: session.customer ? String(session.customer) : null,
          stripeSubscriptionId: session.subscription ? String(session.subscription) : null,
          status: "active",
        };
        upsertOperator(billingRecord);
        try {
          await provisionFleetFromSubscription(billingRecord);
        } catch (error) {
          console.error("Fleet-Provision nach Checkout fehlgeschlagen:", error.message);
        }
        console.log(`Abo gestartet: ${planId} · ${email}`);
        break;
      }
      case "customer.subscription.updated":
      case "customer.subscription.deleted": {
        const subscription = event.data.object;
        const existing =
          findOperatorBySubscription(subscription.id) ||
          findOperatorByCustomer(String(subscription.customer || ""));
        const billingRecord = {
          planId: existing?.planId || String(subscription.metadata?.planId || "unknown"),
          email: existing?.email || "",
          companyName: existing?.companyName || "",
          stripeCustomerId: String(subscription.customer || existing?.stripeCustomerId || ""),
          stripeSubscriptionId: subscription.id,
          status: subscription.status || "unknown",
        };
        upsertOperator(billingRecord);
        try {
          if (["active", "trialing"].includes(String(subscription.status))) {
            await provisionFleetFromSubscription(billingRecord);
          } else if (["canceled", "unpaid", "incomplete_expired"].includes(String(subscription.status))) {
            const fleetOp =
              fleet.findByStripeSubscription(subscription.id) ||
              fleet.findByStripeCustomer(String(subscription.customer || ""));
            if (fleetOp) {
              fleet.updateOperator(fleetOp.slug, { status: "suspended" });
              console.log(`Fleet-Mandant pausiert: ${fleetOp.slug}`);
            }
          }
        } catch (error) {
          console.error("Fleet-Sync nach Subscription-Update:", error.message);
        }
        break;
      }
      case "invoice.paid":
      case "invoice.payment_failed": {
        const invoice = event.data.object;
        console.log(`Rechnung ${event.type}: ${invoice.id} · ${invoice.customer_email || "—"}`);
        break;
      }
      case "payment_intent.succeeded": {
        const intent = event.data.object;
        const bookingId = String(intent.metadata?.bookingId || "").trim();
        const booking = bookingId ? findBooking(bookingId) : null;
        if (booking) {
          markBookingPaid(booking, intent.id);
          saveBookings();
          console.log(`Fahrgastzahlung OK: ${bookingId} · ${intent.id}`);
        } else {
          console.log(`payment_intent.succeeded ohne Buchung: ${intent.id}`);
        }
        break;
      }
      case "payment_intent.payment_failed": {
        const intent = event.data.object;
        const bookingId = String(intent.metadata?.bookingId || "").trim();
        const booking = bookingId ? findBooking(bookingId) : null;
        if (booking && booking.paymentStatus !== "paid") {
          booking.paymentStatus = "failed";
          booking.updatedAt = new Date().toISOString();
          saveBookings();
        }
        break;
      }
      case "account.updated": {
        const account = event.data.object;
        const accountId = String(account.id || "").trim();
        const slug = String(account.metadata?.operatorSlug || "").trim().toLowerCase();
        let fleetOp =
          (slug && fleet.findBySlug(slug)) ||
          fleet.list(true).find((op) => String(op.stripeConnectAccountId || "") === accountId);
        if (fleetOp && accountId) {
          if (!fleetOp.stripeConnectAccountId) {
            fleet.updateOperator(fleetOp.slug, { stripeConnectAccountId: accountId });
          }
          console.log(
            `Connect account.updated: ${fleetOp.slug} · charges=${account.charges_enabled} · payouts=${account.payouts_enabled}`
          );
        }
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

/** Einfaches Rate-Limit für PIN-Prüfungen (Brute-Force). */
const authVerifyAttempts = new Map();
const AUTH_VERIFY_WINDOW_MS = 15 * 60 * 1000;
const AUTH_VERIFY_MAX = 12;

function clientIp(req) {
  const xf = String(req.headers["x-forwarded-for"] || "")
    .split(",")[0]
    .trim();
  return xf || req.socket?.remoteAddress || "unknown";
}

function consumeAuthAttempt(ip) {
  const now = Date.now();
  let entry = authVerifyAttempts.get(ip);
  if (!entry || now - entry.start > AUTH_VERIFY_WINDOW_MS) {
    entry = { start: now, count: 0 };
  }
  entry.count += 1;
  authVerifyAttempts.set(ip, entry);
  return entry.count <= AUTH_VERIFY_MAX;
}

app.post("/api/auth/verify", (req, res) => {
  const ip = clientIp(req);
  if (!consumeAuthAttempt(ip)) {
    return res.status(429).json({
      error: "Zu viele Anmeldeversuche — bitte später erneut versuchen.",
    });
  }
  if (!authRequiredForRequest(req)) {
    return res.json({ ok: true, mfaEnabled: false, sessionToken: null });
  }
  const pin = String(req.body.pin || "").trim();
  const totp = String(req.body.totp || req.body.code || "").trim();
  if (pin.length < 4) {
    return res.status(401).json({ error: "PIN ungültig" });
  }
  if (!verifyRequestPin(req, pin)) {
    return res.status(401).json({ error: "PIN ungültig" });
  }

  // Betriebs-PIN (Leitstelle): kein MFA, kein Session-Token.
  if (!isPlatformAdminPin(pin)) {
    return res.json({ ok: true, mfaEnabled: false, sessionToken: null, role: "operator" });
  }

  adminMfa = loadAdminMfa();

  if (adminMfa.enabled) {
    if (!totp) {
      return res.status(401).json({
        error: "Authenticator-Code erforderlich",
        mfaRequired: true,
        mfaEnabled: true,
      });
    }
    if (!verifyTotp(adminMfa.secret, totp)) {
      return res.status(401).json({
        error: "Authenticator-Code ungültig",
        mfaRequired: true,
        mfaEnabled: true,
      });
    }
    const sessionToken = createAdminSession();
    return res.json({
      ok: true,
      mfaEnabled: true,
      sessionToken,
      role: "admin",
    });
  }

  // MFA noch nicht aktiv: Admin mit PIN nutzen; Setup optional (nicht blockierend).
  const sessionToken = createAdminSession();
  return res.json({
    ok: true,
    mfaEnabled: false,
    mfaSetupRequired: false,
    mfaSetupOptional: true,
    sessionToken,
    role: "admin",
  });
});

app.get("/api/auth/mfa/status", requireAdmin, (_req, res) => {
  res.json({
    enabled: Boolean(adminMfa.enabled),
    enabledAt: adminMfa.enabledAt || null,
  });
});

/** QR/Secret für Authenticator — Session nach PIN-Login nötig. */
app.post("/api/auth/mfa/setup", requireAdmin, async (req, res) => {
  if (!adminPin) {
    return res.status(503).json({ error: "ADMIN_PIN not configured" });
  }
  // Immer frisch von Disk (Render kann mehrere Instanzen haben).
  adminMfa = loadAdminMfa();
  if (adminMfa.enabled) {
    return res.status(400).json({ error: "MFA ist bereits aktiv" });
  }
  // Pending-Secret stabil halten — sonst wechselt der QR und App-Codes passen nie.
  // Neuer QR nur bei explizitem reset:true („Neuen QR erzeugen“).
  const forceNew = Boolean(req.body?.reset || req.query?.reset);
  if (forceNew || !adminMfa.pendingSecret) {
    adminMfa.pendingSecret = generateSecret();
    saveAdminMfa(adminMfa);
  }
  const secret = adminMfa.pendingSecret;
  const url = otpauthUrl({
    secret,
    accountName: "Luckys Admin",
    issuer: "Luckys Taxi App",
  });
  let qrDataUrl = "";
  try {
    qrDataUrl = await QRCode.toDataURL(url, {
      errorCorrectionLevel: "M",
      margin: 2,
      width: 200,
    });
  } catch (err) {
    console.warn("MFA QR-Erzeugung fehlgeschlagen:", err.message);
  }
  res.json({
    secret,
    otpauthUrl: url,
    qrDataUrl,
    reused: Boolean(!forceNew && adminMfa.pendingSecret),
    serverTime: new Date().toISOString(),
  });
});

app.post("/api/auth/mfa/confirm", requireAdmin, (req, res) => {
  adminMfa = loadAdminMfa();
  if (adminMfa.enabled) {
    return res.status(400).json({ error: "MFA ist bereits aktiv" });
  }

  const totp = String(req.body.totp || req.body.code || "")
    .replace(/\D/g, "")
    .slice(0, 6);
  if (!/^\d{6}$/.test(totp)) {
    return res.status(400).json({
      error: "Bitte genau 6 Ziffern aus der Authenticator-App eingeben.",
    });
  }

  // Quelle der Wahrheit: Secret vom aktuellen QR auf dem Bildschirm.
  // So funktioniert Confirm auch, wenn Setup auf einer anderen Render-Instanz
  // lief oder die ephemeral Disk den Pending-Secret verloren hat.
  const fromBody = String(req.body.secret || "")
    .toUpperCase()
    .replace(/[^A-Z2-7]/g, "");
  const fromDisk = String(adminMfa.pendingSecret || "")
    .toUpperCase()
    .replace(/[^A-Z2-7]/g, "");
  const secret = fromBody || fromDisk;
  if (!secret) {
    return res.status(400).json({
      error: "Kein MFA-Secret — bitte „Neuen QR erzeugen“, scannen und Code eingeben.",
    });
  }

  if (!verifyTotp(secret, totp, 4)) {
    console.warn("MFA-Confirm: TOTP mismatch", {
      secretLen: secret.length,
      fromBody: Boolean(fromBody),
      fromDisk: Boolean(fromDisk),
      same: fromBody === fromDisk || !fromBody || !fromDisk,
    });
    return res.status(400).json({
      error:
        "Authenticator-Code ungültig oder abgelaufen. Neuen Code aus der App nehmen (nicht den PIN). Tipp: Alten Eintrag löschen → Neuen QR erzeugen → sofort scannen → Code tippen.",
    });
  }

  adminMfa = {
    enabled: true,
    secret,
    enabledAt: new Date().toISOString(),
    pendingSecret: null,
  };
  saveAdminMfa(adminMfa);
  const sessionToken = createAdminSession();
  console.log("Admin-MFA aktiviert (TOTP).");
  res.json({ ok: true, mfaEnabled: true, sessionToken });
});

app.post("/api/auth/mfa/disable", requireAdmin, (req, res) => {
  if (!adminMfa.enabled) {
    return res.json({ ok: true, mfaEnabled: false });
  }
  const totp = String(req.body.totp || req.body.code || "").trim();
  if (!verifyTotp(adminMfa.secret, totp)) {
    return res.status(400).json({ error: "Authenticator-Code ungültig" });
  }
  adminMfa = { enabled: false, secret: null, enabledAt: null, pendingSecret: null };
  saveAdminMfa(adminMfa);
  adminSessions.clear();
  saveAdminSessionsToDisk();
  console.log("Admin-MFA deaktiviert.");
  res.json({ ok: true, mfaEnabled: false });
});

app.get("/api/offering", (_req, res) => {
  res.json(offering);
});

app.get("/api/billing/config", (_req, res) => {
  res.json({
    enabled: isBillingConfigured(),
    trialDays: 14,
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
      metadata: { ...STRIPE_PRODUCT_META, planId, companyName, trialDays: "14" },
      subscription_data: {
        trial_period_days: 14,
        metadata: { ...STRIPE_PRODUCT_META, planId, companyName },
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

app.post("/api/billing/portal", async (req, res) => {
  if (!stripe) {
    return res.status(503).json({ error: "Stripe not configured" });
  }
  const email = String(req.body.email || "").trim().toLowerCase();
  if (!email || !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)) {
    return res.status(400).json({ error: "Valid email required" });
  }
  const billingOp =
    operators.find((op) => String(op.email || "").trim().toLowerCase() === email) || null;
  const fleetOp = fleet.findByBillingEmail(email);
  const customerId =
    String(billingOp?.stripeCustomerId || fleetOp?.stripeCustomerId || "").trim();
  if (!customerId) {
    return res.status(404).json({
      error: "Kein Stripe-Kunde zu dieser E-Mail — Kündigung per E-Mail an den Support.",
    });
  }
  try {
    const baseUrl = resolvePublicBaseUrl(req);
    const session = await stripe.billingPortal.sessions.create({
      customer: customerId,
      return_url: `${baseUrl}/kuendigung.html`,
    });
    res.json({ url: session.url });
  } catch (error) {
    console.error(error);
    res.status(500).json({ error: error.message || "Billing portal failed" });
  }
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

/** Geocoding-Proxy (Nominatim) — Browser spricht nicht mehr direkt mit OSM. */
app.get("/api/geocode", async (req, res) => {
  try {
    const q = String(req.query.q || req.query.query || "").trim();
    if (q.length < 3) return res.status(400).json({ error: "query too short" });
    const country = String(req.query.country || "de").slice(0, 8);
    const data = await nominatimSearch(q, { countrycodes: country, limit: 1 });
    if (!data.length) return res.status(404).json({ error: "not found" });
    res.json({
      latitude: Number(data[0].lat),
      longitude: Number(data[0].lon),
      attribution: "© OpenStreetMap contributors",
      provider: "nominatim",
    });
  } catch (err) {
    console.error("geocode", err.message);
    res.status(err.status === 429 ? 429 : 502).json({ error: "geocoding unavailable" });
  }
});

app.get("/api/geocode/reverse", async (req, res) => {
  try {
    const lat = Number(req.query.lat ?? req.query.latitude);
    const lon = Number(req.query.lon ?? req.query.lng ?? req.query.longitude);
    const data = await nominatimReverse(lat, lon);
    if (!data) return res.status(400).json({ error: "lat/lon required" });
    const addr = data.address || {};
    res.json({
      street: addr.road || addr.pedestrian || addr.footway || "",
      houseNumber: addr.house_number || "",
      postalCode: addr.postcode || "",
      city: addr.city || addr.town || addr.village || addr.municipality || "",
      formatted: data.display_name || "",
      attribution: "© OpenStreetMap contributors",
      provider: "nominatim",
    });
  } catch (err) {
    console.error("geocode/reverse", err.message);
    res.status(err.status === 429 ? 429 : 502).json({ error: "geocoding unavailable" });
  }
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

/** Logo-Datei hochladen (Admin) → speichert Datei und setzt logoUrl auf öffentliche URL. */
app.post(
  "/api/fleet/operators/:slug/logo",
  requireAdmin,
  (req, res, next) => {
    upload.single("logo")(req, res, (err) => {
      if (err) return res.status(400).json({ error: err.message || "Upload fehlgeschlagen" });
      next();
    });
  },
  (req, res) => {
    try {
      const slug = String(req.params.slug || "").trim().toLowerCase();
      const operator = fleet.findBySlug(slug);
      if (!operator) return res.status(404).json({ error: "Operator not found" });
      const file = req.file;
      if (!file) return res.status(400).json({ error: "logo file required (PNG oder JPEG)" });
      if (file.mimetype !== "image/jpeg" && file.mimetype !== "image/png") {
        return res.status(400).json({ error: "Logo nur als PNG oder JPEG" });
      }

      if (operator.logoDocument) {
        deleteDocumentFile(dataDir, operator.logoDocument);
      }
      const meta = saveDocumentFile(dataDir, operator.operatorId, "logo", file);
      const baseUrl = resolvePublicBaseUrl(req).replace(/\/$/, "");
      const logoUrl = `${baseUrl}/api/public/operators/${encodeURIComponent(slug)}/logo`;
      const updated = fleet.updateOperator(slug, {
        logoUrl,
        logoDocument: meta,
      });
      res.json({
        operator: fleet.toAdminSummary(updated, baseUrl),
        logoUrl,
      });
    } catch (error) {
      res.status(400).json({ error: error.message || "Logo-Upload fehlgeschlagen" });
    }
  }
);

/** Öffentliches Logo für Buchung / Branding (kein Admin-PIN). */
app.get("/api/public/operators/:slug/logo", (req, res) => {
  const slug = String(req.params.slug || "").trim().toLowerCase();
  const operator = fleet.findBySlug(slug);
  if (!operator) return res.status(404).json({ error: "Operator not found" });
  const meta = operator.logoDocument;
  if (meta?.relativePath) {
    const abs = resolveAbsolutePath(dataDir, meta.relativePath);
    if (!abs) return res.status(404).json({ error: "Logo file missing" });
    res.setHeader("Cache-Control", "public, max-age=3600");
    res.setHeader("Content-Type", meta.mimeType || "image/png");
    return fs.createReadStream(abs).pipe(res);
  }
  const external = String(operator.logoUrl || "").trim();
  if (/^https:\/\//i.test(external) && !external.includes("/api/public/operators/")) {
    return res.redirect(302, external);
  }
  return res.status(404).json({ error: "No logo" });
});

app.get("/api/fleet/operators.csv", requireAdmin, (req, res) => {
  const rows = [
    [
      "slug",
      "companyName",
      "status",
      "billingEmail",
      "centralPhone",
      "city",
      "planId",
      "logoUrl",
      "stripeConnectAccountId",
      "concessionNumber",
      "createdAt",
    ],
  ];
  for (const op of fleet.list(true)) {
    rows.push([
      op.slug || "",
      op.companyName || "",
      op.status || "",
      op.billingEmail || op.legalEmail || "",
      op.centralPhone || "",
      op.city || "",
      op.planId || "",
      op.logoUrl || "",
      op.stripeConnectAccountId || "",
      op.concessionNumber || "",
      op.createdAt || "",
    ]);
  }
  const csv = rows
    .map((cols) =>
      cols
        .map((cell) => {
          const s = String(cell ?? "");
          if (/[",\n\r]/.test(s)) return `"${s.replace(/"/g, '""')}"`;
          return s;
        })
        .join(",")
    )
    .join("\n");
  res.setHeader("Content-Type", "text/csv; charset=utf-8");
  res.setHeader(
    "Content-Disposition",
    `attachment; filename="luckys-mandanten-${new Date().toISOString().slice(0, 10)}.csv"`
  );
  res.send(`\uFEFF${csv}\n`);
});

app.delete("/api/fleet/operators/:slug", requireAdmin, (req, res) => {
  try {
    const slug = String(req.params.slug || "").trim().toLowerCase();
    const existing = fleet.findBySlug(slug);
    if (!existing) {
      return res.status(404).json({ error: "Operator not found" });
    }

    const docs = existing.documents || {};
    for (const meta of Object.values(docs)) {
      if (meta) deleteDocumentFile(dataDir, meta);
    }
    if (existing.logoDocument) {
      deleteDocumentFile(dataDir, existing.logoDocument);
    }

    const keptDrivers = [];
    for (const driver of drivers) {
      if (driver.operatorId === existing.operatorId) {
        const driverDocs = driver.documents || {};
        for (const meta of Object.values(driverDocs)) {
          if (meta) deleteDocumentFile(dataDir, meta);
        }
      } else {
        keptDrivers.push(driver);
      }
    }
    if (keptDrivers.length !== drivers.length) {
      drivers.length = 0;
      drivers.push(...keptDrivers);
      saveDriversConfig();
    }

    const removed = fleet.deleteOperator(slug);
    if (!removed) {
      return res.status(404).json({ error: "Operator not found" });
    }

    res.json({
      ok: true,
      deleted: {
        slug: removed.slug,
        companyName: removed.companyName,
        operatorId: removed.operatorId,
      },
    });
  } catch (error) {
    console.error(error);
    res.status(500).json({ error: error.message || "Delete failed" });
  }
});

app.get("/api/compliance", requireAdmin, (req, res) => {
  const operator = resolveFleetOperatorFromRequest(req);
  if (!operator) {
    return res.status(400).json({ error: "operator query required" });
  }
  const summary = fleet.complianceSummary(operator);
  const opDrivers = drivers
    .filter((d) => d.operatorId === operator.operatorId)
    .map((d) => ({
      driverId: d.driverId,
      name: d.name,
      phone: d.phone,
      vehicle: d.vehicle || "",
      status: d.status || "available",
      ...driverCompliancePublic(d),
    }));
  res.json({
    slug: operator.slug,
    operatorId: operator.operatorId,
    ...summary,
    complianceGaps: fleet.toAdminSummary(operator).complianceGaps,
    complianceComplete: fleet.toAdminSummary(operator).complianceComplete,
    drivers: opDrivers,
  });
});

app.patch(
  "/api/compliance",
  requireAdmin,
  (req, res, next) => {
    const contentType = String(req.headers["content-type"] || "");
    if (contentType.includes("multipart/form-data")) {
      return upload.fields([
        { name: "concessionDocument", maxCount: 1 },
        { name: "ownerPScheinDocument", maxCount: 1 },
      ])(req, res, (err) => {
        if (err) return res.status(400).json({ error: err.message || "Upload fehlgeschlagen" });
        next();
      });
    }
    next();
  },
  (req, res) => {
    const operator = resolveFleetOperatorFromRequest(req);
    if (!operator) {
      return res.status(400).json({ error: "operator query required" });
    }
    try {
      const patch = pickComplianceTextFields(req.body);
      applyOperatorDocumentUploads(operator, req);
      patch.documents = operator.documents;
      const updated = fleet.updateOperator(operator.slug, patch);
      res.json({
        ...fleet.complianceSummary(updated),
        complianceGaps: fleet.toAdminSummary(updated).complianceGaps,
        complianceComplete: fleet.toAdminSummary(updated).complianceComplete,
      });
    } catch (error) {
      res.status(400).json({ error: error.message || "Update failed" });
    }
  }
);

app.get("/api/fleet/operators/:slug/documents/:docKey", requireAdmin, (req, res) => {
  const operator = fleet.findBySlug(req.params.slug);
  if (!operator) return res.status(404).json({ error: "Operator not found" });
  const docKey = String(req.params.docKey || "").trim();
  if (!OPERATOR_DOC_FIELDS.includes(docKey)) {
    return res.status(400).json({ error: "Unknown document key" });
  }
  const meta = operator.documents?.[docKey];
  if (!meta?.relativePath) return res.status(404).json({ error: "Document not found" });
  const abs = resolveAbsolutePath(dataDir, meta.relativePath);
  if (!abs) return res.status(404).json({ error: "Document file missing" });
  res.setHeader("Content-Type", meta.mimeType || "application/octet-stream");
  res.setHeader(
    "Content-Disposition",
    `inline; filename="${encodeURIComponent(meta.originalName || docKey)}"`
  );
  fs.createReadStream(abs).pipe(res);
});

app.get("/api/drivers/:id/documents/:docKey", requireAdmin, (req, res) => {
  const driver = findDriver(req.params.id);
  if (!driver) {
    return res.status(404).json({ error: "Driver not found" });
  }
  const scopedOperator = resolveFleetOperatorFromRequest(req);
  if (scopedOperator && driver.operatorId !== scopedOperator.operatorId) {
    return res.status(404).json({ error: "Driver not found" });
  }
  const docKey = String(req.params.docKey || "").trim();
  if (!DRIVER_DOC_FIELDS.includes(docKey)) {
    return res.status(400).json({ error: "Unknown document key" });
  }
  const meta = driver.documents?.[docKey];
  if (!meta?.relativePath) return res.status(404).json({ error: "Document not found" });
  const abs = resolveAbsolutePath(dataDir, meta.relativePath);
  if (!abs) return res.status(404).json({ error: "Document file missing" });
  res.setHeader("Content-Type", meta.mimeType || "application/octet-stream");
  res.setHeader(
    "Content-Disposition",
    `inline; filename="${encodeURIComponent(meta.originalName || docKey)}"`
  );
  fs.createReadStream(abs).pipe(res);
});

/** Stripe Connect Express: Onboarding-Link für Auszahlung + Plattformgebühr */
app.post("/api/fleet/operators/:slug/connect/onboard", requireAdmin, async (req, res) => {
  if (!stripe) {
    return res.status(503).json({ error: "Stripe not configured" });
  }
  const slug = String(req.params.slug || "").trim().toLowerCase();
  const operator = fleet.findBySlug(slug);
  if (!operator) {
    return res.status(404).json({ error: "Operator not found" });
  }

  try {
    let accountId = String(operator.stripeConnectAccountId || "").trim();
    if (!accountId) {
      const account = await stripe.accounts.create({
        type: "express",
        country: String(operator.country || "DE").toUpperCase() || "DE",
        email: String(operator.billingEmail || operator.legalEmail || "").trim() || undefined,
        capabilities: {
          card_payments: { requested: true },
          transfers: { requested: true },
        },
        business_profile: {
          name: operator.companyName,
          product_description: "Taxi-Fahrten — Auszahlung über Luckys Taxi App / Code & Grow",
        },
        metadata: {
          ...STRIPE_PRODUCT_META,
          operatorSlug: operator.slug,
          operatorId: operator.operatorId,
        },
      });
      accountId = account.id;
      fleet.updateOperator(slug, { stripeConnectAccountId: accountId });
    }

    const baseUrl = resolvePublicBaseUrl(req);
    const accountLink = await stripe.accountLinks.create({
      account: accountId,
      refresh_url: `${baseUrl}/admin.html?connect=refresh&o=${encodeURIComponent(slug)}`,
      return_url: `${baseUrl}/admin.html?connect=return&o=${encodeURIComponent(slug)}`,
      type: "account_onboarding",
    });

    res.json({
      url: accountLink.url,
      accountId,
      expiresAt: accountLink.expires_at,
    });
  } catch (error) {
    console.error("Connect onboard:", error);
    res.status(500).json({
      error:
        error.message ||
        "Connect-Onboarding fehlgeschlagen — in Stripe Dashboard Connect aktivieren?",
    });
  }
});

app.get("/api/fleet/operators/:slug/connect/status", requireAdmin, async (req, res) => {
  if (!stripe) {
    return res.status(503).json({ error: "Stripe not configured" });
  }
  const slug = String(req.params.slug || "").trim().toLowerCase();
  const operator = fleet.findBySlug(slug);
  if (!operator) {
    return res.status(404).json({ error: "Operator not found" });
  }
  const accountId = String(operator.stripeConnectAccountId || "").trim();
  if (!accountId) {
    return res.json({
      connected: false,
      chargesEnabled: false,
      payoutsEnabled: false,
      detailsSubmitted: false,
      accountId: null,
    });
  }
  try {
    const account = await stripe.accounts.retrieve(accountId);
    res.json({
      connected: true,
      accountId,
      chargesEnabled: Boolean(account.charges_enabled),
      payoutsEnabled: Boolean(account.payouts_enabled),
      detailsSubmitted: Boolean(account.details_submitted),
      requirementsDue: account.requirements?.currently_due || [],
    });
  } catch (error) {
    res.status(500).json({ error: error.message || "Connect status failed" });
  }
});

app.post(
  "/api/fleet/register",
  (req, res, next) => {
    const contentType = String(req.headers["content-type"] || "");
    if (contentType.includes("multipart/form-data")) {
      return upload.fields([
        { name: "concessionDocument", maxCount: 1 },
        { name: "ownerPScheinDocument", maxCount: 1 },
        { name: "driverPScheinDocument", maxCount: 1 },
        { name: "driverLicenseDocument", maxCount: 1 },
        { name: "pScheinDocument", maxCount: 1 },
        { name: "licenseDocument", maxCount: 1 },
      ])(req, res, (err) => {
        if (err) return res.status(400).json({ error: err.message || "Upload fehlgeschlagen" });
        next();
      });
    }
    next();
  },
  async (req, res) => {
    try {
      const input = await prepareFleetOperatorBody(req);
      input.status = "pending";
      input.planId = String(req.body.planId || "fleet").trim().toLowerCase();

      const operator = fleet.createOperator(input);
      applyOperatorDocumentUploads(operator, req);
      fleet.updateOperator(operator.slug, { documents: operator.documents });

      const driverPayload = {
        name: req.body.driverName,
        phone: req.body.driverPhone,
        vehicle: req.body.driverVehicle,
        taxiNumber: req.body.driverTaxiNumber,
        pScheinNumber: req.body.driverPScheinNumber,
        pScheinValidUntil: req.body.driverPScheinValidUntil,
        licenseNumber: req.body.driverLicenseNumber,
      };
      const firstDriver = createDriverFromBody(driverPayload, operator, req);
      if (firstDriver) {
        drivers.push(firstDriver);
        saveDriversConfig();
      }

      const gaps = fleet.toAdminSummary(operator).complianceGaps || [];
      if (resendApiKey && contactNotifyEmail) {
        await sendContactNotification({
          inquiryId: `lead-${operator.slug}`,
          planId: operator.planId || "fleet",
          email: operator.legalEmail || "keine E-Mail",
          companyName: operator.companyName,
          message: `Neue Registrierungsanfrage (pending). Slug: ${operator.slug}. PLZ: ${(operator.serviceArea?.postalPrefixes || []).join(", ")}. Konzession: ${operator.concessionNumber || "—"}. Fehlend: ${gaps.join(", ") || "nichts"}.${firstDriver ? ` Erster Fahrer: ${firstDriver.name}.` : ""}`,
          createdAt: new Date().toISOString(),
        });
      } else {
        console.log(
          `Neue Registrierungsanfrage (pending): ${operator.companyName} (${operator.slug}) · Konzession ${operator.concessionNumber || "—"}`
        );
      }

      res.status(201).json({
        operator: fleet.toPublicSummary(operator),
        message:
          "Anfrage eingegangen. Wir prüfen Ihre Konzession und Fahrer-Nachweise und schalten Ihren Betrieb frei.",
      });
    } catch (error) {
      res.status(400).json({ error: error.message || "Registration failed" });
    }
  }
);

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
  const list = filterDriversForRequest(req).map((d) => {
    const { documents, ...rest } = d;
    return {
      ...rest,
      ...driverCompliancePublic(d),
      locationFresh: driverHasFreshLocation(d),
    };
  });
  res.json({ drivers: list });
});

/** Öffentliche Fahrer-Selbstregistrierung (P-Schein + Foto) für einen Betrieb */
app.post(
  "/api/drivers/register",
  (req, res, next) => {
    upload.fields([
      { name: "photo", maxCount: 1 },
      { name: "pScheinDocument", maxCount: 1 },
      { name: "licenseDocument", maxCount: 1 },
    ])(req, res, (err) => {
      if (err) return res.status(400).json({ error: err.message || "Upload fehlgeschlagen" });
      next();
    });
  },
  (req, res) => {
    try {
      const operator =
        resolveFleetOperatorFromRequest(req) ||
        fleet.findBySlug(String(req.body.operator || req.body.o || "").trim());
      if (!operator || operator.status !== "active") {
        return res.status(400).json({
          error: "Betrieb nicht gefunden oder noch nicht freigeschaltet. Bitte Link mit ?o=betriebsname nutzen.",
        });
      }

      const name = String(req.body.name || "").trim();
      const phone = String(req.body.phone || "").trim();
      const pScheinNumber = String(req.body.pScheinNumber || "").trim();
      const taxiNumber = String(req.body.taxiNumber || "").trim();
      if (!name || !phone) {
        return res.status(400).json({ error: "Name und Handy erforderlich" });
      }
      if (!pScheinNumber) {
        return res.status(400).json({ error: "P-Schein-Nummer erforderlich" });
      }
      if (!taxiNumber) {
        return res.status(400).json({ error: "Taxinummer erforderlich" });
      }

      const files = filesFromRequest(req);
      if (!files.photo) {
        return res.status(400).json({ error: "Profilfoto erforderlich (JPEG/PNG)" });
      }
      if (!files.pScheinDocument) {
        return res.status(400).json({ error: "Scan/Foto vom P-Schein erforderlich" });
      }

      const limit = fleet.driverLimitFor(operator);
      if (limit !== null) {
        const count = drivers.filter((d) => d.operatorId === operator.operatorId).length;
        if (count >= limit) {
          return res.status(403).json({
            error: `Fahrer-Limit des Betriebs erreicht (${limit}). Bitte den Unternehmer kontaktieren.`,
          });
        }
      }

      const duplicate = drivers.find(
        (d) =>
          d.operatorId === operator.operatorId &&
          String(d.phone || "").replace(/\D/g, "") === phone.replace(/\D/g, "")
      );
      if (duplicate) {
        return res.status(409).json({
          error: "Mit dieser Handynummer ist bereits ein Fahrer für diesen Betrieb registriert.",
        });
      }

      const driver = createDriverFromBody(req.body, operator, req, { status: "pending" });
      if (!driver) {
        return res.status(400).json({ error: "Registrierung fehlgeschlagen" });
      }

      drivers.push(driver);
      saveDriversConfig();

      console.log(
        `Fahrer-Registrierung (pending): ${driver.name} · ${operator.companyName} (${operator.slug})`
      );

      res.status(201).json({
        ok: true,
        message:
          "Registrierung eingegangen. Der Betrieb prüft Ihre Daten (P-Schein, Foto) und schaltet Sie frei.",
        driver: {
          driverId: driver.driverId,
          name: driver.name,
          status: driver.status,
          companyName: operator.companyName,
        },
      });
    } catch (error) {
      res.status(400).json({ error: error.message || "Registrierung fehlgeschlagen" });
    }
  }
);

app.post(
  "/api/drivers",
  requireAdmin,
  (req, res, next) => {
    const contentType = String(req.headers["content-type"] || "");
    if (contentType.includes("multipart/form-data")) {
      return upload.fields([
        { name: "pScheinDocument", maxCount: 1 },
        { name: "licenseDocument", maxCount: 1 },
        { name: "photo", maxCount: 1 },
      ])(req, res, (err) => {
        if (err) return res.status(400).json({ error: err.message || "Upload fehlgeschlagen" });
        next();
      });
    }
    next();
  },
  (req, res) => {
    const name = String(req.body.name || "").trim();
    const phone = String(req.body.phone || "").trim();
    const vehicle = String(req.body.vehicle || "").trim();
    const compliance = pickDriverComplianceFields(req.body);

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
            error: `Fahrer-Limit erreicht (${limit} im Tarif ${operator.planId || "fleet"}). Bitte Tarif/Fahrzeuge erweitern.`,
          });
        }
      }
    }

    const driver = {
      driverId: crypto.randomUUID(),
      name,
      phone,
      vehicle,
      taxiNumber: compliance.taxiNumber || "",
      pScheinNumber: compliance.pScheinNumber || "",
      pScheinValidUntil: compliance.pScheinValidUntil || "",
      licenseNumber: compliance.licenseNumber || "",
      documents: {},
      status: "available",
      trackingPin: generateTrackingPin(),
      activeBookingId: null,
      lastLat: null,
      lastLng: null,
      lastLocationAt: null,
      registeredAt: new Date().toISOString(),
      ...(operator ? { operatorId: operator.operatorId } : {}),
    };

    applyDriverDocumentUploads(driver, operator?.operatorId, req);

    drivers.push(driver);
    saveDriversConfig();
    res.status(201).json({ ...driver, ...driverCompliancePublic(driver) });
  }
);

app.put(
  "/api/drivers/:id",
  requireAdmin,
  (req, res, next) => {
    const contentType = String(req.headers["content-type"] || "");
    if (contentType.includes("multipart/form-data")) {
      return upload.fields([
        { name: "pScheinDocument", maxCount: 1 },
        { name: "licenseDocument", maxCount: 1 },
        { name: "photo", maxCount: 1 },
      ])(req, res, (err) => {
        if (err) return res.status(400).json({ error: err.message || "Upload fehlgeschlagen" });
        next();
      });
    }
    next();
  },
  (req, res) => {
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
    if (req.body.status !== undefined) {
      const status = String(req.body.status).trim();
      if (DRIVER_STATUSES.has(status)) driver.status = status;
    }
    const compliance = pickDriverComplianceFields(req.body);
    Object.assign(driver, compliance);
    applyDriverDocumentUploads(driver, driver.operatorId, req);

    if (!driver.name || !driver.phone) {
      return res.status(400).json({ error: "name and phone required" });
    }

    saveDriversConfig();
    res.json({ ...driver, ...driverCompliancePublic(driver) });
  }
);

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
    paymentStatus: isCardPaymentMethod(req.body.paymentMethod) ? "awaiting_fare" : null,
    paymentIntentId: null,
    paymentAccessToken: null,
    mediationChannel: normalizeMediationChannel(req.body.mediationChannel || req.body.source || req.body.channel),
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

/**
 * Fahrer-App (ohne ADMIN_PIN): offene Buchungen + Annehmen / Abschließen.
 * Query: ?operator=mannheim (Slug)
 */
app.get("/api/driver/open-bookings", (req, res) => {
  const operator = resolveFleetOperatorFromRequest(req);
  if (fleet.enabled() && !operator) {
    return res.status(400).json({ error: "operator query required (z.B. ?operator=mannheim)" });
  }

  const open = filterBookingsForRequest(req).filter((booking) => {
    if (booking.assignedDriverId) return false;
    return booking.status === "confirmed" || booking.status === "accepted";
  });

  res.json({
    bookings: open.map((b) => ({
      bookingId: b.bookingId,
      pickupDate: b.pickupDate,
      addressLine: b.addressLine,
      destinationAddressLine: b.destinationAddressLine || null,
      paymentMethod: b.paymentMethod || null,
      latitude: b.latitude,
      longitude: b.longitude,
      status: b.status,
      createdAt: b.createdAt,
    })),
  });
});

app.patch("/api/driver/bookings/:id/accept", requireDriverApp, (req, res) => {
  const booking = findBooking(req.params.id);
  if (!booking) {
    return res.status(404).json({ error: "Booking not found" });
  }
  if (!bookingMatchesRequest(req, booking)) {
    return res.status(404).json({ error: "Booking not found" });
  }
  if (booking.assignedDriverId) {
    return res.status(409).json({ error: "Booking already assigned" });
  }
  if (booking.status !== "confirmed" && booking.status !== "accepted") {
    return res.status(400).json({ error: "Booking not open" });
  }

  const driverUid = String(req.body.driverUid || "").trim();
  const driverName = String(req.body.driverName || "Fahrer").trim() || "Fahrer";
  if (!driverUid) {
    return res.status(400).json({ error: "driverUid required" });
  }

  const fleetDriver = ensureAppDriverFromFirebase({
    firebaseUid: driverUid,
    name: driverName,
    req,
  });
  if (!fleetDriver) {
    return res.status(500).json({ error: "Could not link driver profile" });
  }

  booking.assignedDriverId = fleetDriver.driverId;
  booking.assignedFirebaseUid = driverUid;
  booking.assignedDriverName = driverName;
  booking.status = "assigned";
  booking.updatedAt = new Date().toISOString();
  fleetDriver.status = "busy";
  fleetDriver.activeBookingId = booking.bookingId;
  saveBookings();
  saveDriversConfig();
  console.log(
    `Fahrer-App: ${driverName} (${driverUid} → fleet ${fleetDriver.driverId}) hat ${booking.bookingId} angenommen`
  );
  res.json({
    ...booking,
    fleetDriverId: fleetDriver.driverId,
  });
});

app.patch("/api/driver/bookings/:id/complete", requireDriverApp, async (req, res) => {
  const booking = findBooking(req.params.id);
  if (!booking) {
    return res.status(404).json({ error: "Booking not found" });
  }
  if (!bookingMatchesRequest(req, booking)) {
    return res.status(404).json({ error: "Booking not found" });
  }

  const driverUid = String(req.body.driverUid || "").trim();
  if (!driverOwnsBooking(booking, driverUid)) {
    return res.status(403).json({ error: "Not your booking" });
  }

  const wantsCard = isCardPaymentMethod(booking.paymentMethod);
  const rawTotal = req.body.totalAmount;
  const hasTotal = rawTotal !== undefined && rawTotal !== null && String(rawTotal).trim() !== "";
  const totalEuros = hasTotal ? Number(String(rawTotal).replace(",", ".")) : NaN;
  const tipEuros =
    req.body.tipAmount !== undefined && req.body.tipAmount !== null && String(req.body.tipAmount).trim() !== ""
      ? Number(String(req.body.tipAmount).replace(",", "."))
      : Number(booking.tipAmount) || 0;

  if (wantsCard) {
    if (!Number.isFinite(totalEuros) || totalEuros < 0.5) {
      return res.status(400).json({
        error: "totalAmount required for card payment (EUR, min 0.50)",
      });
    }
  }

  if (Number.isFinite(totalEuros) && totalEuros >= 0) {
    booking.totalAmount = Math.round(totalEuros * 100) / 100;
    booking.tariffAmount = Math.max(0, Math.round((booking.totalAmount - (Number.isFinite(tipEuros) ? tipEuros : 0)) * 100) / 100);
    if (Number.isFinite(tipEuros) && tipEuros >= 0) {
      booking.tipAmount = Math.round(tipEuros * 100) / 100;
    }
  }

  releaseDriverFromBooking(booking);
  booking.status = "completed";
  booking.updatedAt = new Date().toISOString();

  let payUrl = null;
  if (wantsCard && Number.isFinite(booking.totalAmount) && booking.totalAmount >= 0.5) {
    if (!stripe) {
      booking.paymentStatus = "awaiting_fare";
      saveBookings();
      saveDriversConfig();
      return res.status(503).json({
        error: "Stripe not configured — Kartenzahlung nicht möglich",
        booking,
      });
    }
    try {
      const result = await ensureRidePaymentIntent(booking);
      payUrl = buildPayUrl(req, booking);
      if (result.alreadyPaid) {
        payUrl = null;
      }
    } catch (error) {
      console.error("complete+payment:", error);
      saveBookings();
      saveDriversConfig();
      return res.status(500).json({
        error: error.message || "PaymentIntent failed",
        booking,
      });
    }
  }

  saveBookings();
  saveDriversConfig();
  res.json({
    ...booking,
    payUrl,
  });
});

/** Fahrer-App sendet GPS (Auth: DRIVER_API_KEY + Firebase-UID). */
app.post("/api/driver/location", requireDriverApp, (req, res) => {
  const driverUid = String(req.body.driverUid || "").trim();
  if (!driverUid) {
    return res.status(400).json({ error: "driverUid required" });
  }

  const driver = findDriverByFirebaseUid(driverUid) || findDriver(driverUid);
  if (!driver) {
    return res.status(404).json({ error: "Driver not found — accept a booking first" });
  }

  const latitude = Number(req.body.latitude);
  const longitude = Number(req.body.longitude);
  if (!Number.isFinite(latitude) || !Number.isFinite(longitude)) {
    return res.status(400).json({ error: "latitude and longitude required" });
  }

  const bookingId = String(req.body.bookingId || "").trim();
  if (bookingId) {
    const booking = findBooking(bookingId);
    if (!booking || !driverOwnsBooking(booking, driverUid)) {
      return res.status(403).json({ error: "Not assigned to this booking" });
    }
  }

  driver.lastLat = latitude;
  driver.lastLng = longitude;
  driver.lastLocationAt = new Date().toISOString();
  if (driver.status === "offline") {
    driver.status = "busy";
  }
  if (bookingId) {
    driver.activeBookingId = bookingId;
  }
  saveDriversConfig();

  res.json({
    ok: true,
    driverId: driver.driverId,
    firebaseUid: driver.firebaseUid || null,
    activeBookingId: driver.activeBookingId || null,
    updatedAt: driver.lastLocationAt,
  });
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
  saveDriversConfig();

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

app.get("/api/stripe/config", (_req, res) => {
  res.json({
    paymentsEnabled: Boolean(stripe && stripePublishableKey),
    publishableKey: stripePublishableKey || null,
    terminalEnabled: isTerminalConfigured(),
    terminalLocationId: isTerminalConfigured() ? stripeTerminalLocationId : null,
  });
});

app.get("/api/terminal/config", requireDriverApp, (_req, res) => {
  res.json({
    enabled: isTerminalConfigured(),
    locationId: isTerminalConfigured() ? stripeTerminalLocationId : null,
    simulated: String(process.env.STRIPE_TERMINAL_SIMULATED || "").trim() === "1",
  });
});

app.post("/api/terminal/connection-token", requireDriverApp, async (_req, res) => {
  if (!stripe) {
    return res.status(503).json({ error: "Stripe not configured" });
  }
  try {
    const token = await stripe.terminal.connectionTokens.create();
    res.json({ secret: token.secret });
  } catch (error) {
    console.error("connection-token:", error);
    res.status(500).json({ error: error.message || "Connection token failed" });
  }
});

app.post("/api/driver/bookings/:id/tap-pay", requireDriverApp, async (req, res) => {
  if (!isTerminalConfigured()) {
    return res.status(503).json({
      error:
        "Tap to Pay nicht konfiguriert — STRIPE_TERMINAL_LOCATION_ID in Render setzen (Stripe → Terminal → Locations)",
    });
  }

  const booking = findBooking(req.params.id);
  if (!booking) {
    return res.status(404).json({ error: "Booking not found" });
  }
  if (!bookingMatchesRequest(req, booking)) {
    return res.status(404).json({ error: "Booking not found" });
  }

  const driverUid = String(req.body.driverUid || "").trim();
  if (!driverOwnsBooking(booking, driverUid)) {
    return res.status(403).json({ error: "Not your booking" });
  }

  const rawTotal = req.body.totalAmount;
  const totalEuros = Number(String(rawTotal ?? "").replace(",", "."));
  if (!Number.isFinite(totalEuros) || totalEuros < 0.5) {
    return res.status(400).json({ error: "totalAmount required (EUR, min 0.50)" });
  }

  booking.totalAmount = Math.round(totalEuros * 100) / 100;
  booking.paymentMethod = booking.paymentMethod || "Karte";
  booking.updatedAt = new Date().toISOString();

  try {
    const result = await ensureRidePaymentIntent(booking, { channel: "terminal" });
    if (result.alreadyPaid) {
      return res.json({
        alreadyPaid: true,
        paymentStatus: "paid",
        bookingId: booking.bookingId,
        totalAmount: booking.totalAmount,
      });
    }
    console.log(
      `Tap to Pay PI: ${booking.bookingId} · ${result.paymentIntentId} · ${booking.totalAmount} € · Fahrer ${driverUid}`
    );
    res.json({
      bookingId: booking.bookingId,
      totalAmount: booking.totalAmount,
      paymentIntentId: result.paymentIntentId,
      clientSecret: result.clientSecret,
      locationId: stripeTerminalLocationId,
      paymentStatus: booking.paymentStatus,
    });
  } catch (error) {
    console.error("tap-pay:", error);
    saveBookings();
    res.status(500).json({ error: error.message || "Tap to Pay PaymentIntent failed" });
  }
});

app.get("/api/pay/:bookingId", (req, res) => {
  const booking = findBooking(req.params.bookingId);
  const token = String(req.query.token || "").trim();
  if (!booking || !booking.paymentAccessToken || token !== booking.paymentAccessToken) {
    return res.status(404).json({ error: "Payment not found" });
  }
  res.json({
    bookingId: booking.bookingId,
    paymentStatus: booking.paymentStatus || null,
    totalAmount: Number(booking.totalAmount) || 0,
    currency: "eur",
    paymentMethod: booking.paymentMethod || null,
    addressLine: booking.addressLine || null,
    destinationAddressLine: booking.destinationAddressLine || null,
    paidAt: booking.paidAt || null,
    paymentsEnabled: Boolean(stripe && stripePublishableKey),
  });
});

app.post("/api/pay/:bookingId/intent", async (req, res) => {
  const booking = findBooking(req.params.bookingId);
  const token = String(req.body.token || req.query.token || "").trim();
  if (!booking || !booking.paymentAccessToken || token !== booking.paymentAccessToken) {
    return res.status(404).json({ error: "Payment not found" });
  }
  if (booking.paymentStatus === "paid") {
    return res.json({ alreadyPaid: true, paymentStatus: "paid" });
  }
  if (!Number.isFinite(Number(booking.totalAmount)) || Number(booking.totalAmount) < 0.5) {
    return res.status(400).json({ error: "Fare not set yet" });
  }
  try {
    const result = await ensureRidePaymentIntent(booking, {
      receiptEmail: req.body.receiptEmail || booking.passengerEmail,
    });
    if (result.alreadyPaid) {
      return res.json({ alreadyPaid: true, paymentStatus: "paid" });
    }
    res.json({
      clientSecret: result.clientSecret,
      paymentIntentId: result.paymentIntentId,
      paymentStatus: booking.paymentStatus,
    });
  } catch (error) {
    console.error(error);
    const status = error.code === "stripe_missing" ? 503 : 500;
    res.status(status).json({ error: error.message || "PaymentIntent failed" });
  }
});

app.post("/create-payment-intent", async (req, res) => {
  if (!stripe) {
    return res.status(503).json({ error: "Stripe not configured (STRIPE_SECRET_KEY missing)" });
  }

  try {
    const bookingId = String(req.body.bookingId || "").trim();
    if (bookingId) {
      const booking = findBooking(bookingId);
      const token = String(req.body.token || "").trim();
      if (!booking || !booking.paymentAccessToken || token !== booking.paymentAccessToken) {
        return res.status(404).json({ error: "Booking payment not found" });
      }
      if (Number.isFinite(Number(req.body.amountEuros))) {
        booking.totalAmount = Math.round(Number(req.body.amountEuros) * 100) / 100;
      } else if (Number.isInteger(Number(req.body.amount)) && Number(req.body.amount) >= 50) {
        booking.totalAmount = Number(req.body.amount) / 100;
      }
      const result = await ensureRidePaymentIntent(booking, {
        receiptEmail: req.body.receiptEmail || req.body.passengerEmail,
      });
      if (result.alreadyPaid) {
        return res.json({ alreadyPaid: true, clientSecret: null });
      }
      return res.json({ clientSecret: result.clientSecret, paymentIntentId: result.paymentIntentId });
    }

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
      metadata: { ...STRIPE_PRODUCT_META },
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

// redeploy: Tap to Pay terminal API 2026-09-05T22:10:00Z

// redeploy: passenger card pay + tap-to-pay docs 2026-09-05T21:20:00Z

// redeploy: home-screen look 2026-09-05T09:07:16Z

// redeploy: driver home-screen parity 2026-09-05T09:30:29Z

// redeploy: driver HTML matches simulator app 2026-09-05T09:36:29Z

// redeploy: pause games in driver HTML 2026-09-05T09:50:49Z

// redeploy: fix pause game click handler 2026-09-05T09:57:02Z

// redeploy: home yellow white text 2026-09-05T20:26:00Z

// redeploy: book.html yellow black 2026-09-05T20:31:00Z

// redeploy: hero pitch readable yellow 2026-09-05T20:45:00Z

// redeploy: restore pause-games brain training blurb 2026-09-05T20:49:00Z

// redeploy: admin stay logged in localStorage 2026-09-05T21:03:00Z

// redeploy: new admin dashboard 2026-09-08T20:07:40Z

// redeploy: admin logo csv copy-links gate 2026-09-21T19:56:00Z

// redeploy: legal pages agb-betriebe 2026-09-08T20:19:00Z

// redeploy: impressum insurance section 2026-09-08T20:30:00Z
