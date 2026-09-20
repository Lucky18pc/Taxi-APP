/**
 * Phase 2 — Persistenz für User / Vehicle / Ride / Location (JSON unter DATA_DIR).
 * Additive Schicht neben bookings.json / drivers.json.
 */

const fs = require("fs");
const path = require("path");
const {
  createUser,
  createVehicle,
  createRide,
  createLocation,
  USER_ROLES,
  VEHICLE_STATUSES,
  RIDE_STATUSES,
  BOOKING_TO_RIDE_STATUS,
  DRIVER_TO_VEHICLE_STATUS,
  normalizeRideStatus,
  normalizeVehicleStatus,
  nowIso,
} = require("./core-models");

const LOCATION_HISTORY_MAX = Number(process.env.LOCATION_HISTORY_MAX || 2000);

function loadWrapped(filePath, key) {
  try {
    if (!fs.existsSync(filePath)) return [];
    const parsed = JSON.parse(fs.readFileSync(filePath, "utf8"));
    if (Array.isArray(parsed)) return parsed;
    if (parsed && Array.isArray(parsed[key])) return parsed[key];
    return [];
  } catch (error) {
    console.warn(`core-store: konnte ${filePath} nicht laden:`, error.message);
    return [];
  }
}

function saveWrapped(filePath, key, items) {
  fs.mkdirSync(path.dirname(filePath), { recursive: true });
  const payload = { [key]: items, updatedAt: nowIso() };
  fs.writeFileSync(filePath, `${JSON.stringify(payload, null, 2)}\n`, "utf8");
}

/**
 * @param {{ dataDir: string }} opts
 */
