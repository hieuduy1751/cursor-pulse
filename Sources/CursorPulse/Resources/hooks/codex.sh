#!/bin/bash
state="$1"
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

# Write the session record as properly escaped JSON via python3.
# Fallback (no python3): embed only fixed internal strings, drop user data.
write_record() {
  if command -v python3 >/dev/null 2>&1; then
    local json
    json=$(TOOL="codex" STATE="$state" SESSION="$session" CWD="$cwd" TS="$(date +%s)" python3 -c '
import json, os
print(json.dumps({
    "tool": os.environ.get("TOOL", "codex"),
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
{"tool":"codex","state":"${state}","ts":${ts},"cwd":"","session":"unknown"}
EOF
}

write_record codex "$state" "$session" "$cwd"

exit 0
