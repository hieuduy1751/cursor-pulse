#!/bin/bash
mode="$1"
session="unknown"
cwd=""

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
print("session=" + shlex.quote(str(d.get("conversationId") or d.get("sessionId") or "unknown")))
paths = d.get("workspacePaths") or []
print("cwd=" + shlex.quote(paths[0] if paths else str(d.get("workspace") or "")))
' 2>/dev/null)"
fi

[ -z "$session" ] && session="unknown"
dir="${HOME}/.cursorpulse/sessions"
mkdir -p "$dir"
file="${dir}/cursor__${session}.json"

state="${mode:-working}"

if [ "$state" = "idle" ]; then
  rm -f "$file" 2>/dev/null
  echo '{"decision":"allow"}'
  exit 0
fi

ts=$(date +%s)
cat > "$file" <<EOF
{"tool":"cursor","state":"${state}","ts":${ts},"cwd":"${cwd}","session":"${session}"}