function createCoreStore(opts) {
  const dataDir = opts.dataDir;
  const usersPath = path.join(dataDir, "users.json");
  const vehiclesPath = path.join(dataDir, "vehicles.json");
  const ridesPath = path.join(dataDir, "rides.json");
  const locationsPath = path.join(dataDir, "locations.json");
  const locationLatestPath = path.join(dataDir, "locations-latest.json");

  /** @type {ReturnType<typeof createUser>[]} */
  let users = loadWrapped(usersPath, "users");
  /** @type {ReturnType<typeof createVehicle>[]} */
  let vehicles = loadWrapped(vehiclesPath, "vehicles");
  /** @type {ReturnType<typeof createRide>[]} */
  let rides = loadWrapped(ridesPath, "rides");
  /** @type {ReturnType<typeof createLocation>[]} */
  let locations = loadWrapped(locationsPath, "locations");
  /** @type {Record<string, ReturnType<typeof createLocation>>} */
  let latestByDriver = {};
  try {
    if (fs.existsSync(locationLatestPath)) {
      const parsed = JSON.parse(fs.readFileSync(locationLatestPath, "utf8"));
      latestByDriver = parsed?.byDriver && typeof parsed.byDriver === "object" ? parsed.byDriver : {};
    }
  } catch {
    latestByDriver = {};
  }

  function saveUsers() {
    saveWrapped(usersPath, "users", users);
  }
  function saveVehicles() {
    saveWrapped(vehiclesPath, "vehicles", vehicles);
  }
  function saveRides() {
    saveWrapped(ridesPath, "rides", rides);
  }
  function saveLocations() {
    saveWrapped(locationsPath, "locations", locations);
    fs.writeFileSync(
      locationLatestPath,
      `${JSON.stringify({ byDriver: latestByDriver, updatedAt: nowIso() }, null, 2)}\n`,
      "utf8"
    );
  }

  function findUser(userId) {
    return users.find((u) => u.userId === userId) || null;
  }

  function findUserByFirebaseUid(uid) {
    const id = String(uid || "").trim();
    if (!id) return null;
    return users.find((u) => u.firebaseUid === id) || null;
  }

  function findUserByLegacyDriverId(driverId) {
    const id = String(driverId || "").trim();
    if (!id) return null;
    return users.find((u) => u.legacyDriverId === id) || null;
  }

  function upsertUser(input) {
    const incoming = createUser(input);
    const existing =
      (incoming.userId && findUser(incoming.userId)) ||
      (incoming.firebaseUid && findUserByFirebaseUid(incoming.firebaseUid)) ||
      (incoming.legacyDriverId && findUserByLegacyDriverId(incoming.legacyDriverId)) ||
      (incoming.phone &&
        users.find(
          (u) => u.phone && u.phone === incoming.phone && u.role === incoming.role
        )) ||
      null;

    if (existing) {
      existing.name = incoming.name || existing.name;
      existing.phone = incoming.phone ?? existing.phone;
      existing.role = incoming.role || existing.role;
      if (incoming.paymentMethods?.length) {
        existing.paymentMethods = incoming.paymentMethods;
      }
      existing.email = incoming.email ?? existing.email;
      existing.firebaseUid = incoming.firebaseUid || existing.firebaseUid;
      existing.operatorId = incoming.operatorId ?? existing.operatorId;
      existing.legacyDriverId = incoming.legacyDriverId || existing.legacyDriverId;
      existing.updatedAt = nowIso();
      saveUsers();
      return existing;
    }

    users.unshift(incoming);
    saveUsers();
    return incoming;
  }

  function listUsers(filter = {}) {
    let list = users.slice();
    if (filter.role) list = list.filter((u) => u.role === filter.role);
    if (filter.operatorId) {
      list = list.filter((u) => u.operatorId === filter.operatorId);
    }
    return list;
  }

  function findVehicle(vehicleId) {
    return vehicles.find((v) => v.vehicleId === vehicleId) || null;
  }

  function findVehicleByPlate(plate) {
    const p = String(plate || "")
      .trim()
      .toUpperCase();
    if (!p) return null;
    return vehicles.find((v) => String(v.plate).toUpperCase() === p) || null;
  }

  function findVehicleByLegacyDriverId(driverId) {
    const id = String(driverId || "").trim();
    if (!id) return null;
    return vehicles.find((v) => v.legacyDriverId === id || v.driverId === id) || null;
  }

  function upsertVehicle(input) {
    const incoming = createVehicle(input);
    const existing =
      (incoming.vehicleId && findVehicle(incoming.vehicleId)) ||
      (incoming.legacyDriverId && findVehicleByLegacyDriverId(incoming.legacyDriverId)) ||
      findVehicleByPlate(incoming.plate) ||
      null;

    if (existing) {
      existing.plate = incoming.plate || existing.plate;
      existing.type = incoming.type || existing.type;
      existing.status = incoming.status || existing.status;
      existing.driverId = incoming.driverId || existing.driverId;
      existing.operatorId = incoming.operatorId ?? existing.operatorId;
      existing.legacyDriverId = incoming.legacyDriverId || existing.legacyDriverId;
      existing.updatedAt = nowIso();
      saveVehicles();
      return existing;
    }

    vehicles.unshift(incoming);
    saveVehicles();
    return incoming;
  }

  function setVehicleStatus(vehicleId, status) {
    const vehicle = findVehicle(vehicleId);
    if (!vehicle) return null;
    const next = normalizeVehicleStatus(status);
    if (!next) throw new Error("Ungültiger Vehicle-Status");
    vehicle.status = next;
    vehicle.updatedAt = nowIso();
    saveVehicles();
    return vehicle;
  }

  function listVehicles(filter = {}) {
    let list = vehicles.slice();
    if (filter.status) list = list.filter((v) => v.status === filter.status);
    if (filter.type) list = list.filter((v) => v.type === filter.type);
    if (filter.driverId) list = list.filter((v) => v.driverId === filter.driverId);
    if (filter.operatorId) {
      list = list.filter((v) => v.operatorId === filter.operatorId);
    }
    return list;
  }

  function findRide(rideId) {
    return rides.find((r) => r.rideId === rideId) || null;
  }

  function findRideByBookingId(bookingId) {
    const id = String(bookingId || "").trim();
    if (!id) return null;
    return rides.find((r) => r.bookingId === id) || null;
  }

  function upsertRide(input) {
    const incoming = createRide(input);
    const existing =
      (incoming.rideId && findRide(incoming.rideId)) ||
      (incoming.bookingId && findRideByBookingId(incoming.bookingId)) ||
      null;

    if (existing) {
      existing.customerId = incoming.customerId ?? existing.customerId;
      existing.driverId = incoming.driverId ?? existing.driverId;
      existing.vehicleId = incoming.vehicleId ?? existing.vehicleId;
      existing.start = incoming.start || existing.start;
      existing.end = incoming.end ?? existing.end;
      existing.startAddress = incoming.startAddress ?? existing.startAddress;
      existing.endAddress = incoming.endAddress ?? existing.endAddress;
      existing.status = incoming.status || existing.status;
      existing.fare = Number.isFinite(incoming.fare) ? incoming.fare : existing.fare;
      existing.paymentMethod = incoming.paymentMethod ?? existing.paymentMethod;
      existing.operatorId = incoming.operatorId ?? existing.operatorId;
      existing.bookingId = incoming.bookingId || existing.bookingId;
      existing.updatedAt = nowIso();
      saveRides();
      return existing;
    }

    rides.unshift(incoming);
    saveRides();
    return incoming;
  }

  function updateRideStatus(rideId, status, patch = {}) {
    const ride = findRide(rideId) || findRideByBookingId(rideId);
    if (!ride) return null;
    const next = normalizeRideStatus(status);
    if (!next) throw new Error("Ungültiger Ride-Status");
    ride.status = next;
    if (patch.driverId !== undefined) ride.driverId = patch.driverId;
    if (patch.vehicleId !== undefined) ride.vehicleId = patch.vehicleId;
    if (patch.fare !== undefined) ride.fare = Number(patch.fare) || 0;
    if (patch.end) ride.end = patch.end;
    ride.updatedAt = nowIso();
    saveRides();
    return ride;
  }

  function listRides(filter = {}) {
    let list = rides.slice();
    if (filter.status) list = list.filter((r) => r.status === filter.status);
    if (filter.customerId) list = list.filter((r) => r.customerId === filter.customerId);
    if (filter.driverId) list = list.filter((r) => r.driverId === filter.driverId);
    if (filter.operatorId) list = list.filter((r) => r.operatorId === filter.operatorId);
    return list;
  }

  function recordLocation(input) {
    const loc = createLocation(input);
    latestByDriver[loc.driverId] = loc;
    locations.unshift(loc);
    if (locations.length > LOCATION_HISTORY_MAX) {
      locations.length = LOCATION_HISTORY_MAX;
    }
    saveLocations();
    return loc;
  }

  function getLatestLocation(driverId) {
    const id = String(driverId || "").trim();
    return latestByDriver[id] || null;
  }

  function listLocations(filter = {}) {
    let list = locations.slice();
    if (filter.driverId) list = list.filter((l) => l.driverId === filter.driverId);
    if (filter.rideId) list = list.filter((l) => l.rideId === filter.rideId);
    if (filter.bookingId) list = list.filter((l) => l.bookingId === filter.bookingId);
    const limit = Number(filter.limit) || 100;
    return list.slice(0, Math.min(limit, 500));
  }

  /** Sync aus Legacy-Driver-Objekt. */
  function syncFromLegacyDriver(driver) {
    if (!driver?.driverId) return { user: null, vehicle: null };
    const user = upsertUser({
      name: driver.name || "Fahrer",
      phone: driver.phone,
      role: USER_ROLES.FAHRER,
      firebaseUid: driver.firebaseUid || null,
      legacyDriverId: driver.driverId,
      operatorId: driver.operatorId || null,
    });
    const plate = String(driver.vehicle || driver.taxiNumber || "").trim() || `TAXI-${driver.driverId.slice(0, 8)}`;
    const vehicle = upsertVehicle({
      plate,
      type: "standard",
      status: DRIVER_TO_VEHICLE_STATUS[driver.status] || VEHICLE_STATUSES.FREI,
      driverId: user.userId,
      legacyDriverId: driver.driverId,
      operatorId: driver.operatorId || null,
    });
    return { user, vehicle };
  }

  /** Sync aus Legacy-Booking. */
  function syncFromLegacyBooking(booking, opts = {}) {
    if (!booking?.bookingId) return null;

    let customerId = opts.customerId || null;
    if (!customerId && (booking.passengerEmail || opts.passengerName)) {
      const customer = upsertUser({
        name: opts.passengerName || booking.passengerEmail || "Fahrgast",
        email: booking.passengerEmail || null,
        phone: opts.passengerPhone || null,
        role: USER_ROLES.KUNDE,
        paymentMethods: booking.paymentMethod
          ? [{ type: String(booking.paymentMethod), label: String(booking.paymentMethod) }]
          : [],
        operatorId: booking.operatorId || null,
      });
      customerId = customer.userId;
    }

    let driverCoreId = null;
    let vehicleId = null;
    if (booking.assignedDriverId && opts.findLegacyDriver) {
      const legacy = opts.findLegacyDriver(booking.assignedDriverId);
      if (legacy) {
        const synced = syncFromLegacyDriver(legacy);
        driverCoreId = synced.user?.userId || null;
        vehicleId = synced.vehicle?.vehicleId || null;
      }
    }

    const rideStatus =
      opts.rideStatus ||
      BOOKING_TO_RIDE_STATUS[booking.status] ||
      RIDE_STATUSES.RIDE_REQUEST;

    return upsertRide({
      bookingId: booking.bookingId,
      customerId,
      driverId: driverCoreId,
      vehicleId,
      startLatitude: booking.latitude,
      startLongitude: booking.longitude,
      startAddress: booking.addressLine,
      endLatitude: booking.destinationLatitude,
      endLongitude: booking.destinationLongitude,
      endAddress: booking.destinationAddressLine,
      status: rideStatus,
      fare: booking.totalAmount,
      paymentMethod: booking.paymentMethod,
      operatorId: booking.operatorId || null,
      createdAt: booking.createdAt,
    });
  }

  function stats() {
    return {
      users: users.length,
      vehicles: vehicles.length,
      rides: rides.length,
      locations: locations.length,
      latestDrivers: Object.keys(latestByDriver).length,
    };
  }

  return {
    upsertUser,
    findUser,
    findUserByFirebaseUid,
    findUserByLegacyDriverId,
    listUsers,
    upsertVehicle,
    findVehicle,
    findVehicleByLegacyDriverId,
    setVehicleStatus,
    listVehicles,
    upsertRide,
    findRide,
    findRideByBookingId,
    updateRideStatus,
    listRides,
    recordLocation,
    getLatestLocation,
    listLocations,
    syncFromLegacyDriver,
    syncFromLegacyBooking,
    stats,
    enums: {
      USER_ROLES,
      VEHICLE_STATUSES,
      RIDE_STATUSES,
    },
  };
}

module.exports = { createCoreStore, LOCATION_HISTORY_MAX };
