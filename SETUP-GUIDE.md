# Agent 配置指南

> 本文档供 AI Agent（OpenCode / Claude Code）阅读。
> 用户会告诉你："读取这个文件，帮我配置 agent-loop"。

## 第零步：检查环境

在配置前，先确认依赖已安装：

```bash
command -v jq && jq --version
command -v opencode && opencode --version
# 或
command -v claude && claude --version
```

缺少 jq：`brew install jq`（macOS）/ `apt install jq`（Linux）
缺少 opencode：`curl -fsSL https://opencode.ai/install | bash`
缺少 claude：`npm install -g @anthropic-ai/claude-code`

agent-loop 自动处理各系统差异（md5/md5sum、stat 语法、会话路径等），无需手动适配。

## 你的工作流程

### 第一步：了解用户的目标

问用户：
1. "你想用 agent-loop 做什么？"
   - 提升代码质量（测试、lint、类型检查）
   - 安全加固
   - 文档完善
   - 性能优化
   - 新功能开发
   - Bug 修复
   - 其他

2. "你希望每个阶段多长时间？"
   - 建议：15-30 分钟（太长容易超时，太短做不完）

3. "你希望用哪个 Agent？"
   - OpenCode (OC)
   - Claude Code (CC)

### 第二步：分析项目

1. 读取项目根目录的 `package.json` / `README.md` / 目录结构
2. 了解项目类型（前端/后端/全栈/CLI/库）
3. 了解技术栈（语言、框架、测试工具）
4. 检查当前状态（测试覆盖、lint 状态、文档完整性）

### 第三步：建议阶段

根据用户目标和项目状态，建议 3-5 个阶段。每个阶段：
- 一个具体目标
- 可在 15-30 分钟内完成
- 有明确的成功标准

**示例**（用户想提升代码质量）：
```
01-test-baseline    — 运行全量测试，修复失败用例
02-lint-fix         — 运行 lint，修复所有 warning
03-security-scan    — 安全审查，修复 HIGH 级别问题
04-final-verify     — 全量回归验证
```

**示例**（用户想开发新功能）：
```
01-design           — 分析需求，设计方案
02-implement        — 实现核心功能
03-test             — 编写测试
04-docs             — 更新文档
```

**示例**（用户想部署上线）：
```
01-docker-build     — Docker 构建验证
02-env-config       — 环境变量配置检查
03-health-check     — 健康检查端点验证
04-smoke-test       — 冒烟测试
```

### 第四步：与用户确认

把建议的阶段展示给用户，问：
- "这些阶段合适吗？"
- "需要调整顺序吗？"
- "需要增加或删除某个阶段吗？"

### 第五步：生成配置

确认后，在 `agent-loop/` 目录生成：

1. **阶段文件** `phases/01-xxx.md`：
```markdown
# 阶段 01：[名称]

## 目标
[一句话]

## 具体任务
- [任务1]
- [任务2]

## 成功标准
- [标准1]

## 时间限制
20 分钟
```

2. **配置文件** `agent-loop.json`：
```json
{
  "commander_agent": "opencode",
  "worker_agent": "opencode",
  "project_dir": "/absolute/path/to/project",
  "timeout_minutes": 60,
  "phases": "01-xxx,02-xxx,03-xxx",
  "commander_extra_instructions": "",
  "worker_extra_instructions": ""
}
```

### 第六步：告知用户

告诉用户：
```
配置完成！你可以：

1. 测试一轮：cd agent-loop && ./manage.sh start
2. 后台运行：nohup ./loop.sh &
3. 查看状态：./manage.sh status
4. 停止：./manage.sh stop
```

## 注意事项

1. **项目目录必须是绝对路径**
2. **Agent 必须配置为自动批准**
   - OpenCode：`"permission": {"*": "allow"}`
   - Claude Code：loop.sh 自动处理
3. **阶段文件名必须与配置一致**
4. **每个阶段控制在 30 分钟内**
5. **不要硬编码阶段** — 让用户和 Agent 一起决定
