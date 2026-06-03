#!/bin/bash
# ─────────────────────────────────────────────────────────────
# agent-loop — AI 自动循环引擎
# 让 AI Agent 自己打磨项目，你去睡觉
#
# 支持：macOS / Linux / Windows(WSL)
# 支持：OpenCode (OC) / Claude Code (CC)
# ─────────────────────────────────────────────────────────────
set -eo pipefail

# cron 环境 PATH 不含 /usr/local/bin，手动补全
export PATH="/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin:$PATH"

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CONFIG="${1:-$SCRIPT_DIR/agent-loop.json}"
TASKS="$SCRIPT_DIR/tasks"

# ─── 依赖检查 ───
for cmd in jq; do
    command -v "$cmd" >/dev/null 2>&1 || { echo "需要 jq，请先安装"; exit 1; }
done

[ -f "$CONFIG" ] || { echo "配置不存在: $CONFIG"; exit 1; }

# ─── 读取配置 ───
COMMANDER_AGENT=$(jq -r '.commander_agent // .agent // "opencode"' "$CONFIG")
WORKER_AGENT=$(jq -r '.worker_agent // .agent // "opencode"' "$CONFIG")
PROJECT_DIR=$(jq -r '.project_dir // "."' "$CONFIG")
TIMEOUT=$(jq -r '.timeout_minutes // 60' "$CONFIG")
PHASES_STR=$(jq -r '.phases // ""' "$CONFIG")
COMMANDER_EXTRA=$(jq -r '.commander_extra_instructions // ""' "$CONFIG")
WORKER_EXTRA=$(jq -r '.worker_extra_instructions // ""' "$CONFIG")

