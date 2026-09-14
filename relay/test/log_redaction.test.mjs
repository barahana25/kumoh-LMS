import test from "node:test";
import assert from "node:assert/strict";
import http from "node:http";
import WebSocket from "ws";
import { redactLogText, installLogRedaction } from "../src/log_redaction.mjs";
import { createRelayServer } from "../src/server.mjs";

const ORIGIN = "https://barahana25.github.io";

test("IPv4 주소를 [ip]로 가린다", () => {
  assert.equal(
    redactLogText("new connection on / from 203.0.113.7 (origin: https://barahana25.github.io)"),
    "new connection on / from [ip] (origin: https://barahana25.github.io)",
  );
});

test("IPv4-매핑 IPv6 주소를 [ip]로 가린다", () => {
  assert.equal(
    redactLogText("new connection on / from ::ffff:203.0.113.7 (origin: null)"),
    "new connection on / from [ip] (origin: null)",
  );
});

test("루프백 IPv6(::1)을 [ip]로 가린다", () => {
  assert.equal(redactLogText("from ::1 (origin: null)"), "from [ip] (origin: null)");
});

test("전체 IPv6 주소를 [ip]로 가린다", () => {
  assert.equal(redactLogText("from 2001:db8::1 (origin: null)"), "from [ip] (origin: null)");
});

test("호스트명:포트는 건드리지 않는다", () => {
  const text = "(1) opening new tcp stream to lms.kumoh.ac.kr:82";
  assert.equal(redactLogText(text), text);
});

test("wisp 타임스탬프는 건드리지 않는다", () => {
  const text = "[2026/09/14 - 12:34:56] info: setting up new wisp v1 connection with id 1";
  assert.equal(redactLogText(text), text);
});

test("installLogRedaction은 문자열 인자를 가리고 문자열 아닌 인자는 그대로 둔다", () => {
  const calls = [];
  const fake = {
    debug: (...a) => calls.push(["debug", a]),
    info: (...a) => calls.push(["info", a]),
    log: (...a) => calls.push(["log", a]),
    warn: (...a) => calls.push(["warn", a]),
    error: (...a) => calls.push(["error", a]),
  };
  installLogRedaction(fake);
  const err = new Error("boom");
  fake.info("from 203.0.113.7", "and", err, 42);
  assert.deepEqual(calls, [["info", ["from [ip]", "and", err, 42]]]);
});

test("installLogRedaction은 멱등이다 (두 번 걸어도 한 번만 적용)", () => {
  const calls = [];
  const fake = { debug() {}, info: (...a) => calls.push(a), log() {}, warn() {}, error() {} };
  installLogRedaction(fake);
  installLogRedaction(fake);
  fake.info("from 203.0.113.7");
  assert.deepEqual(calls, [["from [ip]"]]);
});

test("통합: 중계 서버 콘솔 출력에 127.0.0.1이 남지 않는다", async (t) => {
  const originalConsole = { ...console };
  const captured = [];
  for (const method of ["debug", "info", "log", "warn", "error"]) {
    console[method] = (...args) => captured.push(args.map(String).join(" "));
  }
  t.after(() => {
    Object.assign(console, originalConsole);
  });

  const server = createRelayServer({ allowedOrigins: [ORIGIN] });
  await new Promise((resolve) => server.listen(0, "127.0.0.1", resolve));
  t.after(() => server.close());
  const port = server.address().port;

  await new Promise((resolve, reject) => {
    const ws = new WebSocket(`ws://127.0.0.1:${port}/`, { origin: ORIGIN });
    const timer = setTimeout(() => reject(new Error("연결 로그를 받지 못함")), 5000);
    ws.on("open", () => {
      setTimeout(() => {
        clearTimeout(timer);
        ws.close();
        resolve();
      }, 200);
    });
    ws.on("error", reject);
  });

  const combined = captured.join("\n");
  assert.equal(combined.includes("127.0.0.1"), false);
});
