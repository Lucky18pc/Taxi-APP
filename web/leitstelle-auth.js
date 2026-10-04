/**
 * PIN-Schutz für Leitstelle & Einstellungen (ADMIN_PIN oder Betriebs-dispatchPin).
 * Multi-Mandant: ?o=mannheim oder ?operator=mannheim in der URL.
 *
 * API-Basis: bei file://, Surge, Netlify o. Ä. → Live-Backend auf Render,
 * damit Login nicht mit „Load failed“ scheitert.
 */
(function () {
  const STORAGE_KEY = "taxiapp_admin_pin";
  const OPERATOR_KEY = "taxiapp_operator_slug";
  const LIVE_API = "https://taxiapp-api.onrender.com";

  function resolveApiBase() {
    const origin = String(window.location.origin || "");
    const protocol = String(window.location.protocol || "");
    if (protocol === "file:" || !origin || origin === "null") {
      return LIVE_API;
    }
    if (origin.includes("localhost") || origin.includes("127.0.0.1")) {
      return origin;
    }
    // Gleiche Origin, wenn die Seite vom Render-Backend kommt
    if (origin.includes("taxiapp-api.onrender.com")) {
      return origin;
    }
    // Statisches Hosting (Surge/Netlify/…) → Live-API
    return LIVE_API;
  }

  const API_BASE = resolveApiBase();

  function apiUrl(path) {
    if (/^https?:\/\//i.test(path)) return path;
    const normalized = path.startsWith("/") ? path : `/${path}`;
    return `${API_BASE}${normalized}`;
  }

  function operatorSlugFromPage() {
    const params = new URLSearchParams(window.location.search);
    return String(params.get("o") || params.get("operator") || "").trim().toLowerCase();
  }

  function getOperatorSlug() {
    return sessionStorage.getItem(OPERATOR_KEY) || operatorSlugFromPage() || "";
  }

  function setOperatorSlug(slug) {
    const normalized = String(slug || "").trim().toLowerCase();
    if (normalized) {
      sessionStorage.setItem(OPERATOR_KEY, normalized);
    } else {
      sessionStorage.removeItem(OPERATOR_KEY);
    }
  }

  function getPin() {
    return sessionStorage.getItem(STORAGE_KEY) || "";
  }

  function setPin(pin) {
    sessionStorage.setItem(STORAGE_KEY, pin);
  }

  function clearPin() {
    sessionStorage.removeItem(STORAGE_KEY);
  }

  function withOperatorQuery(url) {
    const slug = getOperatorSlug();
    if (!slug) return url;
    const separator = url.includes("?") ? "&" : "?";
    return `${url}${separator}operator=${encodeURIComponent(slug)}`;
  }

  function authHeaders() {
    const pin = getPin();
    const headers = {};
    if (pin) headers.Authorization = `Bearer ${pin}`;
    const slug = getOperatorSlug();
    if (slug) headers["X-Operator-Slug"] = slug;
    return headers;
  }

  function networkErrorMessage(err) {
    const msg = String(err && err.message ? err.message : err || "");
    if (/load failed|failed to fetch|networkerror|network request failed/i.test(msg)) {
      return (
        "Server nicht erreichbar. Bitte öffnen: " +
        LIVE_API +
        "/dispatch.html — oder Internet prüfen."
      );
    }
    return msg || "Anmeldung fehlgeschlagen";
  }

  async function authRequired() {
    try {
      const res = await fetch(withOperatorQuery(apiUrl("/api/auth/required")));
      if (!res.ok) {
        // Fail closed: bei Fehler Login verlangen (nicht offen lassen)
        return true;
      }
      const data = await res.json();
      return Boolean(data.required);
    } catch {
      return true;
    }
  }

  async function verifyPin(pin) {
    const slug = getOperatorSlug();
    let res;
    try {
      res = await fetch(apiUrl("/api/auth/verify"), {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ pin, operator: slug || undefined }),
      });
    } catch (err) {
      throw new Error(networkErrorMessage(err));
    }
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
        <p id="leitstelle-login-hint">Bitte PIN eingeben.</p>
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
        background: #fff8cc; border-radius: 16px; padding: 1.5rem;
        max-width: 360px; width: 100%;
        border: 2.5px solid #0c1c34; box-shadow: 0 4px 0 #0c1c34;
      }
      .leitstelle-login-card h2 { margin: 0 0 0.5rem; color: #0c1c34; }
      .leitstelle-login-card p { margin: 0 0 1rem; font-size: 0.9rem; color: #0c1c34; font-weight: 600; }
      .leitstelle-login-card input {
        width: 100%; padding: 0.65rem; margin-bottom: 0.75rem;
        border: 2px solid #0c1c34; border-radius: 10px; font: inherit; background: #fffdf0;
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
        errEl.textContent = networkErrorMessage(err);
        errEl.hidden = false;
      }
    });
  }

  function showLogin() {
    ensureLoginOverlay();
    const slug = getOperatorSlug();
    const hint = document.getElementById("leitstelle-login-hint");
    if (hint) {
      const offHost =
        window.location.protocol === "file:" ||
        !String(window.location.origin || "").includes("taxiapp-api.onrender.com");
      if (slug) {
        hint.textContent = `PIN für Betrieb „${slug}“ eingeben.`;
      } else if (offHost) {
        hint.textContent =
          "Bitte ADMIN_PIN (Render) eingeben. Am zuverlässigsten über die Live-URL öffnen.";
      } else {
        hint.textContent = "Bitte Leitstellen-PIN Ihres Betriebs eingeben.";
      }
    }
    document.getElementById("leitstelle-login").classList.add("visible");
  }

  async function init() {
    const slug = operatorSlugFromPage();
    if (slug) setOperatorSlug(slug);

    ensureLoginOverlay();
    let required = true;
    try {
      required = await authRequired();
    } catch {
      required = true;
    }
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
    let res;
    try {
      res = await fetch(withOperatorQuery(apiUrl(url)), { ...options, headers });
    } catch (err) {
      throw new Error(networkErrorMessage(err));
    }
    if (res.status === 401) {
      clearPin();
      showLogin();
      throw new Error("Anmeldung erforderlich. Bitte PIN erneut eingeben.");
    }
    return res;
  }

  function operatorLink(path) {
    const slug = getOperatorSlug();
    if (!slug) return path;
    const separator = path.includes("?") ? "&" : "?";
    return `${path}${separator}o=${encodeURIComponent(slug)}`;
  }

  window.LeitstelleAuth = {
    init,
    apiFetch,
    authHeaders,
    showLogin,
    clearPin,
    getOperatorSlug,
    operatorLink,
    withOperatorQuery,
    apiBase: API_BASE,
  };
})();
