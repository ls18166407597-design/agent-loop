#!/bin/bash
# ─────────────────────────────────────────────────────────────
# agent-loop — AI 自动循环引擎
# 让 AI Agent 自己打磨项目，你去睡觉
#
# 支持：macOS / Linux / Windows(WSL)
# 支持：OpenCode (OC) / Claude Code (CC)
# ─────────────────────────────────────────────────────────────
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CONFIG="${1:-$SCRIPT_DIR/agent-loop.json}"
TASKS="$SCRIPT_DIR/tasks"
LOG="/tmp/agent-loop-$$.log"
LOCK="/tmp/agent-loop-$$.lock"

log() { echo "[$(date +%H:%M:%S)] $1" >> "$LOG"; }

for cmd in jq; do
    command -v "$cmd" >/dev/null 2>&1 || { echo "需要 jq，请先安装"; exit 1; }
done

[ -f "$CONFIG" ] || { echo "配置不存在: $CONFIG"; exit 1; }

# ─── 读取配置 ───
COMMANDER_AGENT=$(jq -r '.commander_agent // .agent // "opencode"' "$CONFIG")
WORKER_AGENT=$(jq -r '.worker_agent // .agent // "opencode"' "$CONFIG")
PROJECT_DIR=$(jq -r '.project_dir // "."' "$CONFIG")
TIMEOUT=$(jq -r '.timeout_minutes // 30' "$CONFIG")
PHASES_STR=$(jq -r '.phases // ""' "$CONFIG")
COMMANDER_EXTRA=$(jq -r '.commander_extra_instructions // ""' "$CONFIG")
WORKER_EXTRA=$(jq -r '.worker_extra_instructions // ""' "$CONFIG")

