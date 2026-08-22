const zlib = require("zlib");

const FONT_5X7 = {
  A: ["01110", "10001", "10001", "11111", "10001", "10001", "10001"],
  B: ["11110", "10001", "10001", "11110", "10001", "10001", "11110"],
  C: ["01110", "10001", "10000", "10000", "10000", "10001", "01110"],
  D: ["11110", "10001", "10001", "10001", "10001", "10001", "11110"],
  E: ["11111", "10000", "10000", "11110", "10000", "10000", "11111"],
  F: ["11111", "10000", "10000", "11110", "10000", "10000", "10000"],
  G: ["01110", "10001", "10000", "10111", "10001", "10001", "01110"],
  H: ["10001", "10001", "10001", "11111", "10001", "10001", "10001"],
  I: ["11111", "00100", "00100", "00100", "00100", "00100", "11111"],
  J: ["00111", "00010", "00010", "00010", "00010", "10010", "01100"],
  K: ["10001", "10010", "10100", "11000", "10100", "10010", "10001"],
  L: ["10000", "10000", "10000", "10000", "10000", "10000", "11111"],
  M: ["10001", "11011", "10101", "10101", "10001", "10001", "10001"],
  N: ["10001", "11001", "10101", "10011", "10001", "10001", "10001"],
  O: ["01110", "10001", "10001", "10001", "10001", "10001", "01110"],
  P: ["11110", "10001", "10001", "11110", "10000", "10000", "10000"],
  Q: ["01110", "10001", "10001", "10001", "10101", "10010", "01101"],
  R: ["11110", "10001", "10001", "11110", "10100", "10010", "10001"],
  S: ["01111", "10000", "10000", "01110", "00001", "00001", "11110"],
  T: ["11111", "00100", "00100", "00100", "00100", "00100", "00100"],
  U: ["10001", "10001", "10001", "10001", "10001", "10001", "01110"],
  V: ["10001", "10001", "10001", "10001", "10001", "01010", "00100"],
  W: ["10001", "10001", "10001", "10101", "10101", "10101", "01010"],
  X: ["10001", "10001", "01010", "00100", "01010", "10001", "10001"],
  Y: ["10001", "10001", "01010", "00100", "00100", "00100", "00100"],
  Z: ["11111", "00001", "00010", "00100", "01000", "10000", "11111"],
  "0": ["01110", "10001", "10011", "10101", "11001", "10001", "01110"],
  "1": ["00100", "01100", "00100", "00100", "00100", "00100", "01110"],
  "2": ["01110", "10001", "00001", "00010", "00100", "01000", "11111"],
  "3": ["11110", "00001", "00001", "01110", "00001", "00001", "11110"],
  "4": ["00010", "00110", "01010", "10010", "11111", "00010", "00010"],
  "5": ["11111", "10000", "11110", "00001", "00001", "10001", "01110"],
  "6": ["01110", "10000", "10000", "11110", "10001", "10001", "01110"],
  "7": ["11111", "00001", "00010", "00100", "01000", "01000", "01000"],
  "8": ["01110", "10001", "10001", "01110", "10001", "10001", "01110"],
  "9": ["01110", "10001", "10001", "01111", "00001", "00001", "01110"],
};

function crc32(buf) {
  let c = ~0;
  for (let i = 0; i < buf.length; i += 1) {
    c ^= buf[i];
    for (let k = 0; k < 8; k += 1) {
      c = (c & 1) ? 0xedb88320 ^ (c >>> 1) : c >>> 1;
    }
  }
  return (~c) >>> 0;
}

function pngChunk(type, data) {
  const len = Buffer.alloc(4);
  len.writeUInt32BE(data.length);
  const typeBuf = Buffer.from(type, "ascii");
  const crcBuf = Buffer.alloc(4);
  crcBuf.writeUInt32BE(crc32(Buffer.concat([typeBuf, data])));
  return Buffer.concat([len, typeBuf, data, crcBuf]);
}

