(function () {
  const STORAGE_KEY = "taxiapp_platform_admin_pin";

  function getPin() {
    return sessionStorage.getItem(STORAGE_KEY) || "";
  }

  function setPin(pin) {
    sessionStorage.setItem(STORAGE_KEY, pin);
  }

  function clearPin() {
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
        </td>
        <td>${statusBadge(op.status)}<br><small>${op.hasDispatchPin ? "PIN gesetzt" : "kein PIN"}</small></td>
        <td>${escapeHtml(op.planId || "starter")}<br><small>${op.maxDrivers == null ? "∞ Fahrer" : op.maxDrivers + " Fahrer"}</small></td>
        <td>
          <ul class="link-list">
            <li><a href="${links.dispatch || "#"}" target="_blank">Leitstelle</a></li>
            <li><a href="${links.settings || "#"}" target="_blank">Einstellungen</a></li>
            <li><a href="${links.book || "#"}" target="_blank">Buchung</a></li>
            <li><a href="${links.qr || "#"}" target="_blank">QR</a></li>
          </ul>
          <button type="button" class="btn-sm btn-secondary copy-links" data-slug="${escapeHtml(op.slug)}">Links kopieren</button>
        </td>
        <td>
          ${op.status !== "active" ? `<button type="button" class="btn-sm btn-success activate" data-slug="${escapeHtml(op.slug)}">Aktivieren</button> ` : ""}
          ${op.status === "active" ? `<button type="button" class="btn-sm btn-danger suspend" data-slug="${escapeHtml(op.slug)}">Sperren</button>` : ""}
        </td>
      `;
      tr.querySelector(".copy-links")?.addEventListener("click", () => {
        const text = [
          `Leitstelle: ${links.dispatch}`,
          `Einstellungen: ${links.settings}`,
          `Buchung: ${links.book}`,
          `QR: ${links.qr}`,
        ].join("\n");
        copyText(text);
      });
      tr.querySelector(".activate")?.addEventListener("click", () => patchTenant(op.slug, { status: "active" }));
      tr.querySelector(".suspend")?.addEventListener("click", () => patchTenant(op.slug, { status: "suspended" }));
      tbody.appendChild(tr);
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
    setPin(pin);
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
          return Promise.all([loadTenants(), loadInquiries()]);
        }
        clearPin();
        showLogin();
      })
      .catch(() => showLogin());
  } else {
    showLogin();
  }
})();
