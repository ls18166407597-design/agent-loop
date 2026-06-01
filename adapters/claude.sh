#!/bin/bash
# Claude Code 适配器
# 需要 --dangerously-skip-permissions 跳过权限确认

claude_get_pattern() { echo "claude -p"; }

claude_get_latest_session() {
    local project_dir="${1:-$(pwd)}"
    # Claude Code 会话存储在 ~/.claude/projects/ 下
    local sessions_base="$HOME/.claude/projects"

    [ -d "$sessions_base" ] || return 0

    # 找最新的会话目录（按修改时间）
    find "$sessions_base" -maxdepth 2 -mindepth 2 -type d 2>/dev/null | while read -r d; do
        echo "$(stat_mtime "$d") $d"
    done | sort -rn | head -1 | while read -r ts d; do
        basename "$d" 2>/dev/null
    done
}

stat_mtime() {
    if [[ "$OSTYPE" == "darwin"* ]]; then
        stat -f %m "$1" 2>/dev/null || echo 0
    else
        stat -c %Y "$1" 2>/dev/null || echo 0
    fi
}

claude_invoke() {
    local cmd="$1"
    local logfile="$2"
    local session_id="${3:-}"

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

    claude_get_latest_session
    return $exit_code
}
