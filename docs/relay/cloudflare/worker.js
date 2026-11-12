// API relay for the VPN client, as a Cloudflare Worker.
//
// When Mozilla's sign-in, Guardian, or server list cannot be reached from
// your network, the client sends those requests (never the VPN traffic)
// through this relay: set its URL in the app's Settings > Connection >
// "If Mozilla is blocked" > "Cloudflare Worker", for example
// https://relay.NAME.workers.dev/?secret=SECRET
// Opened in a browser, the URL shows whether the relay works.
//
// The client asks for /?url=<target>; the relay sends the same method,
// headers, and body to the target and answers with its response. Only the
// hosts below are relayed, so the relay is not an open proxy for others.
//
// Deploy: Cloudflare dashboard > Workers & Pages > Create > Worker, paste
// this file, set SECRET with `wrangler secret put SECRET` (never in the code),
// Deploy. The client's authenticated ?health=1 check verifies only that this
// worker is responding. It does not make any request to Guardian or another
// host.

// A secret only your client knows, which the relay URL ends in: ?secret=SECRET.
// Required: without one the relay relays nothing (the sign-in and the account
// tokens cross it). Keep it in a Worker secret binding; the empty default means
// "not set up yet", which the worker refuses to run with.
const SECRET = "";

// The names this relay answers with, so a client can tell a relay it can trust
// from a page that merely answered. Both spellings are accepted: the app's own
// documentation and the reference core use each of them.
const RELAY_NAME = "spider-firefox-vpn";
const RELAY_NAMES = [RELAY_NAME, "arman-vpn"];
const HEALTH_VERSION = 1;

// The marker header that says "this answer came back through the relay", so a
// client is not fooled by a Cloudflare error page generated before the worker
// ran (an exhausted quota, for instance).
const RELAY_HEADER = "X-Spider-Relay";
const RELAY_HEADER_ALIASES = ["X-Spider-Relay", "X-Arman-Relay"];

const ALLOWED = [
  "mozilla.org", "mozilla.com", "firefox.com", // accounts, Guardian, server list
  "github.com", "githubusercontent.com", "jsdelivr.net", // geo files, flags
];

const DROP = ["host", "connection", "content-length", "content-encoding", "keep-alive", "proxy-authenticate",
  "proxy-authorization", "te", "trailer", "transfer-encoding", "upgrade", "forwarded", "x-forwarded-for",
  "x-forwarded-proto", "x-forwarded-host", "x-real-ip", "true-client-ip", ...RELAY_HEADER_ALIASES.map((h) => h.toLowerCase())];

// The page for whoever opens the relay's URL in a browser (no url parameter).
const STATES = {
  works: {
    status: 200, color: "#10b981", badge: "✓ Working",
    title: "Your relay is ready",
    text: "Put this page's address in the app:",
    path: ["Settings", "Connection", "If Mozilla is blocked", "Cloudflare Worker"],
  },
  wrong: {
    status: 403, color: "#ef4444", badge: "✗ Wrong secret",
    title: "This address has no secret, or the wrong one",
    text: "It must end in <code>?secret=</code> followed by the SECRET set in the worker.",
  },
  unset: {
    status: 503, color: "#f59e0b", badge: "⚠ Not set up",
    title: "Set a secret first",
    text: "Set <code>SECRET</code> with <code>wrangler secret put SECRET</code>, deploy again, and open this address with <code>?secret=…</code> at the end.",
  },
};

