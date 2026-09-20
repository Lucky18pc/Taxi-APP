/**
 * Phase 7 — GoBD-Quittungen (fortlaufende Nummerierung) + PDF + E-Mail.
 *
 * Nach Fahrtabschluss: Quittung mit Nr., MwSt., Start, Zeitstempel.
 * Nach Stripe payment_intent.succeeded: PDF erzeugen und an Fahrgast mailen.
 */

const fs = require("fs");
const path = require("path");
const crypto = require("crypto");
const { buildSimplePdf } = require("./pdf-simple");

const DEFAULT_VAT_PERCENT = Number(process.env.RECEIPT_VAT_PERCENT || 7);

function loadJson(filePath, fallback) {
  try {
    if (!fs.existsSync(filePath)) return fallback;
    return JSON.parse(fs.readFileSync(filePath, "utf8"));
  } catch {
    return fallback;
  }
}

function saveJson(filePath, data) {
  fs.mkdirSync(path.dirname(filePath), { recursive: true });
  const tmp = `${filePath}.${process.pid}.tmp`;
  fs.writeFileSync(tmp, `${JSON.stringify(data, null, 2)}\n`, "utf8");
  fs.renameSync(tmp, filePath);
}

function round2(n) {
  return Math.round(Number(n) * 100) / 100;
}

function splitGross(gross, vatPercent) {
  const rate = Number(vatPercent);
  const grossAmount = round2(gross);
  if (!Number.isFinite(grossAmount) || grossAmount < 0) {
    return { grossAmount: 0, netAmount: 0, vatAmount: 0, vatPercent: rate };
  }
  const netAmount = round2(grossAmount / (1 + rate / 100));
  const vatAmount = round2(grossAmount - netAmount);
  return { grossAmount, netAmount, vatAmount, vatPercent: rate };
}

function formatEuro(n) {
  return `${round2(n).toFixed(2)} EUR`;
}

function formatDeDate(iso) {
  try {
    return new Intl.DateTimeFormat("de-DE", {
      dateStyle: "medium",
      timeStyle: "short",
      timeZone: "Europe/Berlin",
    }).format(new Date(iso));
  } catch {
    return String(iso || "");
  }
}

/**
 * @param {{ dataDir: string, getTenantConfig?: Function, getFleetOperator?: Function, sendEmail?: Function }} opts
 */
