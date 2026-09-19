(function () {
  /** Queued until gtag is ready (fetch of measurement ID is async). */
  var pendingEvents = [];
  var CONSENT_KEY = "luckys_analytics_consent";

  function flushPending() {
    if (typeof window.gtag !== "function") return;
    while (pendingEvents.length) {
      var args = pendingEvents.shift();
      window.gtag.apply(null, args);
    }
  }

  /**
   * B2B conversion helper. Safe no-op if GA is not configured / no consent.
   */
  window.luckysTrack = function (eventName, params) {
    if (localStorage.getItem(CONSENT_KEY) !== "1") return;
    var payload = ["event", String(eventName || "").trim(), params || {}];
    if (!payload[1]) return;
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
      'Details: <a href="datenschutz.html">Datenschutz</a>.</p>' +
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

  fetch("/api/public/analytics")
    .then(function (res) {
      return res.ok ? res.json() : null;
    })
    .then(function (cfg) {
      if (cfg && cfg.gaMeasurementId) maybeLoad(cfg.gaMeasurementId);
    })
    .catch(function () {});
})();
