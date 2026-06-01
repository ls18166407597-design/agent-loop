#!/bin/bash
# OpenCode 适配器
# 需要 opencode.json 中配置 "permission": {"*": "allow"}

get_agent_pattern() { echo "opencode run"; }

# 获取 OpenCode 最新 session ID
get_latest_session_id() {
    ls -t ~/.local/share/opencode/storage/session_diff/*.json 2>/dev/null | head -1 | xargs basename 2>/dev/null | sed "s/.json//"
}

# 验证 session 是否存在
validate_session() {
    local session_id="$1"
    [ -z "$session_id" ] && return 1
    [ -f "$HOME/.local/share/opencode/storage/session_diff/${session_id}.json" ]
}

# 启动 Agent
# 参数: $1=指令 $2=日志文件 $3=session_id(可选)
invoke_agent() {
    local cmd="$1"
    local logfile="$2"
    local session_id="${3:-}"

    # 验证 session 是否有效
    if [ -n "$session_id" ] && ! validate_session "$session_id"; then
        session_id=""  # session 无效，用新的
    fi

    # 记录启动前的 session
    local before_session=$(get_latest_session_id)

    if [ -n "$session_id" ]; then
        echo "$cmd" | opencode run -s "$session_id" > "$logfile" 2>&1
    else
        echo "$cmd" | opencode run > "$logfile" 2>&1
    fi
    local exit_code=$?

    # 获取新 session（如果有）
    local after_session=$(get_latest_session_id)
    if [ -n "$after_session" ] && [ "$after_session" != "$before_session" ]; then
        echo "$after_session"
    elif [ -n "$session_id" ]; then
        echo "$session_id"
    fi

    return $exit_code
}
