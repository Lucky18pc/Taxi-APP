#!/usr/bin/env node
/**
 * Plattform-Admin Live-Karte: alle Betriebe, ein Betrieb, Betriebs-PIN abgewiesen.
 * Startet ein eigenes Backend mit leerem DATA_DIR.
 */
const { spawn } = require("child_process");
const fs = require("fs");
const os = require("os");
const path = require("path");

const dataDir = fs.mkdtempSync(path.join(os.tmpdir(), "luckys-admin-map-"));
const port = Number(process.env.LIVE_MAP_TEST_PORT || 4291);
const adminPin = "4242-admin-map";
const base = `http://127.0.0.1:${port}`;

const child = spawn(process.execPath, ["server.js"], {
  cwd: path.join(__dirname, "..", "backend"),
  env: {
    ...process.env,
    PORT: String(port),
    HOST: "127.0.0.1",
    ADMIN_PIN: adminPin,
    DATA_DIR: dataDir,
    RESEND_API_KEY: "",
    REQUIRE_ADMIN_PIN: "",
  },
  stdio: ["ignore", "pipe", "pipe"],
});

let logs = "";
child.stdout.on("data", (chunk) => {
  logs += chunk.toString();
});
child.stderr.on("data", (chunk) => {
  logs += chunk.toString();
});

const SEP = String.fromCharCode(30);

async function eio(pathname, options = {}) {
  const res = await fetch(`${base}${pathname}`, options);
  const text = await res.text();
  return { res, text, packets: text ? text.split(SEP) : [] };
}

async function subscribeFleet(token) {
  const open = await eio("/socket.io/?EIO=4&transport=polling");
  const openPacket = open.packets.find((packet) => packet.startsWith("0"));
  if (!openPacket) {
    return { ready: false, denied: false, packets: open.packets, nextPacket: async () => [], close: () => {} };
  }
  const sid = JSON.parse(openPacket.slice(1)).sid;
  const q = `/socket.io/?EIO=4&transport=polling&sid=${encodeURIComponent(sid)}`;
  await eio(q, {
    method: "POST",
    headers: { "Content-Type": "text/plain;charset=UTF-8" },
    body: "40",
  });
  await eio(q);
  await eio(q, {
    method: "POST",
    headers: { "Content-Type": "text/plain;charset=UTF-8" },
    body: `42${JSON.stringify(["subscribe:fleet", { token }])}`,
  });
  const reply = await eio(q);
  const packets = reply.packets;
  return {
    ready: packets.some((packet) => packet.includes("fleet:ready")),
    denied: packets.some((packet) => packet.includes("fleet:denied")),
    packets,
    nextPacket: () => eio(q).then((result) => result.packets),
    close: () => {},
  };
}

function fail(message) {
  console.error(message);
  console.error(logs.slice(-4000));
  child.kill("SIGTERM");
  process.exit(1);
}

async function waitForHealth() {
  const deadline = Date.now() + 20000;
  while (Date.now() < deadline) {
    try {
      const res = await fetch(`${base}/health`);
      if (res.ok) return;
    } catch {
      /* boot */
    }
    await new Promise((resolve) => setTimeout(resolve, 200));
  }
  fail("Backend ist nicht gestartet.");
}

async function api(pathname, options = {}) {
  const headers = { ...(options.headers || {}) };
  if (options.admin) headers.Authorization = `Bearer ${adminPin}`;
  if (options.pin) headers.Authorization = `Bearer ${options.pin}`;
  const res = await fetch(`${base}${pathname}`, { ...options, headers });
  const text = await res.text();
  let body = {};
  try {
    body = text ? JSON.parse(text) : {};
  } catch {
    body = { raw: text };
  }
  return { res, body };
}

