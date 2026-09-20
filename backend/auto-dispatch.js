/**
 * Phase 3 — Auto-Dispatch mit 15-Sekunden-Timeout.
 * Leitet an den nächstgelegenen freien Fahrer weiter, wenn keine Annahme kommt.
 */

const { rankAvailableDrivers } = require("./matching");
const { RIDE_STATUSES } = require("./core-models");

const OFFER_TIMEOUT_MS = Number(process.env.MATCH_OFFER_TIMEOUT_MS || 15_000);

/**
 * @param {object} deps
 * @param {() => object[]} deps.getDrivers
 * @param {(id: string) => object|null} deps.findBooking
 * @param {(id: string) => object|null} deps.findDriver
 * @param {() => void} deps.saveBookings
 * @param {() => void} [deps.saveDrivers]
 * @param {(booking: object, extra?: object) => void} [deps.syncCoreBooking]
 * @param {(driver: object) => void} [deps.syncCoreDriver]
 * @param {(event: string, payload: object) => void} [deps.emit]
 * @param {number} [deps.timeoutMs]
 * @param {number} [deps.radiusKm]
 */
function createAutoDispatch(deps) {
  const timeoutMs = Number(deps.timeoutMs) > 0 ? Number(deps.timeoutMs) : OFFER_TIMEOUT_MS;
  /** @type {Map<string, NodeJS.Timeout>} */
  const timers = new Map();

  function clearTimer(bookingId) {
    const t = timers.get(bookingId);
    if (t) {
      clearTimeout(t);
      timers.delete(bookingId);
    }
  }

  function emit(event, payload) {
    if (typeof deps.emit === "function") deps.emit(event, payload);
  }

  function publicDispatch(booking) {
    const d = booking?.dispatch;
    if (!d) return null;
    return {
      mode: d.mode,
      status: d.status,
      offerDriverId: d.offerDriverId || null,
      offeredAt: d.offeredAt || null,
      expiresAt: d.expiresAt || null,
      timeoutMs: d.timeoutMs || timeoutMs,
      attempt: d.attempt || 0,
      skippedDriverIds: d.skippedDriverIds || [],
      candidateCount: Array.isArray(d.candidateDriverIds) ? d.candidateDriverIds.length : 0,
    };
  }

  function buildCandidates(booking, excludeIds = []) {
    const drivers = typeof deps.getDrivers === "function" ? deps.getDrivers() : [];
    const scoped = booking.operatorId
      ? drivers.filter((d) => !d.operatorId || d.operatorId === booking.operatorId)
      : drivers;

    const ranked = rankAvailableDrivers({
      latitude: booking.latitude,
      longitude: booking.longitude,
      drivers: scoped,
      excludeDriverIds: excludeIds,
      radiusKm: deps.radiusKm,
    });
    return ranked;
  }

  function offerToDriver(booking, candidate, allCandidateIds) {
    const now = Date.now();
    booking.dispatch = {
      mode: "auto",
      status: "offering",
      offerDriverId: candidate.driverId,
      offeredAt: new Date(now).toISOString(),
      expiresAt: new Date(now + timeoutMs).toISOString(),
      timeoutMs,
      attempt: (booking.dispatch?.attempt || 0) + 1,
      skippedDriverIds: booking.dispatch?.skippedDriverIds || [],
      candidateDriverIds: allCandidateIds,
      lastDistanceKm: candidate.distanceKm,
    };
    booking.updatedAt = new Date().toISOString();
    // Status bleibt confirmed/accepted bis echte Annahme — Apps brechen nicht
    if (booking.status === "assigned" && !booking.assignedDriverId) {
      booking.status = "confirmed";
    }
    deps.saveBookings();
    if (deps.syncCoreBooking) {
      deps.syncCoreBooking(booking, { rideStatus: RIDE_STATUSES.RIDE_REQUEST });
    }
    emit("dispatch:offer", {
      bookingId: booking.bookingId,
      driverId: candidate.driverId,
      distanceKm: candidate.distanceKm,
      expiresAt: booking.dispatch.expiresAt,
      attempt: booking.dispatch.attempt,
    });
    scheduleTimeout(booking.bookingId);
    return booking.dispatch;
  }

  function markExhausted(booking) {
    clearTimer(booking.bookingId);
    booking.dispatch = {
      ...(booking.dispatch || {}),
      mode: "auto",
      status: "exhausted",
      offerDriverId: null,
      offeredAt: booking.dispatch?.offeredAt || null,
      expiresAt: null,
      timeoutMs,
      attempt: booking.dispatch?.attempt || 0,
      skippedDriverIds: booking.dispatch?.skippedDriverIds || [],
      candidateDriverIds: booking.dispatch?.candidateDriverIds || [],
      exhaustedAt: new Date().toISOString(),
    };
    booking.updatedAt = new Date().toISOString();
    deps.saveBookings();
    emit("dispatch:exhausted", { bookingId: booking.bookingId });
    return booking.dispatch;
  }

  function advanceOffer(bookingId, reason) {
    const booking = deps.findBooking(bookingId);
    if (!booking) return null;
    if (booking.assignedDriverId && booking.status === "assigned") {
      clearTimer(bookingId);
      return publicDispatch(booking);
    }
    if (booking.status === "completed" || booking.status === "cancelled") {
      clearTimer(bookingId);
      return publicDispatch(booking);
    }

    const skipped = new Set(booking.dispatch?.skippedDriverIds || []);
    if (booking.dispatch?.offerDriverId) {
      skipped.add(booking.dispatch.offerDriverId);
    }

    booking.dispatch = {
      ...(booking.dispatch || { mode: "auto" }),
      skippedDriverIds: [...skipped],
      offerDriverId: null,
      status: "searching",
    };

    const ranked = buildCandidates(booking, [...skipped]);
    if (!ranked.drivers.length) {
      return markExhausted(booking);
    }

    const next = ranked.drivers[0];
    const allIds = ranked.drivers.map((d) => d.driverId);
    offerToDriver(booking, next, allIds);
    emit("dispatch:timeout", {
      bookingId,
      reason: reason || "timeout",
      nextDriverId: next.driverId,
      distanceKm: next.distanceKm,
    });
    return publicDispatch(booking);
  }

  function scheduleTimeout(bookingId) {
    clearTimer(bookingId);
    const handle = setTimeout(() => {
      timers.delete(bookingId);
      try {
        advanceOffer(bookingId, "timeout");
      } catch (error) {
        console.warn("auto-dispatch timeout:", error.message || error);
      }
    }, timeoutMs);
    if (typeof handle.unref === "function") handle.unref();
    timers.set(bookingId, handle);
  }

  function startDispatch(bookingId, options = {}) {
    const booking = deps.findBooking(bookingId);
    if (!booking) {
      const err = new Error("Booking not found");
      err.status = 404;
      throw err;
    }
    if (booking.status === "completed" || booking.status === "cancelled") {
      const err = new Error("Booking already closed");
      err.status = 400;
      throw err;
    }
    if (booking.assignedDriverId && !options.force) {
      const err = new Error("Booking already assigned — use force=true to re-dispatch");
      err.status = 409;
      throw err;
    }

    clearTimer(bookingId);
    if (options.force && booking.assignedDriverId) {
      const prev = deps.findDriver(booking.assignedDriverId);
      booking.assignedDriverId = null;
      booking.assignedFirebaseUid = null;
      booking.assignedDriverName = null;
      booking.status = "confirmed";
      if (prev && prev.status === "busy") {
        prev.status = "available";
        prev.activeBookingId = null;
        if (deps.saveDrivers) deps.saveDrivers();
        if (deps.syncCoreDriver) deps.syncCoreDriver(prev);
      }
    }

    booking.dispatch = {
      mode: "auto",
      status: "searching",
      offerDriverId: null,
      offeredAt: null,
      expiresAt: null,
      timeoutMs,
      attempt: 0,
      skippedDriverIds: [],
      candidateDriverIds: [],
      startedAt: new Date().toISOString(),
    };

    const ranked = buildCandidates(booking, []);
    if (!ranked.drivers.length) {
      return {
        dispatch: markExhausted(booking),
        matching: ranked,
      };
    }

    const first = ranked.drivers[0];
    offerToDriver(
      booking,
      first,
      ranked.drivers.map((d) => d.driverId)
    );
    return {
      dispatch: publicDispatch(booking),
      matching: ranked,
    };
  }

  function acceptOffer(booking, driver) {
    if (!booking?.dispatch || booking.dispatch.status !== "offering") {
      return { ok: false, error: "No active offer" };
    }
    if (booking.dispatch.offerDriverId !== driver.driverId) {
      return { ok: false, error: "Offer is for another driver" };
    }
    clearTimer(booking.bookingId);
    booking.dispatch.status = "accepted";
    booking.dispatch.acceptedAt = new Date().toISOString();
    booking.dispatch.offerDriverId = null;
    booking.dispatch.expiresAt = null;
    booking.assignedDriverId = driver.driverId;
    booking.assignedDriverName = driver.name;
    if (driver.firebaseUid) booking.assignedFirebaseUid = driver.firebaseUid;
    booking.status = "assigned";
    driver.status = "busy";
    driver.activeBookingId = booking.bookingId;
    booking.updatedAt = new Date().toISOString();
    deps.saveBookings();
    if (deps.saveDrivers) deps.saveDrivers();
    if (deps.syncCoreDriver) deps.syncCoreDriver(driver);
    if (deps.syncCoreBooking) {
      deps.syncCoreBooking(booking, { rideStatus: RIDE_STATUSES.ACCEPTED });
    }
    emit("dispatch:accepted", {
      bookingId: booking.bookingId,
      driverId: driver.driverId,
    });
    return { ok: true };
  }

  function declineOffer(booking, driverId) {
    if (!booking?.dispatch || booking.dispatch.status !== "offering") {
      return { ok: false, error: "No active offer" };
    }
    if (booking.dispatch.offerDriverId !== driverId) {
      return { ok: false, error: "Offer is for another driver" };
    }
    return { ok: true, dispatch: advanceOffer(booking.bookingId, "declined") };
  }

  /** Nach Restart: abgelaufene Offers nachziehen. */
  function recoverOpenOffers(bookings) {
    const now = Date.now();
    for (const booking of bookings || []) {
      if (!booking?.dispatch || booking.dispatch.status !== "offering") continue;
      if (booking.assignedDriverId) continue;
      const expires = booking.dispatch.expiresAt
        ? new Date(booking.dispatch.expiresAt).getTime()
        : 0;
      if (expires && expires <= now) {
        advanceOffer(booking.bookingId, "recovery");
      } else if (expires > now) {
        const remain = expires - now;
        clearTimer(booking.bookingId);
        const handle = setTimeout(() => {
          timers.delete(booking.bookingId);
          advanceOffer(booking.bookingId, "timeout");
        }, remain);
        if (typeof handle.unref === "function") handle.unref();
        timers.set(booking.bookingId, handle);
      }
    }
  }

  function stopDispatch(bookingId) {
    const booking = deps.findBooking(bookingId);
    clearTimer(bookingId);
    if (!booking?.dispatch) return null;
    booking.dispatch.status = "cancelled";
    booking.dispatch.offerDriverId = null;
    booking.dispatch.expiresAt = null;
    booking.updatedAt = new Date().toISOString();
    deps.saveBookings();
    return publicDispatch(booking);
  }

  return {
    timeoutMs,
    startDispatch,
    advanceOffer,
    acceptOffer,
    declineOffer,
    recoverOpenOffers,
    stopDispatch,
    publicDispatch,
    buildCandidates,
    clearTimer,
  };
}

module.exports = {
  createAutoDispatch,
  OFFER_TIMEOUT_MS,
};
