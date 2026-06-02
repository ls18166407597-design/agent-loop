#!/bin/bash
# Claude Code 适配器
# 需要 --dangerously-skip-permissions 跳过权限确认

claude_get_pattern() { echo "claude -p"; }

claude_get_latest_session() {
    local project_dir="${1:-$(pwd)}"
    # Claude Code 会话存储路径（跨平台）
    local sessions_base=""
    if [ -d "$HOME/.claude/projects" ]; then
        sessions_base="$HOME/.claude/projects"
    elif [ -d "$HOME/Library/Application Support/claude/projects" ]; then
        sessions_base="$HOME/Library/Application Support/claude/projects"
    fi

    [ -n "$sessions_base" ] && [ -d "$sessions_base" ] || return 0

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
    local work_dir="${4:-$(pwd)}"

    # 检查 claude 是否安装
    if ! command -v claude >/dev/null 2>&1; then
        echo "错误: claude 命令未找到，请先安装 Claude Code CLI" > "$logfile"
        return 1
    fi

    local stderr_file="${logfile}.stderr"
    if [ -n "$session_id" ]; then
        printf '%s' "$cmd" | claude -p \
            --dangerously-skip-permissions \
            --resume "$session_id" \
            --output-format text \
            --cwd "$work_dir" \
            > "$logfile" 2>"$stderr_file"
    else
        printf '%s' "$cmd" | claude -p \
            --dangerously-skip-permissions \
            --output-format text \
            --cwd "$work_dir" \
            > "$logfile" 2>"$stderr_file"
    fi
    local exit_code=$?

    claude_get_latest_session
    return $exit_code
}
