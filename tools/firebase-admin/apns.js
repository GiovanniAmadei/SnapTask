// Minimal APNs client (token-based auth, HTTP/2) with no extra dependencies.
//
// Env (all optional):
//   APNS_KEY_PATH  path to the .p8 key   (default: <repo>/AuthKey_QVFJN9UACT.p8, gitignored)
//   APNS_KEY_ID    key id                 (default: QVFJN9UACT)
//   APNS_TEAM_ID   Apple team id          (default: Y997848SS8)

const crypto = require("crypto");
const fs = require("fs");
const http2 = require("http2");
const path = require("path");

const KEY_PATH = process.env.APNS_KEY_PATH || path.resolve(__dirname, "../../AuthKey_QVFJN9UACT.p8");
const KEY_ID = process.env.APNS_KEY_ID || "QVFJN9UACT";
const TEAM_ID = process.env.APNS_TEAM_ID || "Y997848SS8";

const HOSTS = {
  production: "https://api.push.apple.com",
  sandbox: "https://api.sandbox.push.apple.com",
};

let cachedJwt = null;

function base64url(input) {
  return Buffer.from(input).toString("base64").replace(/=/g, "").replace(/\+/g, "-").replace(/\//g, "_");
}

// APNs accepts the same token for up to 60 minutes; refresh after 50.
function providerToken() {
  const now = Math.floor(Date.now() / 1000);
  if (cachedJwt && now - cachedJwt.issuedAt < 50 * 60) return cachedJwt.token;

  const header = base64url(JSON.stringify({ alg: "ES256", kid: KEY_ID }));
  const claims = base64url(JSON.stringify({ iss: TEAM_ID, iat: now }));
  const signature = crypto.sign("sha256", Buffer.from(`${header}.${claims}`), {
    key: fs.readFileSync(KEY_PATH, "utf8"),
    dsaEncoding: "ieee-p1363",
  });
  cachedJwt = { token: `${header}.${claims}.${base64url(signature)}`, issuedAt: now };
  return cachedJwt.token;
}

/**
 * Sends one push. Resolves to { status, reason } — never throws for APNs rejections,
 * so callers can decide (e.g. drop the token on 410 / BadDeviceToken).
 */
function sendPush({ token, environment = "production", topic, payload, collapseId }) {
  return new Promise((resolve, reject) => {
    const client = http2.connect(HOSTS[environment] || HOSTS.production);
    client.on("error", reject);

    const headers = {
      ":method": "POST",
      ":path": `/3/device/${token}`,
      authorization: `bearer ${providerToken()}`,
      "apns-topic": topic,
      "apns-push-type": "alert",
      "apns-priority": "10",
    };
    if (collapseId) headers["apns-collapse-id"] = collapseId;

    const req = client.request(headers);
    let status = 0;
    let body = "";
    req.on("response", (h) => { status = h[":status"]; });
    req.setEncoding("utf8");
    req.on("data", (chunk) => { body += chunk; });
    req.on("end", () => {
      client.close();
      let reason = null;
      try { reason = body ? JSON.parse(body).reason : null; } catch { reason = body; }
      resolve({ status, reason });
    });
    req.on("error", (err) => { client.close(); reject(err); });
    req.end(JSON.stringify(payload));
  });
}

module.exports = { sendPush };
