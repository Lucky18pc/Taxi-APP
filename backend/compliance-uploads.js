const fs = require("fs");
const path = require("path");
const crypto = require("crypto");
const multer = require("multer");

const ALLOWED_MIME = new Set(["image/jpeg", "image/png", "application/pdf"]);
const MAX_BYTES = 5 * 1024 * 1024;

const OPERATOR_DOC_FIELDS = ["concessionDocument", "ownerPScheinDocument"];
const DRIVER_DOC_FIELDS = ["pScheinDocument", "licenseDocument", "photo"];
const IMAGE_ONLY_DOC_FIELDS = new Set(["photo"]);

function ensureUploadsRoot(dataDir) {
  const root = path.join(dataDir, "uploads");
  fs.mkdirSync(root, { recursive: true });
  return root;
}

function extensionForMime(mime) {
  if (mime === "image/jpeg") return ".jpg";
  if (mime === "image/png") return ".png";
  if (mime === "application/pdf") return ".pdf";
  return "";
}

function sanitizeOriginalName(name) {
  return String(name || "upload")
    .replace(/[^\w.\-äöüÄÖÜß ]+/g, "_")
    .slice(0, 120);
}

function createUploadMiddleware() {
  return multer({
    storage: multer.memoryStorage(),
    limits: { fileSize: MAX_BYTES, files: 8 },
    fileFilter(_req, file, cb) {
      if (!ALLOWED_MIME.has(file.mimetype)) {
        return cb(new Error("Nur JPEG, PNG oder PDF (max. 5 MB)"));
      }
      cb(null, true);
    },
  });
}

function saveDocumentFile(dataDir, operatorId, kind, file) {
  if (!file || !file.buffer) return null;
  if (IMAGE_ONLY_DOC_FIELDS.has(kind)) {
    if (file.mimetype !== "image/jpeg" && file.mimetype !== "image/png") {
      throw new Error("Profilfoto nur als JPEG oder PNG");
    }
  } else if (!ALLOWED_MIME.has(file.mimetype)) {
    throw new Error("Nur JPEG, PNG oder PDF erlaubt");
  }
  if (file.size > MAX_BYTES) {
    throw new Error("Datei zu groß (max. 5 MB)");
  }

  const id = crypto.randomUUID();
  const ext = extensionForMime(file.mimetype) || path.extname(file.originalname || "") || ".bin";
  const dirRel = path.join(operatorId || "pending", kind);
  const absDir = path.join(ensureUploadsRoot(dataDir), dirRel);
  fs.mkdirSync(absDir, { recursive: true });

  const filename = `${id}${ext}`;
  const absPath = path.join(absDir, filename);
  fs.writeFileSync(absPath, file.buffer);

  return {
    id,
    kind,
    originalName: sanitizeOriginalName(file.originalname),
    mimeType: file.mimetype,
    relativePath: path.join("uploads", dirRel, filename).split(path.sep).join("/"),
    size: file.size,
    uploadedAt: new Date().toISOString(),
  };
}

function resolveAbsolutePath(dataDir, relativePath) {
  const rel = String(relativePath || "").replace(/^\/+/, "");
  if (!rel.startsWith("uploads/") || rel.includes("..")) return null;
  const abs = path.join(dataDir, rel);
  const root = path.join(dataDir, "uploads");
  if (!abs.startsWith(root)) return null;
  if (!fs.existsSync(abs)) return null;
  return abs;
}

function deleteDocumentFile(dataDir, meta) {
  if (!meta?.relativePath) return;
  const abs = resolveAbsolutePath(dataDir, meta.relativePath);
  if (abs) {
    try {
      fs.unlinkSync(abs);
    } catch {
      /* ignore */
    }
  }
}

function documentPublicMeta(meta) {
  if (!meta || !meta.id) return null;
  return {
    id: meta.id,
    kind: meta.kind,
    originalName: meta.originalName || "",
    mimeType: meta.mimeType || "",
    size: meta.size || 0,
    uploadedAt: meta.uploadedAt || null,
    present: true,
  };
}

function parseBool(raw) {
  if (raw === true || raw === "true" || raw === "on" || raw === "1") return true;
  if (raw === false || raw === "false" || raw === "off" || raw === "0" || raw === "") return false;
  return Boolean(raw);
}

function pickComplianceTextFields(body = {}) {
  const out = {};
  if (body.concessionNumber !== undefined) {
    out.concessionNumber = String(body.concessionNumber || "").trim();
  }
  if (body.concessionAuthority !== undefined) {
    out.concessionAuthority = String(body.concessionAuthority || "").trim();
  }
  if (body.concessionValidUntil !== undefined) {
    out.concessionValidUntil = String(body.concessionValidUntil || "").trim();
  }
  if (body.ownerHasPSchein !== undefined) {
    out.ownerHasPSchein = parseBool(body.ownerHasPSchein);
  }
  if (body.ownerPScheinNumber !== undefined) {
    out.ownerPScheinNumber = String(body.ownerPScheinNumber || "").trim();
  }
  if (body.ownerPScheinValidUntil !== undefined) {
    out.ownerPScheinValidUntil = String(body.ownerPScheinValidUntil || "").trim();
  }
  return out;
}

function pickDriverComplianceFields(body = {}) {
  const out = {};
  if (body.taxiNumber !== undefined) out.taxiNumber = String(body.taxiNumber || "").trim();
  if (body.pScheinNumber !== undefined) out.pScheinNumber = String(body.pScheinNumber || "").trim();
  if (body.pScheinValidUntil !== undefined) {
    out.pScheinValidUntil = String(body.pScheinValidUntil || "").trim();
  }
  if (body.licenseNumber !== undefined) out.licenseNumber = String(body.licenseNumber || "").trim();
  return out;
}

function complianceGaps(operator) {
  const gaps = [];
  if (!String(operator?.concessionNumber || "").trim()) gaps.push("Konzessionsnummer");
  if (!operator?.documents?.concessionDocument) gaps.push("Konzessions-Dokument");
  if (operator?.ownerHasPSchein) {
    if (!String(operator?.ownerPScheinNumber || "").trim()) gaps.push("Inhaber-P-Schein-Nummer");
    if (!operator?.documents?.ownerPScheinDocument) gaps.push("Inhaber-P-Schein-Dokument");
  }
  return gaps;
}

module.exports = {
  ALLOWED_MIME,
  MAX_BYTES,
  OPERATOR_DOC_FIELDS,
  DRIVER_DOC_FIELDS,
  createUploadMiddleware,
  saveDocumentFile,
  resolveAbsolutePath,
  deleteDocumentFile,
  documentPublicMeta,
  pickComplianceTextFields,
  pickDriverComplianceFields,
  complianceGaps,
  parseBool,
};
