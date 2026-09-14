# iOS PWA 블라인드 중계 1단계 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** iPhone 홈 화면 PWA에서 로그인·강의·과제·공지를 볼 수 있게 한다. 학교 서버와의 TLS는 브라우저 안에서 종단하고, NAS 중계 서버는 암호문만 전달한다.

**Architecture:** Flutter 앱을 웹으로도 빌드한다. 웹에서는 Dio 어댑터가 libcurl.js(WASM)로 요청을 보내고, libcurl.js는 Wisp 프로토콜로 NAS의 wisp-js 서버에 TCP를 연다. 쿠키·리다이렉트·SAML 브리지는 기존 Dart 코드를 재사용한다. 모바일 코드 경로는 바꾸지 않고, 웹 차이는 조건부 import로 격리한다.

**Tech Stack:** Flutter 3.47.2 / Dart 3.13.2, dio 5.11.1, drift 2.31.0(웹: WasmDatabase), sqlite3 2.9.4, libcurl.js 0.7.4, @mercuryworkshop/wisp-js 0.5.0, Node 24, Docker, GitHub Actions, GitHub Pages

**Spec:** `docs/superpowers/specs/2026-09-14-pwa-blind-relay-design.md`

## Global Constraints

- 모바일(Android/iOS) 동작을 바꾸지 않는다. 기존 VM 테스트(현재 292개)는 모든 태스크 후 전부 통과해야 한다.
- 웹 차이는 `export 'x_native.dart' if (dart.library.js_interop) 'x_web.dart';` 형태의 조건부 export로만 격리한다.
- 중계 서버가 연결을 허용하는 곳: 호스트 `lms.kumoh.ac.kr`, `canvas.kumoh.ac.kr`, 포트 `82`, `443`. 사설 IP, 루프백, IP 직접 지정, UDP는 금지한다.
- 중계 서버는 WebSocket `Origin`이 허용 목록(운영: `https://barahana25.github.io`)에 없으면 403으로 거부한다.
- 웹 런타임 파일(libcurl.js, libcurl.wasm, sqlite3.wasm, drift_worker.js)은 `web/vendor/`에 커밋하고 `web/vendor/SHA256SUMS`로 검증한다. CDN에서 불러오지 않는다.
- 웹에서는 비밀번호를 저장하지 않는다.
- PWA 주소: `https://barahana25.github.io/kumoh-LMS/` (`--base-href /kumoh-LMS/`).
- Windows 개발 환경의 Flutter 경로: `C:\src\flutter\bin\flutter.bat`. 로컬 자격증명 파일 `env`는 출력하거나 커밋하지 않는다.
- 커밋 메시지는 기존 형식(`feat:`, `fix:`, `docs:`, `chore:` + 한국어 요약)을 따르고 끝에 `Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>`를 붙인다.
- push와 GitHub 설정 변경(Pages 활성화, 변수 등록)은 사용자 확인 후에만 한다.

## 사전 조건

- 현재 `feat/v1-client`에 미커밋 SSO 패치(`canvas_session.dart`, `providers.dart` 등)와 내장 WebView 신원 토큰 수정이 있다. Task 9가 같은 파일을 고치므로, **사용자가 이 변경을 먼저 커밋한 뒤** `feat/pwa-relay` 브랜치를 만들어 시작한다.
- 로컬에 Node 24, Chrome, Git Bash가 있어야 한다.

## 파일 구조

| 경로 | 책임 |
|---|---|
| `tool/spike/` | 1회용 검증 페이지와 로컬 Wisp 서버. 배포하지 않는다 |
| `relay/src/policy.mjs` | 허용 호스트·포트, Origin 판정 |
| `relay/src/server.mjs` | HTTP 서버 + Origin 검사 + Wisp 라우팅 |
| `relay/src/main.mjs` | 환경변수로 서버 시작 |
| `relay/test/relay.test.mjs` | Origin 거부, 허용 목록 밖 연결 차단 |
| `relay/Dockerfile`, `relay/compose.yaml`, `relay/README.md` | NAS 배포 |
| `lib/core/storage/db/connection.dart` | DB 실행기 조건부 export |
| `lib/core/storage/db/connection_native.dart` | 기존 SQLCipher 파일 DB 열기(이동) |
| `lib/core/storage/db/connection_web.dart` | drift WasmDatabase |
| `lib/core/platform/app_platform.dart` | 웹에서 예외 없는 `isAndroidApp`, `isIOSApp` |
| `lib/core/network/libcurl/curl_binding.dart` | libcurl 호출 추상화(순수 Dart) |
| `lib/core/network/libcurl/libcurl_adapter.dart` | Dio `HttpClientAdapter` 구현(순수 Dart) |
| `lib/core/network/libcurl/libcurl_js_binding.dart` | `dart:js_interop`로 libcurl.js 호출(웹 전용) |
| `lib/core/network/jar_cookie_interceptor.dart` | 웹용 쿠키 인터셉터(순수 Dart) |
| `lib/core/network/platform_http.dart` (+`_native`, `_web`) | 플랫폼별 어댑터·쿠키 인터셉터 선택 |
| `lib/features/canvas/presentation/canvas_file_open.dart` (+`_io`, `_web`) | 파일 열기 |
| `lib/features/canvas/presentation/canvas_page_launcher.dart` (+`_native`, `_web`) | 로그인된 원문 열기 |
| `lib/core/platform/browser_display.dart` (+`_native`, `_web`) | PWA 설치 여부 감지 |
| `lib/features/auth/presentation/install_hint.dart` | 홈 화면 추가 안내 |
| `web/` | Flutter 웹 진입점, manifest, 아이콘, vendor 런타임 |
| `tool/web_vendor.sh` | vendor 파일 재현 다운로드 + 해시 검증 |
| `.github/workflows/pwa.yml`, `.github/workflows/relay-image.yml` | 공개 CI 배포 |
| `docs/pwa/spike-results.md`, `docs/pwa/verification.md` | 스파이크 결과, 실기기 확인 목록 |

---

### Task 1: 스파이크 — libcurl.js 터널로 SSO 브리지와 브라우저 SAML POST 검증

설계의 전제를 실제 학교 서버로 확인한다. **사람이 직접 학번·비밀번호를 입력해 실행하는 태스크다.** 에이전트는 하네스를 만들고 사용자에게 실행을 요청한 뒤, 사용자가 알려준 결과를 기록한다. 이 태스크 결과가 Task 2(허용 호스트), Task 9(원문 열기 방식)를 결정한다.

**Files:**
- Create: `tool/spike/package.json`
- Create: `tool/spike/serve.mjs`
- Create: `tool/spike/index.html`
- Create: `tool/spike/spike.js`
- Create: `docs/pwa/spike-results.md`
- Modify: `.gitignore`

**Interfaces:**
- Produces: `docs/pwa/spike-results.md`의 판정 3개 — `터널 브리지: 성공|실패`, `브라우저 SAML POST: 성공|실패`, `파일 다운로드 리다이렉트 호스트: <호스트 또는 없음>`

- [ ] **Step 1: 스파이크 패키지와 로컬 Wisp 서버 작성**

`tool/spike/package.json`:

```json
{
  "name": "kumoh-pwa-spike",
  "private": true,
  "type": "module",
  "scripts": { "start": "node serve.mjs" },
  "dependencies": {
    "@mercuryworkshop/wisp-js": "0.5.0",
    "libcurl.js": "0.7.4"
  }
}
```

`tool/spike/serve.mjs`:

```js
// 스파이크 전용. 127.0.0.1에서만 열고 학교 서버로만 중계한다.
import http from "node:http";
import { readFile } from "node:fs/promises";
import { server as wisp, logging } from "@mercuryworkshop/wisp-js/server";

wisp.options.hostname_whitelist = [/^lms\.kumoh\.ac\.kr$/, /^canvas\.kumoh\.ac\.kr$/];
wisp.options.port_whitelist = [82, 443];
wisp.options.allow_udp_streams = false;
wisp.options.allow_direct_ip = false;
logging.set_level(logging.INFO);

const files = {
  "/": ["index.html", "text/html; charset=utf-8"],
  "/spike.js": ["spike.js", "text/javascript"],
  "/libcurl.js": ["node_modules/libcurl.js/libcurl.js", "text/javascript"],
  "/libcurl.wasm": ["node_modules/libcurl.js/libcurl.wasm", "application/wasm"],
};

const server = http.createServer(async (req, res) => {
  const entry = files[new URL(req.url, "http://127.0.0.1").pathname];
  if (!entry) {
    res.writeHead(404).end();
    return;
  }
  const body = await readFile(new URL(entry[0], import.meta.url));
  res.writeHead(200, { "Content-Type": entry[1] }).end(body);
});
server.on("upgrade", (req, socket, head) => wisp.routeRequest(req, socket, head));
server.listen(5001, "127.0.0.1", () => console.log("http://127.0.0.1:5001/"));
```

- [ ] **Step 2: 검증 페이지 작성**

`tool/spike/index.html`:

```html
<!doctype html>
<meta charset="utf-8">
<title>PWA 스파이크</title>
<p>입력한 값은 저장하지 않습니다. 결과 로그에 토큰은 앞 4자만 표시됩니다.</p>
<input id="id" placeholder="학번" autocomplete="off">
<input id="pw" type="password" placeholder="비밀번호" autocomplete="off">
<button id="tunnel">A. 터널 브리지 + Canvas API</button>
<button id="browser">B. 브라우저 SAML POST</button>
<pre id="out"></pre>
<script src="/libcurl.js"></script>
<script src="/spike.js"></script>
```

`tool/spike/spike.js`:

```js
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
```

- [ ] **Step 3: node_modules 제외 후 설치 확인**

`.gitignore` 끝에 추가:

```gitignore
# 스파이크 의존성
tool/spike/node_modules/
```

Run: `cd tool/spike && npm install && node -e "import('@mercuryworkshop/wisp-js/server').then(m => console.log(typeof m.server.routeRequest))"`
Expected: `function`

- [ ] **Step 4: 사용자에게 실행 요청**

사용자에게 다음을 요청하고 결과 로그를 받는다(토큰은 앞 4자만 나온다).

1. `cd tool/spike && npm start`
2. Chrome에서 `http://127.0.0.1:5001/` 열기, 학번·비밀번호 입력
3. A 버튼 → 로그 전체 복사
4. B 버튼 → 새 창이 로그인된 Canvas 강좌 목록인지, 로그인 화면이나 오류인지 알려주기

- [ ] **Step 5: 결과 기록**

`docs/pwa/spike-results.md`를 받은 결과로 작성한다. 형식:

```markdown
# PWA 스파이크 결과

확인일: <YYYY-MM-DD>, Chrome <버전>, libcurl.js 0.7.4, wisp-js 0.5.0

## 판정

- 터널 브리지: <성공|실패>
- 브라우저 SAML POST: <성공|실패>
- 파일 다운로드 리다이렉트 호스트: <호스트 또는 없음>

## 관찰

- Set-Cookie 읽기: <읽힘|안 읽힘>
- redirect: manual: <3xx가 그대로 보임|자동으로 따라감>
- Origin 헤더 지정 로그인: <code 200|기타>
- Canvas profile / courses status: <값>

## 로그 (토큰 앞 4자만)

<사용자가 준 로그>
```

판정 규칙:
- **터널 브리지가 실패하면 여기서 멈추고 사용자와 설계를 재검토한다.** 이후 태스크를 진행하지 않는다.
- 파일 다운로드 리다이렉트 호스트가 `canvas.kumoh.ac.kr`, `lms.kumoh.ac.kr` 외의 호스트면 Task 2 Step 3의 `ALLOWED_HOSTNAMES`에 그 호스트의 정규식(`^호스트$`, 점은 `\.`)을 추가하고 `relay/test/relay.test.mjs`의 허용 목록 테스트는 그대로 둔다.
- 브라우저 SAML POST 결과는 Task 9에서 방식 A(성공) 또는 방식 B(실패)를 고르는 데 쓴다.

- [ ] **Step 6: Commit**

