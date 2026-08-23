(function () {
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
