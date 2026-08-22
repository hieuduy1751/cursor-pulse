#!/bin/bash
# CursorPulse hook for Claude Code / Claude Desktop — $1 = mode (working | pre_tool | stop | ready | idle | busy | needs_input | needs_approval).

# 1. If invoked inside Cursor / VSCode / Superconductor environment, ignore completely.
if [ -n "$CURSOR_PROJECT_DIR" ] || [ -n "$CURSOR_APP_VERSION" ] || [ -n "$CURSOR_VERSION" ] || [ -n "$CURSOR_USER_DATA_DIR" ] || [ -n "$SUPERCONDUCTOR_WORKTREE_PATH" ]; then
  exit 0
fi

# 1b. Ancestry check: IDEs like Cursor import ~/.claude/settings.json and run
# these hooks for their own agent runs. Walk the process tree and bail if any
# ancestor belongs to such an app, regardless of env vars or payload shape.
pid=$$
for _ in 1 2 3 4 5 6; do
  pid=$(ps -o ppid= -p "$pid" 2>/dev/null | tr -d ' ')
  if [ -z "$pid" ] || [ "$pid" = "0" ] || [ "$pid" = "1" ]; then
    break
  fi
  ancestor=$(ps -o comm= -p "$pid" 2>/dev/null)
  case "$ancestor" in
    *Cursor*|*cursor*|*Antigravity*|*antigravity*|*Superconductor*)
      exit 0
      ;;
  esac
done

mode="$1"
session="unknown"
cwd=""
tool_name=""
is_foreign_caller="false"
claude_identity="false"

input_json=""
if [ ! -t 0 ]; then
  input_json=$(cat)
fi

if command -v python3 >/dev/null 2>&1 && [ -n "$input_json" ]; then
  eval "$(printf '%s' "$input_json" | python3 -c '
import json, shlex, sys
try:
    d = json.load(sys.stdin)
except Exception:
    d = {}

# Check if this hook was invoked by Cursor / Antigravity / other IDEs importing Claude settings
has_cursor_keys = bool(
    d.get("hook_event_name") or
    d.get("hookEventName") or
    d.get("workspace_roots") or
    d.get("workspaceRoots") or
    d.get("generation_id") or
    d.get("generationId") or
    d.get("turn_id") or
    d.get("turnId") or
    d.get("conversation_id") or
    d.get("conversationId")
)

has_claude_keys = bool(
    d.get("session_id") or
    d.get("sessionId") or
    d.get("transcript_path") or
    d.get("entrypoint") == "claude-desktop"
)

if has_cursor_keys and not has_claude_keys:
    print("is_foreign_caller=true")
else:
    print("is_foreign_caller=false")

print("claude_identity=" + ("true" if has_claude_keys else "false"))

session_val = d.get("session_id") or d.get("sessionId") or "unknown"
print("session=" + shlex.quote(str(session_val)))
roots = d.get("workspacePaths") or []
cwd_val = roots[0] if roots else (d.get("cwd") or "")
print("cwd=" + shlex.quote(str(cwd_val)))
tc = d.get("toolCall") or d.get("tool") or {}
tname = tc.get("name") or d.get("tool_name") or ""
print("tool_name=" + shlex.quote(str(tname)))
' 2>/dev/null)"
fi

# If invoked by Cursor or another IDE sharing Claude settings, ignore to prevent dual-tracking
if [ "$is_foreign_caller" = "true" ]; then
  exit 0
fi

# 2. Require positive evidence of a genuine Claude Code / Claude Desktop
# invocation (session_id, transcript_path, or claude-desktop entrypoint).
# Real Claude hooks always provide one of these; IDE cross-invocations with
# missing or reshaped payloads must never produce a "claude" badge state.
if [ "$claude_identity" != "true" ]; then
  exit 0
fi

[ -z "$session" ] && session="unknown"
dir="${HOME}/.cursorpulse/sessions"
mkdir -p "$dir"
file="${dir}/claude__${session}.json"

state="working"

case "$mode" in
  pre_tool)
    if [ "$tool_name" = "AskFollowupQuestion" ] || [ "$tool_name" = "ask_question" ]; then
      state="needs_input"
    elif [ "$tool_name" = "Bash" ] || [ "$tool_name" = "Edit" ] || [ "$tool_name" = "Write" ]; then
      state="needs_approval"
    else
      state="working"
    fi
    ;;
  stop|ready)
    state="ready"
    ;;
  idle)
    rm -f "$file" 2>/dev/null
    exit 0
    ;;
  *)
    state="${mode:-working}"
    ;;
esac

# Write the session record as properly escaped JSON via python3.
# Fallback (no python3): embed only fixed internal strings, drop user data.
write_record() {
  if command -v python3 >/dev/null 2>&1; then
    local json
    json=$(TOOL="claude" STATE="$state" SESSION="$session" CWD="$cwd" TS="$(date +%s)" python3 -c '
import json, os
print(json.dumps({
    "tool": os.environ.get("TOOL", "claude"),
    "state": os.environ.get("STATE", "working"),
    "ts": int(os.environ.get("TS", "0") or 0),
    "cwd": os.environ.get("CWD", ""),
    "session": os.environ.get("SESSION", "unknown"),
}))' 2>/dev/null) || json=""
    if [ -n "$json" ]; then
      printf '%s\n' "$json" > "$file"
      return
    fi
  fi
  local ts
  ts=$(date +%s)
  cat > "$file" <<EOF
{"tool":"claude","state":"${state}","ts":${ts},"cwd":"","session":"unknown"}
EOF
}

write_record claude "$state" "$session" "$cwd"

exit 0
