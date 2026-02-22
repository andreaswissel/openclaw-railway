/**
 * OpenClaw Railway Health Check Server
 * Minimal server for Railway health checks only.
 */

import http from "node:http";
import { execSync } from "node:child_process";

const PORT = Number.parseInt(process.env.PORT ?? "8080", 10);

function isGatewayRunning() {
  try {
    execSync("pidof openclaw-gateway", { stdio: "ignore" });
    return true;
  } catch {
    return false;
  }
}

const server = http.createServer((req, res) => {
  // Health check - verify gateway is actually running
  if (req.url === "/healthz" && req.method === "GET") {
    const gatewayUp = isGatewayRunning();
    res.writeHead(gatewayUp ? 200 : 503, {
      "Content-Type": "text/plain",
      "X-Content-Type-Options": "nosniff",
      "X-Frame-Options": "DENY",
    });
    res.end(gatewayUp ? "OK" : "GATEWAY_DOWN");
    return;
  }

  // Everything else - minimal info (no product name leak)
  res.writeHead(200, {
    "Content-Type": "text/plain",
    "X-Content-Type-Options": "nosniff",
    "X-Frame-Options": "DENY",
  });
  res.end("OK");
});

server.listen(PORT, "0.0.0.0", () => {
  console.log(`[openclaw] Health server on :${PORT}`);
});
