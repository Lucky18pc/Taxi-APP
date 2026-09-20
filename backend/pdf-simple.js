/**
 * Minimal PDF 1.4 text generator (Helvetica) — keine Extra-Dependency.
 * Geeignet fuer GoBD-Quittungen mit lateinischem Text + Euro-Betraegen.
 */

function escapePdfText(text) {
  const map = {
    "\u00C4": "Ae",
    "\u00D6": "Oe",
    "\u00DC": "Ue",
    "\u00E4": "ae",
    "\u00F6": "oe",
    "\u00FC": "ue",
    "\u00DF": "ss",
    "\u20AC": "EUR",
    "\u2013": "-",
    "\u2014": "-",
    "\u201E": '"',
    "\u201C": '"',
    "\u201D": '"',
    "\u201A": "'",
    "\u2018": "'",
    "\u2019": "'",
  };
  return String(text || "")
    .replace(/[\u00C4\u00D6\u00DC\u00E4\u00F6\u00FC\u00DF\u20AC\u2013\u2014\u201E\u201C\u201D\u201A\u2018\u2019]/g, (ch) => map[ch] || "?")
    .replace(/[^\x20-\x7E]/g, "?")
    .replace(/\\/g, "\\\\")
    .replace(/\(/g, "\\(")
    .replace(/\)/g, "\\)");
}

/**
 * @param {{ title?: string, lines: string[] }} doc
 * @returns {Buffer}
 */
function buildSimplePdf(doc) {
  const title = escapePdfText(doc.title || "Quittung");
  const lines = (doc.lines || []).map((l) => escapePdfText(l));

  const contentLines = [];
  contentLines.push("BT");
  contentLines.push("/F1 16 Tf");
  contentLines.push("50 780 Td");
  contentLines.push(`(${title}) Tj`);
  contentLines.push("/F1 10 Tf");
  contentLines.push("0 -28 Td");

  for (let i = 0; i < lines.length; i += 1) {
    const line = lines[i] || " ";
    if (i > 0) contentLines.push("0 -14 Td");
    contentLines.push(`(${line}) Tj`);
  }
  contentLines.push("ET");

  const stream = contentLines.join("\n");
  const streamLen = Buffer.byteLength(stream, "utf8");

  const objects = [];
  objects.push("1 0 obj\n<< /Type /Catalog /Pages 2 0 R >>\nendobj\n");
  objects.push("2 0 obj\n<< /Type /Pages /Kids [3 0 R] /Count 1 >>\nendobj\n");
  objects.push(
    "3 0 obj\n<< /Type /Page /Parent 2 0 R /MediaBox [0 0 595 842] /Contents 4 0 R /Resources << /Font << /F1 5 0 R >> >> >>\nendobj\n"
  );
  objects.push(`4 0 obj\n<< /Length ${streamLen} >>\nstream\n${stream}\nendstream\nendobj\n`);
  objects.push("5 0 obj\n<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>\nendobj\n");

  let pdf = "%PDF-1.4\n";
  const offsets = [0];
  for (const obj of objects) {
    offsets.push(Buffer.byteLength(pdf, "utf8"));
    pdf += obj;
  }
  const xrefPos = Buffer.byteLength(pdf, "utf8");
  pdf += `xref\n0 ${objects.length + 1}\n`;
  pdf += "0000000000 65535 f \n";
  for (let i = 1; i <= objects.length; i += 1) {
    pdf += `${String(offsets[i]).padStart(10, "0")} 00000 n \n`;
  }
  pdf += `trailer\n<< /Size ${objects.length + 1} /Root 1 0 R >>\n`;
  pdf += `startxref\n${xrefPos}\n%%EOF\n`;
  return Buffer.from(pdf, "utf8");
}

module.exports = { buildSimplePdf, escapePdfText };
