/**
 * Zeigt aktive Partner-Firmen auf Stadtseiten und im Städte-Hub.
 * Nutzt /api/operators (nur öffentliche Felder).
 */
(function () {
  "use strict";

  function esc(s) {
    return String(s || "")
      .replace(/&/g, "&amp;")
      .replace(/</g, "&lt;")
      .replace(/>/g, "&gt;")
      .replace(/"/g, "&quot;");
  }

  function normalize(s) {
    return String(s || "")
      .toLowerCase()
      .normalize("NFD")
      .replace(/[\u0300-\u036f]/g, "")
      .replace(/ä/g, "ae")
      .replace(/ö/g, "oe")
      .replace(/ü/g, "ue")
      .replace(/ß/g, "ss")
      .replace(/[^a-z0-9]+/g, " ")
      .trim();
  }

  function cityFromLegal(legalCity) {
    return String(legalCity || "")
      .replace(/^\d{4,5}\s*/, "")
      .trim();
  }

  function pageMeta() {
    const body = document.body;
    const mode = body.getAttribute("data-partners-mode") || "";
    let slug = (body.getAttribute("data-city-slug") || "").trim();
    let name = (body.getAttribute("data-city") || "").trim();
    let country = (body.getAttribute("data-country") || "").trim().toUpperCase();
    let type = (body.getAttribute("data-loc-type") || "").trim();

    if (!slug) {
      const m = location.pathname.match(/\/staedte\/([^/]+?)(?:\.html)?\/?$/i);
      if (m && m[1] && m[1].toLowerCase() !== "index") slug = m[1].toLowerCase();
    }
    if (!name) {
      const h1 = document.querySelector(".city-hero h1");
      if (h1) {
        name = h1.textContent
          .replace(/^Taxi(\s*-?\s*Software)?\s+in\s+/i, "")
          .replace(/^Taxi bestellen in\s+/i, "")
          .trim();
      }
    }
    if (!mode && /\/staedte\/?(index\.html)?$/i.test(location.pathname)) {
      return { mode: "directory", slug: "", name: "", country: "", type: "hub" };
    }
    return { mode: mode || "city", slug, name, country, type: type || "city" };
  }

  function matchesCity(op, meta) {
    if (meta.type === "country" && meta.country) {
      return String(op.country || "").toUpperCase() === meta.country;
    }
    const nName = normalize(meta.name);
    const nSlug = normalize(meta.slug).replace(/\s+/g, "-");
    const legal = cityFromLegal(op.legalCity);
    const nLegal = normalize(legal);
    const opSlug = normalize(op.slug).replace(/\s+/g, "-");

    if (meta.slug && (opSlug === nSlug || opSlug.includes(nSlug) || nSlug.includes(opSlug))) {
      return true;
    }
    if (nName && nLegal && (nLegal.includes(nName) || nName.includes(nLegal))) {
      return true;
    }
    return false;
  }

  function bookHref(op) {
    return `../book.html?o=${encodeURIComponent(op.slug || "")}`;
  }

  function renderCard(op) {
    const city = cityFromLegal(op.legalCity) || op.legalCity || "";
    const phone = op.centralPhoneDisplay || "";
    const logo = op.logoUrl
      ? `<img class="city-partner-logo" src="${esc(op.logoUrl)}" alt="" width="48" height="48" loading="lazy">`
      : `<span class="city-partner-mark" aria-hidden="true">${esc((op.companyName || "?").slice(0, 2).toUpperCase())}</span>`;

    return `<li class="city-partner-card">
      ${logo}
      <div class="city-partner-body">
        <strong class="city-partner-name">${esc(op.companyName || "Taxi-Betrieb")}</strong>
        ${city ? `<span class="city-partner-city">${esc(city)}</span>` : ""}
        ${phone ? `<span class="city-partner-phone">${esc(phone)}</span>` : ""}
        <a class="city-partner-link" href="${esc(bookHref(op))}">Taxi bestellen</a>
      </div>
    </li>`;
  }

  function ensureMount(meta) {
    let el = document.getElementById("city-partners");
    if (el) return el;

    const main = document.querySelector("main.city-main") || document.querySelector("main");
    if (!main) return null;

    el = document.createElement("section");
    el.id = "city-partners";
    el.className = "city-partners";
    el.setAttribute("aria-live", "polite");
    el.hidden = true;

    const faq = main.querySelector(".city-faq:not(#produkte)");
    const split = main.querySelector(".city-split");
    const nav = main.querySelector(".city-nav");
    if (meta.mode === "directory") {
      const lead = main.querySelector(".lead");
      if (lead && lead.nextSibling) main.insertBefore(el, lead.nextSibling);
      else main.insertBefore(el, main.firstChild);
    } else if (split && split.nextSibling) {
      main.insertBefore(el, split.nextSibling);
    } else if (faq) {
      main.insertBefore(el, faq);
    } else if (nav) {
      main.insertBefore(el, nav);
    } else {
      main.appendChild(el);
    }
    return el;
  }

  function renderList(mount, ops, meta) {
    if (!ops.length) {
      if (meta.mode === "directory") {
        mount.hidden = false;
        mount.innerHTML = `<h2>Aktive Partner-Firmen</h2>
          <p class="city-partners-empty">Noch keine aktiven Betriebe öffentlich gelistet. <a href="../onboard.html">Partner werden</a></p>`;
        return;
      }
      mount.hidden = true;
      mount.innerHTML = "";
      return;
    }

    const title =
      meta.mode === "directory"
        ? "Aktive Partner-Firmen nach Stadt"
        : meta.name
          ? `Partner in ${esc(meta.name)}`
          : "Partner vor Ort";

    const intro =
      meta.mode === "directory"
        ? "<p>Diese Taxi-Betriebe sind an die Plattform angebunden. Buchungen laufen unter dem Namen des Betriebs.</p>"
        : "<p>Hier fahren Partner unter ihrem Firmennamen. Vertragspartner der Fahrt ist der Betrieb, nicht Code &amp; Grow.</p>";

    mount.hidden = false;
    mount.innerHTML = `<h2>${title}</h2>
      ${intro}
      <ul class="city-partner-list">
        ${ops.map(renderCard).join("\n        ")}
      </ul>`;
  }

  async function loadLocations() {
    try {
      const res = await fetch("locations.generated.json", { credentials: "same-origin" });
      if (!res.ok) return [];
      return await res.json();
    } catch {
      return [];
    }
  }

  async function init() {
    const meta = pageMeta();
    if (meta.mode === "city" && !meta.slug && !meta.name) return;

    if (meta.mode === "city" && (!meta.country || !meta.type || meta.type === "city")) {
      const locs = await loadLocations();
      const hit = locs.find((l) => l.slug === meta.slug);
      if (hit) {
        if (!meta.name) meta.name = hit.name;
        meta.country = hit.country || meta.country;
        meta.type = hit.type || meta.type;
      }
    }

    const mount = ensureMount(meta);
    if (!mount) return;

    try {
      const res = await fetch("/api/operators", { credentials: "same-origin" });
      if (!res.ok) throw new Error("operators " + res.status);
      const data = await res.json();
      let ops = Array.isArray(data.operators) ? data.operators : [];
      ops = ops.filter((op) => String(op.status || "active") === "active");

      if (meta.mode !== "directory") {
        ops = ops.filter((op) => matchesCity(op, meta));
      } else {
        ops = ops.slice().sort((a, b) => {
          const ca = cityFromLegal(a.legalCity) || a.legalCity || "";
          const cb = cityFromLegal(b.legalCity) || b.legalCity || "";
          const byCity = ca.localeCompare(cb, "de");
          if (byCity) return byCity;
          return String(a.companyName || "").localeCompare(String(b.companyName || ""), "de");
        });
      }

      renderList(mount, ops, meta);
    } catch {
      mount.hidden = true;
    }
  }

  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", init);
  } else {
    init();
  }
})();
