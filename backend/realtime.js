/**
 * Phase-1 Echtzeit: Socket.io für Fahrzeugkoordinaten (~2,5 s).
 * HTTP-Polling bleibt als Fallback für Clients ohne WebSocket.
 */

const { Server } = require("socket.io");

const LOCATION_STREAM_INTERVAL_MS = Number(process.env.LOCATION_STREAM_INTERVAL_MS || 2500);

/**
 * @param {import("http").Server} httpServer
 * @param {{ buildTrackingPayload: (bookingId: string) => object | null }} deps
 */
function createRealtimeHub(httpServer, deps) {
  const io = new Server(httpServer, {
    path: "/socket.io",
    cors: { origin: true, methods: ["GET", "POST"] },
    transports: ["websocket", "polling"],
  });

  const FLEET_ROOM = "fleet:admin";

  io.on("connection", (socket) => {
    socket.on("subscribe:booking", (bookingId) => {
      const id = String(bookingId || "").trim();
      if (!id) return;
      socket.join(bookingRoom(id));
      const payload = deps.buildTrackingPayload(id);
      if (payload) {
        socket.emit("tracking:update", payload);
      }
    });

    socket.on("unsubscribe:booking", (bookingId) => {
      const id = String(bookingId || "").trim();
      if (!id) return;
      socket.leave(bookingRoom(id));
    });

    // Dieselbe GPS-Leitung wie die Fahrer-App, nur für den Plattform-Admin auf der Karte.
    socket.on("subscribe:fleet", (auth) => {
      const token = String(auth?.token || "").trim();
      const allowed = typeof deps.isPlatformAdminToken === "function" && deps.isPlatformAdminToken(token);
      if (!allowed) {
        socket.emit("fleet:denied");
        return;
      }
      socket.join(FLEET_ROOM);
      socket.emit("fleet:ready", { ok: true });
    });

    socket.on("unsubscribe:fleet", () => {
      socket.leave(FLEET_ROOM);
    });
  });

  function bookingRoom(bookingId) {
    return `booking:${bookingId}`;
  }

  function publishBookingTracking(bookingId) {
    const id = String(bookingId || "").trim();
    if (!id) return;
    const payload = deps.buildTrackingPayload(id);
    if (!payload) return;
    io.to(bookingRoom(id)).emit("tracking:update", payload);
  }

  /** Nach GPS-Update: aktive Buchung des Fahrers + die Admin-Karte. */
  function publishDriverLocation(driver, explicitBookingId) {
    const ids = new Set();
    if (explicitBookingId) ids.add(String(explicitBookingId));
    if (driver?.activeBookingId) ids.add(String(driver.activeBookingId));
    for (const id of ids) {
      publishBookingTracking(id);
    }
    if (typeof deps.fleetDriverPayload === "function") {
      const payload = deps.fleetDriverPayload(driver);
      if (payload) io.to(FLEET_ROOM).emit("fleet:driver", payload);
    }
  }

  return {
    io,
    intervalMs: LOCATION_STREAM_INTERVAL_MS,
    publishBookingTracking,
    publishDriverLocation,
  };
}

module.exports = {
  createRealtimeHub,
  LOCATION_STREAM_INTERVAL_MS,
};
