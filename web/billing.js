(function () {
  const statusEl = document.getElementById("billing-status");
  const forms = document.querySelectorAll("[data-billing-form]");

  function setStatus(message, isError) {
    if (!statusEl) return;
    statusEl.textContent = message;
    statusEl.hidden = !message;
    statusEl.className = isError ? "billing-status error" : "billing-status ok";
  }

  async function loadBillingConfig() {
    try {
      const res = await fetch("/api/billing/config");
      if (!res.ok) throw new Error("Config nicht erreichbar");
      return res.json();
    } catch {
      return { enabled: false, plans: [] };
    }
  }

  function planCheckoutAvailable(config, planId) {
    const plan = config.plans.find((item) => item.id === planId);
    return Boolean(config.enabled && plan?.checkoutAvailable);
  }

  function wireForm(form, config) {
    const planId = form.dataset.planId;
    const checkoutBtn = form.querySelector("[data-checkout-btn]");
    const inquiryBtn = form.querySelector("[data-inquiry-btn]");
    const useCheckout = planCheckoutAvailable(config, planId);

    if (checkoutBtn) checkoutBtn.hidden = !useCheckout;
    if (inquiryBtn) inquiryBtn.hidden = useCheckout;

    form.addEventListener("submit", async (event) => {
      event.preventDefault();
      setStatus("");

      const email = form.querySelector("[name=email]")?.value.trim();
      const companyName = form.querySelector("[name=companyName]")?.value.trim();
      const message = form.querySelector("[name=message]")?.value.trim() || "";

      if (!email || !companyName) {
        setStatus((window.LuckysI18n && window.LuckysI18n.t("billing.fill")) || "Bitte E-Mail und Firmenname ausfüllen.", true);
        return;
      }

      const submitBtn = form.querySelector("button[type=submit]");
      if (submitBtn) submitBtn.disabled = true;

      try {
        if (useCheckout) {
          const res = await fetch("/api/billing/checkout", {
            method: "POST",
            headers: { "Content-Type": "application/json" },
            body: JSON.stringify({ planId, email, companyName }),
          });
          const data = await res.json();
          if (!res.ok) throw new Error(data.error || "Checkout fehlgeschlagen");
          window.location.href = data.url;
          return;
        }

        const res = await fetch("/api/contact", {
          method: "POST",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify({ planId, email, companyName, message }),
        });
        const data = await res.json();
        if (!res.ok) throw new Error(data.error || "Anfrage fehlgeschlagen");

        setStatus(
          (window.LuckysI18n && window.LuckysI18n.t("billing.thanks")) ||
            "Danke! Ihre Anfrage ist eingegangen — wir melden uns per E-Mail.",
          false
        );
        form.reset();
      } catch (error) {
        setStatus(error.message || (window.LuckysI18n && window.LuckysI18n.t("billing.error")) || "Es ist ein Fehler aufgetreten.", true);
      } finally {
        if (submitBtn) submitBtn.disabled = false;
      }
    });
  }

  document.addEventListener("DOMContentLoaded", async () => {
    const config = await loadBillingConfig();
    forms.forEach((form) => wireForm(form, config));

    if (config.enabled && statusEl) {
      statusEl.textContent =
        (window.LuckysI18n && window.LuckysI18n.t("billing.online")) ||
        "Online-Abo verfügbar — Rechnung kommt automatisch per E-Mail von Stripe.";
      statusEl.hidden = false;
      statusEl.className = "billing-status ok";
    }

    document.addEventListener("luckys-lang", () => {
      if (config.enabled && statusEl && !statusEl.hidden && statusEl.classList.contains("ok")) {
        statusEl.textContent =
          (window.LuckysI18n && window.LuckysI18n.t("billing.online")) || statusEl.textContent;
      }
    });
  });
})();
