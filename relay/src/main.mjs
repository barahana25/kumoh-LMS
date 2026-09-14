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
