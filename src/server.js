/**
 * OpenClaw Railway Health Check Server
 *
 * Minimal server that only provides a health check endpoint for Railway.
 * All setup happens via SSH, access via Tailscale.
 */

import http from "node:http";
import { execSync } from "node:child_process";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";

const PORT = Number.parseInt(process.env.PORT ?? "8080", 10);
const STATE_DIR = process.env.OPENCLAW_STATE_DIR?.trim() || path.join(os.homedir(), ".openclaw");

function isConfigured() {
  try {
    return fs.existsSync(path.join(STATE_DIR, "openclaw.json"));
  } catch {
    return false;
  }
}

function getTailscaleStatus() {
  try {
    const output = execSync("tailscale status --json 2>/dev/null", { encoding: "utf8", timeout: 5000 });
    const status = JSON.parse(output);
    return {
      online: status.Self?.Online || false,
      dnsName: status.Self?.DNSName?.replace(/\.$/, "") || null,
    };
  } catch {
    return { online: false, dnsName: null };
  }
}

const server = http.createServer((req, res) => {
  if (req.url === "/healthz" && req.method === "GET") {
    const configured = isConfigured();
    const tailscale = getTailscaleStatus();
    res.writeHead(200, { "Content-Type": "application/json" });
    res.end(JSON.stringify({ ok: true, configured, tailscale: tailscale.online }));
    return;
  }

  // Everything else: show simple status
  const configured = isConfigured();
  const tailscale = getTailscaleStatus();

  let message = "OpenClaw Railway\n\n";

  if (configured && tailscale.online) {
    message += `Status: Ready\n`;
    message += `Control UI: https://${tailscale.dnsName}/\n\n`;
    message += `Access from any device on your Tailnet.`;
  } else if (configured) {
    message += `Status: Needs Tailscale\n\n`;
    message += `SSH in and run: tailscale up`;
  } else {
    message += `Status: Not configured\n\n`;
    message += `SSH in and run:\n`;
    message += `  1. tailscale up\n`;
    message += `  2. openclaw onboard`;
  }

  res.writeHead(200, { "Content-Type": "text/plain" });
  res.end(message);
});

server.listen(PORT, "0.0.0.0", () => {
  console.log(`[openclaw] Health server on :${PORT}`);
});
