/**
 * Phase 4 — Places Autocomplete, Distance Matrix, Tarif-Quote.
 * Nutzt Google Maps Platform wenn GOOGLE_MAPS_* Key gesetzt, sonst Nominatim/Haversine-Fallback.
 */

const { haversineKm } = require("./geohash");

const BASE_FARE_DAY = Number(process.env.FARE_BASE_DAY || 3.9);
const PER_KM_DAY = Number(process.env.FARE_PER_KM_DAY || 2.3);
const BASE_FARE_NIGHT = Number(process.env.FARE_BASE_NIGHT || 4.9);
const PER_KM_NIGHT = Number(process.env.FARE_PER_KM_NIGHT || 2.6);

function googleKey() {
  return String(
    process.env.GOOGLE_MAPS_SERVER_KEY ||
      process.env.GOOGLE_MAPS_API_KEY ||
      process.env.GOOGLE_MAPS_BROWSER_KEY ||
      ""
  ).trim();
}

function isNightHour(date = new Date()) {
  const hour = date.getHours();
  return hour < 6 || hour >= 22;
}

function calculateFareFromKm(distanceKm, at = new Date()) {
  const night = isNightHour(at);
  const base = night ? BASE_FARE_NIGHT : BASE_FARE_DAY;
  const perKm = night ? PER_KM_NIGHT : PER_KM_DAY;
  const fare = Math.round((base + distanceKm * perKm) * 100) / 100;
  return {
    fare,
    basePrice: base,
    pricePerKm: perKm,
    isNight: night,
    formula: "Grundpreis + (Kilometer * Kilometertarif)",
    distanceKm: Math.round(distanceKm * 1000) / 1000,
  };
}

async function placesAutocomplete(query, { sessionToken } = {}) {
  const q = String(query || "").trim();
  if (q.length < 2) return { predictions: [], provider: "none" };

  const key = googleKey();
  if (!key) {
    return {
      predictions: [],
      provider: "unavailable",
      hint: "GOOGLE_MAPS_API_KEY setzen — sonst Nominatim-Fallback über Route",
    };
  }

  const params = new URLSearchParams({
    input: q,
    key,
    language: "de",
    components: "country:de",
  });
  if (sessionToken) params.set("sessiontoken", sessionToken);
  const url = `https://maps.googleapis.com/maps/api/place/autocomplete/json?${params}`;
  const res = await fetch(url);
  const data = await res.json();
  if (data.status && data.status !== "OK" && data.status !== "ZERO_RESULTS") {
    throw new Error(data.error_message || `Places status ${data.status}`);
  }
  const predictions = (data.predictions || []).map((p) => ({
    placeId: p.place_id,
    description: p.description,
    mainText: p.structured_formatting?.main_text || p.description,
    secondaryText: p.structured_formatting?.secondary_text || "",
  }));
  return { predictions, provider: "google_places" };
}

async function placeDetails(placeId) {
  const key = googleKey();
  if (!key || !placeId) return null;
  const params = new URLSearchParams({
    place_id: placeId,
    key,
    language: "de",
    fields: "geometry,formatted_address,name",
  });
  const res = await fetch(`https://maps.googleapis.com/maps/api/place/details/json?${params}`);
  const data = await res.json();
  const r = data.result;
  if (!r?.geometry?.location) return null;
  return {
    placeId,
    name: r.name || "",
    address: r.formatted_address || r.name || "",
    latitude: r.geometry.location.lat,
    longitude: r.geometry.location.lng,
    provider: "google_places",
  };
}

/**
 * Distance Matrix API oder Haversine-Fallback.
 */
async function distanceMatrix(origin, destination) {
  const oLat = Number(origin.latitude ?? origin.lat);
  const oLng = Number(origin.longitude ?? origin.lng);
  const dLat = Number(destination.latitude ?? destination.lat);
  const dLng = Number(destination.longitude ?? destination.lng);
  if (![oLat, oLng, dLat, dLng].every(Number.isFinite)) {
    throw new Error("origin/destination latitude+longitude required");
  }

  const key = googleKey();
  if (key) {
    const params = new URLSearchParams({
      origins: `${oLat},${oLng}`,
      destinations: `${dLat},${dLng}`,
      key,
      language: "de",
      mode: "driving",
      units: "metric",
    });
    const res = await fetch(`https://maps.googleapis.com/maps/api/distancematrix/json?${params}`);
    const data = await res.json();
    const element = data.rows?.[0]?.elements?.[0];
    if (element?.status === "OK") {
      const distanceMeters = element.distance.value;
      const durationSeconds = element.duration.value;
      return {
        provider: "google_distance_matrix",
        distanceMeters,
        durationSeconds,
        distanceText: element.distance.text,
        durationText: element.duration.text,
        origin: { latitude: oLat, longitude: oLng },
        destination: { latitude: dLat, longitude: dLng },
      };
    }
  }

  const distanceKm = haversineKm(oLat, oLng, dLat, dLng);
  const distanceMeters = Math.round(distanceKm * 1000);
  // grobe Stadtgeschwindigkeit ~30 km/h
  const durationSeconds = Math.round((distanceKm / 30) * 3600);
  return {
    provider: "haversine_fallback",
    distanceMeters,
    durationSeconds,
    distanceText: `${distanceKm.toFixed(1)} km`,
    durationText: `${Math.max(1, Math.round(durationSeconds / 60))} Min.`,
    origin: { latitude: oLat, longitude: oLng },
    destination: { latitude: dLat, longitude: dLng },
  };
}

