const $ = (id) => document.getElementById(id);
const log = (...a) => { $("out").textContent += a.join(" ") + "\n"; };
const API = "https://lms.kumoh.ac.kr:82/api/v1";
const ORIGIN = "https://lms.kumoh.ac.kr";
const CANVAS = "https://canvas.kumoh.ac.kr";
const mask = (v) => (!v ? "<empty>" : `${v.slice(0, 4)}…(${v.length}자)`);

let ready;
function init() {
  return (ready ??= (async () => {
    await libcurl.load_wasm("/libcurl.wasm");
    libcurl.set_websocket(`ws://${location.host}/`);
  })());
}

// 앱의 Dart CookieJar 역할을 흉내 내는 최소 저장소. 이름 → {value, domain}
const jar = new Map();
function storeCookies(res, url) {
  for (const [name, value] of res.raw_headers) {
    if (name.toLowerCase() !== "set-cookie") continue;
    const [pair, ...attrs] = value.split(";");
    const i = pair.indexOf("=");
    const key = pair.slice(0, i).trim();
    const domainAttr = attrs.map((a) => a.trim()).find((a) => a.toLowerCase().startsWith("domain="));
    const domain = domainAttr ? domainAttr.slice(7).replace(/^\./, "") : new URL(url).hostname;
    jar.set(key, { value: pair.slice(i + 1).trim(), domain });
    log(`    Set-Cookie 읽힘: ${key}=${mask(pair.slice(i + 1).trim())} (${domain})`);
  }
}
function cookieHeader(url) {
  const host = new URL(url).hostname;
  return [...jar]
    .filter(([, c]) => host === c.domain || host.endsWith("." + c.domain))
    .map(([n, c]) => `${n}=${c.value}`)
    .join("; ");
}
async function curl(url, opts = {}) {
  const headers = { ...(opts.headers || {}) };
  const cookie = cookieHeader(url);
  if (cookie) headers.Cookie = cookie;
  const res = await libcurl.fetch(url, { ...opts, headers, redirect: "manual", _libcurl_http_version: 1.1 });
  storeCookies(res, url);
  return res;
}

async function bridge() {
  await init();
  jar.clear();
  const json = { "Content-Type": "application/json", Origin: ORIGIN, Referer: ORIGIN + "/" };
  log("[1] LINUS 로그인 (Origin 헤더 지정)");
  let res = await curl(`${API}/login`, {
    method: "POST",
    headers: json,
    body: JSON.stringify({ userId: $("id").value.trim().toUpperCase(), password: $("pw").value }),
  });
  const body = await res.json();
  log(`    status ${res.status}, code ${body.code}`);
  const { accessToken, refreshToken } = body.data || {};
  if (!accessToken) throw new Error("토큰 없음");
  log(`    accessToken ${mask(accessToken)}`);
  const auth = { ...json, Authorization: `Bearer ${accessToken}`, "X-Refresh-Token": refreshToken };
  jar.set("_linus_saml_login", { value: accessToken, domain: "kumoh.ac.kr" });
  jar.set("_linus_saml_domain", { value: "/courses", domain: "kumoh.ac.kr" });

  log("[2] SSO 진입 URL");
  res = await curl(`${API}/saml/redirect.do?relayState=%2Fcourses`, { headers: auth });
  let url = (await res.text()).trim();
  log(`    host ${new URL(url).host}`);

  log("[3] 리다이렉트 수동 추적 (redirect: manual이 먹는지 확인)");
  let html = "";
  for (let hop = 0; hop < 10; hop++) {
    res = await curl(url, { headers: { Accept: "text/html" } });
    const loc = res.headers.get("location");
    log(`    hop ${hop}: ${res.status} ${new URL(url).host}${loc ? " -> " + new URL(loc, url).host : ""}`);
    if (res.status >= 300 && res.status < 400 && loc) {
      url = new URL(loc, url).href;
      continue;
    }
    html = await res.text();
    break;
  }
  const action = html.match(/<form[^>]*action="([^"]+)"/i)?.[1];
  const saml = html.match(/<input[^>]*name="SAMLResponse"[^>]*value="([^"]*)"/i)?.[1];
  const relay = html.match(/<input[^>]*name="RelayState"[^>]*value="([^"]*)"/i)?.[1] ?? "/";
  log(`    폼 action ${action ? new URL(action).host : "없음"}, SAMLResponse ${mask(saml)}`);
  if (!action || !saml) throw new Error("SAML 폼 없음");
  return { action, saml, relay };
}

async function testTunnel() {
  const form = await bridge();
  log("[4] ACS POST (터널)");
  const acs = await curl(form.action, {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({ SAMLResponse: form.saml, RelayState: form.relay }).toString(),
  });
  log(`    status ${acs.status}, _normandy_session ${jar.has("_normandy_session") ? "있음" : "없음"}`);
  const accept = { headers: { Accept: "application/json" } };
  const profile = await curl(`${CANVAS}/api/v1/users/self/profile`, accept);
  log(`[5] Canvas profile status ${profile.status}`);
  const coursesRes = await curl(`${CANVAS}/api/v1/courses?per_page=1&enrollment_state=active`, accept);
  const courses = coursesRes.status === 200 ? await coursesRes.json() : [];
  log(`[6] courses status ${coursesRes.status}, ${courses.length}건`);
  if (!courses[0]) return;
  const filesRes = await curl(`${CANVAS}/api/v1/courses/${courses[0].id}/files?per_page=1`, accept);
  const files = filesRes.status === 200 ? await filesRes.json() : [];
  log(`[7] files status ${filesRes.status}, ${files.length}건`);
  if (!files[0]) return;
  const dl = await curl(`${CANVAS}/files/${files[0].id}/download?download_frd=1`);
  const loc = dl.headers.get("location");
  log(`    download status ${dl.status} -> ${loc ? new URL(loc, CANVAS).host : "(리다이렉트 없음)"}`);
}

async function testBrowserPost() {
  // await 이전, 클릭 처리 안에서 창을 연다. 뒤에서 열면 팝업 차단된다.
  const win = window.open("", "_blank");
  if (!win) {
    log("팝업이 차단됨");
    return;
  }
  win.document.write("<p>연결 중…</p>");
  try {
    const form = await bridge();
    const doc = win.document;
    doc.body.innerHTML = "";
    const el = doc.createElement("form");
    el.method = "POST";
    el.action = form.action;
    for (const [name, value] of [["SAMLResponse", form.saml], ["RelayState", form.relay]]) {
      const input = doc.createElement("input");
      input.type = "hidden";
      input.name = name;
      input.value = value;
      el.appendChild(input);
    }
    doc.body.appendChild(el);
    el.submit();
    log("[4] 새 창에서 ACS POST 제출. 새 창이 로그인된 Canvas 강좌 목록이면 성공, 로그인 화면·오류면 실패");
  } catch (e) {
    win.close();
    throw e;
  }
}

const run = (fn) => () => fn().catch((e) => log("실패:", e.message));
$("tunnel").onclick = run(testTunnel);
$("browser").onclick = run(testBrowserPost);
