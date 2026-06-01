#!/bin/bash
# ─────────────────────────────────────────────────────────────
# agent-loop 初始化脚本
# 分析项目并生成配置
#
# 用法：./init.sh /path/to/project [agent]
# ─────────────────────────────────────────────────────────────
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="${1:-.}"
AGENT="${2:-opencode}"

# 将相对路径转为绝对路径
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
HAS_SECURITY=false

if [ -f "$PROJECT_DIR/package.json" ]; then
    # Node.js 项目
    if grep -q "react\|vue\|angular\|next\|nuxt\|vite" "$PROJECT_DIR/package.json" 2>/dev/null; then
        HAS_FRONTEND=true
        PROJECT_TYPE="web"
    elif grep -q "express\|fastify\|koa\|hono" "$PROJECT_DIR/package.json" 2>/dev/null; then
        PROJECT_TYPE="api"
    else
        PROJECT_TYPE="node"
    fi
fi

# 检查测试
[ -d "$PROJECT_DIR/__tests__" ] || [ -d "$PROJECT_DIR/test" ] || [ -d "$PROJECT_DIR/tests" ] || [ -d "$PROJECT_DIR/src/__tests__" ] && HAS_TESTS=true

# 检查文档
[ -f "$PROJECT_DIR/README.md" ] || [ -f "$PROJECT_DIR/CLAUDE.md" ] || [ -d "$PROJECT_DIR/docs" ] && HAS_DOCS=true

echo "检测结果："
echo "  项目类型: $PROJECT_TYPE"
echo "  有前端: $HAS_FRONTEND"
echo "  有测试: $HAS_TESTS"
echo "  有文档: $HAS_DOCS"
echo ""

# ─── 生成阶段 ───
PHASES=""

# 阶段 1：测试基线（所有项目都有）
PHASES="01-tests"

# 阶段 2：安全审查
PHASES="$PHASES,02-security"

# 阶段 3：文档审查
if [ "$HAS_DOCS" = true ]; then
    PHASES="$PHASES,03-docs"
fi

# 阶段 4：前端优化（如有前端）
if [ "$HAS_FRONTEND" = true ]; then
    PHASES="$PHASES,04-frontend"
fi

# 阶段 5：最终验收
PHASES="$PHASES,05-final"

echo "生成阶段: $PHASES"
echo ""

# ─── 创建阶段文件 ───
mkdir -p "$SCRIPT_DIR/phases"

# 01-tests
cat > "$SCRIPT_DIR/phases/01-tests.md" << 'PHASE'
# 阶段 01：测试基线

## 目标
建立测试基线，确保所有测试通过。

## 具体任务
- 运行全量测试
- 统计通过/失败/跳过数量
- 修复失败的测试用例
- 确保 typecheck 通过
- 确保 lint 通过

## 成功标准
- 所有测试通过
- typecheck + lint 通过

## 时间限制
20 分钟
PHASE

# 02-security
cat > "$SCRIPT_DIR/phases/02-security.md" << 'PHASE'
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
PHASE

# 03-docs
if [ "$HAS_DOCS" = true ]; then
cat > "$SCRIPT_DIR/phases/03-docs.md" << 'PHASE'
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
PHASE
fi

# 04-frontend
if [ "$HAS_FRONTEND" = true ]; then
cat > "$SCRIPT_DIR/phases/04-frontend.md" << 'PHASE'
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
PHASE
fi

# 05-final
cat > "$SCRIPT_DIR/phases/05-final.md" << 'PHASE'
# 阶段 05：最终验收

## 目标
全量验证，确保项目可交付。

## 具体任务
- 运行全量测试
- 验证所有阶段产出
- 写最终验收报告

## 成功标准
- 所有测试通过
- 无阻塞性问题

## 时间限制
20 分钟
PHASE

echo "阶段文件已生成。"
echo ""

# ─── 生成配置 ───
cat > "$SCRIPT_DIR/agent-loop.json" << CONFIG
{
  "commander_agent": "$AGENT",
  "worker_agent": "$AGENT",
  "project_dir": "$PROJECT_DIR",
  "timeout_minutes": 30,
  "phases": "$PHASES",
  "commander_extra_instructions": "",
  "worker_extra_instructions": ""
}
CONFIG

echo "配置文件已生成: $SCRIPT_DIR/agent-loop.json"
echo ""

# ─── 完成 ───
echo "=== 初始化完成 ==="
echo ""
echo "下一步："
echo "  1. 检查配置: cat agent-loop.json"
echo "  2. 启动: ./manage.sh start"
echo "  3. 后台运行: nohup ./loop.sh &"
