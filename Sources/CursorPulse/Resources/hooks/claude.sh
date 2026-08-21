#!/bin/bash
# CursorPulse hook for Claude Code / Claude Desktop — $1 = mode (working | pre_tool | stop | ready | idle | busy | needs_input | needs_approval).

# 1. If invoked inside Cursor / VSCode / Superconductor environment, ignore completely.
if [ -n "$CURSOR_PROJECT_DIR" ] || [ -n "$CURSOR_APP_VERSION" ] || [ -n "$CURSOR_VERSION" ] || [ -n "$CURSOR_USER_DATA_DIR" ] || [ -n "$SUPERCONDUCTOR_WORKTREE_PATH" ]; then
  exit 0
fi

mode="$1"
session="unknown"
cwd=""
tool_name=""
is_foreign_caller="false"

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

ts=$(date +%s)
cat > "$file" <<EOF
{"tool":"claude","state":"${state}","ts":${ts},"cwd":"${cwd}","session":"${session}"}
EOF

exit 0
