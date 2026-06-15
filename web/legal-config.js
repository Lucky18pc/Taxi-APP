/**
 * Firmendaten für Impressum, Datenschutz, AGB usw. aus /api/config.
 */
(function () {
  function setText(id, value, fallback) {
    const el = document.getElementById(id);
    if (!el) return;
    const text = (value || "").trim() || fallback;
    if (el.tagName === "A") {
      el.textContent = text;
      if (el.href.startsWith("mailto:")) el.href = `mailto:${text}`;
      else if (el.href.startsWith("tel:")) el.href = `tel:${String(value || "").replace(/\s/g, "")}`;
    } else {
      el.textContent = text;
    }
    el.classList.toggle("legal-hint", !((value || "").trim()));
  }

  function applyContact(cfg) {
    setText("legal-company", cfg.companyName, "TaxiApp Leitstelle");
    setText("legal-street", cfg.legalStreet, "Straße — in Einstellungen eintragen");
    setText("legal-city", cfg.legalCity, "PLZ Ort — in Einstellungen eintragen");
    setText("legal-owner", cfg.legalOwner, "Inhaber — in Einstellungen eintragen");
    setText("legal-vat", cfg.vatId, "USt-IdNr. — in Einstellungen eintragen");

    const email = (cfg.legalEmail || "partner@taxiapp.de").trim();
    const emailEl = document.getElementById("legal-email");
    if (emailEl) {
      emailEl.textContent = email;
      emailEl.href = `mailto:${email}`;
    }

    const phoneDisplay = cfg.centralPhoneDisplay || cfg.centralPhone || "—";
    const phoneEl = document.getElementById("legal-phone");
    if (phoneEl) {
      phoneEl.textContent = phoneDisplay;
      phoneEl.href = `tel:${String(cfg.centralPhone || "").replace(/\s/g, "")}`;
    }

    const responsible = [cfg.legalOwner, cfg.legalStreet, cfg.legalCity]
      .filter((x) => (x || "").trim())
      .join(", ");
    setText("legal-responsible", responsible, "Wie oben — Inhaber und Anschrift");

    document.querySelectorAll("[data-legal-company]").forEach((el) => {
      const name = (cfg.companyName || "").trim() || "TaxiApp Leitstelle";
      el.textContent = name;
    });
  }

  window.TaxiAppLegal = {
    setText,
    applyContact,
    loadConfig() {
      return fetch("/api/config")
        .then((r) => r.json())
        .then((cfg) => {
          applyContact(cfg);
          return cfg;
        })
        .catch(() => ({}));
    },
  };
})();
