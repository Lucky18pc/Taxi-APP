(function () {
  /** Queued until gtag is ready (fetch of measurement ID is async). */
  var pendingEvents = [];

  function flushPending() {
    if (typeof window.gtag !== "function") return;
    while (pendingEvents.length) {
      var args = pendingEvents.shift();
      window.gtag.apply(null, args);
    }
  }

  /**
   * B2B conversion helper. Safe no-op if GA is not configured.
   * Primary business KPI remains Admin → Tarif-Anfragen; this is secondary.
   */
  window.luckysTrack = function (eventName, params) {
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

  fetch("/api/public/analytics")
    .then(function (res) {
      return res.ok ? res.json() : null;
    })
    .then(function (cfg) {
      if (cfg && cfg.gaMeasurementId) loadAnalytics(cfg.gaMeasurementId);
    })
    .catch(function () {});
})();
