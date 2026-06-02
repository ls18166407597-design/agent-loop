#!/bin/bash
# OpenCode 适配器
# 需要 opencode.json 中配置 "permission": {"*": "allow"}

opencode_get_pattern() { echo "opencode run"; }

opencode_validate_session() {
    [ -z "$1" ] && return 1
    [ -f "${XDG_DATA_HOME:-$HOME/.local/share}/opencode/storage/session_diff/${1}.json" ]
}

opencode_get_latest_session() {
    local dir="${XDG_DATA_HOME:-$HOME/.local/share}/opencode/storage/session_diff"
    [ -d "$dir" ] || return 0
    ls -t "$dir"/*.json 2>/dev/null | head -1 | while read -r f; do
        basename "$f" .json 2>/dev/null
    done
}

opencode_invoke() {
    local cmd="$1"
    local logfile="$2"
    local session_id="${3:-}"
    local work_dir="${4:-$(pwd)}"

    # 验证 session
    if [ -n "$session_id" ] && ! opencode_validate_session "$session_id"; then
        session_id=""
    fi

    local before_session=$(opencode_get_latest_session)

    # 按旧版逻辑：echo pipe + 直接运行（不捕获到子 shell）
    if [ -n "$session_id" ]; then
        echo "$cmd" | opencode run -s "$session_id" --dangerously-skip-permissions --dir "$work_dir" > "$logfile" 2>&1
    else
        echo "$cmd" | opencode run --dangerously-skip-permissions --dir "$work_dir" > "$logfile" 2>&1
    fi
    local exit_code=$?

    # 从文件系统读 session ID（不用子 shell 捕获输出）
    local after_session=$(opencode_get_latest_session)
    if [ -n "$after_session" ] && [ "$after_session" != "$before_session" ]; then
        echo "$after_session"
    elif [ -n "$session_id" ]; then
        echo "$session_id"
    fi

    return $exit_code
}
