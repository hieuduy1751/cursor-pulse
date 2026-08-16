import fs from "fs";
import path from "path";
import os from "os";

const SESSIONS_DIR = path.join(os.homedir(), ".cursorpulse", "sessions");
const directoryCache = new Map();

function sessionFile(sessionID) {
  const clean = String(sessionID).replace(/[^A-Za-z0-9_-]/g, "_");
  return path.join(SESSIONS_DIR, `opencode__${clean}.json`);
}

function report(sessionID, state, cwd) {
  try {
    fs.mkdirSync(SESSIONS_DIR, { recursive: true });
    const file = sessionFile(sessionID || "unknown");
    if (state === "idle") {
      try {
        fs.unlinkSync(file);
      } catch {}
      return;
    }
    const record = {
      tool: "opencode",
      state,
      ts: Math.floor(Date.now() / 1000),
      cwd: cwd || null,
      session: sessionID || "unknown",
    };
    fs.writeFileSync(file, JSON.stringify(record));
  } catch {}
}

export const CursorPulsePlugin = async ({ directory, worktree }) => {
  const fallbackDir = worktree || directory || null;
  return {
    event: async ({ event }) => {
      const properties = (event && event.properties) || {};
      const sessionID = properties.sessionID;
      if (!sessionID) return;

      const info = properties.info;
      if (info && info.directory) {
        directoryCache.set(sessionID, info.directory);
      }
      const cwd = directoryCache.get(sessionID) || fallbackDir;

      if (event.type === "session.status") {
        if (properties.status && properties.status.type === "idle") {
          report(sessionID, "idle", cwd);
        } else {
          report(sessionID, "busy", cwd);
        }
      } else if (event.type === "session.idle") {
        report(sessionID, "idle", cwd);
      } else if (event.type === "permission.asked") {
        report(sessionID, "waiting", cwd);
      }
    },
  };
};