[[ "$PROJECT_DIR" != /* ]] && PROJECT_DIR="$SCRIPT_DIR/$PROJECT_DIR"
[ -d "$PROJECT_DIR" ] || { echo "项目目录不存在: $PROJECT_DIR"; exit 1; }

# 用项目路径哈希隔离锁/日志
if command -v md5sum >/dev/null 2>&1; then
    PROJECT_HASH=$(echo -n "$PROJECT_DIR" | md5sum | cut -c1-8)
elif command -v md5 >/dev/null 2>&1; then
    PROJECT_HASH=$(echo -n "$PROJECT_DIR" | md5 | cut -c1-8)
else
    PROJECT_HASH="default"
fi

LOG="/tmp/agent-loop-${PROJECT_HASH}.log"
LOCK="/tmp/agent-loop-${PROJECT_HASH}.lock"

log() {
    local msg="[$(date +%H:%M:%S)] $1"
    echo "$msg" >> "$LOG"
    [ -t 1 ] && echo "$msg" || true  # 终端时同时输出到屏幕
}

IFS=',' read -ra PHASES <<< "$PHASES_STR"

# ─── 跨平台工具函数 ───
file_mtime() {
    if [[ "$OSTYPE" == "darwin"* ]]; then
        stat -f %m "$1" 2>/dev/null || echo 0
    else
        stat -c %Y "$1" 2>/dev/null || echo 0
    fi
}

find_pid() {
    if command -v pgrep >/dev/null 2>&1; then
        pgrep -f "$1" 2>/dev/null | head -1
    else
        ps aux 2>/dev/null | grep "$1" | grep -v grep | awk '{print $2}' | head -1
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
                date -j -f "%a %b %d %T %Y" "$lstart" +%s 2>/dev/null || date +%s
            else
                date -d "$lstart" +%s 2>/dev/null || date +%s
            fi
        else
            date +%s
        fi
    else
        date +%s
    fi
}

# ─── 防卡死（mkdir 原子锁，无 TOCTOU 竞态）───
if [ -d "$LOCK" ]; then
    LOCK_AGE=$(( $(date +%s) - $(file_mtime "$LOCK") ))
    [ "$LOCK_AGE" -gt 3600 ] && rm -rf "$LOCK" && log "锁超 ${LOCK_AGE}s，清除"
fi
if ! mkdir "$LOCK" 2>/dev/null; then
    exit 0
fi
trap 'rm -rf "$LOCK"' EXIT

# ─── 完成标记（仅当所有阶段都完成时才生效）───
mkdir -p "$TASKS" "$TASKS/reports" "$TASKS/phases"
if [ -f "$TASKS/.done" ]; then
    # 检查是否所有阶段都已完成（防止新增阶段被跳过）
    ALL_DONE=true
    IFS=',' read -ra _CHECK_PHASES <<< "$PHASES_STR"
    for _phase in "${_CHECK_PHASES[@]}"; do
        _phase=$(echo "$_phase" | tr -d '[:space:]')
        [ -z "$_phase" ] && continue
        if [ ! -f "$TASKS/phases/$_phase.done" ]; then
            ALL_DONE=false
            rm -f "$TASKS/.done"
            break
        fi
    done
    [ "$ALL_DONE" = true ] && exit 0
fi

# ─── 验证适配器 ───
for agent in "$COMMANDER_AGENT" "$WORKER_AGENT"; do
    [ -f "$SCRIPT_DIR/adapters/$agent.sh" ] || { echo "适配器不存在: $agent.sh"; exit 1; }
done

# ─── 加载适配器 ───
source "$SCRIPT_DIR/adapters/$COMMANDER_AGENT.sh"
CMD_PATTERN=$(${COMMANDER_AGENT}_get_pattern)

source "$SCRIPT_DIR/adapters/$WORKER_AGENT.sh"
WORK_PATTERN=$(${WORKER_AGENT}_get_pattern)

# ─── 超时检查与恢复 ───
TIMEOUT_KILLED=false
check_and_kill() {
    local pattern="$1"
    local pid=$(find_pid "$pattern")
    [ -z "$pid" ] && return 0

    local start=$(pid_start_time "$pid")
    local age=$(( ($(date +%s) - start) / 60 ))
    if [ "$age" -ge "$TIMEOUT" ]; then
        kill -TERM -- "-$pid" 2>/dev/null || kill -9 "$pid" 2>/dev/null
        log "超时 kill ($pattern, AGE=${age}min)"
        TIMEOUT_KILLED=true
        return 1
    fi
    return 0
}

if [ -n "$(find_pid "$CMD_PATTERN")" ] || [ -n "$(find_pid "$WORK_PATTERN")" ]; then
    check_and_kill "$CMD_PATTERN"
    check_and_kill "$WORK_PATTERN"
    # 超时 kill 后继续执行（不退出），让后续逻辑处理恢复
    if [ "$TIMEOUT_KILLED" = true ]; then
        log "超时恢复：清理完成，继续执行"
        # 清理锁，允许继续
        rm -rf "$LOCK"
    else
        # 还有进程在跑，等下次 cron
        exit 0
    fi
fi

# ─── 初始化 ───
ROUND=$(find "$TASKS" -maxdepth 1 -name "round-*-commander.log" 2>/dev/null | wc -l | tr -d ' ')
ROUND=$((ROUND + 1))

# ─── 当前阶段 ───
CURRENT_PHASE=""
for phase in "${PHASES[@]}"; do
    phase=$(echo "$phase" | tr -d '[:space:]')
    [ -z "$phase" ] && continue
    if [ ! -f "$TASKS/phases/$phase.done" ]; then
        CURRENT_PHASE="$phase"
        break
    fi
done

if [ -z "$CURRENT_PHASE" ]; then
    log "所有阶段完成"
    touch "$TASKS/.done"
    exit 0
fi

PHASE_FILE="$SCRIPT_DIR/phases/$CURRENT_PHASE.md"
if [ ! -f "$PHASE_FILE" ]; then
    log "阶段文件不存在: $PHASE_FILE"
    echo "错误: 阶段文件不存在: $PHASE_FILE" >&2
    exit 1
fi

PHASE_DESC=$(cat "$PHASE_FILE")
log "Round $ROUND: 阶段=$CURRENT_PHASE agent=$COMMANDER_AGENT/$WORKER_AGENT"

# ─── 指令 ───
COMMANDER_CMD="你是规划会话。

当前阶段：$CURRENT_PHASE
阶段目标：
$PHASE_DESC

项目目录：$PROJECT_DIR

你的职责：
1. 读取 tasks/progress.md 了解整体进度
2. 读取 tasks/report.md 了解上一轮结果（可能为空）
3. 分析当前阶段还需要做什么。如果分析后确认当前阶段的所有目标已经圆满完成，无需再做任何代码修改，请在 tasks/next-plan.md 中列出任务：创建阶段完成标志文件：touch tasks/phases/$CURRENT_PHASE.done。
4. 写一个具体的工作计划到 tasks/next-plan.md
5. 计划必须在 20 分钟内可完成
6. 退出

$COMMANDER_EXTRA"

WORKER_CMD="你是执行会话。

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
注意：如果你的修改导致编译/检查（如 npm run check/typecheck）失败，且你在本轮退出前无法修复它们，请务必执行 git checkout . (以及 git clean -fd) 撤销你本轮所做的所有修改，切勿将无法通过编译的脏代码留在工作区中。
重要：如果你确认当前阶段的任务已经全部圆满完成，且无需进一步修改，请务必在退出前执行：touch tasks/phases/$CURRENT_PHASE.done（或按照计划执行该命令）。如果不写入该 done 标志文件，引擎将永远在此阶段循环。
完成后退出。

$WORKER_EXTRA"

# ─── 规划会话 session ───
CMD_SESSION_FILE="$TASKS/commander-session.txt"
CMD_SESSION_ID=""
[ -f "$CMD_SESSION_FILE" ] && [ -s "$CMD_SESSION_FILE" ] && CMD_SESSION_ID=$(cat "$CMD_SESSION_FILE")

# ─── 执行规划会话（带超时保护）───
RLOG="$TASKS/round-$(printf "%03d" $ROUND)-commander.log"
log "Round $ROUND: 规划会话启动 ($COMMANDER_AGENT, session=${CMD_SESSION_ID:-新建})"

# 跨平台超时：后台运行 + watchdog
SESSION_TIMEOUT=$((TIMEOUT * 60))
(
    cd "$PROJECT_DIR" && ${COMMANDER_AGENT}_invoke "$COMMANDER_CMD" "$RLOG" "$CMD_SESSION_ID" "$PROJECT_DIR"
) > "$RLOG.output" 2>&1 &
CMD_PID=$!
( sleep "$SESSION_TIMEOUT" && kill -9 "$CMD_PID" 2>/dev/null && log "规划会话超时 kill (PID=$CMD_PID)" ) &
WATCHDOG_PID=$!
wait "$CMD_PID" 2>/dev/null
CMD_EXIT=$?
kill "$WATCHDOG_PID" 2>/dev/null
CMD_OUTPUT=$(cat "$RLOG.output" 2>/dev/null)
rm -f "$RLOG.output"

# 提取 session ID（UUID 格式或长字符串）
NEW_CMD_SESSION=$(echo "$CMD_OUTPUT" | tail -1 | tr -d '[:space:]' | grep -oE '[a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12}' | head -1 || true)
if [ -z "$NEW_CMD_SESSION" ]; then
    NEW_CMD_SESSION=$(echo "$CMD_OUTPUT" | tail -1 | tr -d '[:space:]' | grep -oE '[a-zA-Z0-9_-]{20,}' | head -1 || true)
fi
[ -n "$NEW_CMD_SESSION" ] && echo "$NEW_CMD_SESSION" > "$CMD_SESSION_FILE"
log "规划会话 EXIT=$CMD_EXIT session=$NEW_CMD_SESSION"

# ─── 检查计划（兼容 agent-loop/tasks 和 项目/tasks 两个路径）───
PLAN_FILE=""
if [ -f "$TASKS/next-plan.md" ]; then
    PLAN_FILE="$TASKS/next-plan.md"
elif [ -f "$PROJECT_DIR/tasks/next-plan.md" ]; then
    PLAN_FILE="$PROJECT_DIR/tasks/next-plan.md"
fi

if [ -z "$PLAN_FILE" ]; then
    log "无计划文件，跳过"
    exit 0
fi

if ! grep -qiE "task|goal|step|任务|目标|步骤|执行|plan" "$PLAN_FILE" 2>/dev/null; then
    log "无有效计划，跳过"
    exit 0
fi

# 复制到 agent-loop/tasks 统一管理
cp "$PLAN_FILE" "$TASKS/next-plan.md" 2>/dev/null || true

# ─── 执行执行会话（带超时保护）───
WLOG="$TASKS/round-$(printf "%03d" $ROUND)-worker.log"
log "Round $ROUND: 执行会话启动 ($WORKER_AGENT)"
(
    cd "$PROJECT_DIR" && ${WORKER_AGENT}_invoke "$WORKER_CMD" "$WLOG" "" "$PROJECT_DIR"
) > "$WLOG.output" 2>&1 &
WORK_PID=$!
( sleep "$SESSION_TIMEOUT" && kill -9 "$WORK_PID" 2>/dev/null && log "执行会话超时 kill (PID=$WORK_PID)" ) &
WATCHDOG_PID=$!
wait "$WORK_PID" 2>/dev/null
WORK_EXIT=$?
kill "$WATCHDOG_PID" 2>/dev/null
WORK_OUTPUT=$(cat "$WLOG.output" 2>/dev/null)
rm -f "$WLOG.output"
log "执行会话 EXIT=$WORK_EXIT"

# ─── 异常退出自动代码回滚 ───
if [ "$WORK_EXIT" -ne 0 ]; then
    log "警告: 执行会话异常退出 (EXIT=$WORK_EXIT)，执行自动代码回滚以清理脏现场"
    (
        cd "$PROJECT_DIR"
        git reset --hard HEAD >/dev/null 2>&1 || true
        git clean -fd >/dev/null 2>&1 || true
    )
fi

# ─── 阶段完成检查 ───
# 阶段完成目前完全依赖 Agent 在打磨通过后自行创建对应的 done 标志文件：$TASKS/phases/$CURRENT_PHASE.done
# loop.sh 不再执行模糊的文本匹配，防止造成阶段完成状态误判。
if [ "$WORK_EXIT" -eq 0 ] && [ -f "$TASKS/phases/$CURRENT_PHASE.done" ]; then
    log "检测到 Agent 已写入 done 状态，阶段 $CURRENT_PHASE 完成"
fi

log "Round $ROUND 完成"

# ─── 连续执行：完成后立即跑下一轮（不等 cron）───
if [ "$WORK_EXIT" -eq 0 ]; then
    log "连续执行下一轮"
    rm -rf "$LOCK"  # exec 前手动清理锁（trap 不会执行）
    exec bash "$SCRIPT_DIR/loop.sh" "$CONFIG"
fi
