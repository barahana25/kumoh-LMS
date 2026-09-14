import test from "node:test";
import assert from "node:assert/strict";
import WebSocket from "ws";
import { createRelayServer } from "../src/server.mjs";
import {
  MAX_CONNECTIONS,
  MAX_CONNECTIONS_PER_CLIENT,
  clientAddress,
  parseFlag,
  parseLimit,
} from "../src/limits.mjs";

const ORIGIN = "https://barahana25.github.io";

async function start(t, limits) {
  const server = createRelayServer({ allowedOrigins: [ORIGIN], ...limits });
  await new Promise((resolve) => server.listen(0, "127.0.0.1", resolve));
  // 서버를 만든 뒤(로그 가림 설치 후) wisp 접속 로그를 조용히 한다.
  // 연결 종료 로그는 테스트가 끝난 뒤에도 조금 늦게 찍히므로, 소켓을 닫고 잠시
  // 기다린 다음에 원래 콘솔로 되돌린다.
  const { info, warn } = console;
  console.info = () => {};
  console.warn = () => {};
  const sockets = [];
  t.after(async () => {
    for (const ws of sockets) ws.terminate();
    await new Promise((resolve) => server.close(resolve));
    await new Promise((resolve) => setTimeout(resolve, 100));
    console.info = info;
    console.warn = warn;
  });
  return { port: server.address().port, sockets };
}

// 업그레이드가 성공하면 101, 거부되면 그 HTTP 상태 코드를 돌려준다.
function connect({ port, sockets }, forwardedFor) {
  const headers = forwardedFor ? { "X-Forwarded-For": forwardedFor } : {};
  const ws = new WebSocket(`ws://127.0.0.1:${port}/`, { origin: ORIGIN, headers });
  sockets.push(ws);
  return new Promise((resolve, reject) => {
    ws.on("open", () => resolve({ status: 101, ws }));
    ws.on("unexpected-response", (_req, res) => resolve({ status: res.statusCode, ws }));
    ws.on("error", reject);
  });
}

async function closeAndWait(ws) {
  await new Promise((resolve) => {
    ws.on("close", resolve);
    ws.close();
  });
}

// 서버 쪽 소켓 close는 클라이언트 close보다 조금 늦을 수 있어 잠깐 재시도한다.
async function eventually(fn) {
  for (let i = 0; i < 50; i++) {
    const result = await fn();
    if (result.status === 101) return result;
    await new Promise((resolve) => setTimeout(resolve, 20));
  }
  return fn();
}

test("연결 수 제한 값을 환경 변수에서 읽는다", () => {
  assert.equal(parseLimit(undefined, 4), 4);
  assert.equal(parseLimit("", 4), 4);
  assert.equal(parseLimit("10", 4), 10);
  assert.equal(parseLimit("0", 4), 4);
  assert.equal(parseLimit("abc", 4), 4);
});

test("기본 한도는 클라이언트당 32, 전체 200이다", () => {
  assert.equal(MAX_CONNECTIONS_PER_CLIENT, 32);
  assert.equal(MAX_CONNECTIONS, 200);
});

test("루프백 프록시를 거친 요청만 X-Forwarded-For의 마지막 주소를 쓴다", () => {
  const req = (remoteAddress, xff) => ({
    socket: { remoteAddress },
    headers: xff === undefined ? {} : { "x-forwarded-for": xff },
  });
  // 한 개 값
  assert.equal(clientAddress(req("127.0.0.1", " 203.0.113.7 ")), "203.0.113.7");
  // 여러 값: 앞쪽은 클라이언트가 속일 수 있고, 마지막이 신뢰하는 프록시가 붙인 주소다.
  assert.equal(clientAddress(req("127.0.0.1", "spoofed, 10.0.0.1, 203.0.113.7")), "203.0.113.7");
  assert.equal(clientAddress(req("127.0.0.1", "203.0.113.7, ,")), "203.0.113.7");
  // 비어 있으면 상대 주소
  assert.equal(clientAddress(req("127.0.0.1", "")), "127.0.0.1");
  assert.equal(clientAddress(req("127.0.0.1", " , ")), "127.0.0.1");
  assert.equal(clientAddress(req("127.0.0.1", ["a, 203.0.113.5", "203.0.113.6"])), "203.0.113.6");
  assert.equal(clientAddress(req("::1", "203.0.113.8")), "203.0.113.8");
  assert.equal(clientAddress(req("::ffff:127.0.0.1", "203.0.113.9")), "203.0.113.9");
  assert.equal(clientAddress(req("127.0.0.1")), "127.0.0.1");
  assert.equal(clientAddress(req("198.51.100.1", "203.0.113.7")), "198.51.100.1");
});

