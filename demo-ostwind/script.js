(() => {
  const header = document.querySelector(".site-header");
  const reveals = document.querySelectorAll("[data-reveal]");
  const form = document.querySelector(".signup__form");
  const note = document.querySelector(".signup__note");

  const onScroll = () => {
    if (!header) return;
    header.classList.toggle("is-scrolled", window.scrollY > 24);
  };

  onScroll();
  window.addEventListener("scroll", onScroll, { passive: true });

  if ("IntersectionObserver" in window) {
    const observer = new IntersectionObserver(
      (entries) => {
        entries.forEach((entry) => {
          if (!entry.isIntersecting) return;
          entry.target.classList.add("is-visible");
          observer.unobserve(entry.target);
        });
      },
      { threshold: 0.16, rootMargin: "0px 0px -8% 0px" }
    );

    reveals.forEach((el, index) => {
      el.style.transitionDelay = `${Math.min(index % 5, 3) * 70}ms`;
      observer.observe(el);
    });
  } else {
    reveals.forEach((el) => el.classList.add("is-visible"));
  }

  if (form && note) {
    form.addEventListener("submit", (event) => {
      event.preventDefault();
      note.hidden = false;
      note.textContent = "Danke — in dieser Demo wird nichts versendet. Deine Auswahl ist notiert.";
      form.reset();
    });
  }
})();