```bash
git add .gitignore tool/spike/package.json tool/spike/serve.mjs tool/spike/index.html tool/spike/spike.js docs/pwa/spike-results.md
git commit -m "docs: PWA 터널 스파이크 하네스와 결과

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

### Task 2: 중계 서버 (`relay/`)

**Files:**
- Create: `relay/package.json`
- Create: `relay/src/policy.mjs`
- Create: `relay/src/server.mjs`
- Create: `relay/src/main.mjs`
- Create: `relay/test/relay.test.mjs`
- Create: `relay/Dockerfile`
- Create: `relay/.dockerignore`
- Create: `relay/compose.yaml`
- Create: `relay/README.md`
- Modify: `.gitignore`

**Interfaces:**
- Consumes: Task 1의 파일 다운로드 리다이렉트 호스트
- Produces: `createRelayServer({ allowedOrigins: string[] }): http.Server`, 환경변수 `RELAY_ALLOWED_ORIGINS`(쉼표 구분), `PORT`(기본 8080), `GET /healthz` → `200 ok`

- [ ] **Step 1: 패키지 작성과 설치**

`relay/package.json`:

```json
{
  "name": "kumoh-lms-relay",
  "private": true,
  "type": "module",
  "engines": { "node": ">=24" },
  "scripts": {
    "start": "node src/main.mjs",
    "test": "node --test"
  },
  "dependencies": {
    "@mercuryworkshop/wisp-js": "0.5.0"
  },
  "devDependencies": {
    "ws": "8.21.3"
  }
}
```

`.gitignore` 끝에 추가:

```gitignore
relay/node_modules/
```

Run: `cd relay && npm install`
Expected: `package-lock.json` 생성, 오류 없음

- [ ] **Step 2: 실패하는 테스트 작성**

`relay/test/relay.test.mjs`:

```js
import test from "node:test";
import assert from "node:assert/strict";
import http from "node:http";
import WebSocket from "ws";
import { createRelayServer } from "../src/server.mjs";
import { isOriginAllowed, parseAllowedOrigins } from "../src/policy.mjs";

const ORIGIN = "https://barahana25.github.io";
const HOST_BLOCKED = 0x48;

async function start(t) {
  const server = createRelayServer({ allowedOrigins: [ORIGIN] });
  await new Promise((resolve) => server.listen(0, "127.0.0.1", resolve));
  t.after(() => server.close());
  return server.address().port;
}

// Wisp v1 CONNECT 패킷: type(1) stream_id(u32 LE) stream_type(1) port(u16 LE) hostname
function connectPacket(streamId, hostname, port) {
  const name = Buffer.from(hostname, "utf8");
  const buf = Buffer.alloc(8 + name.length);
  buf.writeUInt8(0x01, 0);
  buf.writeUInt32LE(streamId, 1);
  buf.writeUInt8(0x01, 5);
  buf.writeUInt16LE(port, 6);
  name.copy(buf, 8);
  return buf;
}

// 서버의 첫 CONTINUE를 받은 뒤 스트림을 요청하고, CLOSE 사유 코드를 돌려준다.
function closeReason(port, hostname, destPort) {
  const ws = new WebSocket(`ws://127.0.0.1:${port}/`, { origin: ORIGIN });
  return new Promise((resolve, reject) => {
    const timer = setTimeout(() => reject(new Error("CLOSE 패킷을 받지 못함")), 5000);
    ws.on("error", reject);
    ws.on("message", (data) => {
      const b = Buffer.from(data);
      const type = b.readUInt8(0);
      const streamId = b.readUInt32LE(1);
      if (type === 0x03 && streamId === 0) {
        ws.send(connectPacket(1, hostname, destPort));
      } else if (type === 0x04 && streamId === 1) {
        clearTimeout(timer);
        resolve(b.readUInt8(5));
        ws.close();
      }
    });
  });
}

test("허용 Origin 목록을 파싱하고 판정한다", () => {
  assert.deepEqual(
    parseAllowedOrigins(" https://a.io, ,http://localhost:8000 "),
    ["https://a.io", "http://localhost:8000"],
  );
  assert.equal(isOriginAllowed(undefined, [ORIGIN]), false);
  assert.equal(isOriginAllowed("https://evil.example", [ORIGIN]), false);
  assert.equal(isOriginAllowed(ORIGIN, [ORIGIN]), true);
});

test("healthz는 200을 돌려준다", async (t) => {
  const port = await start(t);
  const res = await fetch(`http://127.0.0.1:${port}/healthz`);
  assert.equal(res.status, 200);
  assert.equal(await res.text(), "ok");
});

test("허용되지 않은 Origin의 업그레이드는 403으로 거부한다", async (t) => {
  const port = await start(t);
  const status = await new Promise((resolve, reject) => {
    const req = http.request({
      host: "127.0.0.1",
      port,
      headers: {
        Connection: "Upgrade",
        Upgrade: "websocket",
        Origin: "https://evil.example",
        "Sec-WebSocket-Version": "13",
        "Sec-WebSocket-Key": "dGhlIHNhbXBsZSBub25jZQ==",
      },
    });
    req.on("response", (res) => resolve(res.statusCode));
    req.on("upgrade", () => resolve(101));
    req.on("error", reject);
    req.end();
  });
  assert.equal(status, 403);
});

test("허용 목록 밖 호스트로는 스트림을 열지 않는다", async (t) => {
  const port = await start(t);
  assert.equal(await closeReason(port, "example.com", 443), HOST_BLOCKED);
});

test("허용 호스트라도 허용 목록 밖 포트는 막는다", async (t) => {
  const port = await start(t);
  assert.equal(await closeReason(port, "lms.kumoh.ac.kr", 22), HOST_BLOCKED);
});

test("IP 주소로 직접 연결할 수 없다", async (t) => {
  const port = await start(t);
  assert.equal(await closeReason(port, "127.0.0.1", 443), HOST_BLOCKED);
});
```

- [ ] **Step 3: 테스트 실패 확인**

Run: `cd relay && npm test`
Expected: FAIL — `Cannot find module '../src/server.mjs'`

- [ ] **Step 4: 정책과 서버 구현**

`relay/src/policy.mjs` (Task 1에서 추가 호스트가 나왔다면 `ALLOWED_HOSTNAMES`에 넣는다):

```js
// 이 중계 서버가 연결을 허용하는 곳. 목록 밖으로는 어떤 바이트도 나가지 않는다.
// 학교 서버와의 TLS는 사용자 브라우저에서 종단하므로 여기서는 암호문만 오간다.
export const ALLOWED_HOSTNAMES = [/^lms\.kumoh\.ac\.kr$/, /^canvas\.kumoh\.ac\.kr$/];
export const ALLOWED_PORTS = [82, 443];

export function applyPolicy(options) {
  options.hostname_whitelist = ALLOWED_HOSTNAMES;
  options.port_whitelist = ALLOWED_PORTS;
  options.allow_direct_ip = false;
  options.allow_private_ips = false;
  options.allow_loopback_ips = false;
  options.allow_udp_streams = false;
  options.stream_limit_total = 16;
  // 리버스 프록시의 X-Forwarded-For를 해석하지 않는다. 로그에 사용자 IP를 남기지 않는다.
  options.parse_real_ip = false;
}

export function parseAllowedOrigins(value) {
  return (value ?? "")
    .split(",")
    .map((s) => s.trim())
    .filter(Boolean);
}

// 다른 사이트가 이 중계 서버를 가져다 쓰는 것을 막는다. 보안 경계는 아니다.
export function isOriginAllowed(origin, allowed) {
  return typeof origin === "string" && allowed.includes(origin);
}
```

`relay/src/server.mjs`:

```js
import http from "node:http";
import { server as wisp, logging } from "@mercuryworkshop/wisp-js/server";
import { applyPolicy, isOriginAllowed } from "./policy.mjs";

export function createRelayServer({ allowedOrigins }) {
  applyPolicy(wisp.options);
  // INFO는 연결·스트림의 시각과 대상 호스트:포트를 남긴다. 내용은 암호문이라 남길 수 없다.
  logging.set_level(logging.INFO);

  const server = http.createServer((req, res) => {
    if (req.url === "/healthz") {
      res.writeHead(200, { "Content-Type": "text/plain" }).end("ok");
      return;
    }
    res.writeHead(404).end();
  });

  server.on("upgrade", (req, socket, head) => {
    if (!isOriginAllowed(req.headers.origin, allowedOrigins)) {
      socket.end("HTTP/1.1 403 Forbidden\r\nConnection: close\r\n\r\n");
      return;
    }
    wisp.routeRequest(req, socket, head);
  });

  return server;
}
```

`relay/src/main.mjs`:

```js
import { createRelayServer } from "./server.mjs";
import { parseAllowedOrigins } from "./policy.mjs";

const allowedOrigins = parseAllowedOrigins(process.env.RELAY_ALLOWED_ORIGINS);
if (allowedOrigins.length === 0) {
  console.error("RELAY_ALLOWED_ORIGINS가 비어 있습니다. 예: https://barahana25.github.io");
  process.exit(1);
}
const port = Number(process.env.PORT ?? 8080);

createRelayServer({ allowedOrigins }).listen(port, "0.0.0.0", () => {
  console.log(`relay listening on :${port}, origins=${allowedOrigins.join(",")}`);
});
```

- [ ] **Step 5: 테스트 통과 확인**

Run: `cd relay && npm test`
Expected: PASS — 6 tests, 0 failures

- [ ] **Step 6: 컨테이너와 배포 문서 작성**

`relay/Dockerfile`:

```dockerfile
FROM node:24-alpine
WORKDIR /app
ENV NODE_ENV=production
COPY package.json package-lock.json ./
RUN npm ci --omit=dev
COPY src ./src
USER node
EXPOSE 8080
HEALTHCHECK --interval=60s CMD wget -qO- http://127.0.0.1:8080/healthz || exit 1
CMD ["node", "src/main.mjs"]
```

`relay/.dockerignore`:

```
node_modules
test
```

`relay/compose.yaml`:

```yaml
# Synology Container Manager > 프로젝트에 이 파일을 넣는다.
# image는 README의 "이미지 고정" 절차대로 digest로 바꾼다.
services:
  relay:
    image: ghcr.io/barahana25/kumoh-lms-relay:main
    restart: unless-stopped
    environment:
      RELAY_ALLOWED_ORIGINS: https://barahana25.github.io
      PORT: "8080"
    ports:
      - "127.0.0.1:8080:8080"
    read_only: true
    cap_drop:
      - ALL
    security_opt:
      - no-new-privileges:true
```

`relay/README.md`:

````markdown
# 금오 LMS PWA 중계 서버

PWA가 학교 서버에 접속할 수 있게 TCP 바이트만 전달한다. 학교 서버와의 TLS는 사용자 브라우저 안의 libcurl.js가 맺으므로 이 서버와 운영자는 요청·응답 내용(비밀번호, 토큰, 쿠키, 강의 데이터)을 볼 수 없다.

## 허용 범위

- 대상: `lms.kumoh.ac.kr`, `canvas.kumoh.ac.kr`의 82, 443 포트만 ([src/policy.mjs](src/policy.mjs))
- 사설 IP, 루프백, IP 직접 지정, UDP 금지
- WebSocket `Origin`이 `RELAY_ALLOWED_ORIGINS`에 없으면 403
- 로그: 연결·스트림 시각, 대상 호스트:포트. 사용자 IP는 해석하지 않는다(리버스 프록시 주소만 남는다)

## 로컬 개발

```bash
npm install
npm test
RELAY_ALLOWED_ORIGINS=http://localhost:8000 PORT=8080 npm start
```

Flutter 쪽: `flutter run -d chrome --web-port 8000 --dart-define=RELAY_URL=ws://127.0.0.1:8080/`

## Synology NAS 배포

1. **DDNS**: 제어판 → 외부 액세스 → DDNS → 추가. 서비스 공급자 Synology, 호스트 이름 예: `kumoh-relay.synology.me`
2. **인증서**: 제어판 → 보안 → 인증서 → 추가 → Let's Encrypt에서 인증서 받기. 도메인은 1의 호스트 이름
3. **컨테이너**: Container Manager → 프로젝트 → 생성. 경로에 `compose.yaml`을 두고 실행
4. **이미지 고정**: GitHub 저장소 → Packages → `kumoh-lms-relay`에서 배포할 커밋의 `sha256:...` digest를 확인하고 `compose.yaml`의 `image`를 `ghcr.io/barahana25/kumoh-lms-relay@sha256:<digest>`로 바꾼 뒤 프로젝트를 다시 빌드한다
5. **리버스 프록시**: 제어판 → 로그인 포털 → 고급 → 리버스 프록시 → 생성
   - 소스: HTTPS, 호스트 이름 `kumoh-relay.synology.me`, 포트 443
   - 대상: HTTP, `localhost`, 포트 8080
   - 사용자 지정 머리글 → 생성 → **WebSocket** (Upgrade, Connection 헤더 자동 추가)
   - 인증서: 제어판 → 보안 → 인증서 → 설정에서 이 호스트에 2의 인증서 지정
