#!/bin/bash
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
print("session=" + shlex.quote(str(d.get("session_id") or d.get("conversationId") or "unknown")))
paths = d.get("workspacePaths") or []
print("cwd=" + shlex.quote(paths[0] if paths else str(d.get("cwd") or "")))
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
