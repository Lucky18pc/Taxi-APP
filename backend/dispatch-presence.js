/**
 * Leitstellen-Präsenz: Heartbeat aus dispatch.html.
 * Ohne Heartbeat gilt die Zentrale als unbesetzt → Auto-Dispatch / Anruf an Fahrer.
 */

const { rankAvailableDrivers } = require("./matching");

const STALE_AFTER_MS = Number(process.env.DISPATCH_PRESENCE_STALE_MS || 90_000);

/** @type {Map<string, { at: number, source?: string }>} */
const heartbeats = new Map();

function presenceKey(operatorIdOrSlug) {
  const key = String(operatorIdOrSlug || "default").trim() || "default";
  return key.toLowerCase();
}

function touch(operatorIdOrSlug, source = "dispatch") {
  const key = presenceKey(operatorIdOrSlug);
  heartbeats.set(key, { at: Date.now(), source: String(source || "dispatch") });
  return status(key);
}

function status(operatorIdOrSlug) {
  const key = presenceKey(operatorIdOrSlug);
  const entry = heartbeats.get(key);
  const now = Date.now();
  if (!entry) {
    return {
      key,
      online: false,
      lastSeenAt: null,
      staleAfterMs: STALE_AFTER_MS,
      ageMs: null,
    };
  }
  const ageMs = now - entry.at;
  return {
    key,
    online: ageMs <= STALE_AFTER_MS,
    lastSeenAt: new Date(entry.at).toISOString(),
    staleAfterMs: STALE_AFTER_MS,
    ageMs,
    source: entry.source || null,
  };
}

/**
 * Anrufziel:
 * - dispatchMode "auto" (Standard): immer freier Fahrer, Zentrale nur Fallback
 * - dispatchMode "manual": Zentrale wenn besetzt, sonst Fahrer
 */
function resolveDialTarget(opts) {
  const {
    operatorId,
    operatorSlug,
    centralPhone,
    centralPhoneDisplay,
    companyName,
    latitude,
    longitude,
    drivers,
    radiusKm,
    dispatchMode,
  } = opts;

  const key = operatorId || operatorSlug || "default";
  const presence = status(key);
  const central = String(centralPhone || "").trim();
  const mode = String(dispatchMode || "auto").trim().toLowerCase() === "manual" ? "manual" : "auto";

  if (mode === "manual" && presence.online && central) {
    return {
      mode: "central",
      phone: central,
      displayName: centralPhoneDisplay || companyName || "Zentrale",
      label: "Zentrale anrufen",
      dispatchOnline: true,
      dispatchMode: mode,
      presence,
    };
  }

  const lat = Number(latitude);
  const lng = Number(longitude);
  const pool = Array.isArray(drivers) ? drivers : [];
  const scoped = operatorId
    ? pool.filter((d) => !d.operatorId || d.operatorId === operatorId)
    : pool;

  let candidate = null;
  if (Number.isFinite(lat) && Number.isFinite(lng) && scoped.length) {
    try {
      const ranked = rankAvailableDrivers({
        latitude: lat,
        longitude: lng,
        drivers: scoped,
        radiusKm,
        requireFreshLocation: true,
      });
      candidate = ranked.drivers[0] || null;
      // Ohne frische GPS-Daten: trotzdem verfügbare Fahrer mit Telefon
      if (!candidate) {
        const loose = rankAvailableDrivers({
          latitude: lat,
          longitude: lng,
          drivers: scoped,
          radiusKm: radiusKm || 50,
          requireFreshLocation: false,
        });
        candidate = loose.drivers[0] || null;
      }
    } catch {
      candidate = null;
    }
  }

  if (!candidate) {
    const available = scoped.filter(
      (d) => d && d.status === "available" && String(d.phone || "").trim()
    );
    if (available.length) {
      const d = available[0];
      candidate = {
        driverId: d.driverId,
        name: d.name,
        phone: d.phone,
        distanceKm: null,
      };
    }
  }

  if (candidate && String(candidate.phone || "").trim()) {
    return {
      mode: "driver",
      phone: String(candidate.phone).trim(),
      displayName: candidate.name || "Fahrer in der Nähe",
      label: "Fahrer in der Nähe anrufen",
      dispatchOnline: presence.online,
      dispatchMode: mode,
      driverId: candidate.driverId || null,
      distanceKm: candidate.distanceKm ?? null,
      presence,
      note:
        mode === "auto"
          ? "Automatik-Modus — Anruf geht direkt an einen freien Fahrer."
          : "Zentrale gerade nicht besetzt — Anruf geht an einen freien Fahrer.",
    };
  }

  if (central) {
    return {
      mode: "central",
      phone: central,
      displayName: centralPhoneDisplay || companyName || "Zentrale",
      label: "Zentrale anrufen",
      dispatchOnline: presence.online,
      dispatchMode: mode,
      presence,
      note: "Kein freier Fahrer online — Fallback Zentrale.",
    };
  }

  return {
    mode: "unavailable",
    phone: "",
    displayName: "",
    label: "Derzeit nicht erreichbar",
    dispatchOnline: presence.online,
    dispatchMode: mode,
    presence,
    note: "Kein Fahrer mit Nummer und keine Zentrale-Nummer hinterlegt.",
  };
}

module.exports = {
  STALE_AFTER_MS,
  touch,
  status,
  resolveDialTarget,
  presenceKey,
};
