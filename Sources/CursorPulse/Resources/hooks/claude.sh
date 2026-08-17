#!/bin/bash
# CursorPulse hook for Claude Code — $1 = mode (working | pre_tool | stop | ready | idle | busy | needs_input | needs_approval).
mode="$1"
session="unknown"
cwd=""
tool_name=""

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
session_val = d.get("session_id") or d.get("sessionId") or d.get("conversation_id") or d.get("conversationId") or "unknown"
print("session=" + shlex.quote(str(session_val)))
roots = d.get("workspacePaths") or d.get("workspace_roots") or []
cwd_val = roots[0] if roots else (d.get("cwd") or d.get("workspace") or "")
print("cwd=" + shlex.quote(str(cwd_val)))
tc = d.get("toolCall") or d.get("tool") or {}
tname = tc.get("name") or d.get("tool_name") or ""
print("tool_name=" + shlex.quote(str(tname)))
' 2>/dev/null)"
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
    echo '{"decision":"allow"}'
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

echo '{"decision":"allow"}'
exit 0
