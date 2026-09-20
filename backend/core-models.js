/**
 * Phase 2 — Kern-Datenmodelle (User, Vehicle, Ride, Location).
 * Canonical enums + Factory/Normalizer. Persistenz in core-store.js.
 */

const crypto = require("crypto");

const USER_ROLES = Object.freeze({
  KUNDE: "kunde",
  FAHRER: "fahrer",
  ADMIN: "admin",
});

const VEHICLE_TYPES = Object.freeze({
  STANDARD: "standard",
  XL: "xl",
});

const VEHICLE_STATUSES = Object.freeze({
  FREI: "frei",
  BESETZT: "besetzt",
  AUSSER_DIENST: "ausser_dienst",
});

/** Ride-Status laut Phase-2-Spec (Maschinenwerte + Label). */
const RIDE_STATUSES = Object.freeze({
  RIDE_REQUEST: "ride_request",
  ACCEPTED: "accepted",
  ARRIVED: "arrived",
  IN_PROGRESS: "in_progress",
  COMPLETED: "completed",
  CANCELLED: "cancelled",
});

const RIDE_STATUS_LABELS = Object.freeze({
  [RIDE_STATUSES.RIDE_REQUEST]: "Ride Requests",
  [RIDE_STATUSES.ACCEPTED]: "Accepted",
  [RIDE_STATUSES.ARRIVED]: "Arrived",
  [RIDE_STATUSES.IN_PROGRESS]: "In Progress",
  [RIDE_STATUSES.COMPLETED]: "Completed",
  [RIDE_STATUSES.CANCELLED]: "Cancelled",
});

const BOOKING_TO_RIDE_STATUS = Object.freeze({
  confirmed: RIDE_STATUSES.RIDE_REQUEST,
  accepted: RIDE_STATUSES.ACCEPTED,
  assigned: RIDE_STATUSES.ACCEPTED,
  completed: RIDE_STATUSES.COMPLETED,
  cancelled: RIDE_STATUSES.CANCELLED,
});

const DRIVER_TO_VEHICLE_STATUS = Object.freeze({
  available: VEHICLE_STATUSES.FREI,
  busy: VEHICLE_STATUSES.BESETZT,
  offline: VEHICLE_STATUSES.AUSSER_DIENST,
  pending: VEHICLE_STATUSES.AUSSER_DIENST,
});

function newId(prefix) {
  return `${prefix}_${crypto.randomUUID()}`;
}

function nowIso() {
  return new Date().toISOString();
}

function normalizeRole(raw) {
  const s = String(raw || "")
    .trim()
    .toLowerCase();
  if (["kunde", "customer", "passenger", "client"].includes(s)) return USER_ROLES.KUNDE;
  if (["fahrer", "driver"].includes(s)) return USER_ROLES.FAHRER;
  if (["admin", "dispatcher", "leitstelle"].includes(s)) return USER_ROLES.ADMIN;
  return null;
}

function normalizeVehicleType(raw) {
  const s = String(raw || "")
    .trim()
    .toLowerCase();
  if (["xl", "van", "grosse", "große", "large"].includes(s)) return VEHICLE_TYPES.XL;
  return VEHICLE_TYPES.STANDARD;
}

function normalizeVehicleStatus(raw) {
  const s = String(raw || "")
    .trim()
    .toLowerCase()
    .replace(/\s+/g, "_")
    .normalize("NFD")
    .replace(/[\u0300-\u036f]/g, "");
  if (["frei", "available", "free"].includes(s)) return VEHICLE_STATUSES.FREI;
  if (["besetzt", "busy", "occupied"].includes(s)) return VEHICLE_STATUSES.BESETZT;
  if (
    ["ausser_dienst", "ausserdienst", "offline", "out_of_service", "out-of-service"].includes(s)
  ) {
    return VEHICLE_STATUSES.AUSSER_DIENST;
  }
  return null;
}

