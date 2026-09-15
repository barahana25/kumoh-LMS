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
