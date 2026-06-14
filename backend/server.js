require("dotenv").config();

const express = require("express");
const cors = require("cors");
const crypto = require("crypto");
const path = require("path");
const fs = require("fs");

const port = process.env.PORT || 4242;
const secretKey = process.env.STRIPE_SECRET_KEY;

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

const tenantConfig = JSON.parse(fs.readFileSync(tenantConfigPath, "utf8"));
const driversSeed = JSON.parse(fs.readFileSync(driversConfigPath, "utf8"));

/** @type {Array<{driverId:string,name:string,phone:string,vehicle:string,status:string}>} */
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

function saveBookings() {
  saveJsonArray(bookingsFilePath, bookings);
}

function savePhoneCalls() {
  saveJsonArray(callsFilePath, phoneCalls);
}

console.log(`Datenverzeichnis: ${dataDir} · ${bookings.length} Buchung(en), ${phoneCalls.length} Anruf(e)`);

const BOOKING_STATUSES = new Set([
  "confirmed",
  "accepted",
  "assigned",
  "completed",
  "cancelled",
]);
const DRIVER_STATUSES = new Set(["available", "busy", "offline"]);

function findDriver(driverId) {
  return drivers.find((d) => d.driverId === driverId);
}

function findBooking(bookingId) {
  return bookings.find((b) => b.bookingId === bookingId);
}

function releaseDriver(driverId) {
  const driver = findDriver(driverId);
  if (driver && driver.status === "busy") {
    driver.status = "available";
  }
}

function releaseDriverFromBooking(booking) {
  if (booking?.assignedDriverId) {
    releaseDriver(booking.assignedDriverId);
  }
}

function saveTenantConfig() {
  fs.writeFileSync(tenantConfigPath, `${JSON.stringify(tenantConfig, null, 2)}\n`, "utf8");
}

function saveDriversConfig() {
  const payload = {
    drivers: drivers.map(({ driverId, name, phone, vehicle, status }) => ({
      driverId,
      name,
      phone,
      vehicle,
      status,
    })),
  };
  fs.writeFileSync(driversConfigPath, `${JSON.stringify(payload, null, 2)}\n`, "utf8");
}

app.use(cors());
app.use(express.json());
app.use(express.static(path.join(__dirname, "..", "web")));

app.get("/health", (_req, res) => {
  res.json({
    ok: true,
    stripe: Boolean(stripe),
    dataDir,
    bookings: bookings.length,
  });
});

app.get("/api/offering", (_req, res) => {
  res.json(offering);
});

app.get("/api/config", (_req, res) => {
  res.json(tenantConfig);
});

app.patch("/api/config", (req, res) => {
  const allowed = [
    "companyName",
    "centralPhone",
    "centralPhoneDisplay",
    "dispatchHours",
    "dispatchNote",
  ];

  for (const key of allowed) {
    if (req.body[key] !== undefined) {
      tenantConfig[key] = String(req.body[key]).trim();
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

app.get("/api/drivers", (_req, res) => {
  res.json({ drivers });
});

app.post("/api/drivers", (req, res) => {
  const name = String(req.body.name || "").trim();
  const phone = String(req.body.phone || "").trim();
  const vehicle = String(req.body.vehicle || "").trim();

  if (!name || !phone) {
    return res.status(400).json({ error: "name and phone required" });
  }

  const driver = {
    driverId: crypto.randomUUID(),
    name,
    phone,
    vehicle,
    status: "available",
  };

  drivers.push(driver);
  saveDriversConfig();
  res.status(201).json(driver);
});

app.put("/api/drivers/:id", (req, res) => {
  const driver = findDriver(req.params.id);
  if (!driver) {
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

app.delete("/api/drivers/:id", (req, res) => {
  const index = drivers.findIndex((d) => d.driverId === req.params.id);
  if (index === -1) {
    return res.status(404).json({ error: "Driver not found" });
  }

  const removed = drivers.splice(index, 1)[0];
  saveDriversConfig();
  res.json(removed);
});

app.patch("/api/drivers/:id/status", (req, res) => {
  const driver = findDriver(req.params.id);
  if (!driver) {
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

  const destinationAddressLine = String(req.body.destinationAddressLine || "").trim();

  const booking = {
    bookingId: crypto.randomUUID(),
    pickupDate: req.body.pickupDate || new Date().toISOString(),
    latitude,
    longitude,
    addressLine,
    destinationAddressLine: destinationAddressLine || null,
    paymentMethod: req.body.paymentMethod || "Unbekannt",
    totalAmount: Number(req.body.totalAmount) || 0,
    tariffAmount: Number(req.body.tariffAmount) || 0,
    tipAmount: Number(req.body.tipAmount) || 0,
    status: "confirmed",
    assignedDriverId: null,
    createdAt: new Date().toISOString(),
  };

  bookings.unshift(booking);
  saveBookings();
  console.log(`Buchung ${booking.bookingId}: ${addressLine}${destinationAddressLine ? ` → ${destinationAddressLine}` : ""}`);
  res.status(201).json({ bookingId: booking.bookingId });
});

app.get("/api/bookings", (_req, res) => {
  res.json({ bookings });
});

app.get("/api/bookings/:id", (req, res) => {
  const booking = findBooking(req.params.id);
  if (!booking) {
    return res.status(404).json({ error: "Booking not found" });
  }
  res.json(booking);
});

app.patch("/api/bookings/:id/status", (req, res) => {
  const booking = findBooking(req.params.id);
  if (!booking) {
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

app.patch("/api/bookings/:id/assign", (req, res) => {
  const booking = findBooking(req.params.id);
  if (!booking) {
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
  booking.updatedAt = new Date().toISOString();

  console.log(`Buchung ${booking.bookingId} → Fahrer ${driver.name}`);
  saveBookings();
  res.json(booking);
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

app.get("/api/calls", (_req, res) => {
  res.json({ calls: phoneCalls });
});

app.patch("/api/calls/:id/status", (req, res) => {
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

    if (!Number.isInteger(amount) || amount < 50) {
      return res.status(400).json({ error: "amount must be an integer >= 50 (cents)" });
    }

    const paymentIntent = await stripe.paymentIntents.create({
      amount,
      currency,
      automatic_payment_methods: { enabled: true },
    });

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