function normalizeRideStatus(raw) {
  const s = String(raw || "")
    .trim()
    .toLowerCase()
    .replace(/\s+/g, "_");
  const aliases = {
    ride_request: RIDE_STATUSES.RIDE_REQUEST,
    ride_requests: RIDE_STATUSES.RIDE_REQUEST,
    request: RIDE_STATUSES.RIDE_REQUEST,
    requested: RIDE_STATUSES.RIDE_REQUEST,
    confirmed: RIDE_STATUSES.RIDE_REQUEST,
    accepted: RIDE_STATUSES.ACCEPTED,
    assigned: RIDE_STATUSES.ACCEPTED,
    arrived: RIDE_STATUSES.ARRIVED,
    in_progress: RIDE_STATUSES.IN_PROGRESS,
    inprogress: RIDE_STATUSES.IN_PROGRESS,
    started: RIDE_STATUSES.IN_PROGRESS,
    completed: RIDE_STATUSES.COMPLETED,
    done: RIDE_STATUSES.COMPLETED,
    cancelled: RIDE_STATUSES.CANCELLED,
    canceled: RIDE_STATUSES.CANCELLED,
  };
  return aliases[s] || null;
}

function normalizePaymentMethods(raw) {
  if (!raw) return [];
  if (Array.isArray(raw)) {
    return raw
      .map((m) => {
        if (typeof m === "string") return { type: m.trim(), label: m.trim() };
        if (m && typeof m === "object") {
          return {
            type: String(m.type || m.method || "unknown").trim(),
            label: String(m.label || m.type || m.method || "").trim() || undefined,
            last4: m.last4 ? String(m.last4) : undefined,
            provider: m.provider ? String(m.provider) : undefined,
          };
        }
        return null;
      })
      .filter(Boolean);
  }
  if (typeof raw === "string" && raw.trim()) {
    return [{ type: raw.trim(), label: raw.trim() }];
  }
  return [];
}

function geoPoint(lat, lng) {
  const latitude = Number(lat);
  const longitude = Number(lng);
  if (!Number.isFinite(latitude) || !Number.isFinite(longitude)) return null;
  return { latitude, longitude };
}

function createUser(input = {}) {
  const role = normalizeRole(input.role || input.Rolle || USER_ROLES.KUNDE);
  if (!role) {
    throw new Error("Ungültige Rolle (kunde|fahrer|admin)");
  }
  const name = String(input.name || input.Name || "").trim();
  if (!name) throw new Error("Name erforderlich");

  return {
    userId: String(input.userId || input.UserID || "").trim() || newId("usr"),
    name,
    phone: String(input.phone || input.Telefon || "").trim() || null,
    role,
    paymentMethods: normalizePaymentMethods(input.paymentMethods || input.PaymentMethods),
    email: String(input.email || "").trim() || null,
    firebaseUid: String(input.firebaseUid || "").trim() || null,
    operatorId: input.operatorId || null,
    legacyDriverId: input.legacyDriverId || null,
    createdAt: input.createdAt || nowIso(),
    updatedAt: nowIso(),
  };
}

function createVehicle(input = {}) {
  const plate = String(input.plate || input.kennzeichen || input.Kennzeichen || "").trim();
  if (!plate) throw new Error("Kennzeichen erforderlich");

  const status =
    normalizeVehicleStatus(input.status || input.Status) || VEHICLE_STATUSES.FREI;
  const type = normalizeVehicleType(input.type || input.typ || input.Typ);

  return {
    vehicleId: String(input.vehicleId || input.VehicleID || "").trim() || newId("veh"),
    plate,
    type,
    status,
    driverId: input.driverId || input.DriverID || null,
    operatorId: input.operatorId || null,
    legacyDriverId: input.legacyDriverId || null,
    createdAt: input.createdAt || nowIso(),
    updatedAt: nowIso(),
  };
}

function createRide(input = {}) {
  const start = geoPoint(
    input.startLatitude ?? input.start?.latitude ?? input.Startkoordinaten?.latitude,
    input.startLongitude ?? input.start?.longitude ?? input.Startkoordinaten?.longitude
  );
  if (!start) throw new Error("Startkoordinaten (latitude/longitude) erforderlich");

  const endRaw = geoPoint(
    input.endLatitude ?? input.end?.latitude ?? input.Zielkoordinaten?.latitude,
    input.endLongitude ?? input.end?.longitude ?? input.Zielkoordinaten?.longitude
  );

  const status =
    normalizeRideStatus(input.status || input.Status) || RIDE_STATUSES.RIDE_REQUEST;

  const fare = Number(input.fare ?? input.fahrpreis ?? input.Fahrpreis ?? 0);

  return {
    rideId: String(input.rideId || input.RideID || "").trim() || newId("ride"),
    customerId: input.customerId || input.CustomerID || null,
    driverId: input.driverId || input.DriverID || null,
    vehicleId: input.vehicleId || null,
    start,
    end: endRaw,
    startAddress: String(input.startAddress || "").trim() || null,
    endAddress: String(input.endAddress || "").trim() || null,
    status,
    statusLabel: RIDE_STATUS_LABELS[status],
    fare: Number.isFinite(fare) ? fare : 0,
    currency: String(input.currency || "EUR"),
    bookingId: input.bookingId || null,
    operatorId: input.operatorId || null,
    paymentMethod: input.paymentMethod || null,
    createdAt: input.createdAt || nowIso(),
    updatedAt: nowIso(),
  };
}

