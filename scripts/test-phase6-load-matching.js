#!/usr/bin/env node
/**
 * Phase 6 — Load-Test Matchmaking
 * Legt viele verfügbare Fahrer mit GPS an, erzeugt parallele Buchungen mit
 * autoDispatch und misst Offer-/Exhausted-Raten.
 *
 *   ADMIN_PIN=testpin node scripts/test-phase6-load-matching.js [--bookings 20] [--drivers 8]
 */

const DEFAULT_BASE = process.env.BASE_URL || "http://127.0.0.1:4242";
const OPERATOR = process.env.OPERATOR_SLUG || "mannheim";

function parseArgs(argv) {
  const out = {
    base: DEFAULT_BASE,
    drivers: Number(process.env.LOAD_DRIVERS || 8),
    bookings: Number(process.env.LOAD_BOOKINGS || 20),
    radiusKm: Number(process.env.MATCH_RADIUS_KM || 15),
  };
  for (let i = 2; i < argv.length; i += 1) {
    const a = argv[i];
    if (a === "--base") out.base = argv[++i];
    else if (a === "--drivers") out.drivers = Number(argv[++i]);
    else if (a === "--bookings") out.bookings = Number(argv[++i]);
  }
  return out;
}

async function api(base, method, path, { body, adminPin } = {}) {
  const res = await fetch(`${base}${path}`, {
    method,
    headers: {
      "Content-Type": "application/json",
      ...(adminPin ? { Authorization: `Bearer ${adminPin}` } : {}),
    },
    body: body ? JSON.stringify(body) : undefined,
  });
  const json = await res.json().catch(() => ({}));
  if (!res.ok) {
    const err = new Error(json.error || `${method} ${path} → ${res.status}`);
    err.status = res.status;
    throw err;
  }
  return json;
}

function jitter(base, spread) {
  return base + (Math.random() - 0.5) * spread;
}

async function main() {
  const opts = parseArgs(process.argv);
  const adminPin = process.env.ADMIN_PIN || "";
  if (!adminPin) {
    console.error("ADMIN_PIN erforderlich");
    process.exit(1);
  }

  console.log("=== Phase-6 Load Matching ===");
  console.log(
    `Base=${opts.base} drivers=${opts.drivers} bookings=${opts.bookings}`
  );

  // Offline-Sweep available drivers (clean pool)
  const listed = await api(opts.base, "GET", `/api/drivers?operator=${OPERATOR}`, {
    adminPin,
  });
  for (const d of listed.drivers || []) {
    if (d.status === "available") {
      try {
        await api(opts.base, "PATCH", `/api/drivers/${d.driverId}/status?operator=${OPERATOR}`, {
          adminPin,
          body: { status: "offline" },
        });
      } catch (_) {
        /* ignore */
      }
    }
  }

  const center = { lat: 49.4797, lng: 8.4699 };
  const createdDrivers = [];
  for (let i = 0; i < opts.drivers; i += 1) {
    const driver = await api(opts.base, "POST", `/api/drivers?operator=${OPERATOR}`, {
      adminPin,
      body: {
        name: `Load Fahrer ${i + 1}`,
        phone: `+49171${String(2000000 + i)}`,
        vehicle: `MA-L ${i + 1}`,
        operator: OPERATOR,
      },
    });
    await api(opts.base, "PATCH", `/api/drivers/${driver.driverId}/status?operator=${OPERATOR}`, {
      adminPin,
      body: { status: "available" },
    });
    const lat = jitter(center.lat, 0.02);
    const lng = jitter(center.lng, 0.02);
    await api(opts.base, "POST", `/api/drivers/${driver.driverId}/location`, {
      body: {
        trackingPin: driver.trackingPin,
        latitude: lat,
        longitude: lng,
      },
    });
    createdDrivers.push(driver);
  }
  console.log(`  drivers ready: ${createdDrivers.length}`);

  const ranked = await api(
    opts.base,
    "GET",
    `/api/matching/drivers?operator=${OPERATOR}&lat=${center.lat}&lng=${center.lng}`,
    { adminPin }
  );
  console.log(`  matching pool: ${ranked.count}`);

  const t0 = Date.now();
  const results = await Promise.all(
    Array.from({ length: opts.bookings }, async (_, i) => {
      const start = Date.now();
      try {
        const booking = await api(opts.base, "POST", "/api/bookings", {
          body: {
            latitude: jitter(center.lat, 0.008),
            longitude: jitter(center.lng, 0.008),
            addressLine: `Load Booking ${i + 1}`,
            paymentMethod: "Bar",
            totalAmount: 0,
            autoDispatch: true,
          },
        });
        // Kurz warten bis Offer gesetzt
        await new Promise((r) => setTimeout(r, 50));
        const disp = await api(opts.base, "GET", `/api/matching/dispatch/${booking.bookingId}`);
        return {
          ok: true,
          bookingId: booking.bookingId,
          status: disp.dispatch?.status || null,
          offerDriverId: disp.dispatch?.offerDriverId || null,
          ms: Date.now() - start,
        };
      } catch (error) {
        return { ok: false, error: error.message, ms: Date.now() - start };
      }
    })
  );
  const elapsed = Date.now() - t0;

  const ok = results.filter((r) => r.ok);
  const offering = ok.filter((r) => r.status === "offering");
  const exhausted = ok.filter((r) => r.status === "exhausted");
  const failed = results.filter((r) => !r.ok);
  const avgMs =
    ok.reduce((s, r) => s + r.ms, 0) / Math.max(1, ok.length);

  const summary = {
    ok: failed.length === 0 && offering.length + exhausted.length === ok.length,
    drivers: createdDrivers.length,
    matchingPool: ranked.count,
    bookings: opts.bookings,
    succeeded: ok.length,
    offering: offering.length,
    exhausted: exhausted.length,
    failed: failed.length,
    avgDispatchMs: Math.round(avgMs),
    wallMs: elapsed,
    throughputBookingsPerSec: Number((opts.bookings / (elapsed / 1000)).toFixed(2)),
  };

  console.log(JSON.stringify(summary, null, 2));
  if (failed.length) {
    console.error("Sample errors:", failed.slice(0, 3));
    process.exit(1);
  }
  // Unter Last: mindestens ein Offer erwartet wenn Fahrer verfügbar
  if (ranked.count > 0 && offering.length === 0 && exhausted.length === ok.length) {
    console.warn("WARN: alle Buchungen exhausted — GPS/Radius prüfen");
  }
  console.log("OK — Load-Matching abgeschlossen.");
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
