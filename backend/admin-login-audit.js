/**
 * Login-Protokoll für Plattform-Admin und Betriebs-PIN (Leitstelle/Settings).
 * Speichert Erfolg/Fehlschlag mit Zeit, IP, Rolle — kein PIN im Log.
 */

const fs = require("fs");
const path = require("path");
const crypto = require("crypto");

const MAX_ENTRIES = Number(process.env.ADMIN_LOGIN_AUDIT_MAX || 500);

/**
 * @param {string} dataDir
 */
function createAdminLoginAudit(dataDir) {
  const filePath = path.join(dataDir, "admin-login-audit.json");

  function load() {
    try {
      if (!fs.existsSync(filePath)) return { entries: [] };
      const raw = JSON.parse(fs.readFileSync(filePath, "utf8"));
      return { entries: Array.isArray(raw.entries) ? raw.entries : [] };
    } catch {
      return { entries: [] };
    }
  }

  function save(data) {
    fs.writeFileSync(filePath, `${JSON.stringify(data, null, 2)}\n`, "utf8");
  }

  /**
   * @param {object} evt
   * @param {boolean} evt.ok
   * @param {string} evt.role — admin | operator | anonymous | unknown
   * @param {string} [evt.ip]
   * @param {string} [evt.userAgent]
   * @param {string} [evt.operatorSlug]
   * @param {string} [evt.source] — admin.html | settings.html | dispatch.html | api
   * @param {string} [evt.reason] — bei Fehlschlag
   */
  function record(evt) {
    const data = load();
    const entry = {
      id: crypto.randomUUID(),
      at: new Date().toISOString(),
      ok: Boolean(evt.ok),
      role: String(evt.role || "unknown"),
      ip: String(evt.ip || "unknown").slice(0, 128),
      userAgent: String(evt.userAgent || "").slice(0, 240),
      operatorSlug: evt.operatorSlug ? String(evt.operatorSlug).slice(0, 64) : null,
      source: evt.source ? String(evt.source).slice(0, 64) : null,
      reason: evt.reason ? String(evt.reason).slice(0, 160) : null,
    };
    data.entries.unshift(entry);
    if (data.entries.length > MAX_ENTRIES) {
      data.entries = data.entries.slice(0, MAX_ENTRIES);
    }
    save(data);
    return entry;
  }

  function list(limit = 100) {
    const n = Math.min(MAX_ENTRIES, Math.max(1, Number(limit) || 100));
    return load().entries.slice(0, n);
  }

  function clear() {
    save({ entries: [] });
    return { cleared: true };
  }

  return { record, list, clear, filePath };
}

module.exports = { createAdminLoginAudit };