function createReceiptStore(opts) {
  const dataDir = opts.dataDir;
  const receiptsFile = path.join(dataDir, "receipts.json");
  const sequenceFile = path.join(dataDir, "receipts-sequence.json");
  const pdfDir = path.join(dataDir, "receipts-pdf");
  fs.mkdirSync(pdfDir, { recursive: true });

  /** @type {Array<Record<string, unknown>>} */
  let receipts = loadJson(receiptsFile, []);
  if (!Array.isArray(receipts)) receipts = [];

  let sequence = loadJson(sequenceFile, { year: new Date().getFullYear(), next: 1 });
  if (!sequence || typeof sequence !== "object") {
    sequence = { year: new Date().getFullYear(), next: 1 };
  }

  function persist() {
    saveJson(receiptsFile, receipts);
    saveJson(sequenceFile, sequence);
  }

  function nextNumber() {
    const year = new Date().getFullYear();
    if (Number(sequence.year) !== year) {
      sequence.year = year;
      sequence.next = 1;
    }
    const n = Number(sequence.next) || 1;
    sequence.next = n + 1;
    const num = `Q-${year}-${String(n).padStart(6, "0")}`;
    persist();
    return num;
  }

  function findByBookingId(bookingId) {
    return receipts.find((r) => r.bookingId === bookingId) || null;
  }

  function findById(receiptId) {
    return receipts.find((r) => r.receiptId === receiptId) || null;
  }

  function findByNumber(receiptNumber) {
    return receipts.find((r) => r.receiptNumber === receiptNumber) || null;
  }

  function issuerFor(booking) {
    const tenant = typeof opts.getTenantConfig === "function" ? opts.getTenantConfig() : {};
    let fleetOp = null;
    if (booking?.operatorId && typeof opts.getFleetOperator === "function") {
      fleetOp = opts.getFleetOperator(booking.operatorId);
    }
    return {
      companyName:
        fleetOp?.companyName ||
        tenant.platformCompanyName ||
        tenant.companyName ||
        "Luckys Taxi App",
      street: fleetOp?.legalStreet || tenant.platformStreet || tenant.legalStreet || "",
      city: fleetOp?.legalCity || tenant.platformCity || tenant.legalCity || "",
      vatId: fleetOp?.vatId || tenant.vatId || "",
      email: fleetOp?.legalEmail || tenant.platformEmail || tenant.legalEmail || "",
      operatorId: booking?.operatorId || null,
      operatorSlug: fleetOp?.slug || null,
    };
  }

  /**
   * Quittung nach Fahrtabschluss anlegen (idempotent pro bookingId).
   */
  function ensureReceiptForBooking(booking, { vatPercent } = {}) {
    if (!booking?.bookingId) throw new Error("booking required");
    const existing = findByBookingId(booking.bookingId);
    if (existing) return existing;

    const rate = Number.isFinite(Number(vatPercent))
      ? Number(vatPercent)
      : Number.isFinite(Number(booking.vatPercent))
        ? Number(booking.vatPercent)
        : DEFAULT_VAT_PERCENT;

    const gross = Number(booking.totalAmount) || 0;
    const amounts = splitGross(gross, rate);
    const issuer = issuerFor(booking);
    const issuedAt = new Date().toISOString();
    const tripStartedAt =
      booking.pickupDate || booking.createdAt || booking.assignedAt || issuedAt;

    const receipt = {
      receiptId: crypto.randomUUID(),
      receiptNumber: nextNumber(),
      bookingId: booking.bookingId,
      issuedAt,
      tripStartedAt,
      completedAt: booking.updatedAt || issuedAt,
      startAddress: booking.addressLine || "",
      startLatitude: Number.isFinite(Number(booking.latitude)) ? Number(booking.latitude) : null,
      startLongitude: Number.isFinite(Number(booking.longitude))
        ? Number(booking.longitude)
        : null,
      destinationAddress: booking.destinationAddressLine || null,
      paymentMethod: booking.paymentMethod || "Unbekannt",
      paymentStatus: booking.paymentStatus || null,
      paymentIntentId: booking.paymentIntentId || null,
      passengerEmail: booking.passengerEmail || null,
      driverId: booking.assignedDriverId || null,
      ...amounts,
      currency: "EUR",
      issuer,
      pdfRelativePath: null,
      emailSentAt: null,
      emailError: null,
      gobd: {
        immutable: true,
        consecutive: true,
        retentionYears: 8,
        note: "GoBD: fortlaufende Nr., unveraenderbar nach Ausstellung; Aufbewahrung 8 Jahre (AO).",
      },
    };

    receipts.unshift(receipt);
    booking.receiptId = receipt.receiptId;
    booking.receiptNumber = receipt.receiptNumber;
    persist();
    return receipt;
  }

  function buildPdfLines(receipt) {
    const issuer = receipt.issuer || {};
    return [
      `Quittungsnr.: ${receipt.receiptNumber}`,
      `Ausgestellt: ${formatDeDate(receipt.issuedAt)}`,
      `Fahrtbeginn: ${formatDeDate(receipt.tripStartedAt)}`,
      `Abschluss: ${formatDeDate(receipt.completedAt)}`,
      "",
      `Aussteller: ${issuer.companyName || ""}`,
      issuer.street || "",
      issuer.city || "",
      issuer.vatId ? `USt-IdNr.: ${issuer.vatId}` : "",
      "",
      `Start: ${receipt.startAddress || "(ohne Adresse)"}`,
      receipt.startLatitude != null
        ? `Koordinaten: ${receipt.startLatitude}, ${receipt.startLongitude}`
        : "",
      receipt.destinationAddress ? `Ziel: ${receipt.destinationAddress}` : "",
      "",
      `Zahlungsart: ${receipt.paymentMethod || "-"}`,
      `Zahlungsstatus: ${receipt.paymentStatus || "-"}`,
      receipt.paymentIntentId ? `Stripe PI: ${receipt.paymentIntentId}` : "",
      "",
      `Netto: ${formatEuro(receipt.netAmount)}`,
      `MwSt. (${receipt.vatPercent} %): ${formatEuro(receipt.vatAmount)}`,
      `Brutto: ${formatEuro(receipt.grossAmount)}`,
      "",
      "Vielen Dank fuer Ihre Fahrt.",
      "Beleg nach GoBD fortlaufend nummeriert.",
    ].filter((line, idx, arr) => !(line === "" && arr[idx - 1] === ""));
  }

  function generatePdf(receipt) {
    const buf = buildSimplePdf({
      title: `Quittung ${receipt.receiptNumber}`,
      lines: buildPdfLines(receipt),
    });
    const filename = `${receipt.receiptNumber.replace(/[^A-Za-z0-9_-]/g, "_")}.pdf`;
    const abs = path.join(pdfDir, filename);
    fs.writeFileSync(abs, buf);
    receipt.pdfRelativePath = path.join("receipts-pdf", filename);
    receipt.pdfSha256 = crypto.createHash("sha256").update(buf).digest("hex");
    persist();
    return { absolutePath: abs, buffer: buf, filename };
  }

  function absolutePdfPath(receipt) {
    if (!receipt?.pdfRelativePath) return null;
    return path.join(dataDir, receipt.pdfRelativePath);
  }

  async function sendReceiptEmail(receipt, { force = false } = {}) {
    const email = String(receipt.passengerEmail || "").trim();
    if (!email || !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)) {
      return { skipped: true, reason: "no_passenger_email" };
    }
    if (receipt.emailSentAt && !force) {
      return { skipped: true, reason: "already_sent", emailSentAt: receipt.emailSentAt };
    }
    if (typeof opts.sendEmail !== "function") {
      return { skipped: true, reason: "email_not_configured" };
    }

    let pdf = null;
    const existingPath = absolutePdfPath(receipt);
    if (existingPath && fs.existsSync(existingPath)) {
      pdf = {
        buffer: fs.readFileSync(existingPath),
        filename: path.basename(existingPath),
      };
    } else {
      pdf = generatePdf(receipt);
    }

    const subject = `Ihre Quittung ${receipt.receiptNumber}`;
    const text = [
      `Guten Tag,`,
      ``,
      `anbei Ihre Quittung ${receipt.receiptNumber} fuer die Taxi-Fahrt.`,
      `Fahrtbeginn: ${formatDeDate(receipt.tripStartedAt)}`,
      `Start: ${receipt.startAddress || "-"}`,
      `Betrag brutto: ${formatEuro(receipt.grossAmount)} (inkl. ${receipt.vatPercent} % MwSt.)`,
      ``,
      `Mit freundlichen Gruessen`,
      String(receipt.issuer?.companyName || "Luckys Taxi App"),
    ].join("\n");

    try {
      await opts.sendEmail({
        to: email,
        subject,
        text,
        attachments: [
          {
            filename: pdf.filename,
            content: pdf.buffer.toString("base64"),
            contentType: "application/pdf",
          },
        ],
      });
      receipt.emailSentAt = new Date().toISOString();
      receipt.emailError = null;
      persist();
      return { ok: true, emailSentAt: receipt.emailSentAt };
    } catch (error) {
      receipt.emailError = error.message || String(error);
      persist();
      return { ok: false, error: receipt.emailError };
    }
  }

  /**
   * Nach Stripe-Zahlung: Quittung aktualisieren, PDF + Mail.
   */
  async function onPaymentSucceeded(booking, paymentIntentId) {
    if (!booking) return null;
    const receipt = ensureReceiptForBooking(booking);
    // GoBD: Beträge bleiben; Zahlungsstatus/PI nachziehen (kein Nummernwechsel)
    receipt.paymentStatus = "paid";
    receipt.paymentIntentId = paymentIntentId || receipt.paymentIntentId || booking.paymentIntentId;
    receipt.paidAt = booking.paidAt || new Date().toISOString();
    if (booking.passengerEmail && !receipt.passengerEmail) {
      receipt.passengerEmail = booking.passengerEmail;
    }
    if (Number(booking.totalAmount) > 0 && Number(booking.totalAmount) !== Number(receipt.grossAmount)) {
      // Betrag nur anpassen wenn Quittung noch ohne PDF / ohne Mail (sonst Storno nötig)
      if (!receipt.pdfRelativePath && !receipt.emailSentAt) {
        Object.assign(receipt, splitGross(booking.totalAmount, receipt.vatPercent));
      }
    }
    persist();
    generatePdf(receipt);
    const mail = await sendReceiptEmail(receipt);
    return { receipt, mail };
  }

  function listReceipts({ limit = 100, operatorId } = {}) {
    let list = receipts;
    if (operatorId) {
      list = list.filter((r) => r.issuer?.operatorId === operatorId || r.operatorId === operatorId);
    }
    return list.slice(0, Math.max(1, Math.min(500, Number(limit) || 100)));
  }

  function retentionPolicy() {
    return {
      liveGpsSeconds: Number(process.env.LOCATION_RETENTION_SECONDS || 3600),
      liveGpsNote: "Echtzeit-GPS nur fuer Disposition/Tracking; keine dauerhafte Bewegungsprofil-Archivierung.",
      bookingCoordsYears: 8,
      receiptsYears: 8,
      legalBasis: "Art. 6 Abs. 1 lit. b/c DSGVO i. V. m. AO/GoBD",
      vatPercentDefault: DEFAULT_VAT_PERCENT,
    };
  }

  return {
    ensureReceiptForBooking,
    generatePdf,
    sendReceiptEmail,
    onPaymentSucceeded,
    findByBookingId,
    findById,
    findByNumber,
    listReceipts,
    absolutePdfPath,
    retentionPolicy,
    pdfDir,
    DEFAULT_VAT_PERCENT,
  };
}

