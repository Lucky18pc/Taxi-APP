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

  /** Nach GPS-Update: aktive Buchung des Fahrers + optional explizite bookingId. */
  function publishDriverLocation(driver, explicitBookingId) {
    const ids = new Set();
    if (explicitBookingId) ids.add(String(explicitBookingId));
    if (driver?.activeBookingId) ids.add(String(driver.activeBookingId));
    for (const id of ids) {
      publishBookingTracking(id);
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