(async () => {
  try {
    await waitForHealth();

    const speyer = await api("/api/fleet/operators", {
      method: "POST",
      admin: true,
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        companyName: "Taxi Speyer Test",
        email: "speyer@example.com",
        centralPhone: "+496232000001",
        city: "Speyer",
        postalPrefixes: "67",
        centerLat: 49.317,
        centerLng: 8.441,
        radiusKm: 30,
        status: "active",
        dispatchPin: "111111",
        slug: "speyer-test",
      }),
    });
    if (speyer.res.status !== 201) fail(`Speyer anlegen: ${speyer.res.status} ${JSON.stringify(speyer.body)}`);

    const berlin = await api("/api/fleet/operators", {
      method: "POST",
      admin: true,
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        companyName: "Taxi Berlin Test",
        email: "berlin@example.com",
        centralPhone: "+4930000001",
        city: "Berlin",
        postalPrefixes: "10",
        centerLat: 52.52,
        centerLng: 13.405,
        radiusKm: 30,
        status: "active",
        dispatchPin: "222222",
        slug: "berlin-test",
      }),
    });
    if (berlin.res.status !== 201) fail(`Berlin anlegen: ${berlin.res.status} ${JSON.stringify(berlin.body)}`);

    const driverSpeyer = await api("/api/drivers?operator=speyer-test", {
      method: "POST",
      admin: true,
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ name: "Anna Speyer", phone: "+491700000001", vehicle: "SP-TA 1" }),
    });
    if (driverSpeyer.res.status !== 201) fail(`Fahrer Speyer: ${JSON.stringify(driverSpeyer.body)}`);

    const driverBerlin = await api("/api/drivers?operator=berlin-test", {
      method: "POST",
      admin: true,
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ name: "Ben Berlin", phone: "+491700000002", vehicle: "B-TA 2" }),
    });
    if (driverBerlin.res.status !== 201) fail(`Fahrer Berlin: ${JSON.stringify(driverBerlin.body)}`);

    const located = await api(`/api/drivers/${driverSpeyer.body.driverId}/location`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        trackingPin: driverSpeyer.body.trackingPin,
        latitude: 49.319,
        longitude: 8.431,
      }),
    });
    if (!located.res.ok) fail(`GPS: ${located.res.status} ${JSON.stringify(located.body)}`);

    const booking = await api("/api/bookings", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        pickupDate: new Date().toISOString(),
        latitude: 49.317,
        longitude: 8.441,
        addressLine: "Domplatz Speyer",
        postalCode: "67346",
        paymentMethod: "Bar",
        operatorSlug: "speyer-test",
        totalAmount: 0,
      }),
    });
    if (booking.res.status !== 201) fail(`Buchung: ${booking.res.status} ${JSON.stringify(booking.body)}`);

    const denied = await api("/api/fleet/live-map?operator=speyer-test", { pin: "111111" });
    if (denied.res.status !== 403) {
      fail(`Betriebs-PIN sollte 403 sein, war ${denied.res.status} ${JSON.stringify(denied.body)}`);
    }

    const missing = await api("/api/fleet/live-map?operator=gibt-es-nicht", { admin: true });
    if (missing.res.status !== 404) fail(`Unbekannter Betrieb sollte 404 sein, war ${missing.res.status}`);

    const all = await api("/api/fleet/live-map", { admin: true });
    if (!all.res.ok) fail(`Alle: ${all.res.status} ${JSON.stringify(all.body)}`);
    const names = (all.body.drivers || []).map((d) => d.name).sort();
    if (names.join(",") !== "Anna Speyer,Ben Berlin") fail(`Fahrerliste falsch: ${names.join(",")}`);
    const anna = all.body.drivers.find((d) => d.name === "Anna Speyer");
    if (!anna.locationFresh || anna.latitude !== 49.319) fail(`Anna ohne frisches GPS: ${JSON.stringify(anna)}`);
    const ben = all.body.drivers.find((d) => d.name === "Ben Berlin");
    if (ben.latitude !== null || ben.longitude !== null) {
      fail(`Fahrer ohne GPS darf nicht bei 0,0 liegen: ${JSON.stringify(ben)}`);
    }
    if (JSON.stringify(all.body).includes("trackingPin")) fail("trackingPin darf nicht in der Karten-Antwort stehen");
    const jobs = all.body.bookings || [];
    if (!jobs.some((b) => b.addressLine === "Domplatz Speyer" && b.operatorSlug === "speyer-test")) {
      fail(`Auftrag fehlt: ${JSON.stringify(jobs)}`);
    }

    const only = await api("/api/fleet/live-map?operator=berlin-test", { admin: true });
    if (!only.res.ok) fail(`Berlin-Karte: ${only.res.status}`);
    if ((only.body.drivers || []).length !== 1 || only.body.drivers[0].name !== "Ben Berlin") {
      fail(`Filter Berlin falsch: ${JSON.stringify(only.body.drivers)}`);
    }
    if ((only.body.bookings || []).some((b) => b.operatorSlug === "speyer-test")) {
      fail("Speyer-Auftrag darf bei Berlin nicht auftauchen");
    }

    const page = await fetch(`${base}/admin.html`);
    const html = await page.text();
    if (!html.includes('data-panel="map"') || !html.includes('id="admin-map"')) {
      fail("admin.html enthält die Karten-Ansicht nicht");
    }
    if (!html.includes("/socket.io/socket.io.js")) {
      fail("admin.html lädt die Live-Verbindung nicht");
    }

    const live = await subscribeFleet(adminPin);
    if (!live.ready) fail(`Live-Verbindung nicht bereit: ${JSON.stringify(live.packets)}`);
    const stranger = await subscribeFleet("kein-admin");
    if (!stranger.denied) fail(`Fremde Verbindung sollte abgelehnt werden: ${JSON.stringify(stranger.packets)}`);

    const moved = await api(`/api/drivers/${driverSpeyer.body.driverId}/location`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        trackingPin: driverSpeyer.body.trackingPin,
        latitude: 49.33,
        longitude: 8.45,
      }),
    });
    if (!moved.res.ok) fail(`GPS-Update: ${moved.res.status}`);
    const pushed = await live.nextPacket(4000);
    const driverEvent = pushed.find((packet) => packet.includes("fleet:driver") && packet.includes("49.33"));
    if (!driverEvent) fail(`Kein Live-Punkt auf der Admin-Karte: ${JSON.stringify(pushed)}`);
    live.close();
    stranger.close();

    const script = await fetch(`${base}/admin.js?v=20261028-karte3`);
    const source = await script.text();
    if (!source.includes("scrollWheelZoom: false") || !source.includes("dragging: true")) {
      fail("Karte lässt sich noch zoomen statt nur verschieben");
    }
    if (source.includes("zoomControl: true")) fail("Zoom-Buttons sind noch an");

    console.log("OK admin live-map: alle Betriebe, Filter, 403 für Betriebs-PIN, Live-Verbindung");
    child.kill("SIGTERM");
    process.exit(0);
  } catch (error) {
    fail(error.stack || error.message || String(error));
  }
})();
