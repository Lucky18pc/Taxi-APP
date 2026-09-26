/**
 * Phase 3 — Spatial Matching: verfügbare Fahrer nach Entfernung sortieren.
 */

const {
  encodeGeohash,
  haversineKm,
  filterByGeohashProximity,
} = require("./geohash");

const DEFAULT_RADIUS_KM = Number(process.env.MATCH_RADIUS_KM || 15);
const DEFAULT_PRECISION = Number(process.env.GEOHASH_PRECISION || 6);
const LOCATION_MAX_AGE_MS = Number(process.env.MATCH_LOCATION_MAX_AGE_MS || 2 * 60 * 1000);

/**
 * @param {object} opts
 * @param {number} opts.latitude
 * @param {number} opts.longitude
 * @param {Array<object>} opts.drivers — Legacy-Driver mit lastLat/lastLng/status
 * @param {number} [opts.radiusKm]
 * @param {number} [opts.precision]
 * @param {Set<string>|string[]} [opts.excludeDriverIds]
 * @param {boolean} [opts.requireFreshLocation]
 */
function rankAvailableDrivers(opts) {
  const lat = Number(opts.latitude);
  const lng = Number(opts.longitude);
  if (!Number.isFinite(lat) || !Number.isFinite(lng)) {
    throw new Error("latitude/longitude required for matching");
  }

  const radiusKm = Number(opts.radiusKm) > 0 ? Number(opts.radiusKm) : DEFAULT_RADIUS_KM;
  const precision =
    Number(opts.precision) > 0 ? Math.min(12, Number(opts.precision)) : DEFAULT_PRECISION;
  const exclude = new Set(
    [...(opts.excludeDriverIds || [])].map((id) => String(id)).filter(Boolean)
  );
  const requireFresh = opts.requireFreshLocation !== false;
  const now = Date.now();

  const pool = (opts.drivers || []).filter((d) => {
    if (!d || exclude.has(d.driverId)) return false;
    if (d.status !== "available") return false;
    if (!Number.isFinite(d.lastLat) || !Number.isFinite(d.lastLng)) return false;
    if (requireFresh) {
      if (!d.lastLocationAt) return false;
      const age = now - new Date(d.lastLocationAt).getTime();
      if (!Number.isFinite(age) || age > LOCATION_MAX_AGE_MS) return false;
    }
    return true;
  });

  const withCoords = pool.map((d) => ({
    driver: d,
    latitude: d.lastLat,
    longitude: d.lastLng,
    geohash: encodeGeohash(d.lastLat, d.lastLng, precision),
  }));

  const near = filterByGeohashProximity(lat, lng, withCoords, precision, radiusKm);

  const ranked = near
    .map((c) => {
      const distanceKm = haversineKm(lat, lng, c.latitude, c.longitude);
      return {
        driverId: c.driver.driverId,
        name: c.driver.name,
        phone: c.driver.phone,
        vehicle: c.driver.vehicle,
        status: c.driver.status,
        latitude: c.latitude,
        longitude: c.longitude,
        geohash: c.geohash,
        distanceKm: Math.round(distanceKm * 1000) / 1000,
        locationUpdatedAt: c.driver.lastLocationAt || null,
        firebaseUid: c.driver.firebaseUid || null,
        operatorId: c.driver.operatorId || null,
      };
    })
    .filter((c) => c.distanceKm <= radiusKm)
    .sort((a, b) => a.distanceKm - b.distanceKm);

  return {
    origin: {
      latitude: lat,
      longitude: lng,
      geohash: encodeGeohash(lat, lng, precision),
    },
    radiusKm,
    precision,
    method: "geohash+haversine",
    postgisEquivalent: "ST_DWithin(geography, geography, meters)",
    count: ranked.length,
    drivers: ranked,
  };
}

module.exports = {
  rankAvailableDrivers,
  DEFAULT_RADIUS_KM,
  DEFAULT_PRECISION,
  LOCATION_MAX_AGE_MS,
};
