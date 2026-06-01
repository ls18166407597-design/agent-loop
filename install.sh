#!/bin/bash
# ─────────────────────────────────────────────────────────────
# agent-loop 安装脚本
# 用法：curl -fsSL https://raw.githubusercontent.com/USER/agent-loop/main/install.sh | bash
# ─────────────────────────────────────────────────────────────
set -euo pipefail

REPO="https://github.com/USER/agent-loop.git"
INSTALL_DIR="$HOME/.agent-loop"
BIN_DIR="$HOME/.local/bin"

echo "=== agent-loop 安装 ==="
echo ""

# ─── 检查依赖 ───
for cmd in bash jq; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
        echo "❌ 缺少依赖: $cmd"
        if [[ "$OSTYPE" == "darwin"* ]]; then
            echo "   运行: brew install $cmd"
        else
            echo "   运行: sudo apt install $cmd  或  sudo yum install $cmd"
        fi
        exit 1
    fi
done

# ─── 安装 ───
if [ -d "$INSTALL_DIR" ]; then
    echo "已存在 $INSTALL_DIR，更新..."
    cd "$INSTALL_DIR" && git pull 2>/dev/null || echo "更新失败，跳过"
else
    echo "下载 agent-loop..."
    git clone "$REPO" "$INSTALL_DIR" 2>/dev/null || {
        echo "❌ 下载失败。请检查网络连接。"
        echo "   或手动克隆: git clone $REPO $INSTALL_DIR"
        exit 1
    }
fi

# ─── 设置 PATH ───
mkdir -p "$BIN_DIR"

# 创建代理脚本
cat > "$BIN_DIR/agent-loop" << 'WRAPPER'
#!/bin/bash
# agent-loop 代理脚本
INSTALL_DIR="$HOME/.agent-loop"

case "${1:-help}" in
    init)
        shift
        bash "$INSTALL_DIR/init.sh" "$@"
        ;;
    start)
        bash "$INSTALL_DIR/manage.sh" start
        ;;
    stop)
        bash "$INSTALL_DIR/manage.sh" stop
        ;;
    status)
        bash "$INSTALL_DIR/manage.sh" status
        ;;
    log)
        bash "$INSTALL_DIR/manage.sh" log
        ;;
    reset)
        bash "$INSTALL_DIR/manage.sh" reset
        ;;
    help|*)
        echo "agent-loop — AI 自动循环引擎"
        echo ""
        echo "用法:"
        echo "  agent-loop init /path/to/project   初始化项目"
        echo "  agent-loop start                   启动循环"
        echo "  agent-loop stop                    停止循环"
        echo "  agent-loop status                  查看状态"
        echo "  agent-loop log                     查看日志"
        echo "  agent-loop reset                   重置"
        echo ""
        echo "配置文件: ~/.agent-loop/agent-loop.json"
        echo "文档: ~/.agent-loop/README.md"
        ;;
esac
WRAPPER
chmod +x "$BIN_DIR/agent-loop"

# ─── 检查 PATH ───
SHELL_RC=""
if [ -f "$HOME/.zshrc" ]; then
    SHELL_RC="$HOME/.zshrc"
elif [ -f "$HOME/.bashrc" ]; then
    SHELL_RC="$HOME/.bashrc"
elif [ -f "$HOME/.bash_profile" ]; then
    SHELL_RC="$HOME/.bash_profile"
fi

if echo "$PATH" | grep -q "$BIN_DIR"; then
    echo "✅ PATH 已包含 $BIN_DIR"
elif [ -n "$SHELL_RC" ]; then
    echo "" >> "$SHELL_RC"
    echo "# agent-loop" >> "$SHELL_RC"
    echo "export PATH=\"\$HOME/.local/bin:\$PATH\"" >> "$SHELL_RC"
    echo "✅ 已添加 PATH 到 $SHELL_RC"
    echo "   请运行: source $SHELL_RC"
else
    echo "⚠️  请手动添加 $BIN_DIR 到 PATH"
fi

# ─── 完成 ───
echo ""
echo "=== 安装完成 ==="
echo ""
echo "快速开始："
echo "  1. 初始化项目:  agent-loop init /path/to/your/project"
echo "  2. 启动:        agent-loop start"
echo ""
echo "或者让 Agent 配置："
echo "  在 OpenCode/Claude Code 中说: 读取 ~/.agent-loop/SETUP-GUIDE.md，帮我配置"
echo ""
echo "管理命令: agent-loop [start|stop|status|log|reset|help]"