[[ "$PROJECT_DIR" != /* ]] && PROJECT_DIR="$SCRIPT_DIR/$PROJECT_DIR"
[ -d "$PROJECT_DIR" ] || { echo "项目目录不存在: $PROJECT_DIR"; exit 1; }

# 用项目路径哈希作为锁/日志前缀，支持多项目并行
PROJECT_HASH=$(echo "$PROJECT_DIR" | md5sum 2>/dev/null | cut -c1-8 || md5 -q -s "$PROJECT_DIR" 2>/dev/null | cut -c1-8 || echo "default")
LOG="/tmp/agent-loop-${PROJECT_HASH}.log"
LOCK="/tmp/agent-loop-${PROJECT_HASH}.lock"

IFS=',' read -ra PHASES <<< "$PHASES_STR"

# ─── 跨平台工具函数 ───
file_mtime() {
    local f="$1"
    if [[ "$OSTYPE" == "darwin"* ]]; then
        stat -f %m "$f" 2>/dev/null || echo 0
    else
        stat -c %Y "$f" 2>/dev/null || echo 0
    fi
}

find_pid() {
    local pattern="$1"
    if command -v pgrep >/dev/null 2>&1; then
        pgrep -f "$pattern" 2>/dev/null | head -1
    else
        ps aux 2>/dev/null | grep "$pattern" | grep -v grep | awk '{print $2}' | head -1
    fi
}

pid_start_time() {
    local pid="$1"
    if [ -d "/proc/$pid" ] 2>/dev/null; then
        stat -c %Y "/proc/$pid" 2>/dev/null || echo 0
    elif ps -p "$pid" >/dev/null 2>&1; then
        local lstart=$(ps -o lstart= -p "$pid" 2>/dev/null | tr -s ' ')
        if [ -n "$lstart" ]; then
            if [[ "$OSTYPE" == "darwin"* ]]; then
                date -j -f "%a %b %d %T %Y" "$lstart" +%s 2>/dev/null || echo $(date +%s)
            else
                date -d "$lstart" +%s 2>/dev/null || echo $(date +%s)
            fi
        else
            echo $(date +%s)
        fi
    else
        echo $(date +%s)
    fi
}

# ─── 防卡死 ───
if [ -f "$LOCK" ]; then
    LOCK_AGE=$(( $(date +%s) - $(file_mtime "$LOCK") ))
    [ "$LOCK_AGE" -gt 3600 ] && rm -f "$LOCK" && log "锁超 ${LOCK_AGE}s，清除"
fi
[ -f "$LOCK" ] && exit 0
touch "$LOCK"
trap 'rm -f "$LOCK"' EXIT

[ -f "$TASKS/.done" ] && exit 0

# ─── 加载适配器（带命名空间）───
source "$SCRIPT_DIR/adapters/$COMMANDER_AGENT.sh"
CMD_PATTERN=$(${COMMANDER_AGENT}_get_pattern)

source "$SCRIPT_DIR/adapters/$WORKER_AGENT.sh"
WORK_PATTERN=$(${WORKER_AGENT}_get_pattern)

# ─── 超时检查 ───
check_and_kill() {
    local pattern="$1"
    local pid=$(find_pid "$pattern")
    [ -z "$pid" ] && return 0

    local start=$(pid_start_time "$pid")
    local age=$(( ($(date +%s) - start) / 60 ))
    if [ "$age" -ge "$TIMEOUT" ]; then
        kill -- "-$pid" 2>/dev/null || kill -9 "$pid" 2>/dev/null
        log "超时 kill ($pattern, AGE=${age}min)"
        return 1
    fi
    return 0
}

if [ -n "$(find_pid "$CMD_PATTERN")" ] || [ -n "$(find_pid "$WORK_PATTERN")" ]; then
    check_and_kill "$CMD_PATTERN"
    check_and_kill "$WORK_PATTERN"
    exit 0
fi

# ─── 初始化 ───
mkdir -p "$TASKS/reports" "$TASKS/phases"
ROUND=$(find "$TASKS" -name "round-*-commander.log" 2>/dev/null | wc -l | tr -d ' ')
ROUND=$((ROUND + 1))

# ─── 当前阶段 ───
CURRENT_PHASE=""
for phase in "${PHASES[@]}"; do
    phase=$(echo "$phase" | tr -d ' ')
    [ -z "$phase" ] && continue
    [ ! -f "$TASKS/phases/$phase.done" ] && CURRENT_PHASE="$phase" && break
done

if [ -z "$CURRENT_PHASE" ]; then
    log "所有阶段完成"
    touch "$TASKS/.done"
    exit 0
fi

PHASE_DESC=$(cat "$SCRIPT_DIR/phases/$CURRENT_PHASE.md" 2>/dev/null || echo "无阶段定义")
log "Round $ROUND: 阶段=$CURRENT_PHASE agent=$COMMANDER_AGENT/$WORKER_AGENT project=$PROJECT_DIR"

# ─── 指令 ───
COMMANDER_CMD="你是质量守护指挥官。

当前阶段：$CURRENT_PHASE
阶段目标：
$PHASE_DESC

项目目录：$PROJECT_DIR

你的职责：
1. 读取 tasks/progress.md 了解整体进度
2. 读取 tasks/report.md 了解上一轮结果（可能为空）
3. 分析当前阶段还需要做什么
4. 写一个具体的工作计划到 tasks/next-plan.md
5. 计划必须在 20 分钟内可完成
6. 退出

$COMMANDER_EXTRA"

WORKER_CMD="你是质量守护工作会话。

读取 tasks/next-plan.md 了解工作计划。
按照计划执行。完成后写报告到 tasks/report.md。

报告格式：
## 执行报告 [时间]
- 做了什么
- 结果：成功/失败/部分成功
- npm run check：通过/失败（附错误信息）
- 改了哪些文件
- 遇到的问题
- 建议下一步

不要改 .env、ecosystem.config.js、nginx 配置。
如果修改了代码，运行 npm run check。通过则 git commit + push。
完成后退出。

$WORKER_EXTRA"

# ─── 主会话 session ───
CMD_SESSION_FILE="$TASKS/commander-session.txt"
CMD_SESSION_ID=""
[ -f "$CMD_SESSION_FILE" ] && [ -s "$CMD_SESSION_FILE" ] && CMD_SESSION_ID=$(cat "$CMD_SESSION_FILE")

# ─── 执行主会话 ───
RLOG="$TASKS/round-$(printf "%03d" $ROUND)-commander.log"
log "Round $ROUND: 主会话启动 ($COMMANDER_AGENT, session=${CMD_SESSION_ID:-新建})"

CMD_OUTPUT=$(cd "$PROJECT_DIR" && ${COMMANDER_AGENT}_invoke "$COMMANDER_CMD" "$RLOG" "$CMD_SESSION_ID" "$PROJECT_DIR" 2>&1)
CMD_EXIT=$?

NEW_CMD_SESSION=$(echo "$CMD_OUTPUT" | tail -1 | tr -d '[:space:]' | grep -o '[a-f0-9-]\{36\}\|[a-zA-Z0-9_-]\{20,\}' || true)
[ -n "$NEW_CMD_SESSION" ] && echo "$NEW_CMD_SESSION" > "$CMD_SESSION_FILE"
log "主会话 EXIT=$CMD_EXIT session=$NEW_CMD_SESSION"

# ─── 检查计划 ───
if [ ! -f "$TASKS/next-plan.md" ] || ! grep -q "任务\|目标\|步骤\|执行" "$TASKS/next-plan.md" 2>/dev/null; then
    log "无有效计划，跳过"
    exit 0
fi

# ─── 执行工人会话 ───
WLOG="$TASKS/round-$(printf "%03d" $ROUND)-worker.log"
log "Round $ROUND: 工人会话启动 ($WORKER_AGENT)"
WORK_OUTPUT=$(cd "$PROJECT_DIR" && ${WORKER_AGENT}_invoke "$WORKER_CMD" "$WLOG" "" "$PROJECT_DIR" 2>&1)
WORK_EXIT=$?
log "工人会话 EXIT=$WORK_EXIT"

# ─── 阶段完成检查 ───
if [ "$WORK_EXIT" -eq 0 ] && [ -f "$TASKS/report.md" ] && grep -q "全部完成\|阶段完成\|所有目标" "$TASKS/report.md" 2>/dev/null; then
    touch "$TASKS/phases/$CURRENT_PHASE.done"
    log "阶段 $CURRENT_PHASE 完成"
fi

log "Round $ROUND 完成"
