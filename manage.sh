#!/bin/bash
# ─────────────────────────────────────────────────────────────
# agent-loop 管理工具
# 用法：./manage.sh [start|stop|status|reset|log|history]
# ─────────────────────────────────────────────────────────────
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
TASKS="$SCRIPT_DIR/tasks"
LOG="/tmp/agent-loop.log"
CONFIG="$SCRIPT_DIR/agent-loop.json"

case "${1:-status}" in
    start)
        if [ -f "$TASKS/.done" ]; then
            echo "守护已完成。用 './manage.sh reset' 重置后再启动。"
            exit 1
        fi
        echo "启动 agent-loop..."
        echo "配置: $CONFIG"
        echo "日志: $LOG"
        echo "按 Ctrl+C 停止前台运行"
        bash "$SCRIPT_DIR/loop.sh" "$CONFIG"
        ;;

    stop)
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
        for f in "$SCRIPT_DIR"/phases/*.md; do
            phase=$(basename "$f" .md)
            if [ -f "$TASKS/phases/$phase.done" ]; then
                echo "  ✅ $phase"
            else
                echo "  ⏳ $phase (当前)"
                break
            fi
        done
        echo ""
        echo "--- 最近日志 ---"
        tail -5 "$LOG" 2>/dev/null || echo "无日志"
        echo ""
        echo "--- 进程 ---"
        pgrep -f "opencode run" >/dev/null 2>&1 && echo "  OpenCode: 运行中" || echo "  OpenCode: 未运行"
        pgrep -f "claude -p" >/dev/null 2>&1 && echo "  Claude: 运行中" || echo "  Claude: 未运行"
        ;;

    history)
        echo "=== 执行历史 ==="
        echo ""
        if [ ! -d "$TASKS" ] || [ -z "$(ls "$TASKS"/round-*-commander.log 2>/dev/null)" ]; then
            echo "无执行记录"
            exit 0
        fi

        for clog in "$TASKS"/round-*-commander.log; do
            [ -f "$clog" ] || continue
            round=$(basename "$clog" | grep -o '[0-9]*')
            wlog="$TASKS/round-${round}-worker.log"

            echo "━━━ Round $round ━━━"

            # 主 OC 状态
            if [ -f "$clog" ]; then
                echo "  主 OC: $(tail -1 "$clog" 2>/dev/null | head -c 80)"
            fi

            # 工人 OC 状态
            if [ -f "$wlog" ]; then
                echo "  工人 OC: $(tail -1 "$wlog" 2>/dev/null | head -c 80)"
            else
                echo "  工人 OC: 未执行"
            fi

            # 报告摘要
            if [ -f "$TASKS/report.md" ]; then
                echo "  报告: $(head -5 "$TASKS/report.md" 2>/dev/null | tail -1)"
            fi

            echo ""
        done
        ;;

    reset)
        rm -rf "$TASKS/phases"/*.done "$TASKS/.done" "$TASKS/commander-session.txt"
        rm -f "$TASKS"/round-*.log
        rm -f "$TASKS/next-plan.md" "$TASKS/report.md" "$TASKS/progress.md"
        echo "已重置。可以重新开始。"
        ;;

    log)
        tail -30 "$LOG" 2>/dev/null || echo "无日志"
        ;;

    *)
        echo "用法: $0 [start|stop|status|reset|log|history]"
        ;;
esac
