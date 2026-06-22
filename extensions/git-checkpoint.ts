/**
 * git-checkpoint.ts — Auto-stash/restore git state around agent turns.
 *
 * Before each agent turn (if the repo has uncommitted changes), stashes them.
 * After the turn finishes, pops the stash so you see the latest state.
 *
 * Place in ~/.pi/agent/extensions/ or link via this repo.
 */

import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";

export default function (pi: ExtensionAPI) {
  let stashed = false;

  pi.on("turn_start", async (_event, ctx) => {
    // Check if cwd is a git repo with uncommitted changes
    try {
      const { execSync } = await import("node:child_process");
      const status = execSync("git status --porcelain", {
        cwd: ctx.cwd,
        encoding: "utf-8",
        timeout: 3000,
      });
      if (status.trim().length === 0) return;

      execSync("git stash push -m 'pi-checkpoint' --include-untracked", {
        cwd: ctx.cwd,
        timeout: 5000,
        stdio: "pipe",
      });
      stashed = true;
    } catch {
      // Not a git repo or git not available — skip silently
    }
  });

  pi.on("turn_end", async (_event, ctx) => {
    if (!stashed) return;

    try {
      const { execSync } = await import("node:child_process");
      execSync("git stash pop", {
        cwd: ctx.cwd,
        timeout: 5000,
        stdio: "pipe",
      });
    } catch {
      // Pop might fail if conflicts — that's okay, stash stays
    }
    stashed = false;
  });
}
