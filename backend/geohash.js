/**
 * Geohash + Haversine für Spatial Matching (Phase 3).
 * PostGIS ST_DWithin bleibt Phase-C-Option — hier reine JS-Implementierung.
 */

const BASE32 = "0123456789bcdefghjkmnpqrstuvwxyz";

/**
 * @param {number} latitude
 * @param {number} longitude
 * @param {number} [precision=6] ~1.2 km × 0.6 km Zellen
 */
function encodeGeohash(latitude, longitude, precision = 6) {
  let idx = 0;
  let bit = 0;
  let evenBit = true;
  let geohash = "";

  let latMin = -90;
  let latMax = 90;
  let lonMin = -180;
  let lonMax = 180;

  while (geohash.length < precision) {
    if (evenBit) {
      const mid = (lonMin + lonMax) / 2;
      if (longitude >= mid) {
        idx = idx * 2 + 1;
        lonMin = mid;
      } else {
        idx *= 2;
        lonMax = mid;
      }
    } else {
      const mid = (latMin + latMax) / 2;
      if (latitude >= mid) {
        idx = idx * 2 + 1;
        latMin = mid;
      } else {
        idx *= 2;
        latMax = mid;
      }
    }
    evenBit = !evenBit;
    if (++bit === 5) {
      geohash += BASE32.charAt(idx);
      bit = 0;
      idx = 0;
    }
  }
  return geohash;
}

function decodeGeohashBounds(hash) {
  let evenBit = true;
  let latMin = -90;
  let latMax = 90;
  let lonMin = -180;
  let lonMax = 180;

  for (const c of String(hash || "").toLowerCase()) {
    const idx = BASE32.indexOf(c);
    if (idx < 0) continue;
    for (let bit = 4; bit >= 0; bit -= 1) {
      const bitVal = (idx >> bit) & 1;
      if (evenBit) {
        const mid = (lonMin + lonMax) / 2;
        if (bitVal) lonMin = mid;
        else lonMax = mid;
      } else {
        const mid = (latMin + latMax) / 2;
        if (bitVal) latMin = mid;
        else latMax = mid;
      }
      evenBit = !evenBit;
    }
  }
  return { latMin, latMax, lonMin, lonMax };
}

function decodeGeohash(hash) {
  const b = decodeGeohashBounds(hash);
  return {
    latitude: (b.latMin + b.latMax) / 2,
    longitude: (b.lonMin + b.lonMax) / 2,
  };
}

/** 8 Nachbarn + Zentrum (für Prefix-Suche). */
function geohashNeighbors(hash) {
  const h = String(hash || "");
  if (!h) return [];
  const { latMin, latMax, lonMin, lonMax } = decodeGeohashBounds(h);
  const lat = (latMin + latMax) / 2;
  const lon = (lonMin + lonMax) / 2;
  const dLat = (latMax - latMin) * 1.5;
  const dLon = (lonMax - lonMin) * 1.5;
  const precision = h.length;
  const points = [
    [lat, lon],
    [lat + dLat, lon],
    [lat - dLat, lon],
    [lat, lon + dLon],
    [lat, lon - dLon],
    [lat + dLat, lon + dLon],
    [lat + dLat, lon - dLon],
    [lat - dLat, lon + dLon],
    [lat - dLat, lon - dLon],
  ];
  const set = new Set();
  for (const [la, lo] of points) {
    let lng = lo;
    if (lng > 180) lng -= 360;
    if (lng < -180) lng += 360;
    if (la > 90 || la < -90) continue;
    set.add(encodeGeohash(la, lng, precision));
  }
  return [...set];
}

/** Haversine-Distanz in Kilometern. */
function haversineKm(lat1, lon1, lat2, lon2) {
  const toRad = (d) => (d * Math.PI) / 180;
  const R = 6371;
  const dLat = toRad(lat2 - lat1);
  const dLon = toRad(lon2 - lon1);
  const a =
    Math.sin(dLat / 2) ** 2 +
    Math.cos(toRad(lat1)) * Math.cos(toRad(lat2)) * Math.sin(dLon / 2) ** 2;
  return R * 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
}

/**
 * Grobe Zellenfilterung: gleiche/ benachbarte Geohashes, dann exakte Distanz.
 * Entspricht der Idee von ST_DWithin ohne PostGIS.
 */
function filterByGeohashProximity(originLat, originLng, candidates, precision, radiusKm) {
  const originHash = encodeGeohash(originLat, originLng, precision);
  const neighborSet = new Set(geohashNeighbors(originHash));
  return candidates.filter((c) => {
    if (!Number.isFinite(c.latitude) || !Number.isFinite(c.longitude)) return false;
    const h = encodeGeohash(c.latitude, c.longitude, precision);
    if (!neighborSet.has(h) && !h.startsWith(originHash.slice(0, Math.max(1, precision - 1)))) {
      // Fallback: wenn Radius groß, nur Distanz prüfen
      return haversineKm(originLat, originLng, c.latitude, c.longitude) <= radiusKm * 1.5;
    }
    return true;
  });
}

module.exports = {
  encodeGeohash,
  decodeGeohash,
  decodeGeohashBounds,
  geohashNeighbors,
  haversineKm,
  filterByGeohashProximity,
};
