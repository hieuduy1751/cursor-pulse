#!/bin/bash
# CursorPulse hook for Cursor IDE — $1 = mode (working | pre_tool | needs_approval | ready | idle).
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
session_val = d.get("conversation_id") or d.get("conversationId") or d.get("session_id") or d.get("sessionId") or d.get("sessionID") or "unknown"
print("session=" + shlex.quote(str(session_val)))
roots = d.get("workspace_roots") or d.get("workspaceRoots") or d.get("workspacePaths") or []
cwd_val = roots[0] if roots else (d.get("cwd") or d.get("workspace") or "")
print("cwd=" + shlex.quote(str(cwd_val)))
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
EOF

echo '{"decision":"allow"}'
exit 0
