import { createRelayServer } from "./server.mjs";
import { parseAllowedOrigins } from "./policy.mjs";
import { MAX_CONNECTIONS, MAX_CONNECTIONS_PER_CLIENT, parseLimit } from "./limits.mjs";

const allowedOrigins = parseAllowedOrigins(process.env.RELAY_ALLOWED_ORIGINS);
if (allowedOrigins.length === 0) {
  console.error("RELAY_ALLOWED_ORIGINS가 비어 있습니다. 예: https://barahana25.github.io");
  process.exit(1);
}
const port = Number(process.env.PORT ?? 8080);
const maxConnectionsPerClient = parseLimit(
  process.env.RELAY_MAX_CONNECTIONS_PER_CLIENT,
  MAX_CONNECTIONS_PER_CLIENT,
);
const maxConnections = parseLimit(process.env.RELAY_MAX_CONNECTIONS, MAX_CONNECTIONS);

createRelayServer({ allowedOrigins, maxConnectionsPerClient, maxConnections }).listen(
  port,
  "0.0.0.0",
  () => {
    console.log(
      `relay listening on :${port}, origins=${allowedOrigins.join(",")}, ` +
        `max=${maxConnections}, perClient=${maxConnectionsPerClient}`,
    );
  },
);
