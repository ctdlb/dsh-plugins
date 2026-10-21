// Minimal OpenAI-compatible TTS shim backed by Azure Speech.
// Used by the `answer-me-with-html` skill: am video --voice local with AM_TTS_URL set to this server.
// The subscription key and region come from the environment (AZKEY / AZREGION); the file holds no secret.
import http from "node:http";
import https from "node:https";

const PORT = Number(process.env.PORT || 18321);
const REGION = process.env.AZREGION || "eastasia";
const KEY = process.env.AZKEY || "";
const DEFAULT_VOICE = process.env.AZDEFAULTVOICE || "zh-CN-XiaoxiaoNeural";
const OUTPUT_FORMAT = "riff-24khz-16bit-mono-pcm";

// Spoken-form substitutions, e.g. AM_TTS_SUBS='{"999":"九九九","120":"一二零"}'.
// Azure reads a bare "999" as 九百九十九; emergency numbers must be read digit by digit.
const SUBS = (() => {
  try {
    const raw = JSON.parse(process.env.AM_TTS_SUBS || "{}");
    return Object.entries(raw)
      .map(([k, v]) => [String(k), String(v)])
      .filter(([k, v]) => k && v)
      .sort((a, b) => b[0].length - a[0].length);
  } catch {
    return [];
  }
})();

function applySubs(text) {
  let out = text;
  for (const [from, to] of SUBS) out = out.split(from).join(to);
  return out;
}

if (!KEY) {
  console.error("AZKEY is empty; start this process with the key in its environment.");
  process.exit(1);
}

let token = null;
let tokenAt = 0;

function post(host, path, headers, body) {
  return new Promise((resolve, reject) => {
    const req = https.request(
      { host, path, method: "POST", headers: Object.assign({}, headers, { "Content-Length": Buffer.byteLength(body || "") }) },
      (res) => {
        const chunks = [];
        res.on("data", (c) => chunks.push(c));
        res.on("end", () => resolve({ status: res.statusCode, headers: res.headers, body: Buffer.concat(chunks) }));
      },
    );
    req.on("error", reject);
    req.setTimeout(60000, () => req.destroy(new Error("timeout")));
    if (body) req.write(body);
    req.end();
  });
}

async function getToken(force) {
  if (!force && token && Date.now() - tokenAt < 9 * 60 * 1000) return token;
  const res = await post(`${REGION}.api.cognitive.microsoft.com`, "/sts/v1.0/issueToken", {
    "Ocp-Apim-Subscription-Key": KEY,
  }, "");
  if (res.status !== 200) throw new Error(`issueToken HTTP ${res.status}: ${res.body.toString("utf8").slice(0, 200)}`);
  token = res.body.toString("utf8");
  tokenAt = Date.now();
  return token;
}

function escapeXml(text) {
  return text.replace(/[<>&'"]/g, (c) => ({ "<": "&lt;", ">": "&gt;", "&": "&amp;", "'": "&apos;", '"': "&quot;" }[c]));
}

function rate(speed) {
  const s = Number(speed);
  if (!Number.isFinite(s) || Math.abs(s - 1) < 0.01) return "";
  return `<prosody rate="${Math.round((s - 1) * 100)}%">`;
}

async function synthesize({ input, voice, speed }) {
  const name = voice && /^[a-z]{2}-[A-Z]{2}-/.test(voice) ? voice : DEFAULT_VOICE;
  const lang = name.split("-").slice(0, 2).join("-");
  const open = rate(speed);
  const ssml =
    `<speak version='1.0' xmlns='http://www.w3.org/2001/10/synthesis' xml:lang='${lang}'>` +
    `<voice name='${name}'>${open}${escapeXml(applySubs(input))}${open ? "</prosody>" : ""}</voice></speak>`;
  let jwt = await getToken(false);
  let res = await send(jwt, ssml);
  if (res.status === 401) {
    jwt = await getToken(true);
    res = await send(jwt, ssml);
  }
  if (res.status !== 200) throw new Error(`synthesize HTTP ${res.status}: ${res.body.toString("utf8").slice(0, 300)}`);
  return res.body;
}

function send(jwt, ssml) {
  return post(`${REGION}.tts.speech.microsoft.com`, "/cognitiveservices/v1", {
    Authorization: `Bearer ${jwt}`,
    "Content-Type": "application/ssml+xml",
    "X-Microsoft-OutputFormat": OUTPUT_FORMAT,
    "User-Agent": "dsh-tts-shim",
  }, ssml);
}

const server = http.createServer((req, res) => {
  if (req.method === "GET" && (req.url === "/health" || req.url === "/")) {
    res.writeHead(200, { "Content-Type": "application/json" });
    res.end(JSON.stringify({ ok: true, region: REGION, voice: DEFAULT_VOICE, subs: SUBS.length }));
    return;
  }
  if (req.method !== "POST" || !req.url.startsWith("/v1/audio/speech")) {
    res.writeHead(404, { "Content-Type": "application/json" });
    res.end(JSON.stringify({ error: { message: "not found" } }));
    return;
  }
  const chunks = [];
  req.on("data", (c) => chunks.push(c));
  req.on("end", async () => {
    try {
      const body = JSON.parse(Buffer.concat(chunks).toString("utf8") || "{}");
      const text = String(body.input || "").trim();
      if (!text) throw new Error("input is empty");
      const wav = await synthesize({ input: text, voice: body.voice, speed: body.speed });
      res.writeHead(200, { "Content-Type": "audio/wav", "Content-Length": wav.length });
      res.end(wav);
      console.log(`[${new Date().toISOString().slice(11, 19)}] ${text.length} chars -> ${wav.length} bytes`);
    } catch (e) {
      console.error("error:", e.message);
      res.writeHead(500, { "Content-Type": "application/json" });
      res.end(JSON.stringify({ error: { message: e.message } }));
    }
  });
});

server.listen(PORT, "127.0.0.1", () => {
  console.log(`azure tts shim on http://127.0.0.1:${PORT}  region=${REGION}  voice=${DEFAULT_VOICE}`);
});
