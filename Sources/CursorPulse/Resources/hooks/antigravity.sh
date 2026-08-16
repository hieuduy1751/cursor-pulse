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

ts=$(date +%s)
cat > "$file" <<EOF
{"tool":"antigravity","state":"${state}","ts":${ts},"cwd":"${cwd}","session":"${session}"}
EOF

echo '{"decision":"allow"}'
exit 0
