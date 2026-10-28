/**
 * Flexible Fahrpreis-Engine: Taxi (Taxameter-Schätzung, kein Surge)
 * vs. Mietwagen/PHV (verbindlicher Festpreis inkl. optionalem Surge).
 */

const FARE_TIMEZONE = String(process.env.FARE_TIMEZONE || "Europe/Berlin").trim() || "Europe/Berlin";

function hourInFareTimeZone(date = new Date()) {
  try {
    const parts = new Intl.DateTimeFormat("en-US", {
      timeZone: FARE_TIMEZONE,
      hour: "numeric",
      hourCycle: "h23",
    }).formatToParts(date);
    const hour = Number(parts.find((p) => p.type === "hour")?.value);
    if (Number.isFinite(hour)) return hour;
  } catch (_) {
    /* invalid TZ */
  }
  return date.getUTCHours();
}

function isNightHour(date = new Date()) {
  const hour = hourInFareTimeZone(date);
  return hour < 6 || hour >= 22;
}

const DEFAULTS = {
  taxi: {
    baseDay: Number(process.env.FARE_BASE_DAY || 3.9),
    perKmDay: Number(process.env.FARE_PER_KM_DAY || 2.3),
    baseNight: Number(process.env.FARE_BASE_NIGHT || 4.9),
    perKmNight: Number(process.env.FARE_PER_KM_NIGHT || 2.6),
  },
  rentalCar: {
    base: Number(process.env.RENTAL_FARE_BASE || 5.0),
    perKm: Number(process.env.RENTAL_FARE_PER_KM || 1.8),
    perMinute: Number(process.env.RENTAL_FARE_PER_MINUTE || 0.35),
    surgeMin: 1.0,
    surgeMax: 2.0,
  },
};

function normalizeBusinessType(raw) {
  const value = String(raw || "taxi").trim().toLowerCase();
  if (value === "rentalcar" || value === "rental_car" || value === "mietwagen" || value === "phv") {
    return "rentalCar";
  }
  return "taxi";
}

function roundEuro(n) {
  return Math.round(Number(n) * 100) / 100;
}

function round3(n) {
  return Math.round(Number(n) * 1000) / 1000;
}

function clamp(n, min, max) {
  return Math.min(Math.max(n, min), max);
}

/**
 * Pricing aus Fleet-Operator lesen (mit Defaults).
 * @param {object|null} operator
 */
function pricingFromOperator(operator) {
  const businessType = normalizeBusinessType(operator?.businessType);
  const p = operator?.pricing && typeof operator.pricing === "object" ? operator.pricing : {};
  return {
    businessType,
    baseFareDay: Number(p.baseFareDay ?? DEFAULTS.taxi.baseDay),
    perKmDay: Number(p.perKmDay ?? DEFAULTS.taxi.perKmDay),
    baseFareNight: Number(p.baseFareNight ?? DEFAULTS.taxi.baseNight),
    perKmNight: Number(p.perKmNight ?? DEFAULTS.taxi.perKmNight),
    rentalBaseFare: Number(p.rentalBaseFare ?? DEFAULTS.rentalCar.base),
    rentalPerKm: Number(p.rentalPerKm ?? DEFAULTS.rentalCar.perKm),
    rentalPerMinute: Number(p.rentalPerMinute ?? DEFAULTS.rentalCar.perMinute),
    surgeMultiplier: Number(p.surgeMultiplier ?? 1),
    surgeMultiplierMin: Number(p.surgeMultiplierMin ?? DEFAULTS.rentalCar.surgeMin),
    surgeMultiplierMax: Number(p.surgeMultiplierMax ?? DEFAULTS.rentalCar.surgeMax),
    platformCutPercent:
      p.platformCutPercent != null && Number.isFinite(Number(p.platformCutPercent))
        ? Number(p.platformCutPercent)
        : operator?.platformCutPercent != null && Number.isFinite(Number(operator.platformCutPercent))
          ? Number(operator.platformCutPercent)
          : null,
  };
}

/**
 * @param {object} opts
 * @param {number} opts.distanceKm
 * @param {number} [opts.durationSeconds]
 * @param {Date} [opts.at]
 * @param {object|null} [opts.operator]
 * @param {string} [opts.businessType]
 * @param {number} [opts.surgeMultiplier]
 */
function computeFare(opts = {}) {
  const distanceKm = Math.max(0, Number(opts.distanceKm) || 0);
  const durationSeconds =
    Number(opts.durationSeconds) > 0
      ? Number(opts.durationSeconds)
      : (distanceKm / 30) * 3600;
  const durationMinutes = durationSeconds / 60;
  const at = opts.at instanceof Date ? opts.at : new Date();
  const night = isNightHour(at);

  const fromOp = pricingFromOperator(opts.operator || null);
  const businessType = normalizeBusinessType(opts.businessType || fromOp.businessType);

  if (businessType === "taxi") {
    const base = night ? fromOp.baseFareNight : fromOp.baseFareDay;
    const perKm = night ? fromOp.perKmNight : fromOp.perKmDay;
    const fare = roundEuro(base + distanceKm * perKm);
    return {
      businessType: "taxi",
      fare,
      basePrice: base,
      pricePerKm: perKm,
      pricePerMinute: 0,
      surgeMultiplier: 1,
      isNight: night,
      isBindingFixedPrice: false,
      allowsSurge: false,
      distanceKm: round3(distanceKm),
      durationSeconds: Math.round(durationSeconds),
      durationMinutes: round3(durationMinutes),
      formula: "Taxameter-Schätzung: Grundpreis + (km × Tarif) — kein Surge",
      breakdown: {
        base,
        distance: roundEuro(distanceKm * perKm),
        duration: 0,
        surge: 1,
      },
      timeZone: FARE_TIMEZONE,
    };
  }

  // Mietwagen: verbindlicher Festpreis + optional Surge (nie bei Taxi).
  const surge = clamp(
    Number(opts.surgeMultiplier ?? fromOp.surgeMultiplier ?? 1) || 1,
    fromOp.surgeMultiplierMin,
    fromOp.surgeMultiplierMax
  );
  const base = fromOp.rentalBaseFare;
  const distancePart = distanceKm * fromOp.rentalPerKm;
  const durationPart = durationMinutes * fromOp.rentalPerMinute;
  const subtotal = base + distancePart + durationPart;
  const fare = roundEuro(subtotal * surge);

  return {
    businessType: "rentalCar",
    fare,
    basePrice: base,
    pricePerKm: fromOp.rentalPerKm,
    pricePerMinute: fromOp.rentalPerMinute,
    surgeMultiplier: surge,
    isNight: night,
    isBindingFixedPrice: true,
    allowsSurge: true,
    distanceKm: round3(distanceKm),
    durationSeconds: Math.round(durationSeconds),
    durationMinutes: round3(durationMinutes),
    formula: "(Basis + km×Satz + Min×Satz) × Surge — verbindlicher Festpreis",
    breakdown: {
      base,
      distance: roundEuro(distancePart),
      duration: roundEuro(durationPart),
      surge,
    },
    timeZone: FARE_TIMEZONE,
  };
}

module.exports = {
  DEFAULTS,
  normalizeBusinessType,
  pricingFromOperator,
  computeFare,
};
