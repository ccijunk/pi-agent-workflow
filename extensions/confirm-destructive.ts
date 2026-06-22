/**
 * confirm-destructive.ts — Block dangerous bash commands with a confirmation prompt.
 *
 * Intercepts bash tool calls containing rm -rf, sudo, dd, mkfs, etc.
 * and asks for confirmation before allowing execution.
 *
 * Place in ~/.pi/agent/extensions/ or link via this repo.
 */

import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { isToolCallEventType } from "@earendil-works/pi-coding-agent";

const DANGEROUS_PATTERNS = [
  /\brm\s+-rf\b/,
  /\bsudo\b/,
  /\bdd\b/,
  /\bmkfs\b/,
  /\bchmod\s+-?R?\s*777\b/,
  /\b>\/dev\/sda\b/,
  /\b:\(\)\s*\{[^}]*\}:\s*;\s*:\s*;\s*$/m,  // fork bomb
];

export default function (pi: ExtensionAPI) {
  pi.on("tool_call", async (event, ctx) => {
    if (!isToolCallEventType("bash", event)) return;

    const cmd: string = (event.input as any).command ?? "";

    const isDangerous = DANGEROUS_PATTERNS.some((p) => p.test(cmd));
    if (!isDangerous) return;

    const ok = await ctx.ui.confirm(
      "⚠️  Dangerous Command",
      `Allow this?\n\n${cmd.slice(0, 500)}`,
    );

    if (!ok) {
      return {
        block: true,
        reason: "Blocked by confirm-destructive extension",
      };
    }
  });
}
