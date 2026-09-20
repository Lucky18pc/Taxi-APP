#!/usr/bin/env node
/**
 * Phase 6 — Mock-Driver-Skript
 * Simuliert virtuelle Fahrer, die GPS entlang echter (OSRM) oder vordefinierter
 * Routen alle 2,5 s an das Backend streamen.
 *
 * Usage:
 *   ADMIN_PIN=testpin node scripts/mock-drivers.js [--base URL] [--count 5] [--duration 60]
 *
 * Env:
 *   ADMIN_PIN (required for driver create)
 *   BASE_URL / --base (default http://127.0.0.1:4242)
 *   MOCK_DRIVER_COUNT (default 3)
 *   MOCK_DURATION_SEC (default 45)
 *   MOCK_GPS_INTERVAL_MS (default 2500)
 *   OPERATOR_SLUG (default mannheim)
 */

const DEFAULT_BASE = process.env.BASE_URL || "http://127.0.0.1:4242";
const INTERVAL_MS = Number(process.env.MOCK_GPS_INTERVAL_MS || 2500);
const OPERATOR = process.env.OPERATOR_SLUG || "mannheim";

/** Vordefinierte Mannheim-Routen (Fallback ohne OSRM). */
const SEED_ROUTES = [
  [
    [49.4797, 8.4699],
    [49.4815, 8.471],
    [49.484, 8.473],
    [49.4875, 8.466],
    [49.49, 8.464],
  ],
  [
    [49.495, 8.48],
    [49.492, 8.476],
    [49.488, 8.472],
    [49.484, 8.468],
    [49.48, 8.465],
  ],
  [
    [49.47, 8.46],
    [49.475, 8.465],
    [49.48, 8.47],
    [49.485, 8.475],
    [49.49, 8.48],
  ],
  [
    [49.5, 8.47],
    [49.496, 8.468],
    [49.492, 8.466],
    [49.488, 8.464],
    [49.484, 8.462],
  ],
  [
    [49.477, 8.455],
    [49.48, 8.46],
    [49.483, 8.465],
    [49.486, 8.47],
    [49.489, 8.475],
  ],
];

function parseArgs(argv) {
  const out = {
    base: DEFAULT_BASE,
    count: Number(process.env.MOCK_DRIVER_COUNT || 3),
    durationSec: Number(process.env.MOCK_DURATION_SEC || 45),
    intervalMs: INTERVAL_MS,
    useOsrm: String(process.env.MOCK_USE_OSRM || "1") !== "0",
  };
  for (let i = 2; i < argv.length; i += 1) {
    const a = argv[i];
    if (a === "--base") out.base = argv[++i];
    else if (a === "--count") out.count = Number(argv[++i]);
    else if (a === "--duration") out.durationSec = Number(argv[++i]);
    else if (a === "--interval") out.intervalMs = Number(argv[++i]);
    else if (a === "--no-osrm") out.useOsrm = false;
  }
  return out;
}

async function api(base, method, path, { body, adminPin, headers } = {}) {
  const res = await fetch(`${base}${path}`, {
    method,
    headers: {
      "Content-Type": "application/json",
      ...(adminPin ? { Authorization: `Bearer ${adminPin}` } : {}),
      ...headers,
    },
    body: body ? JSON.stringify(body) : undefined,
  });
  const text = await res.text();
  let json = {};
  try {
    json = text ? JSON.parse(text) : {};
  } catch {
    json = { raw: text };
  }
  if (!res.ok) {
    const err = new Error(json.error || `${method} ${path} → ${res.status}`);
    err.status = res.status;
    err.body = json;
    throw err;
  }
  return json;
}

function interpolate(route, t) {
  if (!route.length) return null;
  if (route.length === 1) return route[0];
  const pos = Math.max(0, Math.min(1, t)) * (route.length - 1);
  const i = Math.floor(pos);
  const f = pos - i;
  if (i >= route.length - 1) return route[route.length - 1];
  const a = route[i];
  const b = route[i + 1];
  return [a[0] + (b[0] - a[0]) * f, a[1] + (b[1] - a[1]) * f];
}

/** Densify polyline for smoother 2.5s steps. */
function densify(route, pointsPerSegment = 8) {
  const out = [];
  for (let i = 0; i < route.length - 1; i += 1) {
    const a = route[i];
    const b = route[i + 1];
    for (let s = 0; s < pointsPerSegment; s += 1) {
      const f = s / pointsPerSegment;
      out.push([a[0] + (b[0] - a[0]) * f, a[1] + (b[1] - a[1]) * f]);
    }
  }
  out.push(route[route.length - 1]);
  return out;
}

