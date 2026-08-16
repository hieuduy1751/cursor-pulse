#!/bin/bash
state="$1"
session="unknown"
cwd=""
if command -v python3 >/dev/null 2>&1; then
  eval "$(python3 -c '
import json, shlex, sys
try:
    d = json.load(sys.stdin)
except Exception:
    d = {}
print("session=" + shlex.quote(str(d.get("session_id") or "unknown")))
print("cwd=" + shlex.quote(str(d.get("cwd") or "")))
' 2>/dev/null)"
fi
[ -z "$session" ] && session="unknown"
dir="${HOME}/.cursorpulse/sessions"
mkdir -p "$dir"
file="${dir}/codex__${session}.json"
if [ "$state" = "idle" ]; then
  rm -f "$file" 2>/dev/null
  exit 0
fi
ts=$(date +%s)
cat > "$file" <<EOF
{"tool":"codex","state":"${state}","ts":${ts},"cwd":"${cwd}","session":"${session}"}
EOF
exit 0
