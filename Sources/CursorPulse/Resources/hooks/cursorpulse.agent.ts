// CursorPulse session reporter for pi & Oh My Pi (omp).
//
// Auto-discovered from <agentDir>/extensions/ by both harnesses (pi:
// ~/.pi/agent/extensions, omp: ~/.omp/agent/extensions). The CursorPulse
// installer bakes the tool name ("pi" or "omp") into the @@TOOL@@ placeholder
// below, so this single source file serves every harness.
//
// On each lifecycle event it writes a lightweight JSON record to
// ~/.cursorpulse/sessions/<tool>__<session>.json, which the CursorPulse menu
// bar app watches via FSEvents. session_shutdown removes the file; the app's
// TTL sweeper covers crashes. Deliberately dependency-free and stateless so
// it loads identically under pi's jiti loader and omp's Bun loader.

import { mkdirSync, renameSync, unlinkSync, writeFileSync } from "node:fs";
import { homedir } from "node:os";

const TOOL = "@@TOOL@@";
const SESSIONS_DIR = `${homedir()}/.cursorpulse/sessions`;

// pi has no native approval system, so exec-tier tools map to needs_approval
// Claude-style; omp uses its precise approval events instead.
const APPROVAL_HEURISTIC: Record<string, true> =
    TOOL === "pi" ? { bash: true, edit: true, write: true } : {};
// Tools whose execution blocks on a user answer.
const INPUT_TOOLS: Record<string, true> = { ask: true };

type Handler = (event: unknown, ctx: unknown) => void;

interface ReporterAPI {
    on(event: string, handler: Handler): void;
}

type UnknownRecord = Record<string, unknown>;

function record(value: unknown, key: string): unknown {
    if (typeof value === "object" && value !== null && key in value) {
        return (value as UnknownRecord)[key];
    }
    return undefined;
}

/**
 * Session ids become filename segments (<tool>__<session>.json), so keep the
 * same character class CursorPulse's Paths sanitizer accepts; fall back to
 * "unknown" rather than colliding on empty names.
 */
function sessionId(ctx: unknown): string {
    let raw: unknown;
    try {
        const get = record(record(ctx, "sessionManager"), "getSessionId");
        if (typeof get === "function") raw = get();
    } catch {
        // Fall through to "unknown".
    }
    const cleaned = String(typeof raw === "string" || typeof raw === "number" ? raw : "unknown")
        .replace(/[^a-zA-Z0-9_-]/g, "");
    return cleaned.length > 0 ? cleaned : "unknown";
}

function report(state: string, ctx: unknown): void {
    try {
        mkdirSync(SESSIONS_DIR, { recursive: true });
        const session = sessionId(ctx);
        const cwd = record(ctx, "cwd");
        const payload = JSON.stringify({
            tool: TOOL,
            state,
            ts: Math.floor(Date.now() / 1000),
            cwd: typeof cwd === "string" ? cwd : "",
            session,
        });
        const file = `${SESSIONS_DIR}/${TOOL}__${session}.json`;
        writeFileSync(`${file}.tmp`, payload);
        renameSync(`${file}.tmp`, file);
    } catch {
        // Telemetry must never break the agent.
    }
}

function clearSession(ctx: unknown): void {
    try {
        unlinkSync(`${SESSIONS_DIR}/${TOOL}__${sessionId(ctx)}.json`);
    } catch {
        // Nothing to clean up.
    }
}

// Harnesses evolve independently; registering an event a given build doesn't
// know must degrade to a no-op instead of failing extension load.
function safeOn(pi: ReporterAPI, event: string, handler: Handler): void {
    try {
        pi.on(event, handler);
    } catch {
        // Harness predates this event; skip it.
    }
}

function toolName(event: unknown): unknown {
    return record(event, "toolName");
}

export default function (pi: ReporterAPI): void {
    // Working: any agent/turn/tool activity.
    safeOn(pi, "before_agent_start", (_event, ctx) => report("working", ctx));
    safeOn(pi, "agent_start", (_event, ctx) => report("working", ctx));
    safeOn(pi, "turn_start", (_event, ctx) => report("working", ctx));

    // Approval: precise events on omp, heuristic tool list on pi.
    safeOn(pi, "tool_approval_requested", (_event, ctx) => report("needs_approval", ctx));
    safeOn(pi, "tool_approval_resolved", (_event, ctx) => report("working", ctx));
    safeOn(pi, "tool_execution_start", (event, ctx) => {
        const name = toolName(event);
        if (typeof name === "string" && name in INPUT_TOOLS) {
            report("needs_input", ctx);
        } else if (typeof name === "string" && name in APPROVAL_HEURISTIC) {
            report("needs_approval", ctx);
        } else {
            report("working", ctx);
        }
    });

    // Tool finished; still inside the turn, so back to working.
    safeOn(pi, "tool_execution_end", (_event, ctx) => report("working", ctx));

    // Turn over: queued follow-up messages mean the run continues.
    safeOn(pi, "turn_end", (_event, ctx) => {
        const hasQueued = record(ctx, "hasQueuedMessages");
        const queued = typeof hasQueued === "function" && hasQueued() === true;
        report(queued ? "queued" : "working", ctx);
    });

    // Settled: no retry, compaction, or queued follow-up remains.
    safeOn(pi, "agent_settled", (_event, ctx) => report("ready", ctx));

    // Errors: provider-level HTTP failures (429s, 5xx). The next lifecycle
    // event clears the state when the run recovers.
    safeOn(pi, "after_provider_response", (event, ctx) => {
        const status = record(event, "status");
        if (typeof status === "number" && status >= 400) {
            report("error", ctx);
        }
    });

    safeOn(pi, "session_shutdown", (_event, ctx) => clearSession(ctx));
}