function createLocation(input = {}) {
  const driverId = String(input.driverId || input.DriverID || "").trim();
  if (!driverId) throw new Error("DriverID erforderlich");
  const point = geoPoint(
    input.latitude ?? input.geopoint?.latitude ?? input.Geopoint?.Latitude,
    input.longitude ?? input.geopoint?.longitude ?? input.Geopoint?.Longitude
  );
  if (!point) throw new Error("Geopoint Latitude/Longitude erforderlich");

  return {
    locationId: String(input.locationId || "").trim() || newId("loc"),
    driverId,
    geopoint: point,
    timestamp: String(input.timestamp || input.Timestamp || nowIso()),
    rideId: input.rideId || null,
    bookingId: input.bookingId || null,
    heading: Number.isFinite(Number(input.heading)) ? Number(input.heading) : null,
    speed: Number.isFinite(Number(input.speed)) ? Number(input.speed) : null,
  };
}

function publicUser(user) {
  if (!user) return null;
  return {
    UserID: user.userId,
    Name: user.name,
    Telefon: user.phone,
    Rolle: user.role,
    PaymentMethods: user.paymentMethods,
    userId: user.userId,
    name: user.name,
    phone: user.phone,
    role: user.role,
    paymentMethods: user.paymentMethods,
    email: user.email,
    firebaseUid: user.firebaseUid,
  };
}

function publicVehicle(vehicle) {
  if (!vehicle) return null;
  return {
    VehicleID: vehicle.vehicleId,
    Kennzeichen: vehicle.plate,
    Typ: vehicle.type,
    Status: vehicle.status,
    vehicleId: vehicle.vehicleId,
    plate: vehicle.plate,
    type: vehicle.type,
    status: vehicle.status,
    driverId: vehicle.driverId,
  };
}

function publicRide(ride) {
  if (!ride) return null;
  return {
    RideID: ride.rideId,
    CustomerID: ride.customerId,
    DriverID: ride.driverId,
    Startkoordinaten: ride.start,
    Zielkoordinaten: ride.end,
    Status: RIDE_STATUS_LABELS[ride.status] || ride.status,
    Fahrpreis: ride.fare,
    rideId: ride.rideId,
    customerId: ride.customerId,
    driverId: ride.driverId,
    start: ride.start,
    end: ride.end,
    status: ride.status,
    statusLabel: RIDE_STATUS_LABELS[ride.status] || ride.status,
    fare: ride.fare,
    bookingId: ride.bookingId,
    vehicleId: ride.vehicleId,
  };
}

function publicLocation(loc) {
  if (!loc) return null;
  return {
    DriverID: loc.driverId,
    Geopoint: {
      Latitude: loc.geopoint.latitude,
      Longitude: loc.geopoint.longitude,
    },
    Timestamp: loc.timestamp,
    driverId: loc.driverId,
    geopoint: loc.geopoint,
    timestamp: loc.timestamp,
    rideId: loc.rideId,
    bookingId: loc.bookingId,
  };
}

module.exports = {
  USER_ROLES,
  VEHICLE_TYPES,
  VEHICLE_STATUSES,
  RIDE_STATUSES,
  RIDE_STATUS_LABELS,
  BOOKING_TO_RIDE_STATUS,
  DRIVER_TO_VEHICLE_STATUS,
  createUser,
  createVehicle,
  createRide,
  createLocation,
  normalizeRole,
  normalizeVehicleType,
  normalizeVehicleStatus,
  normalizeRideStatus,
  geoPoint,
  publicUser,
  publicVehicle,
  publicRide,
  publicLocation,
  newId,
  nowIso,
};
