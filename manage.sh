#!/bin/bash
# ─────────────────────────────────────────────────────────────
# agent-loop 管理工具
# 用法：manage.sh [start|stop|status|reset|log|history]
# ─────────────────────────────────────────────────────────────
set -eo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
TASKS="$SCRIPT_DIR/tasks"
CONFIG="$SCRIPT_DIR/agent-loop.json"

# 跨平台进程查找
find_pid() {
    if command -v pgrep >/dev/null 2>&1; then
        pgrep -f "$1" 2>/dev/null | head -1
    else
        ps aux 2>/dev/null | grep "$1" | grep -v grep | awk '{print $2}' | head -1
    fi
}

get_latest_log() {
    ls -t /tmp/agent-loop-*.log 2>/dev/null | head -1
}

case "${1:-status}" in
    start)
        mkdir -p "$TASKS"
        if [ -f "$TASKS/.done" ]; then
            echo "守护已完成。用 'manage.sh reset' 重置后再启动。"
            exit 0
        fi
        echo "启动 agent-loop..."
        echo "配置: $CONFIG"
        echo "日志: /tmp/agent-loop-*.log"
        echo "按 Ctrl+C 停止前台运行"
        bash "$SCRIPT_DIR/loop.sh" "$CONFIG"
        ;;

    stop)
        mkdir -p "$TASKS"
        touch "$TASKS/.done"
        echo "已标记停止，当前轮次完成后退出。"
        ;;

    status)
        echo "=== agent-loop 状态 ==="
        if [ -f "$TASKS/.done" ]; then
            echo "状态: 已完成"
        else
            echo "状态: 运行中"
        fi
        echo ""
        echo "--- 当前阶段 ---"
        has_phases=false
        for f in "$SCRIPT_DIR"/phases/*.md; do
            [ -f "$f" ] || continue
            has_phases=true
            phase=$(basename "$f" .md)
            if [ -f "$TASKS/phases/$phase.done" ]; then
                echo "  ✅ $phase"
            else
                echo "  ⏳ $phase (当前)"
                break
            fi
        done
        [ "$has_phases" = false ] && echo "  无阶段文件"
        echo ""
        echo "--- 进程 ---"
        if [ -n "$(find_pid "opencode run")" ]; then
            echo "  OpenCode (OC): 运行中"
        else
            echo "  OpenCode (OC): 未运行"
        fi
        if [ -n "$(find_pid "claude -p")" ]; then
            echo "  Claude (CC): 运行中"
        else
            echo "  Claude (CC): 未运行"
        fi
        echo ""
        echo "--- 最近日志 ---"
        latest_log=$(get_latest_log)
        if [ -n "$latest_log" ]; then
            tail -5 "$latest_log"
        else
            echo "  无日志"
        fi
        ;;

    history)
        echo "=== 执行历史 ==="
        echo ""
        if [ ! -d "$TASKS" ] || [ -z "$(find "$TASKS" -maxdepth 1 -name "round-*-commander.log" 2>/dev/null)" ]; then
            echo "无执行记录"
            exit 0
        fi

        for clog in "$TASKS"/round-*-commander.log; do
            [ -f "$clog" ] || continue
            round=$(basename "$clog" | sed 's/round-\([0-9]*\)-.*/\1/')
            wlog="$TASKS/round-${round}-worker.log"

            echo "━━━ Round $round ━━━"
            [ -f "$clog" ] && echo "  主会话: $(tail -1 "$clog" 2>/dev/null | head -c 80)"
            if [ -f "$wlog" ]; then
                echo "  工人会话: $(tail -1 "$wlog" 2>/dev/null | head -c 80)"
            else
                echo "  工人会话: 未执行"
            fi
            echo ""
        done
        ;;

    reset)
        rm -rf "$TASKS/phases"/*.done "$TASKS/.done" "$TASKS/commander-session.txt"
        rm -f "$TASKS"/round-*.log
        rm -f "$TASKS/next-plan.md" "$TASKS/report.md" "$TASKS/progress.md"
        rm -rf "$TASKS/reports"
        echo "已重置。可以重新开始。"
        ;;

    log)
        latest_log=$(get_latest_log)
        if [ -n "$latest_log" ]; then
            tail -30 "$latest_log"
        else
            echo "无日志"
        fi
        ;;

    *)
        echo "用法: $0 [start|stop|status|reset|log|history]"
        ;;
esac
