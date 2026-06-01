#!/bin/bash
# Claude Code 适配器
# 需要 --dangerously-skip-permissions 跳过权限确认

claude_get_pattern() { echo "claude -p"; }

claude_get_latest_session() {
    local project_dir="${1:-$(pwd)}"
    local encoded_dir=$(echo "$project_dir" | sed 's|/|-|g; s|^-||')
    local sessions_dir="$HOME/.claude/projects/-${encoded_dir}"

    if [ -d "$sessions_dir" ]; then
        ls -t "$sessions_dir"/*/ 2>/dev/null | head -1 | while read -r d; do
            basename "$d" 2>/dev/null
        done
    fi
}

claude_invoke() {
    local cmd="$1"
    local logfile="$2"
    local session_id="${3:-}"
    local project_dir="${4:-$(pwd)}"

    touch /tmp/.claude-session-marker

    if [ -n "$session_id" ]; then
        printf '%s' "$cmd" | claude -p \
            --dangerously-skip-permissions \
            --resume "$session_id" \
            --output-format text \
            > "$logfile" 2>&1
    else
        printf '%s' "$cmd" | claude -p \
            --dangerously-skip-permissions \
            --output-format text \
            > "$logfile" 2>&1
    fi
    local exit_code=$?

    claude_get_latest_session "$project_dir"

    return $exit_code
}
