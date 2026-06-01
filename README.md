# agent-loop

AI 自动循环引擎 — 让 AI Agent 自己打磨项目，你去睡觉。

## 它怎么工作

```
你（控制会话）                agent-loop                目标项目
    │                            │                        │
    │  "帮我配置"                 │                        │
    │───────────────────────────→│                        │
    │                            │  分析项目、生成阶段     │
    │                            │───────────────────────→│
    │  "启动"                     │                        │
    │───────────────────────────→│                        │
    │                            │                        │
    │                            │  ┌─ 每轮循环 ────────┐ │
    │                            │  │ 主会话：写计划     │ │
    │                            │  │ 工人会话：执行计划 │ │
    │                            │  │ 写报告、检查阶段   │ │
    │                            │  └───────────────────┘ │
    │                            │                        │
    │  "看看状态"                 │                        │
    │───────────────────────────→│  ← 读取进度和报告      │
    │  ← 报告                    │                        │
```

**主会话**保持上下文，记住历史。**工人会话**每次新启，专注当前任务。
阶段按顺序执行，每轮一个具体任务，20 分钟内完成。

## 30 秒开始

### 第一步：安装

```bash
curl -fsSL https://raw.githubusercontent.com/ls18166407597-design/agent-loop/main/install.sh | bash
```

### 第二步：告诉你的 Agent

打开你的 AI Agent（OpenCode / Claude Code），复制粘贴：

```
请读取 ~/.agent-loop/SETUP-GUIDE.md，然后帮我配置 agent-loop。
我的项目在 [你的项目路径]。
请帮我分析项目，生成合适的阶段，配置好一切，然后启动。
```

Agent 会帮你分析项目、生成阶段、配置一切。你只需要回答几个问题。

### 第三步：去睡觉

循环会自动运行。每轮一个任务，全部完成后停止。

## 管理

随时跟你的 Agent 说：

```
请读取 ~/.agent-loop/CONTROL-GUIDE.md，帮我查看 agent-loop 状态
```

Agent 会帮你查看状态、处理问题、调整配置。

## 平台支持

| 平台 | 状态 |
|------|------|
| macOS | ✅ |
| Linux | ✅ |
| Windows | ⚠️ 需要 WSL |

## 支持的 Agent

| Agent | 主会话 | 工人会话 |
|-------|:-----:|:------:|
| [OpenCode](https://opencode.ai) (OC) | ✅ | ✅ |
| [Claude Code](https://docs.anthropic.com/en/docs/claude-code) (CC) | ✅ | ✅ |

可以混搭：OC 做主会话 + CC 做工人，或反过来。

## 阶段系统

每个阶段是一个 markdown 文件，定义"做什么"和"怎么算成功"：

```
phases/
├── 01-tests.md      # 测试基线
├── 02-security.md   # 安全审查
├── 03-docs.md       # 文档审查
├── 04-frontend.md   # 前端优化（可选）
└── 05-final.md      # 最终验收
```

`init.sh` 会根据项目类型自动选择阶段。支持 Node.js、Python、Go、Rust、Java、Ruby。

## 命令参考

```bash
agent-loop init /path/to/project   # 初始化（自动检测项目类型）
agent-loop start                    # 启动
agent-loop stop                     # 停止
agent-loop status                   # 查看状态
agent-loop log                      # 查看日志
agent-loop history                  # 查看执行历史
agent-loop reset                    # 重置
```

## 目录结构

安装后在 `~/.agent-loop/`：

```
~/.agent-loop/
├── loop.sh              # 核心循环
├── manage.sh            # 管理工具
├── init.sh              # 初始化
├── install.sh           # 安装脚本
├── agent-loop.json      # 配置（init 后生成）
├── README.md            # 用户文档
├── SETUP-GUIDE.md       # Agent 配置引导
├── CONTROL-GUIDE.md     # 控制会话管理
├── adapters/
│   ├── opencode.sh      # OpenCode 适配器
│   └── claude.sh        # Claude Code 适配器
├── phases/
│   └── *.md             # 阶段定义
└── tasks/               # 运行时数据（进度、报告）
```

## 常见问题

### 安装后找不到命令？

```bash
source ~/.zshrc   # 或 source ~/.bashrc
```

### Agent 卡在权限确认？

OpenCode：`~/.config/opencode/opencode.json` 设 `"permission": {"*": "allow"}`
Claude Code：loop.sh 自动处理。

### 怎么重来？

```bash
agent-loop reset
agent-loop start
```

### 可以后台运行吗？

```bash
nohup ~/.agent-loop/loop.sh &
tail -f /tmp/agent-loop-*.log
```

## License

MIT
