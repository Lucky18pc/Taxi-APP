/**
 * Phase 2 — REST für Kernmodelle + Schema-Dokumentation.
 */

const {
  publicUser,
  publicVehicle,
  publicRide,
  publicLocation,
  USER_ROLES,
  VEHICLE_TYPES,
  VEHICLE_STATUSES,
  RIDE_STATUSES,
  RIDE_STATUS_LABELS,
} = require("./core-models");

/**
 * @param {import("express").Express} app
 * @param {{
 *   store: ReturnType<import("./core-store").createCoreStore>,
 *   requireAdmin: import("express").RequestHandler,
 * }} opts
 */
function mountCoreModelRoutes(app, opts) {
  const { store, requireAdmin } = opts;

  app.get("/api/core/schema", (_req, res) => {
    res.json({
      phase: 2,
      label: "Datenmodelle & Backend-Kern",
      models: {
        User: {
          fields: ["UserID", "Name", "Telefon", "Rolle", "Payment Methods"],
          roles: Object.values(USER_ROLES),
        },
        Vehicle: {
          fields: ["VehicleID", "Kennzeichen", "Typ", "Status"],
          types: Object.values(VEHICLE_TYPES),
          statuses: Object.values(VEHICLE_STATUSES),
        },
        Ride: {
          fields: [
            "RideID",
            "CustomerID",
            "DriverID",
            "Startkoordinaten",
            "Zielkoordinaten",
            "Status",
            "Fahrpreis",
          ],
          statuses: Object.values(RIDE_STATUSES),
          statusLabels: RIDE_STATUS_LABELS,
        },
        Location: {
          fields: ["DriverID", "Geopoint.Latitude", "Geopoint.Longitude", "Timestamp"],
        },
      },
      stats: store.stats(),
    });
  });

  app.get("/api/core/stats", (_req, res) => {
    res.json(store.stats());
  });

  // —— Users ——
  app.get("/api/core/users", requireAdmin, (req, res) => {
    const role = req.query.role ? String(req.query.role) : undefined;
    res.json({ users: store.listUsers({ role }).map(publicUser) });
  });

  app.get("/api/core/users/:id", requireAdmin, (req, res) => {
    const user = store.findUser(req.params.id);
    if (!user) return res.status(404).json({ error: "User not found" });
    res.json(publicUser(user));
  });

  app.post("/api/core/users", requireAdmin, (req, res) => {
    try {
      const user = store.upsertUser(req.body || {});
      res.status(201).json(publicUser(user));
    } catch (error) {
      res.status(400).json({ error: error.message || "Invalid user" });
    }
  });

  // —— Vehicles ——
  app.get("/api/core/vehicles", requireAdmin, (req, res) => {
    res.json({
      vehicles: store
        .listVehicles({
          status: req.query.status ? String(req.query.status) : undefined,
          type: req.query.type ? String(req.query.type) : undefined,
          driverId: req.query.driverId ? String(req.query.driverId) : undefined,
        })
        .map(publicVehicle),
    });
  });

  app.get("/api/core/vehicles/:id", requireAdmin, (req, res) => {
    const vehicle = store.findVehicle(req.params.id);
    if (!vehicle) return res.status(404).json({ error: "Vehicle not found" });
    res.json(publicVehicle(vehicle));
  });

  app.post("/api/core/vehicles", requireAdmin, (req, res) => {
    try {
      const vehicle = store.upsertVehicle(req.body || {});
      res.status(201).json(publicVehicle(vehicle));
    } catch (error) {
      res.status(400).json({ error: error.message || "Invalid vehicle" });
    }
  });

  app.patch("/api/core/vehicles/:id/status", requireAdmin, (req, res) => {
    try {
      const vehicle = store.setVehicleStatus(req.params.id, req.body?.status);
      if (!vehicle) return res.status(404).json({ error: "Vehicle not found" });
      res.json(publicVehicle(vehicle));
    } catch (error) {
      res.status(400).json({ error: error.message || "Invalid status" });
    }
  });

  // —— Rides ——
  app.get("/api/core/rides", requireAdmin, (req, res) => {
    res.json({
      rides: store
        .listRides({
          status: req.query.status ? String(req.query.status) : undefined,
          customerId: req.query.customerId ? String(req.query.customerId) : undefined,
          driverId: req.query.driverId ? String(req.query.driverId) : undefined,
        })
        .map(publicRide),
    });
  });

  app.get("/api/core/rides/:id", (req, res) => {
    const ride =
      store.findRide(req.params.id) || store.findRideByBookingId(req.params.id);
    if (!ride) return res.status(404).json({ error: "Ride not found" });
    res.json(publicRide(ride));
  });

  app.post("/api/core/rides", requireAdmin, (req, res) => {
    try {
      const ride = store.upsertRide(req.body || {});
      res.status(201).json(publicRide(ride));
    } catch (error) {
      res.status(400).json({ error: error.message || "Invalid ride" });
    }
  });

  app.patch("/api/core/rides/:id/status", requireAdmin, (req, res) => {
    try {
      const ride = store.updateRideStatus(req.params.id, req.body?.status, {
        driverId: req.body?.driverId,
        vehicleId: req.body?.vehicleId,
        fare: req.body?.fare ?? req.body?.fahrpreis,
      });
      if (!ride) return res.status(404).json({ error: "Ride not found" });
      res.json(publicRide(ride));
    } catch (error) {
      res.status(400).json({ error: error.message || "Invalid status" });
    }
  });

  // —— Locations ——
  app.get("/api/core/locations/latest/:driverId", (req, res) => {
    const loc = store.getLatestLocation(req.params.driverId);
    if (!loc) return res.status(404).json({ error: "No location for driver" });
    res.json(publicLocation(loc));
  });

  app.get("/api/core/locations", requireAdmin, (req, res) => {
    res.json({
      locations: store
        .listLocations({
          driverId: req.query.driverId ? String(req.query.driverId) : undefined,
          rideId: req.query.rideId ? String(req.query.rideId) : undefined,
          bookingId: req.query.bookingId ? String(req.query.bookingId) : undefined,
          limit: req.query.limit,
        })
        .map(publicLocation),
    });
  });

  app.post("/api/core/locations", requireAdmin, (req, res) => {
    try {
      const loc = store.recordLocation(req.body || {});
      res.status(201).json(publicLocation(loc));
    } catch (error) {
      res.status(400).json({ error: error.message || "Invalid location" });
    }
  });
}

module.exports = { mountCoreModelRoutes };