async function fareQuote(origin, destination) {
  const matrix = await distanceMatrix(origin, destination);
  const distanceKm = matrix.distanceMeters / 1000;
  const fare = calculateFareFromKm(distanceKm);
  return {
    ...matrix,
    ...fare,
    estimatedEarnings: fare.fare,
  };
}

/**
 * @param {import("express").Express} app
 * @param {{ nominatimSearch?: Function }} [deps]
 */
function mountMapsServiceRoutes(app, deps = {}) {
  app.get("/api/places/autocomplete", async (req, res) => {
    try {
      const q = String(req.query.q || req.query.input || "").trim();
      const key = googleKey();
      if (key) {
        const result = await placesAutocomplete(q, {
          sessionToken: req.query.sessionToken,
        });
        return res.json(result);
      }
      // Nominatim-Fallback als Autocomplete-ähnliche Liste
      if (typeof deps.nominatimSearch === "function" && q.length >= 2) {
        const data = await deps.nominatimSearch(q, { countrycodes: "de", limit: 5 });
        const list = Array.isArray(data) ? data : [];
        return res.json({
          provider: "nominatim",
          predictions: list.map((item, i) => ({
            placeId: `nom:${item.lat},${item.lon}:${i}`,
            description: item.display_name,
            mainText: String(item.display_name || "").split(",")[0],
            secondaryText: String(item.display_name || "")
              .split(",")
              .slice(1)
              .join(",")
              .trim(),
            latitude: Number(item.lat),
            longitude: Number(item.lon),
          })),
        });
      }
      return res.json({
        predictions: [],
        provider: "none",
        hint: "GOOGLE_MAPS_API_KEY oder Nominatim-Proxy",
      });
    } catch (error) {
      res.status(502).json({ error: error.message || "places failed" });
    }
  });

  app.get("/api/places/details", async (req, res) => {
    try {
      const placeId = String(req.query.placeId || "").trim();
      if (placeId.startsWith("nom:")) {
        const parts = placeId.split(":");
        const lat = Number(parts[1]?.split(",")[0]);
        const lon = Number(parts[1]?.split(",")[1]);
        if (!Number.isFinite(lat) || !Number.isFinite(lon)) {
          return res.status(400).json({ error: "invalid nominatim placeId" });
        }
        return res.json({
          placeId,
          latitude: lat,
          longitude: lon,
          address: String(req.query.description || ""),
          provider: "nominatim",
        });
      }
      const details = await placeDetails(placeId);
      if (!details) return res.status(404).json({ error: "place not found" });
      res.json(details);
    } catch (error) {
      res.status(502).json({ error: error.message || "place details failed" });
    }
  });

  app.get("/api/distance-matrix", async (req, res) => {
    try {
      const origin = {
        latitude: Number(req.query.originLat ?? req.query.oLat),
        longitude: Number(req.query.originLng ?? req.query.oLng),
      };
      const destination = {
        latitude: Number(req.query.destLat ?? req.query.dLat),
        longitude: Number(req.query.destLng ?? req.query.dLng),
      };
      const result = await distanceMatrix(origin, destination);
      res.json(result);
    } catch (error) {
      res.status(400).json({ error: error.message || "distance-matrix failed" });
    }
  });

  app.post("/api/fare/quote", async (req, res) => {
    try {
      const origin = req.body.origin || {
        latitude: req.body.originLat,
        longitude: req.body.originLng,
      };
      const destination = req.body.destination || {
        latitude: req.body.destLat,
        longitude: req.body.destLng,
      };
      const quote = await fareQuote(origin, destination);
      res.json(quote);
    } catch (error) {
      res.status(400).json({ error: error.message || "fare quote failed" });
    }
  });

  app.get("/api/fare/tariff", (_req, res) => {
    res.json({
      formula: "Grundpreis + (Kilometer * Kilometertarif)",
      day: { base: BASE_FARE_DAY, perKm: PER_KM_DAY },
      night: { base: BASE_FARE_NIGHT, perKm: PER_KM_NIGHT },
      nightHours: "22:00–06:00",
      googleMapsConfigured: Boolean(googleKey()),
    });
  });
}

module.exports = {
  mountMapsServiceRoutes,
  placesAutocomplete,
  placeDetails,
  distanceMatrix,
  fareQuote,
  calculateFareFromKm,
  googleKey,
};