function page(state) {
  const s = STATES[state];
  const path = s.path ? `<div class="path">${s.path.map((p) => `<span>${p}</span>`).join("<i>›</i>")}</div>` : "";
  const html = `<!doctype html><html lang="en"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>VPN relay</title>
<style>
:root{--bg:#eef0fb;--card:#fff;--text:#1d2040;--muted:#5d6385;--accent:#5b5bd6;--c:${s.color}}
@media (prefers-color-scheme:dark){:root{--bg:#0b0e1f;--card:#151a35;--text:#eef0ff;--muted:#9aa3c7;--accent:#8b8ff8}}
*{box-sizing:border-box}
body{margin:0;min-height:100vh;display:grid;place-items:center;padding:24px;color:var(--text);
font:16px/1.65 system-ui,-apple-system,"Segoe UI",Roboto,sans-serif;
background:radial-gradient(900px 500px at 15% -10%,color-mix(in srgb,var(--accent) 28%,transparent),transparent),
radial-gradient(700px 500px at 110% 110%,color-mix(in srgb,var(--c) 22%,transparent),transparent),var(--bg)}
.card{width:min(560px,100%);background:var(--card);border-radius:22px;padding:34px 32px;
box-shadow:0 24px 70px rgba(20,27,61,.18);border-top:5px solid var(--c)}
.brand{display:flex;align-items:center;gap:10px;font-weight:700;color:var(--muted);font-size:14px;letter-spacing:.02em}
.dot{width:10px;height:10px;border-radius:50%;background:var(--accent)}
.badge{display:inline-block;margin-top:22px;padding:6px 14px;border-radius:999px;font-weight:700;font-size:14px;
color:var(--c);background:color-mix(in srgb,var(--c) 15%,transparent)}
h1{font-size:23px;line-height:1.3;margin:14px 0 8px}
p{margin:0;color:var(--muted)}
code{background:color-mix(in srgb,var(--accent) 12%,transparent);color:var(--accent);padding:1px 6px;border-radius:6px}
.path{display:flex;flex-wrap:wrap;align-items:center;gap:6px;margin-top:16px}
.path span{padding:5px 12px;border-radius:10px;font-weight:600;font-size:14px;
background:color-mix(in srgb,var(--accent) 13%,transparent);color:var(--accent)}
.path i{color:var(--muted);font-style:normal}
</style>
<div class="card"><div class="brand"><span class="dot"></span>VPN relay</div>
<span class="badge">${s.badge}</span><h1>${s.title}</h1><p>${s.text}</p>${path}</div></html>`;
  return new Response(html, { status: s.status, headers: { "Content-Type": "text/html; charset=utf-8", "Cache-Control": "no-store" } });
}

function fail(status, why) {
  return new Response(why, { status, headers: { "X-Relay-Error": why, "Content-Type": "text/plain; charset=utf-8", "Cache-Control": "no-store" } });
}

// A local response proves that the worker currently accepts requests; a Cloudflare
// quota or availability error cannot produce this success body.
function health() {
  return new Response(JSON.stringify({
    relay: RELAY_NAME, aliases: RELAY_NAMES, version: HEALTH_VERSION, ready: true,
  }), {
    status: 200,
    headers: { "Content-Type": "application/json", "Cache-Control": "no-store" },
  });
}

export default {
  async fetch(request, env = {}) {
    const here = new URL(request.url);
    const probe = here.searchParams.get("health") === "1";
    const browser = !here.searchParams.has("url") && !probe;
    const secret = env.SECRET ?? SECRET;

    if (!secret) return browser ? page("unset") : fail(503, "no secret is set in the relay");
    if (here.searchParams.get("secret") !== secret) return browser ? page("wrong") : fail(403, "wrong secret");

    if (probe) {
      if (request.method !== "GET") return fail(405, "health requires GET");
      return health();
    }

    if (browser) return page("works");

    let target;
    try {
      target = new URL(here.searchParams.get("url") || "");
    } catch {
      return fail(400, "url must be an https URL");
    }
    if (target.protocol !== "https:") return fail(400, "url must be an https URL");
    if (target.username || target.password || target.hash || (target.port && target.port !== "443")) {
      return fail(400, "target must not contain credentials, a fragment or a non-HTTPS port");
    }

    const host = target.hostname.toLowerCase();
    if (!ALLOWED.some((domain) => host === domain || host.endsWith("." + domain))) {
      return fail(403, `host not allowed: ${host}`);
    }

    const headers = new Headers();
    for (const [name, value] of request.headers) {
      const lower = name.toLowerCase();
      if (DROP.includes(lower) || lower.startsWith("cf-")) continue;
      headers.set(name, value);
    }

    // The client's requests are small (sign-in, tokens): read whole.
    const hasBody = request.method !== "GET" && request.method !== "HEAD";
    const body = hasBody ? await request.arrayBuffer() : undefined;

    try {
      // Redirects go back to the client, which follows them through the relay.
      const upstream = await fetch(target, { method: request.method, headers, body, redirect: "manual" });
      const responseHeaders = new Headers(upstream.headers);
      // Distinguish a forwarded Guardian response from a Cloudflare error
      // generated before the worker runs (for example an exhausted quota), and
      // answer both spellings a client may look for.
      for (const header of RELAY_HEADER_ALIASES) responseHeaders.set(header, "1");
      return new Response(upstream.body, { status: upstream.status, statusText: upstream.statusText, headers: responseHeaders });
    } catch {
      return fail(502, "upstream request failed");
    }
  },
};