test("trustForwardedFor면 상대 주소와 상관없이 X-Forwarded-For의 마지막 주소를 쓴다", () => {
  const req = (remoteAddress, xff) => ({
    socket: { remoteAddress },
    headers: xff === undefined ? {} : { "x-forwarded-for": xff },
  });
  for (const v of ["1", "true"]) assert.equal(parseFlag(v), true, v);
  for (const v of [undefined, "", "0", "false", "TRUE", "yes"]) assert.equal(parseFlag(v), false, String(v));
  const trust = { trustForwardedFor: true };
  // Docker 브리지 게이트웨이처럼 루프백이 아닌 상대
  assert.equal(clientAddress(req("172.17.0.1", "10.0.0.1, 203.0.113.7"), trust), "203.0.113.7");
  assert.equal(clientAddress(req("172.17.0.1"), trust), "172.17.0.1");
  assert.equal(clientAddress(req("172.17.0.1", " "), trust), "172.17.0.1");
  // 기본값은 루프백 상대만 믿는다.
  assert.equal(clientAddress(req("172.17.0.1", "203.0.113.7")), "172.17.0.1");
  assert.equal(clientAddress(req("172.17.0.1", "203.0.113.7"), { trustForwardedFor: false }), "172.17.0.1");
});

test("trustForwardedFor 서버는 X-Forwarded-For별로 세고 같은 값은 제한에 걸린다", async (t) => {
  const relay = await start(t, {
    maxConnectionsPerClient: 1,
    maxConnections: 100,
    trustForwardedFor: true,
  });
  assert.equal((await connect(relay, "203.0.113.7")).status, 101);
  assert.equal((await connect(relay, "203.0.113.8")).status, 101);
  assert.equal((await connect(relay, "203.0.113.7")).status, 429);
});

test("앞쪽 X-Forwarded-For를 바꿔도 프록시가 붙인 마지막 주소로 함께 센다", async (t) => {
  const relay = await start(t, { maxConnectionsPerClient: 2, maxConnections: 100 });
  assert.equal((await connect(relay, "spoofed-1, 203.0.113.7")).status, 101);
  assert.equal((await connect(relay, "spoofed-2, 203.0.113.7")).status, 101);
  assert.equal((await connect(relay, "spoofed-3, 203.0.113.7")).status, 429);
});

test("같은 클라이언트의 동시 연결이 제한을 넘으면 429로 거부하고, 닫히면 다시 받는다", async (t) => {
  const relay = await start(t, { maxConnectionsPerClient: 2, maxConnections: 100 });
  const a = await connect(relay, "203.0.113.7");
  const b = await connect(relay, "203.0.113.7");
  assert.equal(a.status, 101);
  assert.equal(b.status, 101);
  assert.equal((await connect(relay, "203.0.113.7")).status, 429);

  await closeAndWait(a.ws);
  assert.equal((await eventually(() => connect(relay, "203.0.113.7"))).status, 101);
});

test("X-Forwarded-For가 다른 클라이언트는 따로 센다", async (t) => {
  const relay = await start(t, { maxConnectionsPerClient: 1, maxConnections: 100 });
  assert.equal((await connect(relay, "203.0.113.7")).status, 101);
  assert.equal((await connect(relay, "203.0.113.8")).status, 101);
  assert.equal((await connect(relay, "203.0.113.7")).status, 429);
});

test("전체 동시 연결 제한을 넘으면 429로 거부한다", async (t) => {
  const relay = await start(t, { maxConnectionsPerClient: 10, maxConnections: 2 });
  assert.equal((await connect(relay, "203.0.113.1")).status, 101);
  assert.equal((await connect(relay, "203.0.113.2")).status, 101);
  assert.equal((await connect(relay, "203.0.113.3")).status, 429);
});
