/**
 * Phase-1 Plattform-Metadaten: Mobile, Backend-Wahl, Maps, Realtime, OTP.
 * Bestehende APIs bleiben unverändert — dieser Endpunkt ergänzt nur Transparenz.
 */

const {
  LOCATION_STREAM_INTERVAL_MS,
} = require("./realtime");
const { isTwilioConfigured, otpConfigured } = require("./otp-auth");

function googleMapsBrowserKey() {
  return String(process.env.GOOGLE_MAPS_BROWSER_KEY || process.env.GOOGLE_MAPS_API_KEY || "").trim();
}

function mapboxToken() {
  return String(process.env.MAPBOX_ACCESS_TOKEN || "").trim();
}

function buildPlatformPhase1(realtimeIntervalMs = LOCATION_STREAM_INTERVAL_MS) {
  const mapsKey = googleMapsBrowserKey();
  const mapbox = mapboxToken();

  return {
    phase: 1,
    label: "Architektur, Tech Stack & Infrastruktur",
    mobileApps: {
      passengerIos: {
        stack: "Swift / SwiftUI",
        language: "Swift 6",
        concurrency: "async/await",
        maps: "MapKit",
        path: "TaxiApp/",
      },
      driverIos: {
        stack: "Swift / SwiftUI",
        language: "Swift 6 (Target)",
        concurrency: "async/await",
        auth: "Firebase Auth + Firestore role=driver",
        path: "FahrerApp/",
      },
      passengerAndroidPwa: {
        stack: "PWA (book.html / track.html)",
        backend: "shared Node/Express API",
        maps: mapsKey ? "Google Maps Web SDK" : "Leaflet/OSM (Fallback)",
        googleMapsEnabled: Boolean(mapsKey),
      },
    },
    backend: {
      chosen: "Node.js + Express",
      alternativesDocumented: ["Go", "Python FastAPI"],
      firebase: {
        auth: true,
        firestore: "driver profiles + isOnline",
        cloudFunctions: false,
        adminSdk: false,
      },
      host: "Render.com",
    },
    realtime: {
      transport: "Socket.io (+ HTTP polling fallback)",
      locationIntervalMs: realtimeIntervalMs,
      firestoreListeners: "optional for driver online flag (client)",
      databasePrimary: "JSON files on Render disk (Pilot)",
      databaseOptions: ["PostgreSQL + PostGIS (Phase C)", "Cloud Firestore"],
    },
    thirdParty: {
      appleDeveloper: "required for TestFlight / Tap to Pay",
      googleMaps: {
        enabled: Boolean(mapsKey),
        browserKeyConfigured: Boolean(mapsKey),
        // Browser-Keys sind domain-restricted — Auslieferung an Clients ist üblich.
        browserKey: mapsKey || null,
        services: ["Maps JavaScript API", "Places (planned)", "Directions (planned)", "Distance Matrix (planned)"],
      },
      mapbox: {
        enabled: Boolean(mapbox),
        tokenConfigured: Boolean(mapbox),
      },
      smsOtp: {
        twilioConfigured: isTwilioConfigured(),
        otpEnabled: otpConfigured(),
        firebasePhoneAuth: "native iOS recommended path",
      },
    },
  };
}

/**
 * @param {import("express").Express} app
 * @param {{ intervalMs?: number }} [opts]
 */
function mountPlatformPhase1Routes(app, opts = {}) {
  app.get("/api/platform", (_req, res) => {
    res.json(buildPlatformPhase1(opts.intervalMs));
  });
}

module.exports = {
  buildPlatformPhase1,
  mountPlatformPhase1Routes,
  googleMapsBrowserKey,
};
