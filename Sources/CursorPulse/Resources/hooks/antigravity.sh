#!/bin/bash
mode="$1"
session="unknown"
cwd=""
tool_name=""
term_reason=""
err=""
fully_idle="true"

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
print("session=" + shlex.quote(str(d.get("conversationId") or "unknown")))
paths = d.get("workspacePaths") or []
print("cwd=" + shlex.quote(paths[0] if paths else ""))
tc = d.get("toolCall") or {}
print("tool_name=" + shlex.quote(str(tc.get("name") or "")))
print("term_reason=" + shlex.quote(str(d.get("terminationReason") or "")))
print("err=" + shlex.quote(str(d.get("error") or "")))
if d.get("fullyIdle") is False:
    print("fully_idle=false")
' 2>/dev/null)"
fi

[ -z "$session" ] && session="unknown"
dir="${HOME}/.cursorpulse/sessions"
mkdir -p "$dir"
file="${dir}/antigravity__${session}.json"

state="working"

case "$mode" in
  pre_tool)
    if [ "$tool_name" = "ask_question" ]; then
      state="needs_input"
    elif [ "$tool_name" = "run_command" ] || [ "$tool_name" = "write_to_file" ] || [ "$tool_name" = "replace_file_content" ]; then
      state="needs_approval"
    else
      state="working"
    fi
    ;;
  stop)
    if [ -n "$err" ]; then
      state="error"
    elif [ "$fully_idle" = "false" ]; then
      state="working"
    else
      state="ready"
    fi
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

# Write the session record as properly escaped JSON via python3.
# Fallback (no python3): embed only fixed internal strings, drop user data.
write_record() {
  if command -v python3 >/dev/null 2>&1; then
    local json
    json=$(TOOL="antigravity" STATE="$state" SESSION="$session" CWD="$cwd" TS="$(date +%s)" python3 -c '
import json, os
print(json.dumps({
    "tool": os.environ.get("TOOL", "antigravity"),
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
{"tool":"antigravity","state":"${state}","ts":${ts},"cwd":"","session":"unknown"}
EOF
}

write_record antigravity "$state" "$session" "$cwd"

echo '{"decision":"allow"}'
exit 0
