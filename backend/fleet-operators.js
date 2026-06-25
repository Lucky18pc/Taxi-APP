const fs = require("fs");
const path = require("path");
const crypto = require("crypto");

const CONFIG_KEYS = [
  "companyName",
  "centralPhone",
  "centralPhoneDisplay",
  "dispatchHours",
  "dispatchNote",
  "country",
  "timeZone",
  "currency",
  "legalStreet",
  "legalCity",
  "legalOwner",
  "legalEmail",
  "vatId",
  "nightSurchargeEnabled",
  "nightSurchargeFromHour",
  "nightSurchargeToHour",
];

function haversineKm(lat1, lon1, lat2, lon2) {
  const toRad = (deg) => (deg * Math.PI) / 180;
  const r = 6371;
  const dLat = toRad(lat2 - lat1);
  const dLon = toRad(lon2 - lon1);
  const a =
    Math.sin(dLat / 2) ** 2 +
    Math.cos(toRad(lat1)) * Math.cos(toRad(lat2)) * Math.sin(dLon / 2) ** 2;
  return 2 * r * Math.asin(Math.sqrt(a));
}

function isValidTimeZone(timeZone) {
  try {
    Intl.DateTimeFormat(undefined, { timeZone });
    return true;
  } catch {
    return false;
  }
}

function normalizePostalCode(raw) {
  const digits = String(raw || "").replace(/\D/g, "");
  if (digits.length < 4) return "";
  return digits.slice(0, 5);
}

function parsePostalCodesInput(input) {
  if (Array.isArray(input)) {
    return [...new Set(input.map(normalizePostalCode).filter(Boolean))];
  }
  const text = String(input || "");
  const parts = text.split(/[\s,;]+/).map(normalizePostalCode).filter(Boolean);
  return [...new Set(parts)];
}

function parsePostalPrefixesInput(input) {
  if (Array.isArray(input)) {
    return [...new Set(input.map((p) => String(p).replace(/\D/g, "")).filter(Boolean))];
  }
  const text = String(input || "");
  const parts = text.split(/[\s,;]+/).map((p) => String(p).replace(/\D/g, "")).filter(Boolean);
  return [...new Set(parts)];
}

function slugifyCompanyName(name) {
  return String(name || "")
    .toLowerCase()
    .replace(/ä/g, "ae")
    .replace(/ö/g, "oe")
    .replace(/ü/g, "ue")
    .replace(/ß/g, "ss")
    .replace(/[^a-z0-9]+/g, "-")
    .replace(/^-|-$/g, "")
    .slice(0, 40);
}

function normalizeServiceArea(raw = {}) {
  const area = { ...raw };
  area.postalCodes = parsePostalCodesInput(area.postalCodes || []);
  area.postalPrefixes = parsePostalPrefixesInput(area.postalPrefixes || []);
  if (!Number.isFinite(area.centerLat)) area.centerLat = 51.0;
  if (!Number.isFinite(area.centerLng)) area.centerLng = 10.5;
  if (!Number.isFinite(area.radiusKm)) area.radiusKm = 25;
  return area;
}

