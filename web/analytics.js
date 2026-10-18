(function () {
  /** Queued until gtag is ready (fetch of measurement ID is async). */
  var pendingEvents = [];
  var CONSENT_KEY = "luckys_analytics_consent";
  var CITY_SESSION_KEY = "luckys_page_city";

  function flushPending() {
    if (typeof window.gtag !== "function") return;
    while (pendingEvents.length) {
      var args = pendingEvents.shift();
      window.gtag.apply(null, args);
    }
  }

  function getCityContext() {
    var body = document.body;
    var slug = "";
    var name = "";
    if (body) {
      slug = String(body.getAttribute("data-city-slug") || "").trim().toLowerCase();
      name = String(body.getAttribute("data-city") || "").trim();
    }
    if (!slug) {
      var m = (location.pathname || "").match(/\/staedte\/([^/]+?)(?:\.html)?\/?$/i);
      if (m && m[1] && m[1].toLowerCase() !== "index") {
        slug = m[1].toLowerCase();
      }
    }
    if (!slug) {
      try {
        slug = String(sessionStorage.getItem(CITY_SESSION_KEY) || "").trim().toLowerCase();
      } catch (e) {
        slug = "";
      }
    }
    return { city: slug, page_city: slug, city_name: name };
  }

  function rememberCityFromPage() {
    var ctx = getCityContext();
    if (!ctx.city) return ctx;
    try {
      sessionStorage.setItem(CITY_SESSION_KEY, ctx.city);
    } catch (e) {}
    return ctx;
  }

  /**
   * Conversion / engagement helper. Safe no-op if GA is not configured / no consent.
   * Always merges city context when available (Stadtseite or session).
   */
  window.luckysTrack = function (eventName, params) {
    if (localStorage.getItem(CONSENT_KEY) !== "1") return;
    var name = String(eventName || "").trim();
    if (!name) return;
    var cityCtx = getCityContext();
    var merged = Object.assign({}, cityCtx.city ? { city: cityCtx.city, page_city: cityCtx.page_city } : {}, params || {});
    if (cityCtx.city_name && !merged.city_name) merged.city_name = cityCtx.city_name;
    var payload = ["event", name, merged];
    if (typeof window.gtag === "function") {
      window.gtag.apply(null, payload);
    } else {
      pendingEvents.push(payload);
    }
  };

  function loadAnalytics(measurementId) {
    const id = String(measurementId || "").trim();
    if (!id || !/^G-[A-Z0-9]+$/i.test(id)) return;

    const script = document.createElement("script");
    script.async = true;
    script.src = "https://www.googletagmanager.com/gtag/js?id=" + encodeURIComponent(id);
    document.head.appendChild(script);

    window.dataLayer = window.dataLayer || [];
    function gtag() {
      window.dataLayer.push(arguments);
    }
    window.gtag = gtag;
    gtag("js", new Date());
    gtag("config", id, { anonymize_ip: true });
    flushPending();
    wireCityPageTracking();
  }

  function classifyCtaAccountType(href) {
    var path = "";
    try {
      path = new URL(href, location.href).pathname.toLowerCase();
    } catch (e) {
      path = String(href || "").toLowerCase();
    }
    if (/\/onboard\.html|\/betrieb\.html|\/admin\.html/.test(path)) return "business";
    if (/\/book\.html|\/track\.html/.test(path)) return "private";
    return "";
  }

  function wireCityPageTracking() {
    if (!document.body || !document.body.classList.contains("city-page")) return;
    var ctx = rememberCityFromPage();
    if (!ctx.city) return;

    window.luckysTrack("view_city_page", {
      city: ctx.city,
      page_city: ctx.city,
      city_name: ctx.city_name || undefined,
    });

    document.addEventListener(
      "click",
      function (ev) {
        var a = ev.target && ev.target.closest ? ev.target.closest("a[href]") : null;
        if (!a) return;
        var accountType = classifyCtaAccountType(a.getAttribute("href") || "");
        if (!accountType) return;
        // Intent-Klick (noch keine Registrierung). Privat-Conversion: sign_up in book.html.
        window.luckysTrack("generate_lead", {
          account_type: accountType,
          city: ctx.city,
          page_city: ctx.city,
          lead_source: accountType === "private" ? "city_cta_book" : "city_cta_business",
          method: "city_page_cta",
        });
      },
      true
    );
  }

  function hideBanner() {
    var el = document.getElementById("luckys-consent-banner");
    if (el) el.remove();
  }

  function showConsentBanner(onAccept, onDecline) {
    if (document.getElementById("luckys-consent-banner")) return;
    var bar = document.createElement("div");
    bar.id = "luckys-consent-banner";
    bar.setAttribute("role", "dialog");
    bar.setAttribute("aria-label", "Cookie-Hinweis");
    bar.innerHTML =
      '<p>Wir nutzen optional <strong>Google Analytics</strong> zur Reichweitenmessung (erst nach Ihrer Zustimmung). ' +
      'Details: <a href="/datenschutz.html">Datenschutz</a>.</p>' +
      '<div class="luckys-consent-actions">' +
      '<button type="button" class="luckys-consent-decline" id="luckys-consent-no">Ablehnen</button>' +
      '<button type="button" class="luckys-consent-accept" id="luckys-consent-yes">Akzeptieren</button>' +
      "</div>";
    document.body.appendChild(bar);
    document.getElementById("luckys-consent-yes").addEventListener("click", function () {
      localStorage.setItem(CONSENT_KEY, "1");
      hideBanner();
      onAccept();
    });
    document.getElementById("luckys-consent-no").addEventListener("click", function () {
      localStorage.setItem(CONSENT_KEY, "0");
      hideBanner();
      onDecline();
    });
  }

  function maybeLoad(measurementId) {
    var consent = localStorage.getItem(CONSENT_KEY);
    if (consent === "1") {
      loadAnalytics(measurementId);
      return;
    }
    if (consent === "0") return;
    showConsentBanner(
      function () {
        loadAnalytics(measurementId);
      },
      function () {}
    );
  }

  // Remember city even before consent (session only; no network).
  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", rememberCityFromPage);
  } else {
    rememberCityFromPage();
  }

  fetch("/api/public/analytics")
    .then(function (res) {
      return res.ok ? res.json() : null;
    })
    .then(function (cfg) {
      if (cfg && cfg.gaMeasurementId) maybeLoad(cfg.gaMeasurementId);
    })
    .catch(function () {});
})();
