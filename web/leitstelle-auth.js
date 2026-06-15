/**
 * Einfacher PIN-Schutz für Leitstelle & Einstellungen (ADMIN_PIN auf dem Server).
 */
(function () {
  const STORAGE_KEY = "taxiapp_admin_pin";

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
    if (!pin) return {};
    return { Authorization: `Bearer ${pin}` };
  }

  async function authRequired() {
    try {
      const res = await fetch("/api/auth/required");
      if (!res.ok) return false;
      const data = await res.json();
      return Boolean(data.required);
    } catch {
      return false;
    }
  }

  async function verifyPin(pin) {
    const res = await fetch("/api/auth/verify", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ pin }),
    });
    if (!res.ok) {
      const err = await res.json().catch(() => ({}));
      throw new Error(err.error || "PIN ungültig");
    }
    setPin(pin);
    return true;
  }

  function ensureLoginOverlay() {
    if (document.getElementById("leitstelle-login")) return;

    const overlay = document.createElement("div");
    overlay.id = "leitstelle-login";
    overlay.innerHTML = `
      <div class="leitstelle-login-card">
        <h2>Leitstellen-Zugang</h2>
        <p>Bitte PIN eingeben (vom Betreiber / Render ADMIN_PIN).</p>
        <form id="leitstelle-login-form">
          <input type="password" id="leitstelle-pin" inputmode="numeric" autocomplete="current-password" placeholder="PIN" required>
          <button type="submit" class="btn-primary">Anmelden</button>
        </form>
        <p id="leitstelle-login-error" class="login-error" hidden></p>
      </div>
    `;
    document.body.appendChild(overlay);

    const style = document.createElement("style");
    style.textContent = `
      #leitstelle-login {
        position: fixed; inset: 0; z-index: 9999;
        background: rgba(15, 23, 42, 0.72);
        display: none; align-items: center; justify-content: center;
        padding: 1rem;
      }
      #leitstelle-login.visible { display: flex; }
      .leitstelle-login-card {
        background: #fff; border-radius: 16px; padding: 1.5rem;
        max-width: 360px; width: 100%; box-shadow: 0 12px 40px rgba(0,0,0,0.2);
      }
      .leitstelle-login-card h2 { margin: 0 0 0.5rem; }
      .leitstelle-login-card p { margin: 0 0 1rem; font-size: 0.9rem; color: #4b5563; }
      .leitstelle-login-card input {
        width: 100%; padding: 0.65rem; margin-bottom: 0.75rem;
        border: 1px solid #d1d5db; border-radius: 10px; font: inherit;
      }
      .login-error { color: #991b1b; font-size: 0.85rem; font-weight: 600; }
    `;
    document.head.appendChild(style);

    document.getElementById("leitstelle-login-form").addEventListener("submit", async (e) => {
      e.preventDefault();
      const errEl = document.getElementById("leitstelle-login-error");
      const pin = document.getElementById("leitstelle-pin").value.trim();
      errEl.hidden = true;
      try {
        await verifyPin(pin);
        overlay.classList.remove("visible");
        document.dispatchEvent(new CustomEvent("leitstelle-auth-ok"));
      } catch (err) {
        errEl.textContent = err.message;
        errEl.hidden = false;
      }
    });
  }

  function showLogin() {
    ensureLoginOverlay();
    document.getElementById("leitstelle-login").classList.add("visible");
  }

  async function init() {
    ensureLoginOverlay();
    const required = await authRequired();
    if (!required) return true;
    if (getPin()) {
      try {
        await verifyPin(getPin());
        return true;
      } catch {
        clearPin();
      }
    }
    showLogin();
    return new Promise((resolve) => {
      document.addEventListener(
        "leitstelle-auth-ok",
        () => resolve(true),
        { once: true }
      );
    });
  }

  async function apiFetch(url, options = {}) {
    const headers = {
      ...(options.headers || {}),
      ...authHeaders(),
    };
    const res = await fetch(url, { ...options, headers });
    if (res.status === 401) {
      clearPin();
      showLogin();
      throw new Error("Anmeldung erforderlich — bitte PIN erneut eingeben.");
    }
    return res;
  }

  window.LeitstelleAuth = {
    init,
    apiFetch,
    authHeaders,
    showLogin,
    clearPin,
  };
})();
