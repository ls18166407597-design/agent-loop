# agent-loop

AI 自动循环引擎 — 让 AI Agent 自己打磨项目，你去睡觉。

## 30 秒开始

### 第一步：安装（一行）

```bash
curl -fsSL https://raw.githubusercontent.com/USER/agent-loop/main/install.sh | bash
```

### 第二步：告诉你的 Agent

打开你的 AI Agent（OpenCode / Claude Code），复制粘贴这段话：

```
请读取 ~/.agent-loop/SETUP-GUIDE.md，然后帮我配置 agent-loop。
我的项目在 [你的项目路径]。
请帮我分析项目，生成合适的阶段，配置好一切，然后启动。
```

**完事了。** Agent 会帮你：
- 分析项目类型
- 生成合适的阶段
- 配置 agent-loop.json
- 启动循环

你只需要回答 Agent 的几个问题就行。

## 管理

循环运行中，随时可以跟 Agent 说：

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

| Agent | 主 OC | 工人 OC |
|-------|:-----:|:------:|
| OpenCode | ✅ | ✅ |
| Claude Code | ✅ | ✅ |

可以混搭。

## 命令参考

```bash
agent-loop init /path/to/project   # 初始化
agent-loop start                    # 启动
agent-loop stop                     # 停止
agent-loop status                   # 查看状态
agent-loop log                      # 查看日志
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
│   ├── opencode.sh
│   └── claude.sh
├── phases/
│   └── *.md
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
