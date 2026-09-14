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
