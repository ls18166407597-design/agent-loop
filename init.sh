#!/bin/bash
# ─────────────────────────────────────────────────────────────
# agent-loop 初始化脚本
# 分析项目并生成配置
#
# 用法：init.sh /path/to/project [agent]
# ─────────────────────────────────────────────────────────────
set -eo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="${1:-.}"
AGENT="${2:-opencode}"

[[ "$PROJECT_DIR" != /* ]] && PROJECT_DIR="$(cd "$PROJECT_DIR" && pwd)"
[ -d "$PROJECT_DIR" ] || { echo "目录不存在: $PROJECT_DIR"; exit 1; }

echo "=== agent-loop 初始化 ==="
echo "项目: $PROJECT_DIR"
echo "Agent: $AGENT"
echo ""

# ─── 检测项目类型 ───
PROJECT_TYPE="unknown"
HAS_FRONTEND=false
HAS_TESTS=false
HAS_DOCS=false
TEST_CMD="echo '请配置测试命令'"
LINT_CMD="echo '请配置 lint 命令'"
CHECK_CMD="echo '请配置检查命令'"

# Node.js
if [ -f "$PROJECT_DIR/package.json" ]; then
    if grep -q '"react\|"vue\|"angular\|"next\|"nuxt\|"vite' "$PROJECT_DIR/package.json" 2>/dev/null; then
        HAS_FRONTEND=true
        PROJECT_TYPE="web"
    elif grep -q '"express\|"fastify\|"koa\|"hono' "$PROJECT_DIR/package.json" 2>/dev/null; then
        PROJECT_TYPE="api"
    else
        PROJECT_TYPE="node"
    fi
    TEST_CMD="npm test"
    LINT_CMD="npm run lint"
    CHECK_CMD="npm run check"
# Python
elif [ -f "$PROJECT_DIR/pyproject.toml" ] || [ -f "$PROJECT_DIR/setup.py" ] || [ -f "$PROJECT_DIR/requirements.txt" ]; then
    PROJECT_TYPE="python"
    TEST_CMD="pytest"
    LINT_CMD="ruff check ."
    CHECK_CMD="ruff check . && mypy ."
# Go
elif [ -f "$PROJECT_DIR/go.mod" ]; then
    PROJECT_TYPE="go"
    TEST_CMD="go test ./..."
    LINT_CMD="golangci-lint run"
    CHECK_CMD="go vet ./..."
# Rust
elif [ -f "$PROJECT_DIR/Cargo.toml" ]; then
    PROJECT_TYPE="rust"
    TEST_CMD="cargo test"
    LINT_CMD="cargo clippy"
    CHECK_CMD="cargo check"
# Java/Maven
elif [ -f "$PROJECT_DIR/pom.xml" ]; then
    PROJECT_TYPE="java"
    TEST_CMD="mvn test"
    LINT_CMD="mvn checkstyle:check"
    CHECK_CMD="mvn compile"
# Ruby
elif [ -f "$PROJECT_DIR/Gemfile" ]; then
    PROJECT_TYPE="ruby"
    TEST_CMD="bundle exec rspec"
    LINT_CMD="bundle exec rubocop"
    CHECK_CMD="bundle exec rake"
fi

# 检查测试目录
if [ -d "$PROJECT_DIR/__tests__" ] || [ -d "$PROJECT_DIR/test" ] || [ -d "$PROJECT_DIR/tests" ] || [ -d "$PROJECT_DIR/src/__tests__" ]; then
    HAS_TESTS=true
fi

# 检查文档
if [ -f "$PROJECT_DIR/README.md" ] || [ -f "$PROJECT_DIR/CLAUDE.md" ] || [ -d "$PROJECT_DIR/docs" ]; then
    HAS_DOCS=true
fi

echo "检测结果："
echo "  项目类型: $PROJECT_TYPE"
echo "  有前端: $HAS_FRONTEND"
echo "  有测试: $HAS_TESTS"
echo "  有文档: $HAS_DOCS"
echo "  测试命令: $TEST_CMD"
echo ""

# ─── 生成阶段 ───
PHASES="01-tests"
PHASES="$PHASES,02-security"
if [ "$HAS_DOCS" = true ]; then
    PHASES="$PHASES,03-docs"
fi
if [ "$HAS_FRONTEND" = true ]; then
    PHASES="$PHASES,04-frontend"
fi
PHASES="$PHASES,05-final"

echo "生成阶段: $PHASES"
echo ""

# ─── 创建阶段文件 ───
mkdir -p "$SCRIPT_DIR/phases"

cat > "$SCRIPT_DIR/phases/01-tests.md" << EOF
# 阶段 01：测试基线

## 目标
建立测试基线，确保所有测试通过。

## 具体任务
- 运行测试：$TEST_CMD
- 运行 lint：$LINT_CMD
- 运行检查：$CHECK_CMD
- 修复失败的测试用例
- 确保所有检查通过

## 成功标准
- 测试通过
- lint 通过

## 时间限制
20 分钟
EOF

cat > "$SCRIPT_DIR/phases/02-security.md" << 'EOF'
# 阶段 02：安全审查

## 目标
检查并修复已知安全漏洞。

## 具体任务
- 审查认证逻辑
- 检查数据隔离
- 检查敏感信息泄露
- 检查依赖漏洞
- 修复 HIGH 级别问题

## 成功标准
- 无 HIGH 级别安全漏洞

## 时间限制
20 分钟
EOF

if [ "$HAS_DOCS" = true ]; then
cat > "$SCRIPT_DIR/phases/03-docs.md" << 'EOF'
# 阶段 03：文档审查

## 目标
确保文档与代码一致。

## 具体任务
- 对比文档与代码实际
- 检查端口/版本/模块列表是否一致
- 修正不一致的地方

## 成功标准
- 文档与代码一致

## 时间限制
20 分钟
EOF
fi

if [ "$HAS_FRONTEND" = true ]; then
cat > "$SCRIPT_DIR/phases/04-frontend.md" << 'EOF'
# 阶段 04：前端优化

## 目标
优化前端体验。

## 具体任务
- 检查移动端响应式
- 检查暗色模式
- 检查 loading 状态
- 修复发现的问题

## 成功标准
- 移动端可用
- 暗色模式正常

## 时间限制
20 分钟
EOF
fi

cat > "$SCRIPT_DIR/phases/05-final.md" << EOF
# 阶段 05：最终验收

## 目标
全量验证，确保项目可交付。

## 具体任务
- 运行全量测试：$TEST_CMD
- 运行检查：$CHECK_CMD
- 验证所有阶段产出
- 写最终验收报告

## 成功标准
- 所有测试通过
- 所有检查通过
- 无阻塞性问题

## 时间限制
20 分钟
EOF

echo "阶段文件已生成。"
echo ""

# ─── 生成配置 ───
cat > "$SCRIPT_DIR/agent-loop.json" << EOF
{
  "commander_agent": "$AGENT",
  "worker_agent": "$AGENT",
  "project_dir": "$PROJECT_DIR",
  "timeout_minutes": 30,
  "phases": "$PHASES",
  "commander_extra_instructions": "",
  "worker_extra_instructions": ""
}
EOF

echo "配置文件已生成: $SCRIPT_DIR/agent-loop.json"
echo ""
echo "=== 初始化完成 ==="
echo ""
echo "下一步："
echo "  1. 检查配置: cat agent-loop.json"
echo "  2. 启动: ./manage.sh start"