async function fetchOsrmRoute(from, to) {
  const url =
    `https://router.project-osrm.org/route/v1/driving/` +
    `${from[1]},${from[0]};${to[1]},${to[0]}?overview=full&geometries=geojson`;
  const res = await fetch(url, { headers: { "User-Agent": "LuckysTaxiMockDrivers/1.0" } });
  if (!res.ok) throw new Error(`OSRM HTTP ${res.status}`);
  const data = await res.json();
  const coords = data.routes?.[0]?.geometry?.coordinates;
  if (!Array.isArray(coords) || !coords.length) throw new Error("OSRM empty geometry");
  // GeoJSON is [lng, lat] → [lat, lng]
  return coords.map(([lng, lat]) => [lat, lng]);
}

async function buildRoute(seed, useOsrm) {
  const from = seed[0];
  const to = seed[seed.length - 1];
  if (useOsrm) {
    try {
      const osrm = await fetchOsrmRoute(from, to);
      return densify(osrm, 3);
    } catch (error) {
      console.warn(`  OSRM fallback (${error.message})`);
    }
  }
  return densify(seed, 10);
}

async function createMockDriver(base, adminPin, index) {
  const name = `Mock Fahrer ${index + 1}`;
  const phone = `+49170${String(1000000 + index).slice(0, 7)}`;
  const vehicle = `MA-MOCK ${index + 1}`;
  const driver = await api(base, "POST", `/api/drivers?operator=${OPERATOR}`, {
    adminPin,
    body: { name, phone, vehicle, operator: OPERATOR },
  });
  await api(base, "PATCH", `/api/drivers/${driver.driverId}/status?operator=${OPERATOR}`, {
    adminPin,
    body: { status: "available" },
  });
  return driver;
}

async function postLocation(base, driver, lat, lng) {
  return api(base, "POST", `/api/drivers/${driver.driverId}/location`, {
    body: {
      trackingPin: driver.trackingPin,
      latitude: lat,
      longitude: lng,
    },
  });
}

async function main() {
  const opts = parseArgs(process.argv);
  const adminPin = process.env.ADMIN_PIN || "";
  if (!adminPin) {
    console.error("ADMIN_PIN erforderlich (Fahrer anlegen).");
    process.exit(1);
  }

  console.log("=== Mock-Driver Simulation ===");
  console.log(`Base: ${opts.base}`);
  console.log(
    `Drivers: ${opts.count} · Interval: ${opts.intervalMs}ms · Duration: ${opts.durationSec}s · OSRM: ${opts.useOsrm}`
  );

  const health = await api(opts.base, "GET", "/health");
  console.log(`Health ok · bookings=${health.bookings}`);

  const drivers = [];
  for (let i = 0; i < opts.count; i += 1) {
    const seed = SEED_ROUTES[i % SEED_ROUTES.length];
    const route = await buildRoute(seed, opts.useOsrm);
    const driver = await createMockDriver(opts.base, adminPin, i);
    drivers.push({ driver, route, step: 0 });
    const [lat0, lng0] = route[0];
    await postLocation(opts.base, driver, lat0, lng0);
    console.log(
      `  + ${driver.name} ${driver.driverId.slice(0, 8)}… routePoints=${route.length}`
    );
  }

  const started = Date.now();
  let ticks = 0;
  let posts = 0;
  let errors = 0;

  await new Promise((resolve) => {
    const timer = setInterval(async () => {
      const elapsed = (Date.now() - started) / 1000;
      if (elapsed >= opts.durationSec) {
        clearInterval(timer);
        resolve();
        return;
      }
      ticks += 1;
      const progress = Math.min(1, elapsed / opts.durationSec);

      await Promise.all(
        drivers.map(async (entry) => {
          const point = interpolate(entry.route, progress);
          if (!point) return;
          try {
            await postLocation(opts.base, entry.driver, point[0], point[1]);
            posts += 1;
          } catch (error) {
            errors += 1;
            if (errors <= 3) console.warn(`  GPS error: ${error.message}`);
          }
        })
      );

      if (ticks % 4 === 0) {
        console.log(
          `  … t=${elapsed.toFixed(0)}s posts=${posts} errors=${errors} drivers=${drivers.length}`
        );
      }
    }, opts.intervalMs);
  });

  console.log("");
  console.log(
    JSON.stringify(
      {
        ok: errors === 0 || posts > errors,
        drivers: drivers.map((d) => ({
          driverId: d.driver.driverId,
          name: d.driver.name,
          trackingPin: d.driver.trackingPin,
        })),
        ticks,
        posts,
        errors,
        intervalMs: opts.intervalMs,
        durationSec: opts.durationSec,
      },
      null,
      2
    )
  );
  console.log("OK — Mock-Driver-Stream beendet.");
}

main().catch((error) => {
  console.error(error);
  process.exit(1);
});
