(function () {
  const STORAGE_KEY = "taxiapp_platform_admin_pin";

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

  function statusBadge(status) {
    const cls = status === "active" ? "badge-active" : status === "suspended" ? "badge-suspended" : "badge-pending";
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

  function updateInquiryStats(items) {
    const weekAgo = Date.now() - 7 * 24 * 60 * 60 * 1000;
    document.getElementById("stat-total").textContent = String(items.length);
    document.getElementById("stat-starter").textContent = String(items.filter((i) => i.planId === "starter").length);
    document.getElementById("stat-business").textContent = String(items.filter((i) => i.planId === "business").length);
    document.getElementById("stat-week").textContent = String(
      items.filter((i) => new Date(i.createdAt).getTime() >= weekAgo).length
    );
  }

  function prefillTenantForm(inquiry) {
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
    form.scrollIntoView({ behavior: "smooth", block: "start" });
  }

  async function loadInquiries() {
    const res = await apiFetch("/api/contact/inquiries");
    const data = await res.json();
    const items = data.inquiries || [];
    const tbody = document.getElementById("inquiries-body");
    const emptyEl = document.getElementById("inquiries-empty");
    tbody.innerHTML = "";
    updateInquiryStats(items);

    if (!items.length) {
      emptyEl.classList.remove("hidden");
      return;
    }

    emptyEl.classList.add("hidden");
    for (const inquiry of items) {
      const tr = document.createElement("tr");
      const mailSubject = encodeURIComponent(`Luckys Taxi App — Tarif ${planLabel(inquiry.planId)}`);
      tr.innerHTML = `
        <td>${escapeHtml(formatDate(inquiry.createdAt))}</td>
        <td><strong>${escapeHtml(inquiry.companyName)}</strong></td>
        <td><a href="mailto:${escapeHtml(inquiry.email)}">${escapeHtml(inquiry.email)}</a></td>
        <td>${escapeHtml(planLabel(inquiry.planId))}</td>
        <td class="inquiry-message">${escapeHtml(inquiry.message || "—")}</td>
        <td>
          <button type="button" class="btn-sm btn-secondary reply-inquiry">Antworten</button>
          <button type="button" class="btn-sm btn-primary use-inquiry">Als Mandant</button>
        </td>
      `;
      tr.querySelector(".reply-inquiry")?.addEventListener("click", () => {
        window.location.href = `mailto:${inquiry.email}?subject=${mailSubject}`;
      });
      tr.querySelector(".use-inquiry")?.addEventListener("click", () => prefillTenantForm(inquiry));
      tbody.appendChild(tr);
    }
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

  function complianceCell(op) {
    const docs = op.documents || {};
    const gaps = op.complianceGaps || [];
    const concUrl = `/api/fleet/operators/${encodeURIComponent(op.slug)}/documents/concessionDocument`;
    const ownerUrl = `/api/fleet/operators/${encodeURIComponent(op.slug)}/documents/ownerPScheinDocument`;
    const docButtons = [];
    if (docs.concessionDocument?.present) {
      docButtons.push(
        `<button type="button" class="btn-sm btn-secondary open-doc" data-url="${escapeHtml(concUrl)}">Konzession</button>`
      );
    }
    if (docs.ownerPScheinDocument?.present) {
      docButtons.push(
        `<button type="button" class="btn-sm btn-secondary open-doc" data-url="${escapeHtml(ownerUrl)}">P-Schein Inhaber</button>`
      );
    }
    return `
      <div class="compliance-box">
        <div><strong>Konz.-Nr.:</strong> ${escapeHtml(op.concessionNumber || "—")}</div>
        <div><strong>Behörde:</strong> ${escapeHtml(op.concessionAuthority || "—")}</div>
        <div><strong>gültig bis:</strong> ${escapeHtml(op.concessionValidUntil || "—")}</div>
        ${op.ownerHasPSchein ? `<div><strong>Inhaber-P-Schein:</strong> ${escapeHtml(op.ownerPScheinNumber || "—")}</div>` : ""}
        <div class="doc-row">${docButtons.join(" ") || "<em>keine Uploads</em>"}</div>
        ${
          gaps.length
            ? `<div class="warn">Fehlt: ${escapeHtml(gaps.join(", "))}</div>`
            : `<div class="ok">Nachweise vollständig</div>`
        }
        <button type="button" class="btn-sm btn-secondary show-drivers" data-slug="${escapeHtml(op.slug)}" style="margin-top:0.4rem">Fahrer-Nachweise</button>
        <div class="admin-detail-panel hidden" data-drivers-panel="${escapeHtml(op.slug)}"></div>
      </div>
    `;
  }

  async function loadTenants() {
    const res = await apiFetch("/api/fleet/operators");
    const data = await res.json();
    const tbody = document.getElementById("tenants-body");
    tbody.innerHTML = "";

    for (const op of data.operators || []) {
      const tr = document.createElement("tr");
      const links = op.links || {};
      tr.innerHTML = `
        <td>
          <strong>${escapeHtml(op.companyName)}</strong><br>
          <code>${escapeHtml(op.slug)}</code>
          ${op.billingEmail ? `<br><small>${escapeHtml(op.billingEmail)}</small>` : ""}
          <br><small>${op.stripeConnectAccountId ? "Connect: " + escapeHtml(op.stripeConnectAccountId) : "Connect: nicht verbunden"}</small>
        </td>
        <td>${statusBadge(op.status)}<br><small>${op.hasDispatchPin ? "PIN gesetzt" : "kein PIN"}</small></td>
        <td>${escapeHtml(op.planId || "starter")}<br><small>${op.maxDrivers == null ? "∞ Fahrer" : op.maxDrivers + " Fahrer"}</small></td>
        <td>${complianceCell(op)}</td>
        <td>
          <ul class="link-list">
            <li><a href="${links.dispatch || "#"}" target="_blank">Leitstelle</a></li>
            <li><a href="${links.settings || "#"}" target="_blank">Einstellungen</a></li>
            <li><a href="${links.book || "#"}" target="_blank">Buchung</a></li>
            <li><a href="${links.qr || "#"}" target="_blank">QR</a></li>
            <li><a href="${links.driverOnboard || "#"}" target="_blank">Fahrer-Registrierung</a></li>
          </ul>
          <button type="button" class="btn-sm btn-secondary copy-links" data-slug="${escapeHtml(op.slug)}">Links kopieren</button>
        </td>
        <td>
          ${op.status !== "active" ? `<button type="button" class="btn-sm btn-success activate" data-slug="${escapeHtml(op.slug)}">Aktivieren</button> ` : ""}
          ${op.status === "active" ? `<button type="button" class="btn-sm btn-danger suspend" data-slug="${escapeHtml(op.slug)}">Sperren</button>` : ""}
          <button type="button" class="btn-sm btn-primary connect-onboard" data-slug="${escapeHtml(op.slug)}">Stripe Connect</button>
        </td>
      `;
      tr.querySelector(".copy-links")?.addEventListener("click", () => {
        const text = [
          `Leitstelle: ${links.dispatch}`,
          `Einstellungen: ${links.settings}`,
          `Buchung: ${links.book}`,
          `QR: ${links.qr}`,
          `Fahrer-Registrierung: ${links.driverOnboard || ""}`,
        ].join("\n");
        copyText(text);
      });
      tr.querySelector(".activate")?.addEventListener("click", () => {
        if (op.complianceGaps?.length) {
          const ok = confirm(
            `Nachweise unvollständig (${op.complianceGaps.join(", ")}). Trotzdem aktivieren?`
          );
          if (!ok) return;
        }
        patchTenant(op.slug, { status: "active" });
      });
      tr.querySelector(".suspend")?.addEventListener("click", () => patchTenant(op.slug, { status: "suspended" }));
      tr.querySelector(".connect-onboard")?.addEventListener("click", () => startConnectOnboard(op.slug));
      tr.querySelectorAll(".open-doc").forEach((btn) => {
        btn.addEventListener("click", () => {
          openAuthDocument(btn.getAttribute("data-url")).catch((err) => alert(err.message));
        });
      });
      tr.querySelector(".show-drivers")?.addEventListener("click", async () => {
        const panel = tr.querySelector(`[data-drivers-panel="${op.slug}"]`);
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
            panel.innerHTML = `<h4>Fahrer (${list.length})</h4><ul>${list
              .map((d) => {
                const docs = d.documents || {};
                const buttons = [];
                if (docs.photo?.present) {
                  buttons.push(
                    `<button type="button" class="btn-sm btn-secondary open-doc" data-url="/api/drivers/${encodeURIComponent(d.driverId)}/documents/photo">Foto</button>`
                  );
                }
                if (docs.pScheinDocument?.present) {
                  buttons.push(
                    `<button type="button" class="btn-sm btn-secondary open-doc" data-url="/api/drivers/${encodeURIComponent(d.driverId)}/documents/pScheinDocument">P-Schein</button>`
                  );
                }
                if (docs.licenseDocument?.present) {
                  buttons.push(
                    `<button type="button" class="btn-sm btn-secondary open-doc" data-url="/api/drivers/${encodeURIComponent(d.driverId)}/documents/licenseDocument">Führerschein</button>`
                  );
                }
                const pending = d.status === "pending" ? " · <strong style=\"color:#92400e\">pending</strong>" : "";
                return `<li><strong>${escapeHtml(d.name)}</strong>${pending} · Taxi ${escapeHtml(d.taxiNumber || "—")} · ${escapeHtml(d.vehicle || "—")}<br>P-Schein: ${escapeHtml(d.pScheinNumber || "—")} bis ${escapeHtml(d.pScheinValidUntil || "—")}<br>${buttons.join(" ") || "<em>keine Uploads</em>"}</li>`;
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
      tbody.appendChild(tr);
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
    if (data.url) {
      window.location.href = data.url;
    }
  }

  function escapeHtml(value) {
    return String(value || "")
      .replace(/&/g, "&amp;")
      .replace(/</g, "&lt;")
      .replace(/>/g, "&gt;")
      .replace(/"/g, "&quot;");
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
      await Promise.all([loadTenants(), loadInquiries()]);
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
      if (data.links) {
        copyText(
          [
            `Leitstelle: ${data.links.dispatch}`,
            `Einstellungen: ${data.links.settings}`,
            `Buchung: ${data.links.book}`,
            `QR: ${data.links.qr}`,
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
          return Promise.all([loadTenants(), loadInquiries()]).then(() => {
            const params = new URLSearchParams(window.location.search);
            const connect = params.get("connect");
            const slug = params.get("o");
            if (connect === "return" && slug) {
              alert(
                `Stripe Connect für „${slug}“ — Onboarding abgeschlossen oder fortgesetzt. Status prüfen (Connect-ID in der Liste).`
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