function parseHexColor(value, fallback) {
  const raw = String(value || "").trim();
  const m = raw.match(/^#?([0-9a-fA-F]{6})$/);
  const hex = m ? m[1] : fallback.replace("#", "");
  return {
    r: parseInt(hex.slice(0, 2), 16),
    g: parseInt(hex.slice(2, 4), 16),
    b: parseInt(hex.slice(4, 6), 16),
  };
}

function initialsFromName(name) {
  const parts = String(name || "Taxi")
    .replace(/[^A-Za-zÄÖÜäöüß0-9\s]/g, " ")
    .trim()
    .split(/\s+/)
    .filter(Boolean);
  const letters = parts
    .slice(0, 2)
    .map((part) => part[0])
    .join("")
    .toUpperCase()
    .replace("Ä", "A")
    .replace("Ö", "O")
    .replace("Ü", "U");
  return (letters || "TX").slice(0, 2);
}

function shortAppName(name) {
  const full = String(name || "Luckys Taxi").trim() || "Luckys Taxi";
  if (full.length <= 12) return full;
  const first = full.split(/\s+/)[0];
  if (first.length >= 4 && first.length <= 12) return first;
  return `${full.slice(0, 11)}…`;
}

function glyphRows(ch) {
  return FONT_5X7[ch] || FONT_5X7.T;
}

function renderInitialsPng(size, { background, foreground, initials }) {
  const bg = parseHexColor(background, "#ffcc00");
  const fg = parseHexColor(foreground, "#0c1c34");
  const letters = String(initials || "TX").slice(0, 2);
  const raw = Buffer.alloc(size * (1 + size * 3));
  for (let y = 0; y < size; y += 1) {
    const row = y * (1 + size * 3);
    raw[row] = 0;
    for (let x = 0; x < size; x += 1) {
      const i = row + 1 + x * 3;
      raw[i] = bg.r;
      raw[i + 1] = bg.g;
      raw[i + 2] = bg.b;
    }
  }

  const scale = Math.max(4, Math.floor(size / 18));
  const glyphW = 5 * scale;
  const glyphH = 7 * scale;
  const gap = Math.round(scale * 1.2);
  const totalW = letters.length * glyphW + (letters.length - 1) * gap;
  const startX = Math.floor((size - totalW) / 2);
  const startY = Math.floor((size - glyphH) / 2);

  letters.split("").forEach((ch, index) => {
    const rows = glyphRows(ch);
    const ox = startX + index * (glyphW + gap);
    for (let gy = 0; gy < 7; gy += 1) {
      for (let gx = 0; gx < 5; gx += 1) {
        if (rows[gy][gx] !== "1") continue;
        for (let py = 0; py < scale; py += 1) {
          for (let px = 0; px < scale; px += 1) {
            const x = ox + gx * scale + px;
            const y = startY + gy * scale + py;
            if (x < 0 || y < 0 || x >= size || y >= size) continue;
            const i = y * (1 + size * 3) + 1 + x * 3;
            raw[i] = fg.r;
            raw[i + 1] = fg.g;
            raw[i + 2] = fg.b;
          }
        }
      }
    }
  });

  const ihdr = Buffer.alloc(13);
  ihdr.writeUInt32BE(size, 0);
  ihdr.writeUInt32BE(size, 4);
  ihdr[8] = 8;
  ihdr[9] = 2;
  const png = Buffer.concat([
    Buffer.from([137, 80, 78, 71, 13, 10, 26, 10]),
    pngChunk("IHDR", ihdr),
    pngChunk("IDAT", zlib.deflateSync(raw)),
    pngChunk("IEND", Buffer.alloc(0)),
  ]);
  return png;
}

async function loadLogo(logoUrl) {
  const url = String(logoUrl || "").trim();
  if (!/^https:\/\//i.test(url)) return null;
  try {
    const res = await fetch(url, {
      redirect: "follow",
      signal: AbortSignal.timeout(4000),
      headers: { Accept: "image/png,image/jpeg,image/webp,image/*,*/*" },
    });
    if (!res.ok) return null;
    const type = String(res.headers.get("content-type") || "").split(";")[0].trim();
    if (type && !type.startsWith("image/")) return null;
    const buf = Buffer.from(await res.arrayBuffer());
    if (!buf.length || buf.length > 2_000_000) return null;
    return { buf, type: type || "image/png" };
  } catch {
    return null;
  }
}

function brandFromConfig(cfg) {
  const companyName = String(cfg?.companyName || "Luckys Taxi App").trim() || "Luckys Taxi App";
  return {
    companyName,
    shortName: shortAppName(companyName),
    accent: cfg?.brandAccentColor || "#ffcc00",
    primary: cfg?.brandPrimaryColor || "#0c1c34",
    logoUrl: String(cfg?.logoUrl || "").trim(),
    initials: initialsFromName(companyName),
    slug: cfg?.slug || "",
  };
}

function mountPwaBrandRoutes(app, { configForRequest }) {
  app.get("/api/pwa-icon", async (req, res) => {
    const cfg = configForRequest(req);
    const brand = brandFromConfig(cfg || {});
    const size = Number(req.query.size) === 512 ? 512 : Number(req.query.size) === 180 ? 180 : 192;
    const logo = brand.logoUrl ? await loadLogo(brand.logoUrl) : null;
    if (logo) {
      res.setHeader("Cache-Control", "public, max-age=300");
      res.type(logo.type);
      return res.send(logo.buf);
    }
    const png = renderInitialsPng(size, {
      background: brand.accent,
      foreground: brand.primary,
      initials: brand.initials,
    });
    res.setHeader("Cache-Control", "public, max-age=300");
    res.type("image/png");
    res.send(png);
  });

  app.get("/api/pwa-manifest", (req, res) => {
    const cfg = configForRequest(req);
    const brand = brandFromConfig(cfg || {});
    const slug = String(req.query.operator || req.query.o || brand.slug || "").trim().toLowerCase();
    const q = slug ? `operator=${encodeURIComponent(slug)}` : "";
    const iconBase = q ? `/api/pwa-icon?${q}&` : "/api/pwa-icon?";
    const start = slug ? `/book.html?o=${encodeURIComponent(slug)}` : "/book.html";
    res.setHeader("Cache-Control", "no-store");
    res.type("application/manifest+json");
    res.json({
      name: brand.companyName,
      short_name: brand.shortName,
      start_url: start,
      scope: "/",
      display: "standalone",
      background_color: brand.accent,
      theme_color: brand.primary,
      lang: "de",
      icons: [
        { src: `${iconBase}size=192`, sizes: "192x192", type: "image/png", purpose: "any" },
        { src: `${iconBase}size=512`, sizes: "512x512", type: "image/png", purpose: "any" },
      ],
    });
  });
}

module.exports = {
  mountPwaBrandRoutes,
  brandFromConfig,
  renderInitialsPng,
  initialsFromName,
};
