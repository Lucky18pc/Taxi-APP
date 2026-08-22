/**
 * Runtime-Branding pro Mandant (?o=slug) für Web-Seiten.
 */
(function () {
  function operatorSlugFromPage() {
    const params = new URLSearchParams(window.location.search);
    return String(params.get("o") || params.get("operator") || "").trim().toLowerCase();
  }

  function applyTenantBranding(cfg, options) {
    if (!cfg) return;
    const opts = options || {};
    const primary = cfg.brandPrimaryColor || "#1c304f";
    const accent = cfg.brandAccentColor || "#f5c400";
    const companyName = cfg.companyName || "Taxi";

    document.documentElement.style.setProperty("--tenant-primary", primary);
    document.documentElement.style.setProperty("--tenant-accent", accent);

    if (opts.titleId) {
      const titleEl = document.getElementById(opts.titleId);
      if (titleEl) titleEl.textContent = companyName;
    }
    if (opts.subtitleId && opts.subtitleText) {
      const subEl = document.getElementById(opts.subtitleId);
      if (subEl) subEl.textContent = opts.subtitleText.replace("{company}", companyName);
    }
    if (companyName && opts.documentTitle !== false) {
      document.title = (opts.titlePrefix || "") + companyName + (opts.titleSuffix || "");
    }

    if (opts.heroSelector) {
      const hero = document.querySelector(opts.heroSelector);
      if (hero) {
        hero.style.background = accent;
        hero.style.color = primary;
      }
    }
    if (opts.primaryButtonSelector) {
      document.querySelectorAll(opts.primaryButtonSelector).forEach((btn) => {
        btn.style.background = primary;
        btn.style.color = accent;
      });
    }

    if (opts.logoId) {
      const logoEl = document.getElementById(opts.logoId);
      if (logoEl) {
        if (cfg.logoUrl) {
          logoEl.innerHTML = `<img src="${cfg.logoUrl}" alt="${companyName}" style="width:56px;height:56px;border-radius:12px;object-fit:cover">`;
          logoEl.style.display = "block";
        } else {
          logoEl.textContent = companyName.slice(0, 2).toUpperCase();
          logoEl.style.background = primary;
          logoEl.style.color = accent;
          logoEl.style.display = "flex";
        }
      }
    }
  }

  async function loadTenantConfig(slug) {
    const configUrl = slug
      ? `/api/config?operator=${encodeURIComponent(slug)}`
      : "/api/config";
    const res = await fetch(configUrl);
    if (!res.ok) return null;
    return res.json();
  }

  window.TenantBranding = {
    operatorSlugFromPage,
    applyTenantBranding,
    loadTenantConfig,
  };
})();
