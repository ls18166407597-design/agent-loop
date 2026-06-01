#!/bin/bash
# Claude Code 适配器
# 需要 --dangerously-skip-permissions 跳过权限确认

get_agent_pattern() { echo "claude -p"; }

# 获取 Claude Code 最新 session ID
# 从当前项目的 session 目录中找最新的
get_latest_session_id() {
    local project_dir="${1:-.}"
    # Claude Code 用项目路径编码作为目录名
    local encoded_dir=$(echo "$project_dir" | sed 's|/|-|g; s|^-||')
    local sessions_dir="$HOME/.claude/projects/-${encoded_dir}"

    # 找最新的 session 目录（按修改时间）
    if [ -d "$sessions_dir" ]; then
        ls -t "$sessions_dir"/*/ 2>/dev/null | head -1 | xargs basename 2>/dev/null
    fi
}

# 启动 Agent
# 参数: $1=指令 $2=日志文件 $3=session_id(可选)
invoke_agent() {
    local cmd="$1"
    local logfile="$2"
    local session_id="${3:-}"

    if [ -n "$session_id" ]; then
        echo "$cmd" | claude -p \
            --dangerously-skip-permissions \
            --resume "$session_id" \
            --output-format text \
            > "$logfile" 2>&1
    else
        echo "$cmd" | claude -p \
            --dangerously-skip-permissions \
            --output-format text \
            > "$logfile" 2>&1
    fi
    local exit_code=$?

    # 输出新 session ID
    get_latest_session_id "$PROJECT_DIR"

    return $exit_code
}
