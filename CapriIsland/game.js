(() => {
  const SYMBOLS = [
    { id: "sunglasses", emoji: "🕶️", name: "Brille", payout: 5 },
    { id: "deckchair", emoji: "🏖️", name: "Liege", payout: 10 },
    { id: "cocktail", emoji: "🍹", name: "Cocktail", payout: 20 },
    { id: "sailboat", emoji: "⛵", name: "Segel", payout: 50 },
    { id: "yacht", emoji: "🛥️", name: "Yacht", payout: 100 },
    { id: "isabella", emoji: "👒", name: "Isabella", payout: 150 },
    { id: "gianluca", emoji: "🤵", name: "Gianluca", payout: 200 },
    { id: "capriSun", emoji: "☀️", name: "Sonne", payout: 25 },
    { id: "beachJoker", emoji: "🏄‍♂️", name: "Joker", payout: 0, wild: true },
  ];

  const LADDER = [0, 0.2, 0.5, 1, 2.5, 5, 10, 25, 50, 100];

  const state = {
    balance: 150,
    stake: 1,
    lastWin: 0,
    mode: "idle", // idle | spinning | won | risk
    ladderIndex: 3,
    grid: [
      [SYMBOLS[0], SYMBOLS[5], SYMBOLS[2]],
      [SYMBOLS[3], SYMBOLS[6], SYMBOLS[4]],
      [SYMBOLS[1], SYMBOLS[8], SYMBOLS[7]],
    ],
  };

  const el = {
    balance: document.getElementById("balance"),
    stake: document.getElementById("stake"),
    lastWin: document.getElementById("lastWin"),
    message: document.getElementById("message"),
    reels: document.getElementById("reels"),
    reelsView: document.getElementById("reelsView"),
    ladderView: document.getElementById("ladderView"),
    ladder: document.getElementById("ladder"),
    spinBtn: document.getElementById("spinBtn"),
    riskBtn: document.getElementById("riskBtn"),
    climbBtn: document.getElementById("climbBtn"),
    collectBtn: document.getElementById("collectBtn"),
  };

  const euro = new Intl.NumberFormat("de-DE", {
    style: "currency",
    currency: "EUR",
  });

  function randomSymbol() {
    return SYMBOLS[Math.floor(Math.random() * SYMBOLS.length)];
  }

  function setMessage(text) {
    el.message.style.opacity = "0.35";
    window.setTimeout(() => {
      el.message.textContent = text;
      el.message.style.opacity = "1";
    }, 120);
  }

  function renderHud() {
    el.balance.textContent = euro.format(state.balance);
    el.stake.textContent = euro.format(state.stake);
    el.lastWin.textContent = euro.format(state.lastWin);
  }

  function renderReels(spinning = false) {
    el.reels.innerHTML = "";
    for (let row = 0; row < 3; row += 1) {
      for (let col = 0; col < 3; col += 1) {
        const symbol = state.grid[col][row];
        const cell = document.createElement("div");
        cell.className = "cell";
        if (spinning) cell.classList.add("spinning");
        if (symbol.id === "gianluca") cell.classList.add("gianluca");
        if (symbol.wild) cell.classList.add("joker");
        cell.innerHTML = `<span class="emoji">${symbol.emoji}</span><span class="name">${symbol.name}</span>`;
        el.reels.appendChild(cell);
      }
    }
  }

  function renderLadder() {
    el.ladder.innerHTML = "";
    [...LADDER].map((amount, index) => ({ amount, index }))
      .reverse()
      .forEach(({ amount, index }) => {
        const step = document.createElement("div");
        const active = index === state.ladderIndex;
        step.className = `ladder-step${active ? " active" : ""}`;
        step.innerHTML = `
          <span class="boat">${active ? "⛵" : ""}</span>
          <span>${euro.format(amount)}</span>
          <span class="palm">${active ? "🌴" : ""}</span>
        `;
        el.ladder.appendChild(step);
      });
  }

  function showReels() {
    el.reelsView.hidden = false;
    el.ladderView.hidden = true;
    el.riskBtn.hidden = !(state.mode === "won" && state.lastWin > 0);
    el.spinBtn.disabled = state.mode === "spinning";
    el.spinBtn.textContent =
      state.mode === "spinning" ? "Schiff läuft ein…" : "Spin — La Dolce Vita";
  }

  function showLadder() {
    el.reelsView.hidden = true;
    el.ladderView.hidden = false;
    renderLadder();
    el.climbBtn.disabled = state.ladderIndex === 0;
  }

  function evaluateWin() {
    const flat = state.grid.flat();
    const hasGianluca = flat.some((s) => s.id === "gianluca");
    const hasJoker = flat.some((s) => s.wild);
    const hasIsabella = flat.some((s) => s.id === "isabella");

    // Middle row payline (left → right)
    const line = [state.grid[0][1], state.grid[1][1], state.grid[2][1]];
    const resolved = line.map((s) => (s.wild ? null : s.id));
    const nonWild = resolved.filter(Boolean);
    const lineMatch =
      nonWild.length > 0 && nonWild.every((id) => id === nonWild[0]);

    let chance = Math.random();
    if (hasGianluca) chance -= 0.25;
    if (lineMatch) chance -= 0.35;

    if (chance < 0.48 || hasGianluca || lineMatch) {
      const baseSymbol = lineMatch
        ? SYMBOLS.find((s) => s.id === nonWild[0])
        : hasIsabella
          ? SYMBOLS.find((s) => s.id === "isabella")
          : randomSymbol();
      const mult = Math.max(baseSymbol.payout || 5, 5);
      const roll = 1 + Math.floor(Math.random() * 3);
      let win = state.stake * (mult / 10) * roll;
      if (hasGianluca) win *= 2;
      if (hasJoker) win *= 1.25;
      win = Math.round(win * 100) / 100;

      state.lastWin = win;
      state.balance = Math.round((state.balance + win) * 100) / 100;
      state.mode = "won";

      if (hasGianluca) {
        setMessage(`MEGA-WIN! Gianluca bringt ${euro.format(win)} Luxus.`);
      } else if (lineMatch) {
        setMessage(`Payline trifft ${baseSymbol.name}: ${euro.format(win)}!`);
      } else if (hasJoker) {
        setMessage(`Strand-Joker hilft! Gewinn: ${euro.format(win)}`);
      } else {
        setMessage(`Traumhafter Gewinn: ${euro.format(win)}!`);
      }
    } else {
      state.lastWin = 0;
      state.mode = "idle";
      setMessage("Sonne, Strand und Meer. Neuer Versuch!");
    }
  }

  function spin() {
    if (state.mode === "spinning") return;
    if (state.balance < state.stake) {
      setMessage("Nicht genügend Guthaben im Portemonnaie!");
      return;
    }

    state.balance = Math.round((state.balance - state.stake) * 100) / 100;
    state.mode = "spinning";
    state.lastWin = 0;
    renderHud();
    showReels();
    setMessage("Die Yacht legt ab… Walzen drehen sich!");
    renderReels(true);

    const ticks = 10;
    let i = 0;
    const interval = window.setInterval(() => {
      state.grid = [
        [randomSymbol(), randomSymbol(), randomSymbol()],
        [randomSymbol(), randomSymbol(), randomSymbol()],
        [randomSymbol(), randomSymbol(), randomSymbol()],
      ];
      renderReels(true);
      i += 1;
      if (i >= ticks) {
        window.clearInterval(interval);
        evaluateWin();
        renderHud();
        renderReels(false);
        showReels();
      }
    }, 70);
  }

  function startRisk() {
    if (state.lastWin <= 0) return;
    state.balance = Math.round((state.balance - state.lastWin) * 100) / 100;
    state.ladderIndex = 4;
    state.mode = "risk";
    renderHud();
    setMessage("Aufstieg an der Klippentreppe zum Monte Solaro!");
    showLadder();
  }

  function climb() {
    if (state.mode !== "risk" || state.ladderIndex === 0) return;
    const success = Math.random() < 0.58;
    if (success) {
      if (state.ladderIndex < LADDER.length - 1) {
        state.ladderIndex += 1;
        setMessage("Stufe geschafft! Der Blick von oben wird besser.");
      } else {
        setMessage("Gipfel von Monte Solaro erreicht!");
      }
    } else {
      state.ladderIndex = Math.max(0, state.ladderIndex - 2);
      if (state.ladderIndex === 0) {
        setMessage("Eine steife Brise hat dich erwischt! Abgestürzt.");
        renderLadder();
        window.setTimeout(() => {
          state.lastWin = 0;
          state.mode = "idle";
          renderHud();
          showReels();
          setMessage("Zurück am Hafen. Dreh noch einmal die Walzen.");
        }, 1400);
        return;
      }
      setMessage("Welle erwischt! Ein paar Stufen runtergerutscht.");
    }
    renderLadder();
    el.climbBtn.disabled = state.ladderIndex === 0;
  }

  function collect() {
    if (state.mode !== "risk") return;
    const amount = LADDER[state.ladderIndex];
    state.balance = Math.round((state.balance + amount) * 100) / 100;
    state.lastWin = 0;
    state.mode = "idle";
    renderHud();
    setMessage(`Sicher im Hafen! ${euro.format(amount)} gutgeschrieben.`);
    showReels();
  }

  el.spinBtn.addEventListener("click", spin);
  el.riskBtn.addEventListener("click", startRisk);
  el.climbBtn.addEventListener("click", climb);
  el.collectBtn.addEventListener("click", collect);

  renderHud();
  renderReels(false);
  showReels();
})();
