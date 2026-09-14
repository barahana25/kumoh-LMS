import http from "node:http";
import { server as wisp, logging } from "@mercuryworkshop/wisp-js/server";
import { applyPolicy, isOriginAllowed } from "./policy.mjs";
import { installLogRedaction } from "./log_redaction.mjs";
import {
  MAX_CONNECTIONS,
  MAX_CONNECTIONS_PER_CLIENT,
  clientAddress,
  createConnectionLimiter,
} from "./limits.mjs";

export function createRelayServer({
  allowedOrigins,
  maxConnectionsPerClient = MAX_CONNECTIONS_PER_CLIENT,
  maxConnections = MAX_CONNECTIONS,
  trustForwardedFor = false,
}) {
  // wisp-js는 ES 모듈이라 밖에서 logging.info 등을 바꿔치기할 수 없고,
  // 접속 로그에 상대방 IP를 그대로 남긴다(new connection ... from ${real_ip}).
  // console을 가로채서 어떤 경로로도 IP가 로그에 남지 않게 한다.
  installLogRedaction();
  applyPolicy(wisp.options);
  // INFO는 연결·스트림의 시각과 대상 호스트:포트를 남긴다. 내용은 암호문이라 남길 수 없다.
  logging.set_level(logging.INFO);

  const acquire = createConnectionLimiter({
    perClient: maxConnectionsPerClient,
    total: maxConnections,
  });

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
    const release = acquire(clientAddress(req, { trustForwardedFor }));
    if (!release) {
      socket.end("HTTP/1.1 429 Too Many Requests\r\nConnection: close\r\n\r\n");
      return;
    }
    // 연결이 어떤 이유로 끝나든 소켓이 닫힐 때 자리를 돌려준다.
    socket.once("close", release);
    wisp.routeRequest(req, socket, head);
  });

  return server;
}
