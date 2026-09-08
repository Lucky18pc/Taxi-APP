(function () {
  const STORAGE_KEY = "taxiapp_platform_admin_pin";

  const PANEL_COPY = {
    tenants: {
      title: "Mandanten",
      sub: "Betriebe prüfen, Nachweise öffnen, freischalten und Links kopieren.",
    },
    inquiries: {
      title: "Anfragen",
      sub: "Tarif-Anfragen von der Startseite — antworten oder als Mandant übernehmen.",
    },
    create: {
      title: "Neu anlegen",
      sub: "Betrieb manuell anlegen und sofort aktivieren.",
    },
    analytics: {
      title: "Analytics",
      sub: "Besucherstatistik über Google Analytics.",
    },
  };

  function getPin() {
    return localStorage.getItem(STORAGE_KEY) || sessionStorage.getItem(STORAGE_KEY) || "";
  }

  function setPin(pin, remember) {
    clearPin();
    if (remember) localStorage.setItem(STORAGE_KEY, pin);
    else sessionStorage.setItem(STORAGE_KEY, pin);
  }

  function clearPin() {
    localStorage.removeItem(STORAGE_KEY);
    sessionStorage.removeItem(STORAGE_KEY);
  }

  function authHeaders() {
    const pin = getPin();
    return pin ? { Authorization: `Bearer ${pin}` } : {};
  }

  async function apiFetch(url, options = {}) {
    const res = await fetch(url, {
      ...options,
      headers: { ...(options.headers || {}), ...authHeaders() },
    });
    if (res.status === 401) {
      clearPin();
      showLogin();
      throw new Error("PIN ungültig oder ADMIN_PIN nicht gesetzt.");
    }
    return res;
  }

  function showLogin() {
    document.getElementById("admin-login").classList.remove("hidden");
    document.getElementById("admin-app").classList.add("hidden");
  }

  function showApp() {
    document.getElementById("admin-login").classList.add("hidden");
    document.getElementById("admin-app").classList.remove("hidden");
  }

  function showPanel(id) {
    document.querySelectorAll(".panel").forEach((el) => el.classList.remove("active"));
    document.querySelectorAll(".nav-btn").forEach((el) => el.classList.remove("active"));
    document.getElementById(`panel-${id}`)?.classList.add("active");
    document.querySelector(`.nav-btn[data-panel="${id}"]`)?.classList.add("active");
    const copy = PANEL_COPY[id] || PANEL_COPY.tenants;
    document.getElementById("panel-title").textContent = copy.title;
    document.getElementById("panel-sub").textContent = copy.sub;
  }

  function statusBadge(status) {
    const cls =
      status === "active" ? "badge-active" : status === "suspended" ? "badge-suspended" : "badge-pending";
    return `<span class="badge ${cls}">${status}</span>`;
  }

  function copyText(text) {
    navigator.clipboard?.writeText(text).catch(() => {});
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
    if (planId === "starter") return "Starter";
    if (planId === "business") return "Business";
    return planId || "Allgemein";
  }

  function escapeHtml(value) {
    return String(value || "")
      .replace(/&/g, "&amp;")
      .replace(/</g, "&lt;")
      .replace(/>/g, "&gt;")
      .replace(/"/g, "&quot;");
  }

  function updateInquiryStats(items) {
    const weekAgo = Date.now() - 7 * 24 * 60 * 60 * 1000;
    document.getElementById("stat-total").textContent = String(items.length);
    document.getElementById("stat-starter").textContent = String(
      items.filter((i) => i.planId === "starter").length
    );
    document.getElementById("stat-business").textContent = String(
      items.filter((i) => i.planId === "business").length
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
    if (inquiry.planId === "starter" || inquiry.planId === "business") {
      form.planId.value = inquiry.planId;
    }
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
      const mailSubject = encodeURIComponent(`Luckys Taxi App — Tarif ${planLabel(inquiry.planId)}`);
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
        <div class="link-row">
          <a href="${links.dispatch || "#"}" target="_blank" rel="noopener">Leitstelle</a>
          <a href="${links.settings || "#"}" target="_blank" rel="noopener">Settings</a>
          <a href="${links.book || "#"}" target="_blank" rel="noopener">Buchung</a>
          <a href="${links.qr || "#"}" target="_blank" rel="noopener">QR</a>
          <a href="${links.driverOnboard || "#"}" target="_blank" rel="noopener">Fahrer-Reg.</a>
        </div>
        <div class="actions">
          <button type="button" class="btn btn-ghost btn-sm copy-links">Links kopieren</button>
          ${
            op.status !== "active"
              ? `<button type="button" class="btn btn-ok btn-sm activate">Aktivieren</button>`
              : `<button type="button" class="btn btn-bad btn-sm suspend">Sperren</button>`
          }
          <button type="button" class="btn btn-navy btn-sm connect-onboard">Stripe Connect</button>
        </div>
      `;

      card.querySelector(".copy-links")?.addEventListener("click", () => {
        copyText(
          [
            `Leitstelle: ${links.dispatch}`,
            `Einstellungen: ${links.settings}`,
            `Buchung: ${links.book}`,
            `QR: ${links.qr}`,
            `Fahrer-Registrierung: ${links.driverOnboard || ""}`,
          ].join("\n")
        );
      });
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

  async function refreshAll() {
    await Promise.all([loadTenants(), loadInquiries()]);
  }

  document.querySelectorAll(".nav-btn").forEach((btn) => {
    btn.addEventListener("click", () => showPanel(btn.getAttribute("data-panel")));
  });

  document.getElementById("admin-login-form").addEventListener("submit", async (e) => {
    e.preventDefault();
    const errEl = document.getElementById("admin-login-error");
    errEl.classList.add("hidden");
    const pin = document.getElementById("admin-pin").value.trim();
    const remember = document.getElementById("admin-remember")?.checked !== false;
    setPin(pin, remember);
    try {
      const res = await apiFetch("/api/fleet/operators");
      if (!res.ok) throw new Error("Zugriff verweigert");
      showApp();
      showPanel("tenants");
      await refreshAll();
    } catch (err) {
      clearPin();
      errEl.textContent = err.message;
      errEl.classList.remove("hidden");
    }
  });

  document.getElementById("admin-logout").addEventListener("click", () => {
    clearPin();
    showLogin();
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
      await refreshAll();
    } catch (err) {
      alert(err.message || "Aktualisieren fehlgeschlagen.");
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
        copyText(
          [
            `Leitstelle: ${data.links.dispatch}`,
            `Einstellungen: ${data.links.settings}`,
            `Buchung: ${data.links.book}`,
            `QR: ${data.links.qr}`,
            `Fahrer-Registrierung: ${data.links.driverOnboard || ""}`,
          ].join("\n")
        );
        alert(`Mandant „${data.operator.companyName}“ angelegt. Links in Zwischenablage kopiert.`);
      }
    } catch (err) {
      errEl.textContent = err.message;
      errEl.classList.remove("hidden");
    }
  });

  if (getPin()) {
    apiFetch("/api/fleet/operators")
      .then((res) => {
        if (res.ok) {
          showApp();
          showPanel("tenants");
          return refreshAll().then(() => {
            const params = new URLSearchParams(window.location.search);
            const connect = params.get("connect");
            const slug = params.get("o");
            if (connect === "return" && slug) {
              alert(
                `Stripe Connect für „${slug}“ — Onboarding abgeschlossen oder fortgesetzt. Status prüfen.`
              );
              history.replaceState({}, "", "admin.html");
            } else if (connect === "refresh" && slug) {
              alert(`Connect-Link abgelaufen — bitte für „${slug}“ erneut „Stripe Connect“ klicken.`);
              history.replaceState({}, "", "admin.html");
            }
          });
        }
        clearPin();
        showLogin();
      })
      .catch(() => showLogin());
  } else {
    showLogin();
  }
})();
