"use strict";

const OTPAuth = require("otpauth");

function generateSecret() {
  return new OTPAuth.Secret({ size: 20 }).base32;
}

function makeTotp(secretBase32) {
  return new OTPAuth.TOTP({
    issuer: "Luckys Taxi App",
    label: "Luckys Admin",
    algorithm: "SHA1",
    digits: 6,
    period: 30,
    secret: OTPAuth.Secret.fromBase32(String(secretBase32 || "").replace(/\s/g, "")),
  });
}

function verifyTotp(secretBase32, token, window = 2) {
  const code = String(token || "").replace(/\D/g, "");
  if (!/^\d{6}$/.test(code) || !secretBase32) return false;
  try {
    const delta = makeTotp(secretBase32).validate({ token: code, window });
    return delta !== null;
  } catch {
    return false;
  }
}

function currentTotp(secretBase32) {
  return makeTotp(secretBase32).generate();
}

function otpauthUrl({ secret, accountName, issuer }) {
  const totp = new OTPAuth.TOTP({
    issuer: issuer || "Luckys Taxi App",
    label: accountName || "Luckys Admin",
    algorithm: "SHA1",
    digits: 6,
    period: 30,
    secret: OTPAuth.Secret.fromBase32(String(secret || "").replace(/\s/g, "")),
  });
  return totp.toString();
}

module.exports = {
  generateSecret,
  verifyTotp,
  currentTotp,
  otpauthUrl,
};
