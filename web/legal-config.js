/**
 * Plattform-Anbieter vs. Taxi-Betrieb — getrennte Firmendaten aus /api/config.
 *
 * Plattform (platform*): Datenschutz, Impressum Anbieter, AGB, Kündigung — Software-Anbieter.
 * Betrieb (companyName, legal*, centralPhone): Leitstelle, Fahrgäste, Fahrten.
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

  function platformEmail(cfg) {
    return (cfg.platformEmail || "luckypc81@gmail.com").trim();
  }

  function applyPlatformContact(cfg) {
    setText("legal-company", cfg.platformCompanyName, "Luckys Taxi App");
    setText("legal-street", cfg.platformStreet, "Straße — Plattform in Einstellungen eintragen");
    setText("legal-city", cfg.platformCity, "PLZ Ort — Plattform in Einstellungen eintragen");
    setText("legal-owner", cfg.platformOwner, "Inhaber — Plattform in Einstellungen eintragen");
    setText("legal-vat", cfg.platformVatId, "USt-IdNr. — Plattform in Einstellungen eintragen");

    const email = platformEmail(cfg);
    const emailEl = document.getElementById("legal-email");
    if (emailEl) {
      emailEl.textContent = email;
      emailEl.href = `mailto:${email}`;
    }

    const phoneRaw = (cfg.platformPhone || "").trim();
    const phoneDisplay = phoneRaw || "—";
    const phoneEl = document.getElementById("legal-phone");
    if (phoneEl) {
      phoneEl.textContent = phoneDisplay;
      phoneEl.href = phoneRaw ? `tel:${phoneRaw.replace(/\s/g, "")}` : "#";
      phoneEl.classList.toggle("legal-hint", !phoneRaw);
    }

    const responsible = [cfg.platformOwner, cfg.platformStreet, cfg.platformCity]
      .filter((x) => (x || "").trim())
      .join(", ");
    setText("legal-responsible", responsible, "Wie oben — Inhaber und Anschrift (Plattform)");

    document.querySelectorAll("[data-legal-company]").forEach((el) => {
      const name = (cfg.platformCompanyName || "").trim() || "Luckys Taxi App";
      el.textContent = name;
    });

    document.querySelectorAll("[data-platform-email]").forEach((el) => {
      el.textContent = email;
      el.href = `mailto:${email}`;
    });
  }

  function applyOperatorContact(cfg) {
    const company = (cfg.companyName || "").trim();
    const hasOperator =
      company ||
      (cfg.legalStreet || "").trim() ||
      (cfg.legalCity || "").trim() ||
      (cfg.legalOwner || "").trim();

    const section = document.getElementById("operator-section");
    if (section) {
      section.hidden = !hasOperator;
    }

    setText("operator-company", company, "Taxi-Betrieb — in Einstellungen eintragen");
    setText("operator-street", cfg.legalStreet, "Straße — Taxi-Betrieb in Einstellungen");
    setText("operator-city", cfg.legalCity, "PLZ Ort — Taxi-Betrieb in Einstellungen");
    setText("operator-owner", cfg.legalOwner, "Inhaber — Taxi-Betrieb in Einstellungen");
    setText("operator-vat", cfg.vatId, "USt-IdNr. — Taxi-Betrieb in Einstellungen");

    const opEmail = (cfg.legalEmail || "").trim();
    const opEmailEl = document.getElementById("operator-email");
    if (opEmailEl) {
      if (opEmail) {
        opEmailEl.textContent = opEmail;
        opEmailEl.href = `mailto:${opEmail}`;
        opEmailEl.classList.remove("legal-hint");
      } else {
        opEmailEl.textContent = "—";
        opEmailEl.href = "#";
        opEmailEl.classList.add("legal-hint");
      }
    }

    const phoneDisplay = cfg.centralPhoneDisplay || cfg.centralPhone || "—";
    const phoneEl = document.getElementById("operator-phone");
    if (phoneEl) {
      phoneEl.textContent = phoneDisplay;
      phoneEl.href = cfg.centralPhone ? `tel:${String(cfg.centralPhone).replace(/\s/g, "")}` : "#";
    }
  }

  window.TaxiAppLegal = {
    setText,
    platformEmail,
    applyPlatformContact,
    applyOperatorContact,
    loadConfig() {
      return fetch("/api/config")
        .then((r) => r.json())
        .then((cfg) => {
          applyPlatformContact(cfg);
          applyOperatorContact(cfg);
          return cfg;
        })
        .catch(() => ({}));
    },
  };
})();
