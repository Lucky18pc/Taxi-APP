/**
 * PBefG-Hilfen für Mietwagen-Vermittlung (Rückkehrpflicht).
 * Die Plattform hält selbst keine Beförderungskonzession — nur Software/Matching.
 */

const { haversineKm } = require("./geohash");
const { normalizeBusinessType } = require("./fare-engine");

/** Meter um Betriebssitz = „am Sitz“ für Status Frei. */
const BASE_PROXIMITY_KM = Number(process.env.PBEFG_BASE_PROXIMITY_KM || 0.25);

const DUTY = {
  FREE: "free",
  RETURNING: "returningToBase",
  ON_ASSIGNMENT: "onAssignment",
};

function normalizeDutyStatus(raw) {
  const value = String(raw || "").trim();
  if (value === DUTY.RETURNING || value === "returning" || value === "rueckfahrt") {
    return DUTY.RETURNING;
  }
  if (value === DUTY.ON_ASSIGNMENT || value === "busy" || value === "assigned" || value === "imAuftrag") {
    return DUTY.ON_ASSIGNMENT;
  }
  if (value === DUTY.FREE || value === "available" || value === "frei") {
    return DUTY.FREE;
  }
  // Fallback: aus Legacy-status ableiten
  if (raw == null || raw === "") return DUTY.FREE;
  return DUTY.FREE;
}

function baseCoords(operator) {
  const lat = Number(operator?.baseLat ?? operator?.serviceArea?.centerLat);
  const lng = Number(operator?.baseLng ?? operator?.serviceArea?.centerLng);
  if (!Number.isFinite(lat) || !Number.isFinite(lng)) return null;
  return { latitude: lat, longitude: lng };
}

/**
 * @returns {{ allowed: boolean, reason: string }}
 */
function canAssignNewJob({ businessType, driver, operator }) {
  const type = normalizeBusinessType(businessType || operator?.businessType);
  if (type !== "rentalCar") {
    return { allowed: true, reason: "taxi" };
  }

  const duty = normalizeDutyStatus(driver?.dutyStatus ?? driver?.status);
  if (duty === DUTY.ON_ASSIGNMENT) {
    return { allowed: true, reason: "onAssignment_followUp" };
  }
  if (duty === DUTY.RETURNING) {
    return { allowed: false, reason: "returningToBase_blocked" };
  }

  // free
  const base = baseCoords(operator);
  if (!base) {
    return { allowed: true, reason: "free_noBaseConfigured" };
  }
  const lat = Number(driver?.lastLat ?? driver?.latitude);
  const lng = Number(driver?.lastLng ?? driver?.longitude);
  if (!Number.isFinite(lat) || !Number.isFinite(lng)) {
    return { allowed: false, reason: "free_missingLocation" };
  }
  const distanceKm = haversineKm(lat, lng, base.latitude, base.longitude);
  if (distanceKm <= BASE_PROXIMITY_KM) {
    return { allowed: true, reason: "free_atBase" };
  }
  return { allowed: false, reason: "free_awayFromBase" };
}

function statusAfterTripCompleted(businessType) {
  return normalizeBusinessType(businessType) === "rentalCar" ? DUTY.RETURNING : null;
}

function statusArrivedAtBase(businessType) {
  return normalizeBusinessType(businessType) === "rentalCar" ? DUTY.FREE : null;
}

function statusTripStarted(businessType) {
  return normalizeBusinessType(businessType) === "rentalCar" ? DUTY.ON_ASSIGNMENT : null;
}

module.exports = {
  DUTY,
  BASE_PROXIMITY_KM,
  normalizeDutyStatus,
  canAssignNewJob,
  statusAfterTripCompleted,
  statusArrivedAtBase,
  statusTripStarted,
  baseCoords,
};