6. **공유기**: TCP 443 → NAS만 포워딩한다. DSM 관리 포트 5000/5001은 외부에 열지 않는다
7. **확인**: `https://kumoh-relay.synology.me/healthz`가 `ok`
8. GitHub 저장소 → Settings → Secrets and variables → Actions → Variables에 `RELAY_URL` = `wss://kumoh-relay.synology.me/` 등록 (끝의 `/` 필수)
````

Run: `cd relay && docker build -t kumoh-lms-relay:local .` (Docker가 없으면 이 확인은 CI(Task 11)에서 한다)
Expected: 빌드 성공

- [ ] **Step 7: Commit**

```bash
git add .gitignore relay/package.json relay/package-lock.json relay/src relay/test relay/Dockerfile relay/.dockerignore relay/compose.yaml relay/README.md
git commit -m "feat: 학교 서버 전용 Wisp 블라인드 중계 서버

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

### Task 3: 웹 빌드 가능하게 만들기 — 웹 플랫폼, DB 실행기 분리, vendor 런타임

2026-09-14 시험 빌드에서 웹 컴파일을 막은 것은 `app_database.dart`의 네이티브 import(`drift/native`, `sqlite3/open`, `sqlcipher_flutter_libs`)와 `package:sqlite3/sqlite3.dart` import 두 곳뿐이었다.

**Files:**
- Create: `lib/core/storage/db/connection.dart`
- Create: `lib/core/storage/db/connection_native.dart`
- Create: `lib/core/storage/db/connection_web.dart`
- Modify: `lib/core/storage/db/app_database.dart:1-12, 40-46, 100-151`
- Modify: `lib/features/notifications/data/notification_poller.dart:3`
- Modify: `lib/features/notifications/presentation/notification_settings_section.dart:3`
- Modify: `test/core/app_database_test.dart` (import 추가)
- Modify: `pubspec.yaml` (`web` 의존성)
- Create: `web/` (flutter create 산출물), `web/vendor/*`, `web/vendor/SHA256SUMS`
- Create: `tool/web_vendor.sh`

**Interfaces:**
- Produces: `QueryExecutor openAppDatabaseExecutor(Future<String> Function() keyProvider)` (네이티브: SQLCipher 파일, 웹: WasmDatabase), `Future<void> discardUnreadableCache(File file, String escapedKey)`는 `connection_native.dart`로 이동, `web/vendor/libcurl.js`·`libcurl.wasm`·`sqlite3.wasm`·`drift_worker.js`

- [ ] **Step 1: 웹 빌드가 실패함을 확인**

Run: `C:\src\flutter\bin\flutter.bat create --platforms web --project-name kumoh_lms .`
그다음 `git status --short`로 확인해 `web/`과 `.metadata` 외에 바뀐 파일이 있으면 `git checkout -- <파일>`로 되돌린다.

Run: `C:\src\flutter\bin\flutter.bat build web`
Expected: FAIL — `Dart library 'dart:ffi' is not available on this platform.`

- [ ] **Step 2: 네이티브 DB 열기 코드 이동**

`lib/core/storage/db/connection_native.dart`를 만든다. 내용은 `app_database.dart` 100~151행(`discardUnreadableCache`의 문서 주석부터 `_openEncrypted` 끝까지)을 그대로 옮기고, `_openEncrypted`만 `openAppDatabaseExecutor`로 이름을 바꾼다. 파일 머리:

```dart
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqlcipher_flutter_libs/sqlcipher_flutter_libs.dart';
import 'package:sqlite3/open.dart';
import 'package:sqlite3/sqlite3.dart';

// (app_database.dart 100~151행: discardUnreadableCache와 _openEncrypted를 옮긴다)
// 옮긴 뒤 선언부는 다음과 같아야 한다:
// Future<void> discardUnreadableCache(File file, String escapedKey) async { ... }
// LazyDatabase openAppDatabaseExecutor(Future<String> Function() keyProvider) { ... }
```

`lib/core/storage/db/connection_web.dart`:

```dart
import 'package:drift/drift.dart';
import 'package:drift/wasm.dart';

/// 웹은 SQLCipher가 없어 암호화하지 않는다. 서버에서 다시 받을 수 있는
/// 캐시만 들어가고, 비밀번호는 웹에서 저장하지 않는다.
///
/// GitHub Pages는 COOP/COEP 헤더를 줄 수 없어 drift가 OPFS 대신
/// IndexedDB 등 가능한 저장소를 고른다.
QueryExecutor openAppDatabaseExecutor(Future<String> Function() keyProvider) {
  return DatabaseConnection.delayed(Future(() async {
    final result = await WasmDatabase.open(
      databaseName: 'kumoh_lms',
      sqlite3Uri: Uri.parse('vendor/sqlite3.wasm'),
      driftWorkerUri: Uri.parse('vendor/drift_worker.js'),
    );
    return result.resolvedExecutor;
  }));
}
```

`lib/core/storage/db/connection.dart`:

```dart
export 'connection_native.dart'
    if (dart.library.js_interop) 'connection_web.dart';
```

- [ ] **Step 3: app_database.dart 정리**

`lib/core/storage/db/app_database.dart`에서:
- 1~9행의 `dart:io`, `drift/native.dart`, `path`, `path_provider`, `sqlcipher_flutter_libs`, `sqlite3/open.dart`, `sqlite3/sqlite3.dart` import를 지우고 `import 'connection.dart';`를 추가한다. `package:drift/drift.dart`와 `tables.dart` import는 남긴다.
- 100~151행(옮긴 코드)을 지운다.
- 팩토리를 다음으로 바꾼다:

```dart
  /// 실기기는 SQLCipher 암호화 파일 DB, 웹은 WasmDatabase를 연다.
  factory AppDatabase.encrypted(Future<String> Function() keyProvider) =>
      AppDatabase(openAppDatabaseExecutor(keyProvider));
```

`test/core/app_database_test.dart` import 목록에 추가:

```dart
import 'package:kumoh_lms/core/storage/db/connection_native.dart';
```

`notification_poller.dart:3`, `notification_settings_section.dart:3`의 import를 바꾼다:

```dart
import 'package:sqlite3/common.dart' show SqliteException;
```

- [ ] **Step 4: vendor 런타임 스크립트 작성과 실행**

`pubspec.yaml`의 `dependencies:`에 추가(이미 lock에 1.1.1이 transitive로 있다):

```yaml
  web: ^1.1.1
```

`tool/web_vendor.sh`:

```bash
#!/usr/bin/env bash
# 웹 빌드가 쓰는 외부 런타임을 고정 버전으로 받아 web/vendor에 둔다.
# 버전은 pubspec.lock의 drift, sqlite3와 맞아야 한다. 해시가 다르면 실패한다.
set -euo pipefail
cd "$(dirname "$0")/../web/vendor"

curl -fsSL -o drift_worker.js \
  https://github.com/simolus3/drift/releases/download/drift-2.31.0/drift_worker.js
curl -fsSL -o sqlite3.wasm \
  https://github.com/simolus3/sqlite3.dart/releases/download/sqlite3-2.9.4/sqlite3.wasm

tmp="$(mktemp -d)"
curl -fsSL https://registry.npmjs.org/libcurl.js/-/libcurl.js-0.7.4.tgz | tar -xz -C "$tmp"
cp "$tmp/package/libcurl.js" "$tmp/package/libcurl.wasm" .
cp "$tmp/package/LICENSE" LICENSE.libcurl.js.txt
rm -rf "$tmp"

sha256sum -c SHA256SUMS
```

`web/vendor/SHA256SUMS` (2026-09-14에 계산한 값):

```
f0a9b87085f732fd7b6ee7eb34d3858c556f05d221eb1febfc443649cd365752  drift_worker.js
922a76b182b6af69b030c8e2fdd3283ecc8e827248b20e4b1f3f3db170b52117  sqlite3.wasm
cebdcd90aa27e3bbba1dde2ab7660a5f55fe6b58a697ad97aaa1577c95f8039d  libcurl.js
fe42bbcbd90b06c020ee4e0f11b86e8a671bfbb8fea3ee27200b116b7286dea9  libcurl.wasm
```

Run: `mkdir -p web/vendor && bash tool/web_vendor.sh`
Expected: 네 줄 모두 `OK`

- [ ] **Step 5: 웹 빌드와 기존 테스트 확인**

Run: `C:\src\flutter\bin\flutter.bat pub get; C:\src\flutter\bin\flutter.bat build web`
Expected: `√ Built build\web`

Run: `C:\src\flutter\bin\flutter.bat analyze; C:\src\flutter\bin\flutter.bat test`
Expected: `No issues found!`, `All tests passed!` (292개)

- [ ] **Step 6: Commit**

```bash
git add pubspec.yaml pubspec.lock .metadata web lib/core/storage/db test/core/app_database_test.dart lib/features/notifications/data/notification_poller.dart lib/features/notifications/presentation/notification_settings_section.dart tool/web_vendor.sh
git commit -m "feat: 웹 빌드 지원 — DB 실행기 분리와 고정 웹 런타임

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

### Task 4: 웹에서 예외 없는 플랫폼 검사

웹에서 `dart:io`의 `Platform.isAndroid`는 `UnsupportedError`를 던진다. `main.dart`의 `on Exception`은 `Error`를 잡지 못해 시작 화면에서 멈춘다.

**Files:**
- Create: `lib/core/platform/app_platform.dart`
- Create: `test/web/app_platform_web_test.dart`
- Modify: `lib/features/notifications/notification_runtime.dart` (104, 111, 123, 130, 173, 201, 242, 250행)
- Modify: `lib/features/downloads/folder_storage.dart:12`
- Modify: `lib/features/notifications/background_settings.dart:5`

**Interfaces:**
- Produces: `bool get isAndroidApp`, `bool get isIOSApp`

- [ ] **Step 1: 실패하는 브라우저 테스트 작성**

`test/web/app_platform_web_test.dart`:

```dart
@TestOn('browser')
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:kumoh_lms/core/platform/app_platform.dart';
import 'package:kumoh_lms/features/downloads/folder_storage.dart';
import 'package:kumoh_lms/features/notifications/background_settings.dart';
import 'package:kumoh_lms/features/notifications/notification_runtime.dart';

void main() {
  test('웹에서는 네이티브 전용 기능이 예외 없이 꺼진다', () {
    expect(isAndroidApp, isFalse);
    expect(isIOSApp, isFalse);
    expect(NotificationRuntime.supported, isFalse);
    expect(AndroidFolderStorage.supported, isFalse);
    expect(BackgroundSettings.supported, isFalse);
  });
}
```

- [ ] **Step 2: 실패 확인**

Run: `C:\src\flutter\bin\flutter.bat test --platform chrome test/web/app_platform_web_test.dart`
Expected: FAIL — `app_platform.dart` 없음으로 컴파일 실패

- [ ] **Step 3: 헬퍼 작성과 교체**

`lib/core/platform/app_platform.dart`:

```dart
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;

/// 웹에서 `Platform.isAndroid`를 읽으면 UnsupportedError가 난다.
/// kIsWeb을 먼저 확인해 VM 테스트의 기존 동작(호스트 OS 기준)은 그대로 둔다.
bool get isAndroidApp => !kIsWeb && Platform.isAndroid;

bool get isIOSApp => !kIsWeb && Platform.isIOS;
```

세 파일에서 `Platform.isAndroid` → `isAndroidApp`, `Platform.isIOS` → `isIOSApp`으로 모두 바꾸고 `import '<상대경로>/core/platform/app_platform.dart';`를 추가한다. 상대경로:
- `notification_runtime.dart`: `'../../core/platform/app_platform.dart'`
- `folder_storage.dart`: `'../../core/platform/app_platform.dart'`
- `background_settings.dart`: `'../../core/platform/app_platform.dart'`

교체 후 `dart:io`를 더 쓰지 않는 파일은 그 import를 지운다(`flutter analyze`가 unused import로 알려준다).

Run: `grep -rn "Platform\.is" lib`
Expected: `lib/core/platform/app_platform.dart`만 나온다

- [ ] **Step 4: 통과 확인**

Run: `C:\src\flutter\bin\flutter.bat test --platform chrome test/web/app_platform_web_test.dart`
Expected: PASS

Run: `C:\src\flutter\bin\flutter.bat analyze; C:\src\flutter\bin\flutter.bat test`
Expected: `No issues found!`, `All tests passed!`

- [ ] **Step 5: Commit**

```bash
git add lib/core/platform/app_platform.dart test/web/app_platform_web_test.dart lib/features/notifications/notification_runtime.dart lib/features/downloads/folder_storage.dart lib/features/notifications/background_settings.dart
git commit -m "fix: 웹에서 플랫폼 검사가 예외를 던지지 않게 한다

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

### Task 5: libcurl Dio 어댑터 (순수 Dart)

**Files:**
- Create: `lib/core/network/libcurl/curl_binding.dart`
- Create: `lib/core/network/libcurl/libcurl_adapter.dart`
- Test: `test/core/network/libcurl_adapter_test.dart`

**Interfaces:**
- Produces:
  - `class CurlRequest({required String url, required String method, required Map<String, String> headers, Uint8List? body, required bool followRedirects, Future<void>? cancel})`
  - `class CurlResponse({required int status, required List<(String, String)> headers, required Uint8List body})`
  - `class CurlException(String message) implements Exception`
  - `abstract interface class CurlBinding { Future<CurlResponse> fetch(CurlRequest request); }`
  - `class LibcurlHttpClientAdapter(CurlBinding binding) implements HttpClientAdapter`

- [ ] **Step 1: 실패하는 테스트 작성**

`test/core/network/libcurl_adapter_test.dart`:

```dart
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kumoh_lms/core/error/failure.dart';
import 'package:kumoh_lms/core/network/libcurl/curl_binding.dart';
import 'package:kumoh_lms/core/network/libcurl/libcurl_adapter.dart';
import 'package:kumoh_lms/features/auth/data/auth_api.dart' show throwAsFailure;

class _FakeBinding implements CurlBinding {
  _FakeBinding(this.respond);
  final Future<CurlResponse> Function(CurlRequest request) respond;
  final requests = <CurlRequest>[];

  @override
  Future<CurlResponse> fetch(CurlRequest request) {
    requests.add(request);
    return respond(request);
  }
}

CurlResponse _ok(String body, [List<(String, String)> headers = const []]) =>
    CurlResponse(
        status: 200,
        headers: headers,
        body: Uint8List.fromList(utf8.encode(body)));

void main() {
  test('요청 URL·메서드·헤더·본문을 그대로 넘긴다', () async {
    final binding = _FakeBinding((_) async => _ok('{"code":"200"}',
        [('Content-Type', 'application/json')]));
    final dio = Dio(BaseOptions(
        baseUrl: 'https://lms.kumoh.ac.kr:82/api/v1',
        headers: {'Origin': 'https://lms.kumoh.ac.kr'}))
      ..httpClientAdapter = LibcurlHttpClientAdapter(binding);

    final res = await dio.post<Map<String, dynamic>>('/login',
        data: {'userId': 'A', 'password': 'B'});

    final sent = binding.requests.single;
    expect(sent.url, 'https://lms.kumoh.ac.kr:82/api/v1/login');
    expect(sent.method, 'POST');
    expect(sent.headers['origin'] ?? sent.headers['Origin'],
        'https://lms.kumoh.ac.kr');
    expect(jsonDecode(utf8.decode(sent.body!)),
        {'userId': 'A', 'password': 'B'});
    expect(res.data, {'code': '200'});
  });

  test('중복 Set-Cookie를 모두 소문자 헤더로 전달한다', () async {
    final binding = _FakeBinding((_) async => _ok('', [
          ('Set-Cookie', 'a=1; path=/'),
          ('set-cookie', 'b=2; path=/'),
        ]));
    final dio = Dio()..httpClientAdapter = LibcurlHttpClientAdapter(binding);

    final res = await dio.get<String>('https://canvas.kumoh.ac.kr/');

    expect(res.headers['set-cookie'], ['a=1; path=/', 'b=2; path=/']);
  });

  test('followRedirects: false면 수동 리다이렉트를 요청하고 3xx와 Location을 돌려준다',
      () async {
    final binding = _FakeBinding((_) async => CurlResponse(
        status: 302,
        headers: const [('Location', 'https://lms.kumoh.ac.kr/idp')],
        body: Uint8List(0)));
    final dio = Dio()..httpClientAdapter = LibcurlHttpClientAdapter(binding);

    final res = await dio.get<String>('https://canvas.kumoh.ac.kr/login/saml',
        options: Options(
            followRedirects: false,
            validateStatus: (s) => s != null && s < 400));

    expect(binding.requests.single.followRedirects, isFalse);
    expect(res.statusCode, 302);
    expect(res.headers.value('location'), 'https://lms.kumoh.ac.kr/idp');
  });

  test('libcurl 실패는 연결 오류가 되어 NetworkFailure로 정규화된다', () async {
    final binding = _FakeBinding(
        (_) async => throw const CurlException('websocket closed'));
    final dio = Dio()..httpClientAdapter = LibcurlHttpClientAdapter(binding);

    await expectLater(
      () async {
        try {
          await dio.get<String>('https://canvas.kumoh.ac.kr/');
        } on DioException catch (e) {
          throwAsFailure(e);
        }
      }(),
      throwsA(isA<NetworkFailure>()),
    );
  });

  test('응답이 connect+receive 제한을 넘기면 receiveTimeout으로 실패한다', () async {
    final binding = _FakeBinding((_) => Completer<CurlResponse>().future);
    final dio = Dio(BaseOptions(
        connectTimeout: const Duration(milliseconds: 10),
        receiveTimeout: const Duration(milliseconds: 10)))
      ..httpClientAdapter = LibcurlHttpClientAdapter(binding);

    await expectLater(
      dio.get<String>('https://canvas.kumoh.ac.kr/'),
      throwsA(isA<DioException>().having(
          (e) => e.type, 'type', DioExceptionType.receiveTimeout)),
    );
  });
}
```

- [ ] **Step 2: 실패 확인**

Run: `C:\src\flutter\bin\flutter.bat test test/core/network/libcurl_adapter_test.dart`
Expected: FAIL — `curl_binding.dart` 없음

- [ ] **Step 3: 구현**

`lib/core/network/libcurl/curl_binding.dart`:

```dart
import 'dart:typed_data';

/// libcurl.js 한 번의 요청. 쿠키와 리다이렉트 판단은 Dart(Dio)가 한다.
class CurlRequest {
  const CurlRequest({
    required this.url,
    required this.method,
    required this.headers,
    required this.followRedirects,
    this.body,
    this.cancel,
  });

  final String url;
  final String method;
  final Map<String, String> headers;
  final Uint8List? body;
  final bool followRedirects;
  final Future<void>? cancel;
}

class CurlResponse {
  const CurlResponse({
    required this.status,
    required this.headers,
    required this.body,
  });

  final int status;

  /// 서버가 보낸 순서 그대로의 (이름, 값). Set-Cookie처럼 같은 이름이 여러 번 온다.
  final List<(String, String)> headers;
  final Uint8List body;
}

/// 중계 서버 연결 실패, TLS 실패 등 응답을 받지 못한 경우.
class CurlException implements Exception {
  const CurlException(this.message);
  final String message;

  @override
  String toString() => 'CurlException: $message';
}

/// 테스트에서는 가짜로, 웹에서는 libcurl.js로 구현한다.
abstract interface class CurlBinding {
  Future<CurlResponse> fetch(CurlRequest request);
}
```

`lib/core/network/libcurl/libcurl_adapter.dart`:

```dart
import 'dart:async';
import 'dart:typed_data';

import 'package:dio/dio.dart';

import 'curl_binding.dart';

/// 웹에서 브라우저 fetch 대신 libcurl.js로 요청한다.
///
/// 브라우저 fetch는 CORS, Origin 헤더 고정, Set-Cookie 숨김, 리다이렉트 자동
/// 추적 때문에 학교 서버와 SAML 브리지를 쓸 수 없다. libcurl.js는 TLS를
/// 브라우저 안에서 맺고 중계 서버에는 암호문 TCP만 보낸다.
class LibcurlHttpClientAdapter implements HttpClientAdapter {
  LibcurlHttpClientAdapter(this._binding);

  final CurlBinding _binding;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final body = requestStream == null ? null : await _collect(requestStream);
    final headers = <String, String>{
      for (final entry in options.headers.entries)
        if (entry.value != null)
          entry.key: entry.value is Iterable
              ? (entry.value as Iterable).join(', ')
              : '${entry.value}',
    };

    final request = CurlRequest(
      url: options.uri.toString(),
      method: options.method,
      headers: headers,
      body: body,
      followRedirects: options.followRedirects,
      cancel: cancelFuture,
    );

    final CurlResponse response;
    try {
      var pending = _binding.fetch(request);
      final limit = _timeLimit(options);
      if (limit != null) pending = pending.timeout(limit);
      response = await pending;
    } on TimeoutException {
      throw DioException(
        requestOptions: options,
        type: DioExceptionType.receiveTimeout,
        message: '응답 시간이 초과되었습니다.',
      );
    } on CurlException catch (e) {
      throw DioException.connectionError(
        requestOptions: options,
        reason: e.message,
        error: e,
      );
    }

    final grouped = <String, List<String>>{};
    for (final (name, value) in response.headers) {
      grouped.putIfAbsent(name.toLowerCase(), () => []).add(value);
    }
    return ResponseBody.fromBytes(response.body, response.status,
        headers: grouped);
  }

  static Duration? _timeLimit(RequestOptions options) {
    final connect = options.connectTimeout;
    final receive = options.receiveTimeout;
    if (connect == null && receive == null) return null;
    return (connect ?? Duration.zero) + (receive ?? Duration.zero);
  }

  static Future<Uint8List> _collect(Stream<Uint8List> stream) async {
    final bytes = <int>[];
    await for (final chunk in stream) {
      bytes.addAll(chunk);
    }
    return Uint8List.fromList(bytes);
  }

  @override
  void close({bool force = false}) {}
}
```

- [ ] **Step 4: 통과 확인**

Run: `C:\src\flutter\bin\flutter.bat test test/core/network/libcurl_adapter_test.dart`
Expected: PASS — 5 tests

- [ ] **Step 5: Commit**

```bash
git add lib/core/network/libcurl/curl_binding.dart lib/core/network/libcurl/libcurl_adapter.dart test/core/network/libcurl_adapter_test.dart
git commit -m "feat: libcurl 기반 Dio 어댑터

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

### Task 6: 웹 쿠키 인터셉터, libcurl.js 바인딩, Dio 배선

`dio_cookie_manager`의 `CookieManager`는 생성자에서 `assert(!_kIsWeb)`로 웹을 막는다. 웹에서는 같은 역할의 인터셉터를 쓴다.

**Files:**
- Create: `lib/core/network/jar_cookie_interceptor.dart`
- Create: `lib/core/network/libcurl/libcurl_js_binding.dart`
- Create: `lib/core/network/platform_http.dart`
- Create: `lib/core/network/platform_http_native.dart`
- Create: `lib/core/network/platform_http_web.dart`
- Modify: `lib/core/config/env.dart` (`relayUrl` 추가)
- Modify: `lib/core/network/dio_client.dart`
- Modify: `lib/features/canvas/data/canvas_client.dart`
- Modify: `web/index.html`
- Test: `test/core/network/jar_cookie_interceptor_test.dart`

**Interfaces:**
- Consumes: `LibcurlHttpClientAdapter`, `CurlBinding`, `CurlRequest`, `CurlResponse`, `CurlException` (Task 5)
- Produces: `HttpClientAdapter? platformHttpAdapter()`, `Interceptor platformCookieInterceptor(CookieJar jar)`, `class JarCookieInterceptor(CookieJar jar) extends Interceptor`, `Env.relayUrl`

- [ ] **Step 1: 실패하는 테스트 작성**

`test/core/network/jar_cookie_interceptor_test.dart`:

```dart
import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kumoh_lms/core/network/jar_cookie_interceptor.dart';

class _Script implements HttpClientAdapter {
  final cookieHeaders = <String?>[];

  @override
  Future<ResponseBody> fetch(RequestOptions options,
      Stream<List<int>>? requestStream, Future<void>? cancelFuture) async {
    cookieHeaders.add(options.headers['cookie'] as String?);
    if (options.uri.path == '/set') {
      return ResponseBody.fromString('', 302, headers: {
        'set-cookie': [
          '_normandy_session=abc; path=/; HttpOnly',
          'other=1; path=/',
        ],
      });
    }
    return ResponseBody.fromString('ok', 200);
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  late CookieJar jar;
  late _Script script;
  late Dio dio;

  setUp(() {
    jar = CookieJar();
    script = _Script();
    dio = Dio(BaseOptions(validateStatus: (s) => s != null && s < 400))
      ..httpClientAdapter = script
      ..interceptors.add(JarCookieInterceptor(jar));
  });

  test('응답의 Set-Cookie를 저장하고 다음 요청에 싣는다', () async {
    await dio.get<String>('https://canvas.kumoh.ac.kr/set');
    await dio.get<String>('https://canvas.kumoh.ac.kr/api/v1/courses');

    expect(script.cookieHeaders.last, '_normandy_session=abc; other=1');
  });

  test('저장소에 미리 심은 도메인 쿠키를 하위 호스트 요청에 싣는다', () async {
    await jar.saveFromResponse(Uri.parse('https://lms.kumoh.ac.kr'), [
      Cookie('_linus_saml_login', 'jwt')
        ..domain = '.kumoh.ac.kr'
        ..path = '/',
    ]);

    await dio.get<String>('https://lms.kumoh.ac.kr:82/api/v1/saml/login.do');

    expect(script.cookieHeaders.single, '_linus_saml_login=jwt');
  });

  test('쿠키가 없으면 cookie 헤더를 붙이지 않는다', () async {
    await dio.get<String>('https://canvas.kumoh.ac.kr/');

    expect(script.cookieHeaders.single, isNull);
  });
}
```

- [ ] **Step 2: 실패 확인**

Run: `C:\src\flutter\bin\flutter.bat test test/core/network/jar_cookie_interceptor_test.dart`
Expected: FAIL — `jar_cookie_interceptor.dart` 없음

- [ ] **Step 3: 인터셉터 구현**

`lib/core/network/jar_cookie_interceptor.dart`:

```dart
import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio/dio.dart';

/// 웹용 쿠키 인터셉터. dio_cookie_manager는 웹에서 생성자가 assert로 막힌다.
///
/// 웹에서도 쿠키는 브라우저가 아니라 이 저장소가 관리한다. libcurl.js 응답은
/// Set-Cookie를 숨기지 않으므로 네이티브와 같은 SAML 브리지를 쓸 수 있다.
class JarCookieInterceptor extends Interceptor {
  JarCookieInterceptor(this.jar);

  final CookieJar jar;

  @override
  Future<void> onRequest(
      RequestOptions options, RequestInterceptorHandler handler) async {
    try {
      final cookies = await jar.loadForRequest(options.uri);
      final existing = (options.headers['cookie'] as String?)?.trim();
      final values = [
        if (existing != null && existing.isNotEmpty) existing,
        for (final c in cookies) '${c.name}=${c.value}',
      ];
      if (values.isEmpty) {
        options.headers.remove('cookie');
      } else {
        options.headers['cookie'] = values.join('; ');
      }
      handler.next(options);
    } on Object catch (e, s) {
      handler.reject(DioException(requestOptions: options, error: e, stackTrace: s));
    }
  }

  @override
  Future<void> onResponse(
      Response<dynamic> response, ResponseInterceptorHandler handler) async {
    try {
      await _save(response);
      handler.next(response);
    } on Object catch (e, s) {
      handler.reject(DioException(
          requestOptions: response.requestOptions, error: e, stackTrace: s));
    }
  }

  @override
  Future<void> onError(DioException err, ErrorInterceptorHandler handler) async {
    final response = err.response;
    if (response != null) {
      try {
        await _save(response);
      } on Object {
        // 원래 오류를 우선한다.
      }
    }
    handler.next(err);
  }

  Future<void> _save(Response<dynamic> response) async {
    final values = response.headers['set-cookie'];
    if (values == null || values.isEmpty) return;
    await jar.saveFromResponse(response.requestOptions.uri,
        [for (final v in values) Cookie.fromSetCookieValue(v)]);
  }
}
```

Run: `C:\src\flutter\bin\flutter.bat test test/core/network/jar_cookie_interceptor_test.dart`
Expected: PASS — 3 tests

- [ ] **Step 4: libcurl.js 바인딩과 플랫폼 선택 작성**

`lib/core/network/libcurl/libcurl_js_binding.dart`:

```dart
import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

import 'curl_binding.dart';

@JS('libcurl')
external _Libcurl? get _libcurl;

extension type _Libcurl._(JSObject _) implements JSObject {
  @JS('load_wasm')
  external JSPromise<JSAny?> loadWasm(String url);

  @JS('set_websocket')
  external void setWebsocket(String url);

  external JSPromise<_CurlJsResponse> fetch(String url, JSObject params);
}

extension type _CurlJsResponse._(JSObject _) implements JSObject {
  external int get status;

  @JS('raw_headers')
  external JSArray<JSArray<JSString>> get rawHeaders;

  external JSPromise<JSArrayBuffer> arrayBuffer();
}

/// web/index.html이 먼저 불러온 libcurl.js 전역 객체를 쓴다.
class LibcurlJsBinding implements CurlBinding {
  LibcurlJsBinding({required this.relayUrl, this.wasmUrl = 'vendor/libcurl.wasm'});

  final String relayUrl;
  final String wasmUrl;
  Future<void>? _ready;

  Future<void> _ensureReady() {
    return _ready ??= () async {
      final lib = _libcurl;
      if (lib == null) {
        throw const CurlException('libcurl.js를 불러오지 못했습니다.');
      }
      await lib.loadWasm(wasmUrl).toDart;
      lib.setWebsocket(relayUrl);
    }()
        .catchError((Object e) {
      _ready = null;
      throw e is CurlException ? e : CurlException('$e');
    });
  }

  @override
  Future<CurlResponse> fetch(CurlRequest request) async {
    await _ensureReady();

    final headers = JSObject();
    request.headers.forEach((name, value) => headers[name] = value.toJS);

    final params = JSObject()
      ..['method'] = request.method.toJS
      ..['headers'] = headers
      ..['redirect'] = (request.followRedirects ? 'follow' : 'manual').toJS
      // 학교 서버가 HTTP/2를 제대로 받는지 알 수 없어 1.1로 고정한다.
      ..['_libcurl_http_version'] = 1.1.toJS;
    final body = request.body;
    if (body != null) params['body'] = body.toJS;

    final abort = web.AbortController();
    params['signal'] = abort.signal;
    request.cancel?.then((_) => abort.abort());

    try {
      final res = await _libcurl!.fetch(request.url, params).toDart;
      final pairs = <(String, String)>[
        for (final pair in res.rawHeaders.toDart)
          (pair.toDart[0].toDart, pair.toDart[1].toDart),
      ];
      final bytes = (await res.arrayBuffer().toDart).toDart.asUint8List();
      return CurlResponse(
          status: res.status, headers: pairs, body: Uint8List.fromList(bytes));
    } on Object catch (e) {
      throw CurlException('$e');
    }
  }
}
```

`lib/core/network/platform_http.dart`:

```dart
export 'platform_http_native.dart'
    if (dart.library.js_interop) 'platform_http_web.dart';
```

`lib/core/network/platform_http_native.dart`:

```dart
import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio/dio.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';

/// 네이티브는 dio 기본 어댑터를 그대로 쓴다.
HttpClientAdapter? platformHttpAdapter() => null;

Interceptor platformCookieInterceptor(CookieJar jar) => CookieManager(jar);
```

`lib/core/network/platform_http_web.dart`:

```dart
import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio/dio.dart';

import '../config/env.dart';
import 'jar_cookie_interceptor.dart';
import 'libcurl/libcurl_adapter.dart';
import 'libcurl/libcurl_js_binding.dart';

/// 모든 dio가 하나의 libcurl.js 연결(중계 서버 WebSocket)을 공유한다.
final _adapter =
    LibcurlHttpClientAdapter(LibcurlJsBinding(relayUrl: Env.relayUrl));

HttpClientAdapter? platformHttpAdapter() => _adapter;

Interceptor platformCookieInterceptor(CookieJar jar) => JarCookieInterceptor(jar);
```

`lib/core/config/env.dart`의 `webOrigin` 선언 아래에 추가:

```dart
  /// 웹(PWA)에서 libcurl.js가 접속할 Wisp 중계 서버. 끝의 `/`가 필요하다.
  /// 배포 빌드는 `--dart-define=RELAY_URL=wss://.../`로 넣는다.
  static const String relayUrl =
      String.fromEnvironment('RELAY_URL', defaultValue: 'ws://127.0.0.1:8080/');
```

- [ ] **Step 5: 배선**

`lib/core/network/dio_client.dart`: import에 `import 'platform_http.dart';` 추가. `buildDio`의 `return dio;` 직전과 `buildAuthDio`에서 어댑터를 붙인다. `buildAuthDio`는 다음으로 바꾼다:

```dart
/// 로그인·재발급 전용 dio. 인터셉터가 없어 재발급 재귀가 생기지 않는다.
Dio buildAuthDio() {
  final dio = Dio(BaseOptions(
    baseUrl: Env.apiBaseUrl,
    connectTimeout: Env.connectTimeout,
    receiveTimeout: Env.receiveTimeout,
    headers: {
      'Content-Type': 'application/json',
      'Origin': Env.webOrigin,
      'Referer': '${Env.webOrigin}/',
    },
  ));
  final adapter = platformHttpAdapter();
  if (adapter != null) dio.httpClientAdapter = adapter;
  return dio;
}
```

`buildDio`에서는 `dio.interceptors.add(AuthInterceptor(...));` 앞에 추가:

```dart
  final adapter = platformHttpAdapter();
  if (adapter != null) dio.httpClientAdapter = adapter;
```

`lib/features/canvas/data/canvas_client.dart` 전체:

```dart
import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio/dio.dart';

import '../../../core/config/env.dart';
import '../../../core/network/platform_http.dart';

/// Canvas는 Bearer 토큰이 아니라 세션 쿠키로 인증한다. 쿠키 매니저가 없으면
/// ACS 응답의 `_normandy_session`이 저장되지 않아 이후 모든 API가 막힌다.
/// 이 팩토리를 테스트와 운영이 함께 써서 배선이 어긋나지 않게 한다.
Dio buildCanvasDio(CookieJar jar, {HttpClientAdapter? adapter}) {
  final dio = Dio(BaseOptions(
    connectTimeout: Env.connectTimeout,
    receiveTimeout: Env.receiveTimeout,
    headers: {'Accept': 'application/json'},
  ));
  final selected = adapter ?? platformHttpAdapter();
  if (selected != null) dio.httpClientAdapter = selected;
  dio.interceptors.add(platformCookieInterceptor(jar));
  return dio;
}
```

`web/index.html`의 `<body>` 안, `flutter_bootstrap.js` script 태그 **앞**에 추가:

```html
  <!-- 학교 서버와의 TLS를 브라우저 안에서 맺는다. 파일은 web/vendor/SHA256SUMS로 검증한다. -->
  <script src="vendor/libcurl.js"></script>
```

- [ ] **Step 6: 확인**

Run: `C:\src\flutter\bin\flutter.bat analyze; C:\src\flutter\bin\flutter.bat test`
Expected: `No issues found!`, `All tests passed!` (기존 292 + Task 5의 5 + 이 태스크 3)

Run: `C:\src\flutter\bin\flutter.bat build web`
Expected: `√ Built build\web`

로컬 연동 확인(사용자 실행): 터미널 1에서 `cd relay && RELAY_ALLOWED_ORIGINS=http://localhost:8000 npm start`, 터미널 2에서 `C:\src\flutter\bin\flutter.bat run -d chrome --web-port 8000`. 로그인 후 강의 목록이 보이는지, relay 로그에 `opening new TCP stream to lms.kumoh.ac.kr:82`와 `canvas.kumoh.ac.kr:443`이 찍히는지 확인한다.

- [ ] **Step 7: Commit**

```bash
git add lib/core/network lib/core/config/env.dart lib/features/canvas/data/canvas_client.dart web/index.html test/core/network/jar_cookie_interceptor_test.dart
git commit -m "feat: 웹에서 libcurl.js 터널로 학교 서버에 요청한다

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

### Task 7: 웹 토큰 저장소와 자동 로그인 숨김

**Files:**
- Modify: `lib/core/network/token_store.dart` (`WebTokenStore` 추가)
- Modify: `lib/providers.dart:28` (`tokenStoreProvider`)
- Modify: `lib/features/auth/presentation/login_screen.dart` (생성자 인자, 102~108행)
- Test: `test/core/network/web_token_store_test.dart`
- Test: `test/features/auth/login_remember_me_test.dart`

**Interfaces:**
- Produces: `class WebTokenStore extends SecureTokenStore`, `LoginScreen({bool allowRememberMe = !kIsWeb, bool? showInstallHint})` (`showInstallHint`는 Task 10에서 사용)

- [ ] **Step 1: 실패하는 테스트 작성**

`test/core/network/web_token_store_test.dart`:

```dart
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kumoh_lms/core/network/token_store.dart';

void main() {
  test('웹 저장소는 비밀번호를 저장하지 않고 토큰은 유지한다', () async {
    FlutterSecureStorage.setMockInitialValues({});
    final store = WebTokenStore();

    await store.saveCredentials(userId: '20250001', password: 'secret');
    await store.saveTokens(accessToken: 'a', refreshToken: 'r');

    expect(await store.readCredentials(), isNull);
    expect(await const FlutterSecureStorage().read(key: 'cred_password'), isNull);
    expect(await store.readAccessToken(), 'a');
    expect(await store.readRefreshToken(), 'r');
  });
}
```

`login_screen.dart`의 생성자와 `ProviderScope` 의존성을 확인한 뒤(`sed -n 1,40p lib/features/auth/presentation/login_screen.dart`) `test/features/auth/login_remember_me_test.dart`를 작성한다:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kumoh_lms/core/network/token_store.dart';
import 'package:kumoh_lms/features/auth/presentation/login_screen.dart';
import 'package:kumoh_lms/providers.dart';

void main() {
  Widget app(LoginScreen screen) => ProviderScope(
        overrides: [tokenStoreProvider.overrideWithValue(InMemoryTokenStore())],
        child: MaterialApp(home: screen),
      );

  testWidgets('자동 로그인을 허용하지 않으면 스위치를 숨긴다', (tester) async {
    await tester.pumpWidget(app(const LoginScreen(allowRememberMe: false)));
    expect(find.text('자동 로그인'), findsNothing);
  });

  testWidgets('기본값(네이티브)은 자동 로그인 스위치를 보여준다', (tester) async {
    await tester.pumpWidget(app(const LoginScreen()));
    expect(find.text('자동 로그인'), findsOneWidget);
  });
}
```

(위젯이 다른 provider를 요구해 실패하면 `test/widget_test.dart`의 LoginScreen 사용 부분에서 쓰는 override를 그대로 가져온다.)

- [ ] **Step 2: 실패 확인**

Run: `C:\src\flutter\bin\flutter.bat test test/core/network/web_token_store_test.dart test/features/auth/login_remember_me_test.dart`
Expected: FAIL — `WebTokenStore`, `allowRememberMe` 없음

- [ ] **Step 3: 구현**

`lib/core/network/token_store.dart`의 `SecureTokenStore` 클래스 뒤에 추가:

```dart
/// 웹 전용. 브라우저 저장소는 기기 보안 저장소만큼 보호되지 않으므로
/// 비밀번호는 보관하지 않는다. 토큰이 만료되면 다시 로그인한다.
class WebTokenStore extends SecureTokenStore {
  WebTokenStore([super.storage]);

  @override
  Future<void> saveCredentials(
      {required String userId, required String password}) async {}

  @override
  Future<Credentials?> readCredentials() async => null;
}
```

`lib/providers.dart`: `import 'package:flutter/foundation.dart' show kIsWeb;` 추가 후

```dart
final tokenStoreProvider = Provider<TokenStore>(
    (ref) => kIsWeb ? WebTokenStore() : SecureTokenStore());
```

`login_screen.dart`: `import 'package:flutter/foundation.dart' show kIsWeb;` 추가. 생성자를 다음으로 바꾼다:

```dart
  const LoginScreen({super.key, this.allowRememberMe = !kIsWeb, this.showInstallHint});

  /// 웹은 비밀번호를 저장하지 않으므로 자동 로그인을 제공하지 않는다.
  final bool allowRememberMe;

  /// null이면 실행 환경으로 판단한다(Task 10).
  final bool? showInstallHint;
```

102~108행의 `SwitchListTile.adaptive(...)`를 `if (widget.allowRememberMe) SwitchListTile.adaptive(...)`로 감싼다.

- [ ] **Step 4: 통과 확인**

Run: `C:\src\flutter\bin\flutter.bat analyze; C:\src\flutter\bin\flutter.bat test`
Expected: `No issues found!`, `All tests passed!`

- [ ] **Step 5: Commit**

```bash
git add lib/core/network/token_store.dart lib/providers.dart lib/features/auth/presentation/login_screen.dart test/core/network/web_token_store_test.dart test/features/auth/login_remember_me_test.dart
git commit -m "feat: 웹에서는 비밀번호를 저장하지 않는다

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

### Task 8: 웹 파일 열기

네이티브는 파일로 받아 `open_filex`로 연다. 웹은 파일 시스템이 없으므로 바이트를 Blob URL로 새 창에 연다. iOS Safari는 `await` 뒤에 연 창을 팝업으로 막으므로 **탭 직후 빈 창을 먼저 연다.**

**Files:**
- Rename: `lib/features/canvas/presentation/canvas_file_open.dart` → `canvas_file_open_io.dart`
- Create: `lib/features/canvas/presentation/canvas_file_open.dart` (조건부 export)
- Create: `lib/features/canvas/presentation/canvas_file_open_web.dart`

**Interfaces:**
- Produces: 두 구현 모두 `Future<void> openCanvasFile(BuildContext context, WidgetRef ref, {required String url, required String displayName})`

- [ ] **Step 1: 이동과 조건부 export**

Run: `git mv lib/features/canvas/presentation/canvas_file_open.dart lib/features/canvas/presentation/canvas_file_open_io.dart`

`lib/features/canvas/presentation/canvas_file_open.dart`:

```dart
export 'canvas_file_open_io.dart'
    if (dart.library.js_interop) 'canvas_file_open_web.dart';
```

- [ ] **Step 2: 웹 구현**

`lib/features/canvas/presentation/canvas_file_open_web.dart`:

```dart
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:web/web.dart' as web;

import '../../../core/ui/empty_state.dart';
import '../../../providers.dart';
import '../../auth/data/auth_api.dart' show throwAsFailure;
import '../data/canvas_download.dart' show safeFileName;

/// 세션이 붙은 dio(libcurl 터널)로 받아 Blob URL로 연다.
Future<void> openCanvasFile(
  BuildContext context,
  WidgetRef ref, {
  required String url,
  required String displayName,
}) async {
  final messenger = ScaffoldMessenger.of(context);
  // 사용자 탭 처리 안에서 먼저 연다. await 뒤에 열면 iOS Safari가 막는다.
  final win = web.window.open('', '_blank');
  messenger.showSnackBar(SnackBar(content: Text('$displayName 받는 중…')));

  try {
    final Response<List<int>> res;
    try {
      res = await ref.read(canvasDioProvider).getUri<List<int>>(
            Uri.parse(url),
            options: Options(responseType: ResponseType.bytes),
          );
    } on DioException catch (e) {
      throwAsFailure(e);
    }

    final bytes = Uint8List.fromList(res.data ?? const []);
    final type = res.headers.value('content-type') ?? 'application/octet-stream';
    final blob = web.Blob(<JSAny>[bytes.toJS].toJS, web.BlobPropertyBag(type: type));
    final objectUrl = web.URL.createObjectURL(blob);

    if (win != null) {
      win.location.href = objectUrl;
    } else {
      (web.HTMLAnchorElement()
            ..href = objectUrl
            ..download = safeFileName(displayName))
          .click();
    }
    messenger.hideCurrentSnackBar();
    Future<void>.delayed(
        const Duration(minutes: 1), () => web.URL.revokeObjectURL(objectUrl));
  } on Object catch (e) {
    win?.close();
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(SnackBar(content: Text(userMessage(e))));
  }
}
```

- [ ] **Step 3: 확인**

Run: `C:\src\flutter\bin\flutter.bat analyze; C:\src\flutter\bin\flutter.bat test`
Expected: `No issues found!`, `All tests passed!` (기존 `canvas_file_open_test.dart`는 export를 통해 io 구현을 계속 쓴다)

Run: `C:\src\flutter\bin\flutter.bat build web`
Expected: `√ Built build\web`

로컬 연동 확인(사용자 실행, Task 6 Step 6 환경): 강좌 → 강의자료실에서 PDF를 눌러 새 탭에 PDF가 열리는지 확인한다.

- [ ] **Step 4: Commit**

```bash
git add lib/features/canvas/presentation/canvas_file_open.dart lib/features/canvas/presentation/canvas_file_open_io.dart lib/features/canvas/presentation/canvas_file_open_web.dart
git commit -m "feat: 웹에서 강의 파일을 새 창으로 연다

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

### Task 9: 웹에서 로그인된 Canvas 원문 열기

Task 1의 **브라우저 SAML POST** 판정으로 방식을 고른다.
- 성공 → **방식 A**: 터널로 SAML 폼까지 받고 마지막 POST를 브라우저 창이 한다.
- 실패 → **방식 B**: 새 탭으로 원문 주소를 열고 학교 사이트 로그인이 필요할 수 있다고 안내한다.

두 방식 모두 Step 1~2(`fetchSamlForm` 분리)와 Step 4(런처 분리)는 같다. 방식 B는 Step 1~3을 건너뛴다.

**Files:**
- Modify: `lib/features/canvas/data/canvas_session.dart` (`fetchSamlForm` 추출, 방식 A만)
- Modify: `test/features/canvas/canvas_session_test.dart` (방식 A만)
- Create: `lib/features/canvas/presentation/canvas_page_launcher.dart`
- Create: `lib/features/canvas/presentation/canvas_page_launcher_native.dart`
- Create: `lib/features/canvas/presentation/canvas_page_launcher_web.dart`
- Modify: `lib/features/canvas/presentation/canvas_web_target.dart:34-53`

**Interfaces:**
- Consumes: `canvasSessionProvider`, `canvasRelayState`, `SamlForm`
- Produces: `Future<SamlForm> CanvasSession.fetchSamlForm({String relayState = '/courses'})` (방식 A), `Future<void> launchCanvasPage(BuildContext context, {required String title, required String url})`

- [ ] **Step 1 (방식 A): 실패하는 테스트 작성**

`test/features/canvas/canvas_session_test.dart`의 `main()` 마지막 테스트 뒤에 추가:

```dart
  test('fetchSamlForm은 ACS에 POST하지 않고 IdP 폼을 돌려준다', () async {
    // 웹은 마지막 POST를 브라우저가 해야 세션 쿠키가 브라우저에 남는다.
    final script = _SamlScript(idpBody: autoSubmitForm('BLOB=='));
    final session = build(script);

    final form = await session.fetchSamlForm(relayState: '/courses/5342');

    expect(form.samlResponse, 'BLOB==');
    expect(form.action, 'https://canvas.kumoh.ac.kr/login/saml');
    expect(script.calls.where((c) => c.startsWith('POST')), isEmpty);
    expect(session.isActive, isFalse);
  });
```

Run: `C:\src\flutter\bin\flutter.bat test test/features/canvas/canvas_session_test.dart`
Expected: FAIL — `fetchSamlForm` 없음

- [ ] **Step 2 (방식 A): fetchSamlForm 추출**

`canvas_session.dart`의 `_bridge`를 둘로 나눈다. `_bridge` 본문 중 토큰 확인부터 `parseSamlForm` 결과 확인까지를 옮긴다:

```dart
  /// IdP의 SAML 자동 제출 폼까지만 받는다.
  ///
  /// 네이티브는 이어서 우리가 ACS에 POST한다([_bridge]). 웹은 이 폼을
  /// 브라우저 창에서 제출해야 Canvas 세션 쿠키가 브라우저에 생긴다.
  Future<SamlForm> fetchSamlForm({String relayState = '/courses'}) async {
    final token = await _identityToken();
    if (token == null || token.isEmpty) {
      throw const AuthFailure('로그인 정보가 없어 Canvas에 연결할 수 없습니다.');
    }

    // IdP는 이 쿠키로 사용자를 식별한다. 값은 서명된 accessToken(JWT)이어야
    // 하며, IdP가 서명을 검증한다. 예전처럼 학번 평문을 심으면 검증에 실패해
    // (S010) 폼 대신 500이 돌아오고, 비어 있으면 A001로 거부한다.
    await _jar.saveFromResponse(Uri.parse(Env.canvasBridgeCookieHost), [
      Cookie('_linus_saml_login', token)
        ..domain = '.kumoh.ac.kr'
        ..path = '/',
      Cookie('_linus_saml_domain', relayState)
        ..domain = '.kumoh.ac.kr'
        ..path = '/',
    ]);

    final ssoUrl = await _fetchSsoUrl(relayState);

    // 리다이렉트를 직접 따라간다. dio는 리다이렉트마다 인터셉터를 다시
    // 실행하지 않아서, followRedirects에 맡기면 쿠키 매니저가 첫 홉(canvas)에만
    // 쿠키를 붙인다. 그러면 리다이렉트된 IdP(lms) 요청에 _linus_saml_login이
    // 빠져 폼 대신 오류가 돌아온다.
    final idp = await _followRedirects(Uri.parse(ssoUrl));

    final form = parseSamlForm(idp);
    if (form == null) {
      throw const AuthFailure('Canvas 연결에 실패했습니다. 다시 로그인해 주세요.');
    }
    return form;
  }

  Future<void> _bridge({String relayState = '/courses'}) async {
    final form = await fetchSamlForm(relayState: relayState);

    // 브라우저의 JS 자동 제출을 대신한다.
    await _dio.postUri<void>(
      Uri.parse(form.action),
      data: {
        'SAMLResponse': form.samlResponse,
        'RelayState': form.relayState,
      },
      options: Options(
        contentType: Headers.formUrlEncodedContentType,
        followRedirects: false,
        // 302가 정상 종료다.
        validateStatus: (s) => s != null && s < 400,
      ),
    );

    _active = true;
  }
```

Run: `C:\src\flutter\bin\flutter.bat test test/features/canvas/canvas_session_test.dart`
Expected: PASS — 기존 테스트 전부 + 새 테스트

- [ ] **Step 3 (방식 A): 커밋**

```bash
git add lib/features/canvas/data/canvas_session.dart test/features/canvas/canvas_session_test.dart
git commit -m "refactor: SAML 폼 받기를 브리지에서 분리한다

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

- [ ] **Step 4: 런처 분리 (공통)**

`lib/features/canvas/presentation/canvas_page_launcher.dart`:

```dart
export 'canvas_page_launcher_native.dart'
    if (dart.library.js_interop) 'canvas_page_launcher_web.dart';
```

`lib/features/canvas/presentation/canvas_page_launcher_native.dart`:

```dart
import 'package:flutter/material.dart';

import 'canvas_web_screen.dart';

/// 네이티브는 쿠키를 주입할 수 있는 앱 내 WebView로 연다.
Future<void> launchCanvasPage(
  BuildContext context, {
  required String title,
  required String url,
}) {
  return Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => CanvasWebScreen(title: title, url: url),
    ),
  );
}
```

`lib/features/canvas/presentation/canvas_web_target.dart`: `import 'canvas_web_screen.dart';`를 `import 'canvas_page_launcher.dart';`로 바꾸고, `openCanvasPage` 끝의 `await Navigator.of(context).push(...)`를 다음으로 바꾼다:

```dart
  await launchCanvasPage(context, title: title, url: url);
```

- [ ] **Step 5: 웹 런처 작성 (방식 A 또는 B 중 하나)**

**방식 A** — `lib/features/canvas/presentation/canvas_page_launcher_web.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:web/web.dart' as web;

import '../../../core/ui/empty_state.dart';
import '../../../providers.dart';
import 'canvas_web_target.dart' show canvasRelayState;

/// 웹은 `.kumoh.ac.kr` 쿠키를 만들 수 없다. 대신 터널로 SAML 폼까지 받고,
/// 마지막 ACS POST를 브라우저 창이 직접 해서 Canvas 세션을 브라우저에 만든다.
/// SAMLResponse와 토큰은 브라우저와 학교 서버 사이에서만 오간다.
Future<void> launchCanvasPage(
  BuildContext context, {
  required String title,
  required String url,
}) async {
  final relayState = canvasRelayState(url)!;
  final messenger = ScaffoldMessenger.of(context);
  final container = ProviderScope.containerOf(context, listen: false);
  // 사용자 탭 처리 안에서 먼저 연다. await 뒤에 열면 팝업으로 막힌다.
  final win = web.window.open('', '_blank');
  win?.document.body?.textContent = '$title 여는 중…';

  try {
    final form = await container
        .read(canvasSessionProvider)
        .fetchSamlForm(relayState: relayState);
    // 창을 못 열었으면 현재 창에서 제출한다. PWA가 Canvas로 넘어간다.
    final doc = (win ?? web.window).document;
    final formEl = doc.createElement('form') as web.HTMLFormElement
      ..method = 'POST'
      ..action = form.action;
    for (final (name, value) in [
      ('SAMLResponse', form.samlResponse),
      ('RelayState', form.relayState),
    ]) {
      formEl.append(doc.createElement('input') as web.HTMLInputElement
        ..type = 'hidden'
        ..name = name
        ..value = value);
    }
    doc.body!.append(formEl);
    formEl.submit();
  } on Object catch (e) {
    win?.close();
    messenger.showSnackBar(SnackBar(content: Text(userMessage(e))));
  }
}
```

**방식 B** — `lib/features/canvas/presentation/canvas_page_launcher_web.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:web/web.dart' as web;

import '../../../core/config/env.dart';
import 'canvas_web_target.dart' show canvasRelayState;

/// 브라우저가 제출한 SAML 응답을 Canvas가 받지 않아(스파이크 2026-09),
/// 원문을 새 탭으로 열고 학교 사이트 로그인이 필요할 수 있다고 알린다.
Future<void> launchCanvasPage(
  BuildContext context, {
  required String title,
  required String url,
}) async {
  final target = Uri.parse(Env.canvasHost).resolve(canvasRelayState(url)!);
  web.window.open(target.toString(), '_blank');
  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
    content: Text('새 탭에서 열었습니다. 학교 LMS 로그인이 필요할 수 있습니다.'),
  ));
}
```

- [ ] **Step 6: 확인**

Run: `C:\src\flutter\bin\flutter.bat analyze; C:\src\flutter\bin\flutter.bat test`
Expected: `No issues found!`, `All tests passed!` (`lms_regressions_test.dart`는 네이티브 런처로 `CanvasWebScreen`을 계속 확인한다)

Run: `C:\src\flutter\bin\flutter.bat build web`
Expected: `√ Built build\web`

로컬 연동 확인(사용자 실행): 공지 탭에서 공지를 눌러 새 탭에 로그인된 원문(방식 A) 또는 원문 주소(방식 B)가 열리는지 확인한다.

- [ ] **Step 7: Commit**

```bash
git add lib/features/canvas/presentation/canvas_page_launcher.dart lib/features/canvas/presentation/canvas_page_launcher_native.dart lib/features/canvas/presentation/canvas_page_launcher_web.dart lib/features/canvas/presentation/canvas_web_target.dart
git commit -m "feat: 웹에서 Canvas 원문을 새 창으로 연다

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

### Task 10: PWA 설치 정보와 홈 화면 추가 안내

**Files:**
- Create: `flutter_launcher_icons_web.yaml`
- Modify: `web/manifest.json`, `web/index.html`, `web/icons/*`, `web/favicon.png` (아이콘 생성 산출물)
- Create: `lib/core/platform/browser_display.dart`
- Create: `lib/core/platform/browser_display_native.dart`
- Create: `lib/core/platform/browser_display_web.dart`
- Create: `lib/features/auth/presentation/install_hint.dart`
- Modify: `lib/features/auth/presentation/login_screen.dart`
- Test: `test/features/auth/install_hint_test.dart`

**Interfaces:**
- Consumes: `LoginScreen.showInstallHint` (Task 7)
- Produces: `bool get runsInBrowserTab`, `class InstallHint extends StatelessWidget`

- [ ] **Step 1: 실패하는 테스트 작성**

`test/features/auth/install_hint_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kumoh_lms/core/network/token_store.dart';
import 'package:kumoh_lms/features/auth/presentation/install_hint.dart';
import 'package:kumoh_lms/features/auth/presentation/login_screen.dart';
import 'package:kumoh_lms/providers.dart';

void main() {
  Widget app(Widget child) => ProviderScope(
        overrides: [tokenStoreProvider.overrideWithValue(InMemoryTokenStore())],
        child: MaterialApp(home: child),
      );

  testWidgets('설치 안내는 Safari 공유 → 홈 화면에 추가 순서를 알려준다', (tester) async {
    await tester.pumpWidget(app(const Scaffold(body: InstallHint())));
    expect(find.textContaining('홈 화면에 추가'), findsOneWidget);
  });

  testWidgets('로그인 화면은 요청할 때만 설치 안내를 보여준다', (tester) async {
    await tester.pumpWidget(app(const LoginScreen(showInstallHint: true)));
    expect(find.byType(InstallHint), findsOneWidget);

    await tester.pumpWidget(app(const LoginScreen(showInstallHint: false)));
    expect(find.byType(InstallHint), findsNothing);
  });
}
```

Run: `C:\src\flutter\bin\flutter.bat test test/features/auth/install_hint_test.dart`
Expected: FAIL — `install_hint.dart` 없음

- [ ] **Step 2: 구현**

`lib/core/platform/browser_display.dart`:

```dart
export 'browser_display_native.dart'
    if (dart.library.js_interop) 'browser_display_web.dart';
```

`lib/core/platform/browser_display_native.dart`:

```dart
bool get runsInBrowserTab => false;
```

`lib/core/platform/browser_display_web.dart`:

```dart
import 'package:web/web.dart' as web;

/// 홈 화면에 추가해 실행하면 standalone 모드다. 브라우저 탭이면 설치 안내를 띄운다.
bool get runsInBrowserTab =>
    !web.window.matchMedia('(display-mode: standalone)').matches;
```

`lib/features/auth/presentation/install_hint.dart`:

```dart
import 'package:flutter/material.dart';

/// iOS는 PWA 설치 버튼이 없어 사용자가 직접 홈 화면에 추가해야 한다.
class InstallHint extends StatelessWidget {
  const InstallHint({super.key});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            const Icon(Icons.ios_share),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Safari 아래쪽 공유 버튼을 누르고 "홈 화면에 추가"를 선택하면 앱처럼 쓸 수 있습니다.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
```

`login_screen.dart`: import 추가

```dart
import '../../../core/platform/browser_display.dart';
import 'install_hint.dart';
```

폼 `Column`의 첫 자식으로 추가(학번 입력 필드 앞):

```dart
                    if (widget.showInstallHint ?? (kIsWeb && runsInBrowserTab)) ...[
                      const InstallHint(),
                      const SizedBox(height: 12),
                    ],
```

Run: `C:\src\flutter\bin\flutter.bat test test/features/auth/install_hint_test.dart`
Expected: PASS — 2 tests

- [ ] **Step 3: 웹 아이콘과 manifest**

`flutter_launcher_icons_web.yaml`:

```yaml
flutter_launcher_icons:
  android: false
  ios: false
  image_path: assets/branding/lms_app_icon_ochungi.png
  web:
    generate: true
    image_path: assets/branding/lms_app_icon_ochungi.png
    background_color: '#FFFFFF'
    theme_color: '#FFFFFF'
```

Run: `dart run flutter_launcher_icons -f flutter_launcher_icons_web.yaml`
Expected: `web/icons/Icon-*.png`, `web/favicon.png` 갱신. `git status --short`에 `android/`, `ios/` 변경이 없어야 한다.

`web/manifest.json`의 다음 키를 이 값으로 바꾼다(아이콘 배열은 생성된 그대로 둔다):

```json
  "name": "금오공대 LMS",
  "short_name": "금오 LMS",
  "start_url": ".",
  "display": "standalone",
  "background_color": "#FFFFFF",
  "theme_color": "#FFFFFF",
  "description": "금오공과대학교 Canvas LMS 클라이언트",
  "orientation": "portrait-primary",
```

`web/index.html`의 `<head>`에서 `apple-mobile-web-app-title` meta 값을 `금오 LMS`로, `<title>`을 `금오공대 LMS`로 바꾸고 다음이 있는지 확인해 없으면 추가한다:

```html
  <meta name="mobile-web-app-capable" content="yes">
  <meta name="apple-mobile-web-app-status-bar-style" content="default">
  <link rel="apple-touch-icon" href="icons/Icon-192.png">
```

- [ ] **Step 4: 확인**

Run: `C:\src\flutter\bin\flutter.bat analyze; C:\src\flutter\bin\flutter.bat test; C:\src\flutter\bin\flutter.bat build web`
Expected: `No issues found!`, `All tests passed!`, `√ Built build\web`

- [ ] **Step 5: Commit**

```bash
git add flutter_launcher_icons_web.yaml web lib/core/platform/browser_display.dart lib/core/platform/browser_display_native.dart lib/core/platform/browser_display_web.dart lib/features/auth/presentation/install_hint.dart lib/features/auth/presentation/login_screen.dart test/features/auth/install_hint_test.dart
git commit -m "feat: PWA 설치 정보와 홈 화면 추가 안내

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

### Task 11: 공개 CI 배포 — GitHub Pages와 중계 서버 이미지

**Files:**
- Create: `.github/workflows/pwa.yml`
- Create: `.github/workflows/relay-image.yml`

**Interfaces:**
- Consumes: 저장소 변수 `RELAY_URL` (Task 2 README 8단계), `web/vendor/SHA256SUMS` (Task 3), `relay/` (Task 2)
- Produces: `https://barahana25.github.io/kumoh-LMS/`, `ghcr.io/barahana25/kumoh-lms-relay:main`, `:<커밋 SHA>`

- [ ] **Step 1: PWA 워크플로 작성**

`.github/workflows/pwa.yml`:

```yaml
name: pwa

on:
  push:
    branches: [main]
    paths:
      - "lib/**"
      - "web/**"
      - "assets/**"
      - "test/**"
      - "pubspec.yaml"
      - "pubspec.lock"
      - ".github/workflows/pwa.yml"
  workflow_dispatch:

permissions:
  contents: read

concurrency:
  group: pages
  cancel-in-progress: false

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: 웹 런타임 파일 해시 확인
        working-directory: web/vendor
        run: sha256sum -c SHA256SUMS

      - name: 중계 서버 주소 확인
        run: test -n "${{ vars.RELAY_URL }}"

      - uses: subosito/flutter-action@v2
        with:
          flutter-version: 3.47.2
          channel: stable

      - name: 테스트용 SQLite
        run: sudo apt-get update && sudo apt-get install -y libsqlite3-dev

      - run: flutter pub get
      - run: flutter test
      - run: flutter test --platform chrome test/web

      - name: 웹 빌드
        run: >
          flutter build web --release
          --base-href /kumoh-LMS/
          --dart-define=RELAY_URL=${{ vars.RELAY_URL }}

      - uses: actions/upload-pages-artifact@v3
        with:
          path: build/web

  deploy:
    needs: build
    runs-on: ubuntu-latest
    permissions:
      pages: write
      id-token: write
    environment:
      name: github-pages
      url: ${{ steps.deployment.outputs.page_url }}
    steps:
      - id: deployment
        uses: actions/deploy-pages@v4
```

- [ ] **Step 2: 중계 서버 이미지 워크플로 작성**

`.github/workflows/relay-image.yml`:

```yaml
name: relay-image

on:
  push:
    branches: [main]
    paths:
      - "relay/**"
      - ".github/workflows/relay-image.yml"
  workflow_dispatch:

permissions:
  contents: read
  packages: write

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - uses: actions/setup-node@v4
        with:
          node-version: 24

      - name: 테스트
        working-directory: relay
        run: npm ci && npm test

      - uses: docker/login-action@v3
        with:
          registry: ghcr.io
          username: ${{ github.actor }}
          password: ${{ secrets.GITHUB_TOKEN }}

      - uses: docker/build-push-action@v6
        with:
          context: relay
          platforms: linux/amd64
          push: true
          tags: |
            ghcr.io/barahana25/kumoh-lms-relay:main
            ghcr.io/barahana25/kumoh-lms-relay:${{ github.sha }}
```

- [ ] **Step 3: 워크플로 문법 확인**

Run: `python -c "import yaml,sys; [yaml.safe_load(open(f, encoding='utf-8')) for f in sys.argv[1:]]; print('ok')" .github/workflows/pwa.yml .github/workflows/relay-image.yml`
Expected: `ok`

- [ ] **Step 4: Commit**

```bash
git add .github/workflows/pwa.yml .github/workflows/relay-image.yml
git commit -m "ci: PWA Pages 배포와 중계 서버 이미지 빌드

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

- [ ] **Step 5: 사용자 확인 후 GitHub 설정과 첫 실행**

사용자에게 확인을 받고 다음을 진행한다. 이 단계는 외부에 공개되는 작업이다.
1. 저장소 Settings → Pages → Source: **GitHub Actions**
2. Settings → Secrets and variables → Actions → Variables: `RELAY_URL` (Task 2 README 8단계 값)
3. 브랜치를 push하고 PR로 `main`에 병합 → `pwa`, `relay-image` 워크플로 성공 확인(`gh run list --limit 5`)
4. `flutter test`가 Linux에서만 실패하면 실패한 테스트를 고친 뒤 다시 실행한다. 배포 단계는 테스트가 통과해야 진행된다.

---

### Task 12: 실기기 확인 목록과 인수인계 문서

**Files:**
- Create: `docs/pwa/verification.md`
- Modify: `docs/HANDOFF.md` (맨 위에 절 추가)

- [ ] **Step 1: 확인 목록 작성**

`docs/pwa/verification.md`:

```markdown
# PWA 실기기 확인 목록

운영자가 NAS 배포(relay/README.md)와 Pages 배포(Task 11) 뒤 iPhone에서 확인한다. 결과는 각 줄 끝에 날짜와 함께 적는다.

## 준비

- [ ] `https://<DDNS>/healthz` → `ok`
- [ ] 저장소 Packages에서 배포한 relay 이미지 digest와 compose.yaml의 digest가 같다

## iPhone Safari (iOS 16.4 이상)

- [ ] `https://barahana25.github.io/kumoh-LMS/` 접속 시 로그인 화면에 홈 화면 추가 안내가 보인다
- [ ] 공유 → 홈 화면에 추가 → 아이콘과 이름 "금오 LMS" 확인
- [ ] 홈 화면 아이콘으로 실행하면 주소창 없이 열리고 설치 안내가 보이지 않는다
- [ ] 로그인 화면에 자동 로그인 스위치가 없다
- [ ] 로그인 → 강의 목록, 과제 캘린더, 공지 목록 표시
- [ ] 강좌 상세 9개 탭 이동
- [ ] 강의자료 PDF가 새 창에서 열린다
- [ ] 공지를 누르면 원문이 열린다 (방식 A: 로그인된 상태 / 방식 B: 새 탭 + 안내)
- [ ] 앱을 닫았다 다시 열면 로그인이 유지된다(토큰 유효 기간 안)
- [ ] 설정 화면에 알림·백그라운드·폴더 다운로드 항목이 없다
- [ ] 비행기 모드에서 다시 열면 캐시된 목록과 연결 실패 배너가 보인다

## 블라인드 확인 (PC Chrome)

- [ ] 개발자 도구 → Network → WS → 중계 서버 연결의 Messages가 바이너리이며 `lms.kumoh.ac.kr`, `canvas.kumoh.ac.kr` 호스트 이름 외에 읽을 수 있는 HTTP 헤더·JSON이 보이지 않는다
- [ ] NAS Container Manager 로그에 비밀번호·토큰·강의 이름이 없다

## 중계 서버 차단

- [ ] 다른 사이트 Origin으로 WebSocket 연결 시 403 (`relay/test/relay.test.mjs`와 같은 요청을 curl로: `curl -i -H "Connection: Upgrade" -H "Upgrade: websocket" -H "Origin: https://evil.example" -H "Sec-WebSocket-Version: 13" -H "Sec-WebSocket-Key: dGhlIHNhbXBsZSBub25jZQ==" https://<DDNS>/`)
```

- [ ] **Step 2: HANDOFF 갱신**

`docs/HANDOFF.md`의 첫 제목 줄 바로 아래에 다음 절을 추가한다(날짜는 실제 완료일):

```markdown
## iOS PWA 블라인드 중계 1단계 (<YYYY-MM-DD>)

- 목적: 유료 Apple 계정 없이 iPhone에 배포. Flutter 웹(PWA)을 GitHub Pages로 배포하고, 학교 서버 접속은 브라우저 안의 libcurl.js가 NAS의 Wisp 중계 서버를 거쳐 TLS를 직접 맺는다. 중계 서버는 암호문만 전달한다.
- 설계: docs/superpowers/specs/2026-09-14-pwa-blind-relay-design.md, 계획: docs/superpowers/plans/2026-09-14-pwa-blind-relay-stage1.md, 스파이크 결과: docs/pwa/spike-results.md
- 중계 서버: relay/ (허용 호스트 lms/canvas.kumoh.ac.kr, 포트 82/443, Origin 검사). NAS 배포는 relay/README.md
- 웹 차이는 조건부 export로 격리: DB(connection_*), HTTP(platform_http_*), 파일 열기(canvas_file_open_*), 원문 열기(canvas_page_launcher_*), 설치 감지(browser_display_*). 모바일 경로는 변경 없음
- 웹은 비밀번호를 저장하지 않고(WebTokenStore) DB를 암호화하지 않는다(캐시만)
- 웹 런타임 파일은 web/vendor에 커밋, tool/web_vendor.sh로 재현하고 SHA256SUMS로 검증. pubspec의 drift/sqlite3를 올리면 이 파일도 같은 버전으로 갱신해야 한다
- 검증: <VM 테스트 수>, 브라우저 테스트, relay 테스트 6개. 실기기 확인은 docs/pwa/verification.md
- 남은 단계: 2단계 투명성 장치(이미지 서명, 커밋 SHA 표시), 3단계 선택 동의 알림
```

- [ ] **Step 3: Commit**

```bash
git add docs/pwa/verification.md docs/HANDOFF.md
git commit -m "docs: PWA 실기기 확인 목록과 인수인계

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

## Self-Review 결과

**스펙 대비:**
- 블라인드 터널 구조 → Task 5, 6 / 중계 서버 허용 목록·Origin·로그 → Task 2 / NAS DDNS·인증서·리버스 프록시·443만 개방 → Task 2 README
- PWA GitHub Pages·Actions 전용 배포, Flutter 3.47.2 고정, RELAY_URL dart-define → Task 11, Task 6
- vendor 런타임을 CDN 없이 제공 → Task 3 / manifest·apple-touch-icon·standalone·설치 안내 → Task 10
- 쿠키는 Dart CookieJar, 수동 리다이렉트, SAML 브리지 재사용 → Task 5, 6
- 웹 DB WasmDatabase·비암호화, 비밀번호 미저장 → Task 3, 7
- 알림·백그라운드·폴더 다운로드 숨김 → Task 4(기존 `supported` 게이트가 false가 됨)
- Blob URL 파일 열기 → Task 8 / SAML POST 원문 열기와 대체 경로 → Task 9
- `Platform.is*` 교체 → Task 4 / 중계 서버 연결 불가 배너: 어댑터가 `connectionError` → 기존 `NetworkFailure` 흐름 → Task 5 테스트
- 스파이크 위험 1·2 → Task 1, 위험 3(iOS 창) → Task 12 확인 목록, 위험 4·5 → 운영 이슈로 HANDOFF에 스펙 링크

**스펙과 달라진 점(구현 중 확인한 사실 반영):**
- 로그 항목: wisp-js가 전송 바이트 수를 기록하지 않아 "시각, 대상 호스트:포트"로 줄였다. 대신 사용자 IP를 남기지 않도록 `parse_real_ip: false`를 추가했다.
- 팝업 차단 시 "팝업 허용 안내" 대신 현재 창 제출(방식 A)·다운로드 링크(파일)로 대체한다.
