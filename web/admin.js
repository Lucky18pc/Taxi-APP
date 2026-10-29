(function () {
  const PIN_KEY = "taxiapp_platform_admin_pin";
  const SESSION_KEY = "taxiapp_platform_admin_session";

  const PANEL_COPY = {
    tenants: {
      title: "Mandanten",
      sub: "Betriebe prüfen, Logo speichern, Nachweise öffnen, freischalten und Links kopieren.",
    },
    map: {
      title: "Live-Karte",
      sub: "Live verbunden mit dem Standort der Fahrer-App. Die Leitstelle jedes Betriebs bleibt separat.",
    },
    inquiries: {
      title: "Anfragen",
      sub: "Tarif-Anfragen von der Startseite: antworten oder als Mandant übernehmen.",
    },
    create: {
      title: "Neu anlegen",
      sub: "Betrieb manuell anlegen und sofort aktivieren.",
    },
    audit: {
      title: "Login-Protokoll",
      sub: "Wer sich wann angemeldet hat — Admin und Betriebs-PIN, mit IP und Erfolg/Fehlschlag.",
    },
    analytics: {
      title: "Analytics",
      sub: "Primär: Tarif-Anfragen. Zusätzlich Website-Besucher in Google Analytics.",
    },
    settings: {
      title: "Einstellungen",
      sub: "Dein Überblick als Plattform-Inhaber. Betriebe sehen diese Seite nicht.",
    },
  };

  let pendingPin = "";
  let mfaStep = false;
  let mfaPendingSecret = "";
  let adminMap = null;
  let adminMapTimer = null;
  let adminSocket = null;
  let liveConnected = false;
  let pendingMapSlug = "";
  let mapFittedFor = "";
  let liveMapRequestId = 0;
  let mapDrivers = [];
  let mapBookings = [];
  /** Fahrer-ID, der die Karte live folgt (Straßenebene). */
  let followDriverId = null;
  let followIgnoreMove = false;
  const driverMarkers = new Map();
  const bookingMarkers = new Map();
  const DRIVER_STATUS_LABELS = {
    available: "Frei",
    busy: "Unterwegs",
    offline: "Offline",
    pending: "Prüfung",
  };
  const BOOKING_STATUS_LABELS = {
    confirmed: "Neu",
    accepted: "Angenommen",
    assigned: "Zugewiesen",
  };

  function getSession() {
    return localStorage.getItem(SESSION_KEY) || sessionStorage.getItem(SESSION_KEY) || "";
  }

  function getPin() {
    return localStorage.getItem(PIN_KEY) || sessionStorage.getItem(PIN_KEY) || "";
  }

  function setAuth({ sessionToken, pin, remember }) {
    clearAuth();
    const store = remember ? localStorage : sessionStorage;
    if (sessionToken) store.setItem(SESSION_KEY, sessionToken);
    if (pin) store.setItem(PIN_KEY, pin);
  }

  function clearAuth() {
    localStorage.removeItem(SESSION_KEY);
    sessionStorage.removeItem(SESSION_KEY);
    localStorage.removeItem(PIN_KEY);
    sessionStorage.removeItem(PIN_KEY);
  }

  function authHeaders() {
    const session = getSession();
    const pin = getPin() || pendingPin || "";
    const headers = {};
    if (session) {
      headers.Authorization = `Bearer ${session}`;
    } else if (pin) {
      headers.Authorization = `Bearer ${pin}`;
    }
    // PIN zusätzlich mitsenden: nach Render-Deploy ist die Session oft tot,
    // der PIN reicht für MFA-Setup/Confirm noch (solange MFA nicht aktiv ist).
    if (pin) headers["X-Admin-Pin"] = pin;
    return headers;
  }

  function dropStaleSession() {
    localStorage.removeItem(SESSION_KEY);
    sessionStorage.removeItem(SESSION_KEY);
  }

  async function apiFetch(url, options = {}) {
    // Explizite Header (z. B. PIN bei MFA) schlagen Session-Defaults.
    const headers = { ...authHeaders(), ...(options.headers || {}) };
    if (typeof FormData !== "undefined" && options.body instanceof FormData) {
      delete headers["Content-Type"];
      delete headers["content-type"];
    }
    const controller = new AbortController();
    const timeoutMs = Number(options.timeoutMs) > 0 ? Number(options.timeoutMs) : 25000;
    const timer = setTimeout(() => controller.abort(), timeoutMs);
    const resetOn401 = options.resetOn401 !== false;
    // Nur echte Fetch-Optionen weiterreichen (kein timeoutMs/resetOn401 an fetch()).
    const {
      timeoutMs: _timeoutMs,
      resetOn401: _resetOn401,
      headers: _headers,
      ...fetchOpts
    } = options;
    try {
      let res = await fetch(url, {
        ...fetchOpts,
        headers,
        signal: options.signal || controller.signal,
      });
      // Tote Session nach Deploy: einmal mit PIN allein erneut versuchen.
      if (res.status === 401 && getSession() && (getPin() || pendingPin)) {
        dropStaleSession();
        const retryHeaders = { ...authHeaders(), ...(options.headers || {}) };
        if (typeof FormData !== "undefined" && options.body instanceof FormData) {
          delete retryHeaders["Content-Type"];
          delete retryHeaders["content-type"];
        }
        res = await fetch(url, {
          ...fetchOpts,
          headers: retryHeaders,
          signal: options.signal || controller.signal,
        });
      }
      if (res.status === 401 && resetOn401) {
        const body = await res.clone().json().catch(() => ({}));
        clearAuth();
        if (body.mfaRequired) {
          showMfaCodeStep();
        } else {
          showLogin();
        }
        throw new Error(body.error || "Anmeldung abgelaufen — bitte erneut anmelden.");
      }
      return res;
    } catch (err) {
      if (err && err.name === "AbortError") {
        throw new Error("Server antwortet nicht (Timeout). Bitte erneut versuchen.");
      }
      throw err;
    } finally {
      clearTimeout(timer);
    }
  }

  function showLogin() {
    mfaStep = false;
    pendingPin = "";
    document.getElementById("admin-login").classList.remove("hidden");
    document.getElementById("admin-app").classList.add("hidden");
    document.getElementById("admin-mfa-setup").classList.add("hidden");
    document.getElementById("admin-login-form").classList.remove("hidden");
    document.getElementById("pin-field").classList.remove("hidden");
    document.getElementById("totp-field").classList.add("hidden");
    document.getElementById("remember-row").classList.remove("hidden");
    document.getElementById("admin-totp").value = "";
    document.getElementById("admin-login-submit").textContent = "★ Anmelden ★";
    document.getElementById("mfa-recover-btn")?.classList.add("hidden");
  }

  function showMfaCodeStep() {
    mfaStep = true;
    document.getElementById("admin-login").classList.remove("hidden");
    document.getElementById("admin-app").classList.add("hidden");
    document.getElementById("admin-mfa-setup").classList.add("hidden");
    document.getElementById("admin-login-form").classList.remove("hidden");
    document.getElementById("pin-field").classList.add("hidden");
    document.getElementById("totp-field").classList.remove("hidden");
    document.getElementById("remember-row").classList.add("hidden");
    document.getElementById("admin-login-submit").textContent = "Code bestätigen";
    document.getElementById("admin-totp").focus();
    document.getElementById("mfa-recover-btn")?.classList.remove("hidden");
  }

  function showApp() {
    document.getElementById("admin-login").classList.add("hidden");
    document.getElementById("admin-app").classList.remove("hidden");
    document.getElementById("admin-mfa-setup").classList.add("hidden");
  }

  async function enterAppAfterAuth() {
    showApp();
    showPanel("tenants");
    try {
      const statusRes = await apiFetch("/api/auth/mfa/status");
      const status = statusRes.ok ? await statusRes.json() : { enabled: false };
      const mfaBtn = document.getElementById("admin-setup-mfa");
      if (mfaBtn) mfaBtn.classList.toggle("hidden", Boolean(status.enabled));
    } catch {
      /* ignore */
    }
    await withRefreshBusy(refreshAll);
    const params = new URLSearchParams(window.location.search);
    const connect = params.get("connect");
    const slug = params.get("o");
    if (connect === "return" && slug) {
      alert(`Stripe Connect für „${slug}”: Onboarding abgeschlossen oder fortgesetzt. Status prüfen.`);
      history.replaceState({}, "", "admin.html");
    } else if (connect === "refresh" && slug) {
      alert(`Connect-Link abgelaufen. Bitte für „${slug}“ erneut „Stripe Connect“ klicken.`);
      history.replaceState({}, "", "admin.html");
    }
  }

  async function startMfaSetup(options = {}) {
    const reset = Boolean(options.reset);
    const setupEl = document.getElementById("admin-mfa-setup");
    const formEl = document.getElementById("admin-login-form");
    const errEl = document.getElementById("mfa-setup-error");
    setupEl.classList.remove("hidden");
    formEl.classList.add("hidden");
    errEl.classList.add("hidden");
    errEl.textContent = "";
    document.getElementById("mfa-confirm-code").value = "";
    const pinInput = document.getElementById("mfa-confirm-pin");
    if (pinInput && !pinInput.value) {
      pinInput.value = getPin() || pendingPin || "";
    }

    const pin = (pinInput?.value || getPin() || pendingPin || "").trim();
    if (pin) pendingPin = pin;

    try {
      // MFA-Setup bewusst mit PIN auth (nicht tote Session nach Deploy).
      const headers = { "Content-Type": "application/json" };
      if (pin) {
        headers.Authorization = `Bearer ${pin}`;
        headers["X-Admin-Pin"] = pin;
      } else {
        Object.assign(headers, authHeaders());
      }
      const res = await apiFetch("/api/auth/mfa/setup", {
        method: "POST",
        headers,
        body: JSON.stringify(reset ? { reset: true, pin } : { pin }),
        resetOn401: false,
      });
      const data = await res.json().catch(() => ({}));
      if (!res.ok) throw new Error(data.error || "MFA-Setup fehlgeschlagen");

      document.getElementById("mfa-secret").textContent = data.secret || "";
      mfaPendingSecret = data.secret || "";
      const expectedEl = document.getElementById("mfa-expected-code");
      if (expectedEl) expectedEl.textContent = data.currentCode || "————";

      let host = document.getElementById("mfa-qr");
      if (!host) {
        host = document.createElement("div");
        host.id = "mfa-qr";
        setupEl.querySelector("div[style*='text-align:center']")?.appendChild(host);
      }
      const qrSrc =
        data.qrDataUrl ||
        `https://api.qrserver.com/v1/create-qr-code/?size=200x200&data=${encodeURIComponent(data.otpauthUrl || "")}`;
      // Cache-Buster, falls alter QR im Browser hängen bleibt.
      const qrSrcFresh = qrSrc.startsWith("data:")
        ? qrSrc
        : `${qrSrc}${qrSrc.includes("?") ? "&" : "?"}t=${Date.now()}`;
      host.outerHTML = `<img id="mfa-qr" alt="QR-Code MFA" width="200" height="200" style="border:2px solid #0c1c34;border-radius:12px;background:#fff" src="${qrSrcFresh}">`;
      if (reset) {
        errEl.textContent =
          "Neuer QR erzeugt. Alten Eintrag in der Authenticator-App löschen, dann Geheimnis manuell einfügen (zuverlässiger als scannen).";
        errEl.classList.remove("hidden");
        errEl.style.color = "#0c1c34";
      } else {
        errEl.style.color = "";
      }
    } catch (err) {
      errEl.style.color = "";
      errEl.textContent = err.message || "MFA-Setup fehlgeschlagen";
      errEl.classList.remove("hidden");
      if (String(err.message || "").includes("PIN")) {
        errEl.textContent =
          "Bitte ADMIN_PIN unten eintragen und „Neuen QR erzeugen“ tippen — Session nach Deploy oft abgelaufen.";
        errEl.classList.remove("hidden");
      }
      throw err;
    }
  }

  function showPanel(id) {
    document.querySelectorAll(".panel").forEach((el) => el.classList.remove("active"));
    document.querySelectorAll(".nav-btn").forEach((el) => el.classList.remove("active"));
    document.getElementById(`panel-${id}`)?.classList.add("active");
    document.querySelector(`.nav-btn[data-panel="${id}"]`)?.classList.add("active");
    const copy = PANEL_COPY[id] || PANEL_COPY.tenants;
    document.getElementById("panel-title").textContent = copy.title;
    document.getElementById("panel-sub").textContent = copy.sub;
    // CSV nur bei Mandanten/Anfragen sinnvoll — nicht beim Login-Protokoll.
    const csvBtn = document.getElementById("export-tenants-csv");
    if (csvBtn) {
      csvBtn.classList.toggle("hidden", id !== "tenants" && id !== "inquiries");
    }
    if (id === "audit") loadLoginAudit();
    if (id === "settings") {
      loadPlatformSettings().catch((err) => setSettingsStatus(err.message || "Einstellungen nicht ladbar", true));
    }
    if (id === "map") startAdminMap();
    else stopAdminMap();
  }

  function escapeHtml(value) {
    return String(value || "")
      .replace(/&/g, "&amp;")
      .replace(/</g, "&lt;")
      .replace(/>/g, "&gt;")
      .replace(/"/g, "&quot;");
  }

  function setSettingsStatus(text, isError) {
    const el = document.getElementById("settings-status");
    if (!el) return;
    el.textContent = text || "";
    el.style.color = isError ? "#b91c1c" : "";
  }

  async function loadPlatformSettings() {
    setSettingsStatus("Lade…");
    const [configRes, opsRes] = await Promise.all([
      apiFetch("/api/config"),
      apiFetch("/api/fleet/operators"),
    ]);
    const config = await configRes.json().catch(() => ({}));
    const opsData = await opsRes.json().catch(() => ({}));
    if (!configRes.ok) throw new Error(config.error || "Plattform nicht ladbar");
    if (!opsRes.ok) throw new Error(opsData.error || "Betriebe nicht ladbar");
    const ops = opsData.operators || [];
    document.getElementById("set-stat-tenants").textContent = String(ops.length);
    document.getElementById("set-stat-active").textContent = String(ops.filter((op) => op.status === "active").length);
    document.getElementById("set-stat-pending").textContent = String(ops.filter((op) => op.status === "pending").length);
    document.getElementById("set-stat-gaps").textContent = String(ops.filter((op) => !op.complianceComplete).length);
    for (const key of [
      "platformCompanyName",
      "platformOwner",
      "platformEmail",
      "platformPhone",
      "platformStreet",
      "platformCity",
      "platformVatId",
    ]) {
      const input = document.getElementById(`set-${key}`);
      if (input) input.value = config[key] || "";
    }
    setSettingsStatus("");
  }

  function setAuditStatus(text, isError) {
    const el = document.getElementById("audit-status");
    if (!el) return;
    el.textContent = text || "";
    el.style.color = isError ? "#b91c1c" : "";
  }

  async function loadLoginAudit() {
    const list = document.getElementById("audit-list");
    const empty = document.getElementById("audit-empty");
    const refreshBtn = document.getElementById("refresh-audit");
    if (!list) return;
    const prevRefresh = refreshBtn ? refreshBtn.textContent : "";
    if (refreshBtn) {
      refreshBtn.disabled = true;
      refreshBtn.textContent = "Lädt…";
    }
    list.innerHTML = "<p class=\"meta\">Lade…</p>";
    empty?.classList.add("hidden");
    setAuditStatus("Verbinde…");
    try {
      // Kein Login-Overlay bei Fehler — sonst wirkt der Button wie „blockiert“.
      const res = await apiFetch("/api/auth/login-audit?limit=100", { resetOn401: false });
      if (res.status === 401) throw new Error("Nicht angemeldet — bitte neu anmelden.");
      if (!res.ok) throw new Error("Protokoll nicht ladbar");
      const data = await res.json();
      const entries = Array.isArray(data.entries) ? data.entries : [];
      const stamp = new Date().toLocaleTimeString("de-DE", { timeZone: "Europe/Berlin" });
      if (!entries.length) {
        list.innerHTML = "";
        empty?.classList.remove("hidden");
        setAuditStatus(`Aktualisiert ${stamp} · 0 Einträge`);
        return;
      }
      list.innerHTML = entries
        .map((e) => {
          const when = e.at
            ? new Date(e.at).toLocaleString("de-DE", { timeZone: "Europe/Berlin" })
            : "—";
          const okLabel = e.ok
            ? '<span class="badge badge-active">OK</span>'
            : '<span class="badge badge-suspended">Fehlschlag</span>';
          const role = escapeHtml(e.role || "—");
          const ip = escapeHtml(e.ip || "—");
          const source = escapeHtml(e.source || "—");
          const reason = e.reason ? escapeHtml(e.reason) : "—";
          const slug = e.operatorSlug ? escapeHtml(e.operatorSlug) : "—";
          return `<article class="inquiry-card">
            <div class="card-head" style="margin-bottom:0.35rem">
              <strong>${when}</strong>
              ${okLabel}
            </div>
            <p class="meta" style="margin:0">Rolle: <strong>${role}</strong> · IP: ${ip} · Quelle: ${source}</p>
            <p class="meta" style="margin:0.2rem 0 0">Betrieb: ${slug} · Grund: ${reason}</p>
          </article>`;
        })
        .join("");
      setAuditStatus(`Aktualisiert ${stamp} · ${entries.length} Einträge`);
    } catch (err) {
      list.innerHTML = `<p class="login-error">${escapeHtml(err.message || "Fehler")}</p>`;
      setAuditStatus(err.message || "Fehler", true);
    } finally {
      if (refreshBtn) {
        refreshBtn.disabled = false;
        refreshBtn.textContent = prevRefresh || "Aktualisieren";
      }
    }
  }

  function statusBadge(status) {
    const cls =
      status === "active" ? "badge-active" : status === "suspended" ? "badge-suspended" : "badge-pending";
    return `<span class="badge ${cls}">${status}</span>`;
  }

  async function copyText(text) {
    const value = String(text || "");
    if (!value.trim()) throw new Error("Keine Links zum Kopieren");
    try {
      if (navigator.clipboard?.writeText) {
        await navigator.clipboard.writeText(value);
        return;
      }
    } catch {
      /* Fallback unten */
    }
    const ta = document.createElement("textarea");
    ta.value = value;
    ta.setAttribute("readonly", "");
    ta.style.position = "fixed";
    ta.style.left = "-9999px";
    document.body.appendChild(ta);
    ta.select();
    const ok = document.execCommand("copy");
    ta.remove();
    if (!ok) throw new Error("Kopieren nicht möglich — bitte Links manuell markieren.");
  }

  function formatDate(iso) {
    if (!iso) return "—";
    try {
      return new Date(iso).toLocaleString("de-DE", {
        day: "2-digit",
        month: "2-digit",
        year: "numeric",
        hour: "2-digit",
        minute: "2-digit",
      });
    } catch {
      return iso;
    }
  }

  function planLabel(planId) {
    if (planId === "fleet") return "Pro Fahrzeug";
    if (planId === "starter") return "Starter (alt)";
    if (planId === "business") return "Business (alt)";
    return planId || "Allgemein";
  }

  function updateInquiryStats(items) {
    const weekAgo = Date.now() - 7 * 24 * 60 * 60 * 1000;
    document.getElementById("stat-total").textContent = String(items.length);
    document.getElementById("stat-fleet").textContent = String(
      items.filter((i) => !i.planId || i.planId === "fleet").length
    );
    document.getElementById("stat-legacy").textContent = String(
      items.filter((i) => i.planId === "starter" || i.planId === "business").length
    );
    document.getElementById("stat-week").textContent = String(
      items.filter((i) => new Date(i.createdAt).getTime() >= weekAgo).length
    );
  }

  function updateTenantStats(ops) {
    document.getElementById("stat-tenants-total").textContent = String(ops.length);
    document.getElementById("stat-tenants-active").textContent = String(
      ops.filter((o) => o.status === "active").length
    );
    document.getElementById("stat-tenants-pending").textContent = String(
      ops.filter((o) => o.status === "pending").length
    );
    document.getElementById("stat-tenants-gaps").textContent = String(
      ops.filter((o) => (o.complianceGaps || []).length > 0).length
    );
  }

  function prefillTenantForm(inquiry) {
    showPanel("create");
    const form = document.getElementById("create-tenant-form");
    form.companyName.value = inquiry.companyName || "";
    form.email.value = inquiry.email || "";
    form.billingEmail.value = inquiry.email || "";
    form.planId.value = "fleet";
    form.notes.value = inquiry.message
      ? `Tarif-Anfrage vom ${formatDate(inquiry.createdAt)}:\n${inquiry.message}`
      : `Tarif-Anfrage vom ${formatDate(inquiry.createdAt)}`;
    form.companyName.focus();
  }

  async function openAuthDocument(url) {
    const res = await apiFetch(url);
    if (!res.ok) {
      const err = await res.json().catch(() => ({}));
      throw new Error(err.error || "Dokument konnte nicht geladen werden");
    }
    const blob = await res.blob();
    window.open(URL.createObjectURL(blob), "_blank", "noopener");
  }

  function complianceBlock(op) {
    const docs = op.documents || {};
    const gaps = op.complianceGaps || [];
    const concUrl = `/api/fleet/operators/${encodeURIComponent(op.slug)}/documents/concessionDocument`;
    const ownerUrl = `/api/fleet/operators/${encodeURIComponent(op.slug)}/documents/ownerPScheinDocument`;
    const docButtons = [];
    if (docs.concessionDocument?.present) {
      docButtons.push(
        `<button type="button" class="btn btn-ghost btn-sm open-doc" data-url="${escapeHtml(concUrl)}">Konzession</button>`
      );
    }
    if (docs.ownerPScheinDocument?.present) {
      docButtons.push(
        `<button type="button" class="btn btn-ghost btn-sm open-doc" data-url="${escapeHtml(ownerUrl)}">P-Schein</button>`
      );
    }
    return `
      <div class="compliance">
        <div><strong>Konz.-Nr.:</strong> ${escapeHtml(op.concessionNumber || "—")}</div>
        <div><strong>Behörde:</strong> ${escapeHtml(op.concessionAuthority || "—")}</div>
        <div><strong>gültig bis:</strong> ${escapeHtml(op.concessionValidUntil || "—")}</div>
        ${
          op.ownerHasPSchein
            ? `<div><strong>Inhaber-P-Schein:</strong> ${escapeHtml(op.ownerPScheinNumber || "—")}</div>`
            : ""
        }
        <div class="chip-row" style="margin-top:0.4rem">${docButtons.join("") || "<em>keine Uploads</em>"}</div>
        ${
          gaps.length
            ? `<div class="warn">Fehlt: ${escapeHtml(gaps.join(", "))}</div>`
            : `<div class="ok">Nachweise vollständig</div>`
        }
        <button type="button" class="btn btn-ghost btn-sm show-drivers" data-slug="${escapeHtml(op.slug)}" style="margin-top:0.45rem">Fahrer-Nachweise</button>
        <div class="driver-panel hidden" data-drivers-panel="${escapeHtml(op.slug)}"></div>
      </div>
    `;
  }

  function brandingBlock(op) {
    const logo = String(op.logoUrl || "").trim();
    const preview = logo
      ? `<img class="logo-preview" src="${escapeHtml(logo)}" alt="Logo ${escapeHtml(op.companyName)}" onerror="this.style.display='none'">`
      : `<div class="logo-placeholder">Logo</div>`;
    return `
      <div class="brand-box">
        <strong>Betriebs-Logo</strong>
        <div class="logo-row" style="margin-top:0.45rem">
          ${preview}
          <div style="flex:1;min-width:160px">
            <input type="file" class="logo-file" accept="image/png,image/jpeg" style="font-size:0.78rem;width:100%">
            <div class="chip-row" style="margin-top:0.35rem">
              <button type="button" class="btn btn-navy btn-sm upload-logo">Logo speichern</button>
            </div>
            <div class="meta" style="margin-top:0.25rem">PNG/JPEG, max. 5&nbsp;MB. Erscheint in Buchung und Leitstelle.</div>
          </div>
        </div>
      </div>
    `;
  }

  function wireLogoUpload(card, op) {
    const btn = card.querySelector(".upload-logo");
    const input = card.querySelector(".logo-file");
    if (!btn || !input) return;
    btn.addEventListener("click", async () => {
      const file = input.files && input.files[0];
      if (!file) {
        alert("Bitte zuerst eine PNG- oder JPEG-Datei wählen.");
        return;
      }
      const body = new FormData();
      body.append("logo", file);
      btn.disabled = true;
      try {
        const res = await apiFetch(`/api/fleet/operators/${encodeURIComponent(op.slug)}/logo`, {
          method: "POST",
          body,
        });
        const data = await res.json().catch(() => ({}));
        if (!res.ok) throw new Error(data.error || "Logo-Upload fehlgeschlagen");
        await loadTenants();
      } catch (err) {
        alert(err.message || "Logo-Upload fehlgeschlagen");
      } finally {
        btn.disabled = false;
      }
    });
  }

  async function loadInquiries() {
    const res = await apiFetch("/api/contact/inquiries");
    const data = await res.json();
    const items = data.inquiries || [];
    const list = document.getElementById("inquiries-list");
    const emptyEl = document.getElementById("inquiries-empty");
    list.innerHTML = "";
    updateInquiryStats(items);

    if (!items.length) {
      emptyEl.classList.remove("hidden");
      return;
    }
    emptyEl.classList.add("hidden");

    for (const inquiry of items) {
      const item = document.createElement("article");
      item.className = "inquiry-item";
      const mailSubject = encodeURIComponent(`Luckys Taxi App: Tarif ${planLabel(inquiry.planId)}`);
      item.innerHTML = `
        <div>
          <div class="chip-row">
            <strong>${escapeHtml(inquiry.companyName)}</strong>
            <span class="badge badge-pending">${escapeHtml(planLabel(inquiry.planId))}</span>
          </div>
          <div class="meta">${escapeHtml(formatDate(inquiry.createdAt))} · <a href="mailto:${escapeHtml(inquiry.email)}">${escapeHtml(inquiry.email)}</a></div>
          <p>${escapeHtml(inquiry.message || "—")}</p>
        </div>
        <div class="actions">
          <button type="button" class="btn btn-ghost btn-sm reply-inquiry">Antworten</button>
          <button type="button" class="btn btn-navy btn-sm use-inquiry">Als Mandant</button>
        </div>
      `;
      item.querySelector(".reply-inquiry")?.addEventListener("click", () => {
        window.location.href = `mailto:${inquiry.email}?subject=${mailSubject}`;
      });
      item.querySelector(".use-inquiry")?.addEventListener("click", () => prefillTenantForm(inquiry));
      list.appendChild(item);
    }
  }

  async function loadTenants() {
    const res = await apiFetch("/api/fleet/operators");
    const data = await res.json();
    const ops = data.operators || [];
    const grid = document.getElementById("tenants-grid");
    const emptyEl = document.getElementById("tenants-empty");
    grid.innerHTML = "";
    updateTenantStats(ops);

    if (!ops.length) {
      emptyEl.classList.remove("hidden");
      return;
    }
    emptyEl.classList.add("hidden");

    for (const op of ops) {
      const card = document.createElement("article");
      card.className = "tenant-card";
      const links = op.links || {};
      card.innerHTML = `
        <div>
          <div class="chip-row" style="justify-content:space-between">
            <h3>${escapeHtml(op.companyName)}</h3>
            ${statusBadge(op.status)}
          </div>
          <div class="meta">
            <code>${escapeHtml(op.slug)}</code>
            ${op.billingEmail ? ` · ${escapeHtml(op.billingEmail)}` : ""}<br>
            ${escapeHtml(op.planId || "starter")} · ${op.maxDrivers == null ? "∞ Fahrer" : op.maxDrivers + " Fahrer"}
            · ${op.hasDispatchPin ? "PIN gesetzt" : "kein PIN"}<br>
            ${op.stripeConnectAccountId ? "Connect: " + escapeHtml(op.stripeConnectAccountId) : "Connect: nicht verbunden"}
          </div>
        </div>
        ${complianceBlock(op)}
        ${brandingBlock(op)}
        <div class="link-row">
          <a href="${links.dispatch || "#"}" target="_blank" rel="noopener">Leitstelle</a>
          <a href="${links.settings || "#"}" target="_blank" rel="noopener">Settings</a>
          <a href="${links.book || "#"}" target="_blank" rel="noopener">Buchung</a>
          <a href="${links.qr || "#"}" target="_blank" rel="noopener">QR</a>
          <a href="${links.driverOnboard || "#"}" target="_blank" rel="noopener">Fahrer-Reg.</a>
        </div>
        <div class="actions">
          <button type="button" class="btn btn-navy btn-sm open-map">Live-Karte</button>
          <button type="button" class="btn btn-ghost btn-sm copy-links"${
            op.complianceComplete
              ? ""
              : ' disabled title="Erst Nachweise vollständig ausfüllen (Konzession usw.)"'
          }>Links kopieren</button>
          ${
            op.status !== "active"
              ? `<button type="button" class="btn btn-ok btn-sm activate">Aktivieren</button>`
              : `<button type="button" class="btn btn-bad btn-sm suspend">Sperren</button>`
          }
          <button type="button" class="btn btn-navy btn-sm connect-onboard">Stripe Connect</button>
          <button type="button" class="btn btn-bad btn-sm delete-tenant">Löschen</button>
        </div>
      `;

      card.querySelector(".copy-links")?.addEventListener("click", async () => {
        if (!op.complianceComplete) {
          alert(
            "Nachweise unvollständig. Bitte zuerst Konzession (Nummer + Dokument) hinterlegen, dann Links kopieren."
          );
          return;
        }
        try {
          await copyText(
            [
              `Betrieb: ${op.companyName} (${op.slug})`,
              `Leitstelle: ${links.dispatch || ""}`,
              `Einstellungen: ${links.settings || ""}`,
              `Buchung: ${links.book || ""}`,
              `QR: ${links.qr || ""}`,
              `Fahrer-Registrierung: ${links.driverOnboard || ""}`,
            ].join("\n")
          );
          alert("Links in die Zwischenablage kopiert.");
        } catch (err) {
          alert(err.message || "Kopieren fehlgeschlagen");
        }
      });
      wireLogoUpload(card, op);
      card.querySelector(".open-map")?.addEventListener("click", () => openOperatorOnMap(op.slug));
      card.querySelector(".activate")?.addEventListener("click", () => {
        if (op.complianceGaps?.length) {
          const ok = confirm(
            `Nachweise unvollständig (${op.complianceGaps.join(", ")}). Trotzdem aktivieren?`
          );
          if (!ok) return;
        }
        patchTenant(op.slug, { status: "active" });
      });
      card.querySelector(".suspend")?.addEventListener("click", () =>
        patchTenant(op.slug, { status: "suspended" })
      );
      card.querySelector(".connect-onboard")?.addEventListener("click", () =>
        startConnectOnboard(op.slug)
      );
      card.querySelector(".delete-tenant")?.addEventListener("click", () => {
        const ok = confirm(
          `Betrieb „${op.companyName}“ (${op.slug}) wirklich löschen?\n\nNachweise und zugehörige Fahrer werden mitgelöscht. Das kann nicht rückgängig gemacht werden.`
        );
        if (!ok) return;
        deleteTenant(op.slug);
      });
      card.querySelectorAll(".open-doc").forEach((btn) => {
        btn.addEventListener("click", () => {
          openAuthDocument(btn.getAttribute("data-url")).catch((err) => alert(err.message));
        });
      });
      card.querySelector(".show-drivers")?.addEventListener("click", async () => {
        const panel = card.querySelector(`[data-drivers-panel="${op.slug}"]`);
        if (!panel) return;
        if (!panel.classList.contains("hidden") && panel.dataset.loaded === "1") {
          panel.classList.add("hidden");
          return;
        }
        panel.classList.remove("hidden");
        panel.innerHTML = "<p>Lade Fahrer…</p>";
        try {
          const cres = await apiFetch(`/api/compliance?operator=${encodeURIComponent(op.slug)}`);
          const cdata = await cres.json();
          if (!cres.ok) throw new Error(cdata.error || "Laden fehlgeschlagen");
          const list = cdata.drivers || [];
          if (!list.length) {
            panel.innerHTML = "<p>Keine Fahrer hinterlegt.</p>";
          } else {
            panel.innerHTML = `<strong>Fahrer (${list.length})</strong><ul>${list
              .map((d) => {
                const docs = d.documents || {};
                const buttons = [];
                if (docs.photo?.present) {
                  buttons.push(
                    `<button type="button" class="btn btn-ghost btn-sm open-doc" data-url="/api/drivers/${encodeURIComponent(d.driverId)}/documents/photo">Foto</button>`
                  );
                }
                if (docs.pScheinDocument?.present) {
                  buttons.push(
                    `<button type="button" class="btn btn-ghost btn-sm open-doc" data-url="/api/drivers/${encodeURIComponent(d.driverId)}/documents/pScheinDocument">P-Schein</button>`
                  );
                }
                if (docs.licenseDocument?.present) {
                  buttons.push(
                    `<button type="button" class="btn btn-ghost btn-sm open-doc" data-url="/api/drivers/${encodeURIComponent(d.driverId)}/documents/licenseDocument">Führerschein</button>`
                  );
                }
                const pending =
                  d.status === "pending"
                    ? ' · <strong style="color:#92400e">pending</strong>'
                    : "";
                return `<li><strong>${escapeHtml(d.name)}</strong>${pending} · Taxi ${escapeHtml(d.taxiNumber || "—")} · ${escapeHtml(d.vehicle || "—")}<br>P-Schein: ${escapeHtml(d.pScheinNumber || "—")}<br>${buttons.join(" ") || "<em>keine Uploads</em>"}</li>`;
              })
              .join("")}</ul>`;
            panel.querySelectorAll(".open-doc").forEach((btn) => {
              btn.addEventListener("click", () => {
                openAuthDocument(btn.getAttribute("data-url")).catch((err) => alert(err.message));
              });
            });
          }
          panel.dataset.loaded = "1";
        } catch (err) {
          panel.innerHTML = `<p class="warn">${escapeHtml(err.message)}</p>`;
        }
      });

      grid.appendChild(card);
    }
  }

  async function startConnectOnboard(slug) {
    const res = await apiFetch(`/api/fleet/operators/${encodeURIComponent(slug)}/connect/onboard`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: "{}",
    });
    const data = await res.json().catch(() => ({}));
    if (!res.ok) {
      alert(data.error || "Connect-Onboarding fehlgeschlagen");
      return;
    }
    if (data.url) window.location.href = data.url;
  }

  async function patchTenant(slug, patch) {
    const res = await apiFetch(`/api/fleet/operators/${encodeURIComponent(slug)}`, {
      method: "PATCH",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify(patch),
    });
    if (!res.ok) {
      const err = await res.json().catch(() => ({}));
      alert(err.error || "Aktion fehlgeschlagen");
      return;
    }
    await loadTenants();
  }

  async function deleteTenant(slug) {
    const res = await apiFetch(`/api/fleet/operators/${encodeURIComponent(slug)}`, {
      method: "DELETE",
    });
    if (!res.ok) {
      const err = await res.json().catch(() => ({}));
      alert(err.error || "Löschen fehlgeschlagen");
      return;
    }
    await loadTenants();
  }

  function activePanelId() {
    const active = document.querySelector(".panel.active");
    if (!active?.id) return "";
    return active.id.replace(/^panel-/, "");
  }

  function hasCoords(lat, lng) {
    const la = Number(lat);
    const ln = Number(lng);
    if (!Number.isFinite(la) || !Number.isFinite(ln)) return false;
    if (Math.abs(la) > 90 || Math.abs(ln) > 180) return false;
    // Fehlendes GPS landet oft bei 0,0 (Atlantik) und sprengt fitBounds.
    if (Math.abs(la) < 0.01 && Math.abs(ln) < 0.01) return false;
    return true;
  }

  function setMapStatus(text, isError) {
    const el = document.getElementById("map-status");
    if (!el) return;
    el.textContent = text || "";
    el.style.color = isError ? "#b91c1c" : "";
  }

  function openOperatorOnMap(slug) {
    pendingMapSlug = String(slug || "all");
    showPanel("map");
  }

  function initAdminMap() {
    if (adminMap || typeof L === "undefined") return;
    const el = document.getElementById("admin-map");
    if (!el) return;
    // Normale Straßenkarte (OSM): Zoom + Schieben, Start Europa/DE.
    adminMap = L.map(el, {
      zoomControl: true,
      scrollWheelZoom: true,
      doubleClickZoom: true,
      touchZoom: true,
      boxZoom: true,
      keyboard: true,
      dragging: true,
      inertia: true,
    }).setView([50.8, 10.5], 6);
    L.tileLayer("https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png", {
      maxZoom: 19,
      attribution: '&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a>',
    }).addTo(adminMap);
    // Manuelles Schieben/Zoomen beendet Auto-Follow.
    adminMap.on("dragstart", () => {
      if (!followIgnoreMove) stopFollowDriver();
    });
    adminMap.on("zoomstart", () => {
      if (!followIgnoreMove) stopFollowDriver();
    });
  }

  function taxiIcon(driver) {
    let cls = "taxi-pin";
    if (!driver.locationFresh) cls += " stale";
    else if (driver.status === "busy") cls += " busy";
    return L.divIcon({
      className: "",
      html: `<div class="${cls}">TX</div>`,
      iconSize: [28, 28],
      iconAnchor: [14, 14],
    });
  }

  function pickupIcon() {
    return L.divIcon({
      className: "",
      html: '<div class="pickup-pin">ABHOL</div>',
      iconSize: [52, 22],
      iconAnchor: [26, 11],
    });
  }

  /** OSM zeigt Straßennamen typisch ab Zoom ~16–17. */
  const STREET_ZOOM = 17;

  function fitToPoints(points) {
    if (!adminMap || !points.length) return;
    if (points.length === 1) {
      adminMap.setView(points[0], STREET_ZOOM);
      return;
    }
    adminMap.fitBounds(points, { padding: [40, 40], maxZoom: STREET_ZOOM });
  }

  function paintFollowBar() {
    const bar = document.getElementById("map-follow-bar");
    const label = document.getElementById("map-follow-label");
    if (!bar || !label) return;
    if (!followDriverId) {
      bar.classList.add("hidden");
      label.textContent = "";
      return;
    }
    const driver = mapDrivers.find((d) => d.driverId === followDriverId);
    const name = driver?.name || "Taxi";
    bar.classList.remove("hidden");
    label.textContent = `Live-Follow: ${name} — Karte bleibt am Auto`;
  }

  function stopFollowDriver() {
    if (!followDriverId) return;
    followDriverId = null;
    paintFollowBar();
    renderMapLists(mapDrivers, mapBookings);
  }

  function startFollowDriver(driverId) {
    if (!driverId) return;
    followDriverId = driverId;
    paintFollowBar();
    renderMapLists(mapDrivers, mapBookings);
    const marker = driverMarkers.get(driverId);
    if (marker) {
      followIgnoreMove = true;
      adminMap.flyTo(marker.getLatLng(), STREET_ZOOM, { animate: true, duration: 0.55 });
      marker.openPopup();
      setTimeout(() => {
        followIgnoreMove = false;
      }, 650);
    }
  }

  function followDriverIfNeeded() {
    if (!followDriverId || !adminMap) return;
    const marker = driverMarkers.get(followDriverId);
    if (!marker) {
      stopFollowDriver();
      return;
    }
    const target = marker.getLatLng();
    followIgnoreMove = true;
    if (adminMap.getZoom() < STREET_ZOOM - 0.2) {
      adminMap.setView(target, STREET_ZOOM, { animate: true });
    } else {
      adminMap.panTo(target, { animate: true, duration: 0.35 });
    }
    setTimeout(() => {
      followIgnoreMove = false;
    }, 400);
  }

  function focusMarker(marker) {
    if (!marker || !adminMap) return;
    // Immer auf Straßenebene: Namen und genauer Einstiegspunkt sichtbar.
    followIgnoreMove = true;
    adminMap.flyTo(marker.getLatLng(), STREET_ZOOM, { animate: true, duration: 0.55 });
    marker.openPopup();
    setTimeout(() => {
      followIgnoreMove = false;
    }, 650);
  }

  function syncAdminMarkers(drivers, bookings, refit, center) {
    if (!adminMap) return;
    const bounds = [];
    const seenDrivers = new Set();
    for (const driver of drivers) {
      if (!hasCoords(driver.latitude, driver.longitude)) continue;
      const latLng = [Number(driver.latitude), Number(driver.longitude)];
      seenDrivers.add(driver.driverId);
      bounds.push(latLng);
      const popup = `<strong>${escapeHtml(driver.name)}</strong><br>${escapeHtml(driver.operatorName || "")}<br>${escapeHtml(driver.vehicle || "")}<br>${
        DRIVER_STATUS_LABELS[driver.status] || escapeHtml(driver.status)
      }${driver.locationFresh ? "" : "<br><em>Standort älter als 2 Min.</em>"}`;
      if (driverMarkers.has(driver.driverId)) {
        const marker = driverMarkers.get(driver.driverId);
        marker.setLatLng(latLng);
        marker.setIcon(taxiIcon(driver));
        marker.setPopupContent(popup);
      } else {
        const marker = L.marker(latLng, { icon: taxiIcon(driver) }).addTo(adminMap).bindPopup(popup);
        marker.on("click", () => startFollowDriver(driver.driverId));
        driverMarkers.set(driver.driverId, marker);
      }
    }
    for (const [id, marker] of [...driverMarkers.entries()]) {
      if (!seenDrivers.has(id)) {
        adminMap.removeLayer(marker);
        driverMarkers.delete(id);
      }
    }

    const seenBookings = new Set();
    for (const booking of bookings) {
      if (!hasCoords(booking.latitude, booking.longitude)) continue;
      const latLng = [Number(booking.latitude), Number(booking.longitude)];
      seenBookings.add(booking.bookingId);
      bounds.push(latLng);
      const popup = `<strong>${escapeHtml(booking.addressLine || "Abholung")}</strong><br>${escapeHtml(
        booking.operatorName || ""
      )}<br>${BOOKING_STATUS_LABELS[booking.status] || escapeHtml(booking.status || "")}`;
      if (bookingMarkers.has(booking.bookingId)) {
        const marker = bookingMarkers.get(booking.bookingId);
        marker.setLatLng(latLng);
        marker.setPopupContent(popup);
      } else {
        const marker = L.marker(latLng, { icon: pickupIcon() }).addTo(adminMap).bindPopup(popup);
        bookingMarkers.set(booking.bookingId, marker);
      }
    }
    for (const [id, marker] of [...bookingMarkers.entries()]) {
      if (!seenBookings.has(id)) {
        adminMap.removeLayer(marker);
        bookingMarkers.delete(id);
      }
    }

    const scope = document.getElementById("map-operator")?.value || "all";
    if (refit && mapFittedFor !== scope) {
      if (bounds.length) {
        fitToPoints(bounds);
      } else if (center && hasCoords(center.latitude, center.longitude)) {
        adminMap.setView([Number(center.latitude), Number(center.longitude)], 15);
      } else {
        adminMap.setView([50.8, 10.5], 6);
      }
      mapFittedFor = scope;
    }
    followDriverIfNeeded();
  }

  function renderMapLists(drivers, bookings) {
    const driverRoot = document.getElementById("map-drivers");
    const bookingRoot = document.getElementById("map-bookings");
    if (!driverRoot || !bookingRoot) return;
    if (!drivers.length) {
      driverRoot.innerHTML = '<p class="meta">Keine Fahrer in dieser Ansicht.</p>';
    } else {
      driverRoot.innerHTML = drivers
        .map((driver) => {
          const gps = !hasCoords(driver.latitude, driver.longitude)
            ? "kein GPS"
            : driver.locationFresh
              ? "GPS live"
              : "GPS alt";
          const following = followDriverId === driver.driverId;
          return `<button type="button" class="map-item${following ? " is-following" : ""}" data-focus-driver="${escapeHtml(driver.driverId)}">
            <strong>${escapeHtml(driver.name)}${following ? " · Follow" : ""}</strong>
            <div class="meta">${escapeHtml(driver.operatorName || "ohne Betrieb")} · ${
              DRIVER_STATUS_LABELS[driver.status] || escapeHtml(driver.status)
            } · ${gps}</div>
            <div class="meta">${escapeHtml(driver.vehicle || "")}</div>
          </button>`;
        })
        .join("");
    }
    if (!bookings.length) {
      bookingRoot.innerHTML = '<p class="meta">Keine offenen Aufträge.</p>';
    } else {
      bookingRoot.innerHTML = bookings
        .map((booking) => {
          return `<button type="button" class="map-item" data-focus-booking="${escapeHtml(booking.bookingId)}">
            <strong>${escapeHtml(booking.addressLine || "Abholung")}</strong>
            <div class="meta">${escapeHtml(booking.operatorName || "")} · ${
              BOOKING_STATUS_LABELS[booking.status] || escapeHtml(booking.status || "")
            }</div>
          </button>`;
        })
        .join("");
    }
    driverRoot.querySelectorAll("[data-focus-driver]").forEach((btn) => {
      btn.addEventListener("click", () => {
        const id = btn.getAttribute("data-focus-driver");
        startFollowDriver(id);
      });
    });
    bookingRoot.querySelectorAll("[data-focus-booking]").forEach((btn) => {
      btn.addEventListener("click", () => {
        stopFollowDriver();
        focusMarker(bookingMarkers.get(btn.getAttribute("data-focus-booking")));
      });
    });
  }

  function fillMapOperators(operators, selected) {
    const select = document.getElementById("map-operator");
    if (!select) return;
    const current = selected || select.value || "all";
    const options = ['<option value="all">Alle Betriebe</option>'];
    for (const op of operators || []) {
      const city = op.legalCity ? ` · ${op.legalCity}` : "";
      options.push(
        `<option value="${escapeHtml(op.slug)}">${escapeHtml(op.companyName || op.slug)}${escapeHtml(city)}</option>`
      );
    }
    select.innerHTML = options.join("");
    const known = [...select.options].some((option) => option.value === current);
    select.value = known ? current : "all";
  }

  async function loadLiveMap(refit) {
    const select = document.getElementById("map-operator");
    let slug = select?.value || "all";
    if (pendingMapSlug) {
      slug = pendingMapSlug;
      pendingMapSlug = "";
      refit = true;
      mapFittedFor = "";
    }
    const requestId = ++liveMapRequestId;
    const requestedSlug = slug;
    setMapStatus("Verbinde…");
    const res = await apiFetch(`/api/fleet/live-map?operator=${encodeURIComponent(slug)}`, {
      resetOn401: true,
    });
    const data = await res.json().catch(() => ({}));
    if (requestId !== liveMapRequestId) return;
    if (!res.ok) throw new Error(data.error || "Karte nicht ladbar");
    const responseSlug = data.operator || "all";
    if (responseSlug !== requestedSlug) return;
    mapDrivers = Array.isArray(data.drivers) ? data.drivers : [];
    mapBookings = Array.isArray(data.bookings) ? data.bookings : [];
    fillMapOperators(data.operators, requestedSlug);
    paintMapStats();
    renderMapLists(mapDrivers, mapBookings);
    syncAdminMarkers(mapDrivers, mapBookings, refit, data.center);
    paintMapStatus();
  }

  function paintMapStats() {
    const driversEl = document.getElementById("map-n-drivers");
    if (!driversEl) return;
    driversEl.textContent = String(mapDrivers.length);
    document.getElementById("map-n-live").textContent = String(mapDrivers.filter((d) => d.locationFresh).length);
    document.getElementById("map-n-busy").textContent = String(mapDrivers.filter((d) => d.status === "busy").length);
    document.getElementById("map-n-jobs").textContent = String(mapBookings.length);
  }

  function paintMapStatus() {
    const stamp = new Date().toLocaleTimeString("de-DE", { timeZone: "Europe/Berlin" });
    const link = liveConnected ? "Live verbunden" : "Abruf";
    setMapStatus(`${link} · ${stamp} Uhr (Berlin) · ${mapDrivers.length} Fahrer · ${mapBookings.length} Aufträge`);
  }

  function applyLiveDriver(update) {
    if (!update?.driverId) return;
    const slug = document.getElementById("map-operator")?.value || "all";
    if (slug !== "all" && update.operatorSlug !== slug) return;
    const index = mapDrivers.findIndex((driver) => driver.driverId === update.driverId);
    if (index === -1) mapDrivers.push(update);
    else mapDrivers[index] = { ...mapDrivers[index], ...update };
    paintMapStats();
    renderMapLists(mapDrivers, mapBookings);
    syncAdminMarkers(mapDrivers, mapBookings, false, null);
    paintMapStatus();
    paintFollowBar();
  }

  function connectAdminMapSocket() {
    if (typeof io !== "function" || adminSocket) return;
    const token = getSession() || getPin();
    if (!token) return;
    adminSocket = io({ path: "/socket.io", transports: ["websocket", "polling"] });
    const subscribe = () => adminSocket.emit("subscribe:fleet", { token: getSession() || getPin() });
    adminSocket.on("connect", subscribe);
    adminSocket.on("fleet:ready", () => {
      liveConnected = true;
      paintMapStatus();
    });
    adminSocket.on("fleet:denied", () => {
      liveConnected = false;
      setMapStatus("Live-Verbindung abgelehnt. Bitte neu anmelden.", true);
    });
    adminSocket.on("fleet:driver", (driver) => {
      if (activePanelId() !== "map") return;
      applyLiveDriver(driver);
    });
    adminSocket.on("disconnect", () => {
      liveConnected = false;
      if (activePanelId() === "map") paintMapStatus();
    });
  }

  function disconnectAdminMapSocket() {
    liveConnected = false;
    if (!adminSocket) return;
    adminSocket.emit("unsubscribe:fleet");
    adminSocket.close();
    adminSocket = null;
  }

  function startAdminMap() {
    initAdminMap();
    if (typeof L === "undefined") {
      setMapStatus("Kartenbibliothek nicht geladen. Seite neu laden.", true);
      return;
    }
    connectAdminMapSocket();
    loadLiveMap(true).catch((err) => setMapStatus(err.message || "Karte nicht ladbar", true));
    if (!adminMapTimer) {
      adminMapTimer = setInterval(() => {
        if (document.hidden || activePanelId() !== "map") return;
        loadLiveMap(false).catch((err) => setMapStatus(err.message || "Karte nicht ladbar", true));
      }, 8000);
    }
    setTimeout(() => adminMap?.invalidateSize(), 60);
    setTimeout(() => adminMap?.invalidateSize(), 280);
  }

  function stopAdminMap() {
    followDriverId = null;
    paintFollowBar();
    disconnectAdminMapSocket();
    if (adminMapTimer) {
      clearInterval(adminMapTimer);
      adminMapTimer = null;
    }
  }

  async function refreshAll() {
    const panel = activePanelId();
    if (panel === "audit") {
      await loadLoginAudit();
      return;
    }
    if (panel === "map") {
      await loadLiveMap(false);
      return;
    }
    const errors = [];
    try {
      await loadTenants();
    } catch (err) {
      errors.push(err.message || "Mandanten fehlgeschlagen");
    }
    try {
      await loadInquiries();
    } catch (err) {
      errors.push(err.message || "Anfragen fehlgeschlagen");
    }
    if (errors.length) {
      throw new Error(errors.join(" · "));
    }
  }

  async function withRefreshBusy(run) {
    const btn = document.getElementById("refresh-all");
    const csvBtn = document.getElementById("export-tenants-csv");
    const prev = btn ? btn.textContent : "";
    if (btn) {
      btn.disabled = true;
      btn.textContent = "Lädt…";
    }
    if (csvBtn) csvBtn.disabled = true;
    try {
      await run();
    } finally {
      if (btn) {
        btn.disabled = false;
        btn.textContent = prev || "Aktualisieren";
      }
      if (csvBtn) csvBtn.disabled = false;
    }
  }

  document.querySelectorAll(".nav-btn").forEach((btn) => {
    btn.addEventListener("click", () => showPanel(btn.getAttribute("data-panel")));
  });

  document.querySelectorAll("[data-panel-jump]").forEach((btn) => {
    btn.addEventListener("click", () => showPanel(btn.getAttribute("data-panel-jump")));
  });

  document.getElementById("refresh-audit")?.addEventListener("click", (e) => {
    e.preventDefault();
    loadLoginAudit();
  });

  document.getElementById("clear-audit")?.addEventListener("click", async (e) => {
    e.preventDefault();
    if (!window.confirm("Gesamtes Login-Protokoll löschen?")) return;
    const btn = e.currentTarget;
    const prev = btn.textContent;
    btn.disabled = true;
    btn.textContent = "Lösche…";
    setAuditStatus("Lösche Protokoll…");
    try {
      const res = await apiFetch("/api/auth/login-audit", {
        method: "DELETE",
        resetOn401: false,
      });
      if (res.status === 401) throw new Error("Nicht angemeldet — bitte neu anmelden.");
      if (!res.ok) throw new Error("Löschen fehlgeschlagen");
      await loadLoginAudit();
      setAuditStatus("Protokoll gelöscht");
    } catch (err) {
      setAuditStatus(err.message || "Löschen fehlgeschlagen", true);
      alert(err.message || "Löschen fehlgeschlagen");
    } finally {
      btn.disabled = false;
      btn.textContent = prev || "Löschen";
    }
  });

  function onlyDigits6(el) {
    if (!el) return;
    const digits = String(el.value || "").replace(/\D/g, "").slice(0, 6);
    if (el.value !== digits) el.value = digits;
  }

  document.getElementById("admin-totp")?.addEventListener("input", (e) => {
    onlyDigits6(e.target);
  });
  document.getElementById("mfa-confirm-code")?.addEventListener("input", (e) => {
    onlyDigits6(e.target);
  });

  document.getElementById("mfa-use-server-code")?.addEventListener("click", () => {
    const expected = String(document.getElementById("mfa-expected-code")?.textContent || "")
      .replace(/\D/g, "")
      .slice(0, 6);
    const errEl = document.getElementById("mfa-setup-error");
    if (!/^\d{6}$/.test(expected)) {
      errEl.textContent = "Kein Server-Code — bitte „Neuen QR erzeugen“ tippen.";
      errEl.classList.remove("hidden");
      return;
    }
    const input = document.getElementById("mfa-confirm-code");
    if (input) input.value = expected;
    errEl.style.color = "#0c1c34";
    errEl.textContent =
      "Server-Code eingefügt. Nur aktivieren, wenn die App dieselbe Zahl zeigt.";
    errEl.classList.remove("hidden");
  });

  document.getElementById("admin-login-form").addEventListener("submit", async (e) => {
    e.preventDefault();
    const errEl = document.getElementById("admin-login-error");
    errEl.classList.add("hidden");
    const remember = document.getElementById("admin-remember")?.checked !== false;
    const pin = mfaStep ? pendingPin : document.getElementById("admin-pin").value.trim();
    const totp = document.getElementById("admin-totp").value.trim();

    if (!mfaStep) {
      pendingPin = pin;
      if (!pin) {
        errEl.textContent = "Bitte PIN eingeben.";
        errEl.classList.remove("hidden");
        return;
      }
    } else if (!totp) {
      errEl.textContent = "Bitte Authenticator-Code eingeben.";
      errEl.classList.remove("hidden");
      return;
    }

    try {
      const res = await fetch("/api/auth/verify", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          pin,
          totp: mfaStep || totp ? totp : undefined,
          source: "admin.html",
        }),
      });
      const data = await res.json().catch(() => ({}));
      if (!res.ok) {
        if (data.mfaRequired) {
          showMfaCodeStep();
          errEl.textContent = data.error || "Bitte Authenticator-Code eingeben.";
          errEl.classList.remove("hidden");
          return;
        }
        throw new Error(data.error || "Anmeldung fehlgeschlagen");
      }

      setAuth({
        sessionToken: data.sessionToken || "",
        pin,
        remember,
      });

      const submitBtn = document.getElementById("admin-login-submit");
      submitBtn.disabled = true;
      submitBtn.textContent = "Bitte warten…";

      if (data.mfaSetupRequired) {
        try {
          await startMfaSetup();
        } finally {
          submitBtn.disabled = false;
          submitBtn.textContent = "★ Anmelden ★";
        }
        return;
      }

      await enterAppAfterAuth();
      submitBtn.disabled = false;
      submitBtn.textContent = "★ Anmelden ★";
    } catch (err) {
      clearAuth();
      document.getElementById("admin-login-form").classList.remove("hidden");
      const submitBtn = document.getElementById("admin-login-submit");
      if (submitBtn) {
        submitBtn.disabled = false;
        submitBtn.textContent = mfaStep ? "Code bestätigen" : "★ Anmelden ★";
      }
      errEl.textContent = err.message;
      errEl.classList.remove("hidden");
    }
  });

  document.getElementById("mfa-recover-btn")?.addEventListener("click", async () => {
    const errEl = document.getElementById("admin-login-error");
    errEl.classList.add("hidden");
    const pin = (
      pendingPin ||
      document.getElementById("admin-pin")?.value ||
      ""
    ).trim();
    if (!pin) {
      showLogin();
      errEl.textContent = "Bitte zuerst ADMIN_PIN eintragen, dann MFA zurücksetzen.";
      errEl.classList.remove("hidden");
      return;
    }
    if (
      !confirm(
        "MFA wirklich zurücksetzen? Danach reicht wieder nur der ADMIN_PIN — bitte MFA danach neu einrichten."
      )
    ) {
      return;
    }
    try {
      const res = await fetch("/api/auth/mfa/recover", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ pin }),
      });
      const data = await res.json().catch(() => ({}));
      if (!res.ok) throw new Error(data.error || "Zurücksetzen fehlgeschlagen");
      clearAuth();
      showLogin();
      errEl.style.color = "#0c1c34";
      errEl.textContent =
        "MFA ist aus. Mit ADMIN_PIN anmelden, dann unter „MFA einrichten“ neu scannen.";
      errEl.classList.remove("hidden");
    } catch (err) {
      errEl.style.color = "";
      errEl.textContent = err.message || "Zurücksetzen fehlgeschlagen";
      errEl.classList.remove("hidden");
    }
  });

  document.getElementById("mfa-copy-secret")?.addEventListener("click", async () => {
    const secret = String(
      mfaPendingSecret || document.getElementById("mfa-secret")?.textContent || ""
    ).trim();
    const errEl = document.getElementById("mfa-setup-error");
    if (!secret) {
      errEl.textContent = "Noch kein Geheimnis — bitte „Neuen QR erzeugen“.";
      errEl.classList.remove("hidden");
      return;
    }
    try {
      await navigator.clipboard.writeText(secret);
      errEl.style.color = "#0c1c34";
      errEl.textContent = "Geheimnis kopiert. In der Authenticator-App: Schlüssel einfügen (nicht scannen).";
      errEl.classList.remove("hidden");
    } catch {
      errEl.style.color = "";
      errEl.textContent = "Kopieren fehlgeschlagen — Geheimnis manuell abtippen.";
      errEl.classList.remove("hidden");
    }
  });

  document.getElementById("mfa-confirm-btn").addEventListener("click", async () => {
    const errEl = document.getElementById("mfa-setup-error");
    errEl.style.color = "";
    errEl.classList.add("hidden");
    const pin = (
      document.getElementById("mfa-confirm-pin")?.value ||
      getPin() ||
      pendingPin ||
      ""
    ).trim();
    const code = document
      .getElementById("mfa-confirm-code")
      .value.replace(/\D/g, "")
      .slice(0, 6);
    document.getElementById("mfa-confirm-code").value = code;
    const remember = document.getElementById("admin-remember")?.checked !== false;
    const btn = document.getElementById("mfa-confirm-btn");
    if (!pin) {
      errEl.textContent = "Bitte ADMIN_PIN eintragen (Feld darüber).";
      errEl.classList.remove("hidden");
      document.getElementById("mfa-confirm-pin")?.focus();
      return;
    }
    if (!/^\d{6}$/.test(code)) {
      errEl.textContent = "Bitte genau 6 Ziffern aus der Authenticator-App eingeben.";
      errEl.classList.remove("hidden");
      return;
    }
    pendingPin = pin;
    dropStaleSession();
    btn.disabled = true;
    btn.textContent = "Prüfe…";
    try {
      const res = await fetch("/api/auth/mfa/confirm", {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          Authorization: `Bearer ${pin}`,
          "X-Admin-Pin": pin,
        },
        body: JSON.stringify({
          totp: code,
          pin,
          secret: String(
            mfaPendingSecret || document.getElementById("mfa-secret")?.textContent || ""
          )
            .toUpperCase()
            .replace(/[^A-Z2-7]/g, ""),
        }),
      });
      const data = await res.json().catch(() => ({}));
      if (!res.ok) throw new Error(data.error || "Aktivierung fehlgeschlagen");
      setAuth({
        sessionToken: data.sessionToken || "",
        pin,
        remember,
      });
      await enterAppAfterAuth();
    } catch (err) {
      errEl.textContent =
        err.message ||
        "Code falsch. Oben „Server-Code jetzt“ mit der App vergleichen — müssen gleich sein. Sonst Eintrag löschen → Geheimnis kopieren → manuell einfügen.";
      errEl.classList.remove("hidden");
      // Frischen Server-Code nachladen (ohne Secret zu wechseln).
      try {
        await startMfaSetup({ reset: false });
      } catch {
        /* ignore */
      }
    } finally {
      btn.disabled = false;
      btn.textContent = "MFA aktivieren";
    }
  });

  document.getElementById("mfa-reset-btn")?.addEventListener("click", async () => {
    const btn = document.getElementById("mfa-reset-btn");
    const pin = (
      document.getElementById("mfa-confirm-pin")?.value ||
      getPin() ||
      pendingPin ||
      ""
    ).trim();
    if (!pin) {
      const errEl = document.getElementById("mfa-setup-error");
      errEl.style.color = "";
      errEl.textContent = "Bitte zuerst ADMIN_PIN eintragen, dann „Neuen QR erzeugen“.";
      errEl.classList.remove("hidden");
      document.getElementById("mfa-confirm-pin")?.focus();
      return;
    }
    pendingPin = pin;
    dropStaleSession();
    btn.disabled = true;
    try {
      await startMfaSetup({ reset: true });
    } catch {
      /* Fehler zeigt startMfaSetup */
    } finally {
      btn.disabled = false;
    }
  });

  document.getElementById("mfa-skip-btn")?.addEventListener("click", async () => {
    try {
      await enterAppAfterAuth();
    } catch (err) {
      const errEl = document.getElementById("mfa-setup-error");
      errEl.textContent = err.message || "Weiter ohne MFA fehlgeschlagen — bitte neu anmelden.";
      errEl.classList.remove("hidden");
    }
  });

  document.getElementById("admin-setup-mfa")?.addEventListener("click", async () => {
    document.getElementById("admin-app").classList.add("hidden");
    document.getElementById("admin-login").classList.remove("hidden");
    try {
      await startMfaSetup({ reset: true });
    } catch (err) {
      alert(err.message || "MFA-Setup fehlgeschlagen");
      showApp();
    }
  });

  document.getElementById("admin-logout").addEventListener("click", () => {
    stopAdminMap();
    clearAuth();
    showLogin();
  });

  document.getElementById("map-operator")?.addEventListener("change", () => {
    stopFollowDriver();
    mapFittedFor = "";
    loadLiveMap(true).catch((err) => setMapStatus(err.message || "Karte nicht ladbar", true));
  });
  document.getElementById("refresh-map")?.addEventListener("click", () => {
    loadLiveMap(false).catch((err) => setMapStatus(err.message || "Karte nicht ladbar", true));
  });
  document.getElementById("map-follow-stop")?.addEventListener("click", () => {
    stopFollowDriver();
  });

  document.getElementById("platform-settings-form")?.addEventListener("submit", async (e) => {
    e.preventDefault();
    const body = {};
    for (const key of [
      "platformCompanyName",
      "platformOwner",
      "platformEmail",
      "platformPhone",
      "platformStreet",
      "platformCity",
      "platformVatId",
    ]) {
      body[key] = document.getElementById(`set-${key}`)?.value || "";
    }
    setSettingsStatus("Speichere…");
    try {
      const res = await apiFetch("/api/config", {
        method: "PATCH",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify(body),
      });
      const data = await res.json().catch(() => ({}));
      if (!res.ok) throw new Error(data.error || "Speichern fehlgeschlagen");
      setSettingsStatus("Gespeichert.");
    } catch (err) {
      setSettingsStatus(err.message || "Speichern fehlgeschlagen", true);
    }
  });

  document.getElementById("refresh-inquiries").addEventListener("click", async () => {
    try {
      await loadInquiries();
    } catch (err) {
      alert(err.message || "Anfragen konnten nicht geladen werden.");
    }
  });

  document.getElementById("refresh-all").addEventListener("click", async () => {
    try {
      await withRefreshBusy(refreshAll);
    } catch (err) {
      alert(err.message || "Aktualisieren fehlgeschlagen.");
    }
  });

  document.getElementById("export-tenants-csv")?.addEventListener("click", async () => {
    try {
      const res = await apiFetch("/api/fleet/operators.csv");
      if (!res.ok) {
        const data = await res.json().catch(() => ({}));
        throw new Error(data.error || "CSV-Export fehlgeschlagen");
      }
      const blob = await res.blob();
      const url = URL.createObjectURL(blob);
      const a = document.createElement("a");
      a.href = url;
      a.download = `luckys-mandanten-${new Date().toISOString().slice(0, 10)}.csv`;
      a.click();
      URL.revokeObjectURL(url);
    } catch (err) {
      alert(err.message || "CSV-Export fehlgeschlagen");
    }
  });

  document.getElementById("create-tenant-form").addEventListener("submit", async (e) => {
    e.preventDefault();
    const errEl = document.getElementById("create-error");
    errEl.classList.add("hidden");
    const payload = Object.fromEntries(new FormData(e.target).entries());
    payload.status = "active";
    try {
      const res = await apiFetch("/api/fleet/operators", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify(payload),
      });
      const data = await res.json().catch(() => ({}));
      if (!res.ok) throw new Error(data.error || "Anlegen fehlgeschlagen");
      e.target.reset();
      await loadTenants();
      showPanel("tenants");
      if (data.links) {
        try {
          await copyText(
            [
              `Leitstelle: ${data.links.dispatch}`,
              `Einstellungen: ${data.links.settings}`,
              `Buchung: ${data.links.book}`,
              `QR: ${data.links.qr}`,
              `Fahrer-Registrierung: ${data.links.driverOnboard || ""}`,
            ].join("\n")
          );
          alert(`Mandant „${data.operator.companyName}“ angelegt. Links in Zwischenablage kopiert.`);
        } catch {
          alert(`Mandant „${data.operator.companyName}“ angelegt. Links konnten nicht kopiert werden — bitte auf der Karte nutzen.`);
        }
      }
    } catch (err) {
      errEl.textContent = err.message;
      errEl.classList.remove("hidden");
    }
  });

  async function tryRestoreSession() {
    if (!getSession() && !getPin()) {
      showLogin();
      return;
    }
    try {
      const res = await apiFetch("/api/fleet/operators");
      if (!res.ok) throw new Error("session");
      // MFA ist optional — nicht mehr bei jedem Laden erzwingen.
      await enterAppAfterAuth();
      const statusRes = await apiFetch("/api/auth/mfa/status");
      const status = statusRes.ok ? await statusRes.json() : { enabled: false };
      const mfaBtn = document.getElementById("admin-setup-mfa");
      if (mfaBtn) mfaBtn.classList.toggle("hidden", Boolean(status.enabled));
    } catch (err) {
      console.error(err);
      clearAuth();
      showLogin();
    }
  }

  tryRestoreSession();
})();