function createFleetOperatorsStore({ dataDir, seedFilePath }) {
  const filePath = path.join(dataDir, "fleet-operators.json");

  function seedIfMissing() {
    if (!fs.existsSync(filePath) && fs.existsSync(seedFilePath)) {
      fs.copyFileSync(seedFilePath, filePath);
    }
  }

  function load() {
    seedIfMissing();
    if (!fs.existsSync(filePath)) {
      return { operators: [] };
    }
    const parsed = JSON.parse(fs.readFileSync(filePath, "utf8"));
    const operators = Array.isArray(parsed.operators) ? parsed.operators : [];
    return { operators: operators.map(normalizeOperator) };
  }

  function save(operators) {
    fs.mkdirSync(path.dirname(filePath), { recursive: true });
    fs.writeFileSync(filePath, `${JSON.stringify({ operators }, null, 2)}\n`, "utf8");
  }

  function normalizeOperator(raw) {
    const op = { ...raw };
    if (!op.operatorId) op.operatorId = `op-${crypto.randomUUID()}`;
    if (!op.slug) op.slug = String(op.operatorId).replace(/^op-/, "");
    if (!op.status) op.status = "active";
    if (!op.country) op.country = "DE";
    if (!op.timeZone || !isValidTimeZone(op.timeZone)) op.timeZone = "Europe/Berlin";
    if (!op.currency) op.currency = "eur";
    op.serviceArea = normalizeServiceArea(op.serviceArea || {});
    if (op.dispatchPin === undefined) op.dispatchPin = "";
    if (!op.createdAt) op.createdAt = new Date().toISOString();
    return op;
  }

  let state = load();

  function activeOperators() {
    return state.operators.filter((op) => op.status !== "pending");
  }

  function list(includePending = false) {
    return includePending ? state.operators : activeOperators();
  }

  function enabled() {
    return activeOperators().length > 0;
  }

  function findById(operatorId) {
    return state.operators.find((op) => op.operatorId === operatorId);
  }

  function findBySlug(slug) {
    const normalized = String(slug || "").trim().toLowerCase();
    if (!normalized) return null;
    return state.operators.find((op) => op.slug.toLowerCase() === normalized);
  }

  function uniqueSlug(baseSlug) {
    let slug = baseSlug || "betrieb";
    let suffix = 0;
    while (findBySlug(slug)) {
      suffix += 1;
      slug = `${baseSlug}-${suffix}`;
    }
    return slug;
  }

  function matchesPostal(operator, postalCode) {
    const plz = normalizePostalCode(postalCode);
    if (!plz) return false;
    const area = operator.serviceArea || {};
    if (area.postalCodes.includes(plz)) return true;
    return area.postalPrefixes.some((prefix) => plz.startsWith(prefix));
  }

  function isInServiceArea(operator, latitude, longitude) {
    const area = operator.serviceArea;
    if (!area || !Number.isFinite(area.centerLat) || !Number.isFinite(area.centerLng)) {
      return false;
    }
    if (!Number.isFinite(latitude) || !Number.isFinite(longitude)) {
      return false;
    }
    const radiusKm = Number(area.radiusKm) || 25;
    return haversineKm(latitude, longitude, area.centerLat, area.centerLng) <= radiusKm;
  }

  function operatorMatchesLocation(operator, latitude, longitude, postalCode) {
    const plz = normalizePostalCode(postalCode);
    if (plz && matchesPostal(operator, plz)) return true;
    if (Number.isFinite(latitude) && Number.isFinite(longitude)) {
      return isInServiceArea(operator, latitude, longitude);
    }
    return false;
  }

  function resolveAmong(operators, latitude, longitude) {
    const matches = operators
      .filter((op) => isInServiceArea(op, latitude, longitude))
      .map((op) => ({
        operator: op,
        distanceKm: haversineKm(
          latitude,
          longitude,
          op.serviceArea.centerLat,
          op.serviceArea.centerLng
        ),
      }))
      .sort((a, b) => a.distanceKm - b.distanceKm);
    return matches[0]?.operator || null;
  }

  function resolveByCoordinates(latitude, longitude, operators = activeOperators()) {
    return resolveAmong(operators, latitude, longitude);
  }

  function resolveByPostalCode(postalCode) {
    const plz = normalizePostalCode(postalCode);
    if (!plz) return null;
    const matches = activeOperators().filter((op) => matchesPostal(op, plz));
    if (matches.length === 1) return matches[0];
    return null;
  }

  function resolveForBooking(latitude, longitude, hintSlug, postalCode) {
    const plz = normalizePostalCode(postalCode);
    const hinted = hintSlug ? findBySlug(hintSlug) : null;

    if (hinted && hinted.status !== "pending") {
      if (operatorMatchesLocation(hinted, latitude, longitude, plz)) {
        return hinted;
      }
      if (plz && matchesPostal(hinted, plz)) {
        return hinted;
      }
    }

    if (plz) {
      const plzMatches = activeOperators().filter((op) => matchesPostal(op, plz));
      if (plzMatches.length === 1) {
        return plzMatches[0];
      }
      if (plzMatches.length > 1 && Number.isFinite(latitude) && Number.isFinite(longitude)) {
        const resolved = resolveAmong(plzMatches, latitude, longitude);
        if (resolved) return resolved;
      }
    }

    if (Number.isFinite(latitude) && Number.isFinite(longitude)) {
      return resolveByCoordinates(latitude, longitude);
    }

    return null;
  }

  function toPublicConfig(operator) {
    if (!operator) return null;
    const config = {
      operatorId: operator.operatorId,
      slug: operator.slug,
      serviceArea: {
        postalCodes: operator.serviceArea?.postalCodes || [],
        postalPrefixes: operator.serviceArea?.postalPrefixes || [],
        radiusKm: operator.serviceArea?.radiusKm,
      },
    };
    for (const key of CONFIG_KEYS) {
      if (operator[key] !== undefined) config[key] = operator[key];
    }
    return config;
  }

  function toPublicSummary(operator) {
    return {
      operatorId: operator.operatorId,
      slug: operator.slug,
      companyName: operator.companyName,
      centralPhoneDisplay: operator.centralPhoneDisplay || operator.centralPhone,
      country: operator.country,
      status: operator.status,
    };
  }

  function applyServiceAreaPatch(operator, patch) {
    if (!operator.serviceArea) operator.serviceArea = normalizeServiceArea({});
    if (patch.postalCodes !== undefined) {
      operator.serviceArea.postalCodes = parsePostalCodesInput(patch.postalCodes);
    }
    if (patch.postalPrefixes !== undefined) {
      operator.serviceArea.postalPrefixes = parsePostalPrefixesInput(patch.postalPrefixes);
    }
    if (patch.radiusKm !== undefined) {
      const radius = Number(patch.radiusKm);
      if (Number.isFinite(radius) && radius > 0) {
        operator.serviceArea.radiusKm = radius;
      }
    }
    if (patch.centerLat !== undefined && patch.centerLng !== undefined) {
      const lat = Number(patch.centerLat);
      const lng = Number(patch.centerLng);
      if (Number.isFinite(lat) && Number.isFinite(lng)) {
        operator.serviceArea.centerLat = lat;
        operator.serviceArea.centerLng = lng;
      }
    }
  }

  function updateOperator(slug, patch) {
    const operator = findBySlug(slug);
    if (!operator) return null;

    for (const key of CONFIG_KEYS) {
      if (patch[key] !== undefined) {
        operator[key] = patch[key];
      }
    }
    if (patch.dispatchPin !== undefined) {
      operator.dispatchPin = String(patch.dispatchPin).trim();
    }
    if (patch.serviceArea !== undefined) {
      applyServiceAreaPatch(operator, patch.serviceArea);
    }
    if (patch.postalCodes !== undefined || patch.postalPrefixes !== undefined || patch.radiusKm !== undefined) {
      applyServiceAreaPatch(operator, patch);
    }

    if (!operator.companyName) throw new Error("companyName required");
    if (!operator.centralPhone) throw new Error("centralPhone required");

    operator.updatedAt = new Date().toISOString();
    save(state.operators);
    return operator;
  }

  function createOperator(input) {
    const companyName = String(input.companyName || "").trim();
    const centralPhone = String(input.centralPhone || "").trim();
    if (!companyName) throw new Error("companyName required");
    if (!centralPhone) throw new Error("centralPhone required");

    const baseSlug = slugifyCompanyName(input.slug || companyName);
    const slug = uniqueSlug(baseSlug);

    const postalCodes = parsePostalCodesInput(input.postalCodes || []);
    const postalPrefixes = parsePostalPrefixesInput(input.postalPrefixes || []);
    if (!postalCodes.length && !postalPrefixes.length) {
      throw new Error("postalCodes or postalPrefixes required");
    }

    const operator = normalizeOperator({
      operatorId: `op-${crypto.randomUUID()}`,
      slug,
      status: input.status || "active",
      companyName,
      centralPhone,
      centralPhoneDisplay: String(input.centralPhoneDisplay || centralPhone).trim(),
      dispatchHours: String(input.dispatchHours || "24/7").trim(),
      dispatchNote: String(input.dispatchNote || "App-Buchungen über Luckys Taxi App.").trim(),
      country: String(input.country || "DE").trim().toUpperCase(),
      timeZone: String(input.timeZone || "Europe/Berlin").trim(),
      currency: String(input.currency || "eur").trim().toLowerCase(),
      legalStreet: String(input.legalStreet || "").trim(),
      legalCity: String(input.legalCity || input.city || "").trim(),
      legalOwner: String(input.legalOwner || "").trim(),
      legalEmail: String(input.legalEmail || input.email || "").trim(),
      vatId: String(input.vatId || "").trim(),
      dispatchPin: String(input.dispatchPin || "").trim(),
      serviceArea: normalizeServiceArea({
        centerLat: Number(input.centerLat),
        centerLng: Number(input.centerLng),
        radiusKm: Number(input.radiusKm) || 25,
        postalCodes,
        postalPrefixes,
      }),
      createdAt: new Date().toISOString(),
    });

    state.operators.unshift(operator);
    save(state.operators);
    return operator;
  }

  function pinRequiredForOperator(operator) {
    return Boolean(String(operator?.dispatchPin || "").trim());
  }

  function anyOperatorPinRequired() {
    return state.operators.some((op) => pinRequiredForOperator(op));
  }

  function verifyPin(pin, operatorSlug, adminPin) {
    const normalizedPin = String(pin || "").trim();
    if (!normalizedPin) return false;

    if (adminPin && normalizedPin === adminPin) return true;

    if (operatorSlug) {
      const operator = findBySlug(operatorSlug);
      if (operator?.dispatchPin && normalizedPin === operator.dispatchPin) return true;
    }

    return false;
  }

  function reload() {
    state = load();
  }

  function onboardingLinks(slug, baseUrl) {
    const base = String(baseUrl || "").replace(/\/$/, "");
    const q = `?o=${encodeURIComponent(slug)}`;
    return {
      dispatch: `${base}/dispatch.html${q}`,
      settings: `${base}/settings.html${q}`,
      book: `${base}/book.html${q}`,
      qr: `${base}/qr.html${q}`,
    };
  }

  return {
    filePath,
    list,
    enabled,
    findById,
    findBySlug,
    matchesPostal,
    isInServiceArea,
    resolveByCoordinates,
    resolveByPostalCode,
    resolveForBooking,
    toPublicConfig,
    toPublicSummary,
    updateOperator,
    createOperator,
    pinRequiredForOperator,
    anyOperatorPinRequired,
    verifyPin,
    reload,
    save,
    onboardingLinks,
    normalizePostalCode,
    parsePostalCodesInput,
    parsePostalPrefixesInput,
    slugifyCompanyName,
  };
}

module.exports = {
  createFleetOperatorsStore,
  haversineKm,
  normalizePostalCode,
  parsePostalCodesInput,
};