/**
 * Express-Routen für Quittungen / DSGVO-Retention-API.
 */
function mountReceiptRoutes(app, { store, requireAdmin }) {
  app.get("/api/legal/retention", (_req, res) => {
    res.json({
      phase: 7,
      label: "DSGVO-Speicherfristen & GoBD-Quittungen",
      retention: store.retentionPolicy(),
      privacyPage: "/datenschutz.html",
    });
  });

  app.get("/api/receipts", requireAdmin, (req, res) => {
    const limit = Number(req.query.limit || 100);
    const operatorId = String(req.query.operatorId || "").trim() || undefined;
    res.json({ receipts: store.listReceipts({ limit, operatorId }) });
  });

  app.get("/api/receipts/:id", requireAdmin, (req, res) => {
    const id = String(req.params.id || "").trim();
    const receipt =
      store.findById(id) || store.findByNumber(id) || store.findByBookingId(id);
    if (!receipt) return res.status(404).json({ error: "Receipt not found" });
    res.json({ receipt });
  });

  app.get("/api/receipts/:id/pdf", requireAdmin, (req, res) => {
    const id = String(req.params.id || "").trim();
    let receipt =
      store.findById(id) || store.findByNumber(id) || store.findByBookingId(id);
    if (!receipt) return res.status(404).json({ error: "Receipt not found" });
    let abs = store.absolutePdfPath(receipt);
    if (!abs || !fs.existsSync(abs)) {
      const gen = store.generatePdf(receipt);
      abs = gen.absolutePath;
    }
    res.setHeader("Content-Type", "application/pdf");
    res.setHeader(
      "Content-Disposition",
      `inline; filename="${path.basename(abs)}"`
    );
    fs.createReadStream(abs).pipe(res);
  });

  app.post("/api/receipts/:id/email", requireAdmin, async (req, res) => {
    const id = String(req.params.id || "").trim();
    const receipt =
      store.findById(id) || store.findByNumber(id) || store.findByBookingId(id);
    if (!receipt) return res.status(404).json({ error: "Receipt not found" });
    if (req.body?.passengerEmail) {
      receipt.passengerEmail = String(req.body.passengerEmail).trim();
    }
    const mail = await store.sendReceiptEmail(receipt, { force: Boolean(req.body?.force) });
    res.json({ ok: Boolean(mail.ok || mail.skipped), mail, receipt });
  });
}

module.exports = {
  createReceiptStore,
  mountReceiptRoutes,
  splitGross,
  DEFAULT_VAT_PERCENT,
};
