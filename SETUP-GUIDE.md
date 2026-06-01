# Agent 配置指南

> 本文档供 AI Agent（OpenCode / Claude Code）阅读。
> 用户会告诉你："读取这个文件，帮我配置 agent-loop"。
> 请按以下步骤执行。

## 第一步：了解项目

1. 读取项目根目录的 `package.json` 或 `README.md`
2. 了解项目类型（前端/后端/全栈/CLI/库）
3. 了解技术栈（语言、框架、测试工具）
4. 了解项目结构（源码、测试、文档位置）

## 第二步：与用户确认需求

向用户提问：

1. "你的项目主要需要哪些优化？"
   - 测试补全
   - 安全加固
   - 文档完善
   - 前端体验
   - 性能优化
   - 代码清理
   - 其他

2. "你希望用哪个 Agent 来执行？"
   - OpenCode（推荐，支持多模型）
   - Claude Code
   - 混搭（主 OC 用 A，工人用 B）

3. "每轮任务的时间限制？"
   - 建议：20-30 分钟

## 第三步：生成阶段文件

根据项目情况，在 `agent-loop/phases/` 目录生成阶段文件。

每个阶段文件格式：

```markdown
# 阶段 XX：[名称]

## 目标
[一句话]

## 具体任务
- [任务1]
- [任务2]
- ...

## 成功标准
- [标准1]
- [标准2]

## 时间限制
20 分钟
```

### 推荐阶段模板

根据项目类型选择：

**通用项目**
```
01-setup    → 搭建/初始化
02-tests    → 测试基线
03-security → 安全审查
04-docs     → 文档审查
05-final    → 最终验收
```

**Web 应用（含前端）**
```
01-setup    → 搭建/初始化
02-tests    → 测试基线
03-security → 安全审查
04-docs     → 文档审查
05-frontend → 前端优化
06-e2e      → 端到端验证
07-final    → 最终验收
```

**库/CLI 工具**
```
01-setup    → 搭建/初始化
02-tests    → 测试基线
03-docs     → 文档审查（API 文档重要）
04-final    → 最终验收
```

**已有成熟项目的优化**
```
01-tests    → 修复失败测试
02-security → 安全扫描
03-docs     → 文档同步
04-final    → 最终验收
```

## 第四步：生成配置文件

在 `agent-loop/` 目录生成 `agent-loop.json`：

```json
{
  "commander_agent": "opencode",
  "worker_agent": "opencode",
  "project_dir": "/absolute/path/to/project",
  "timeout_minutes": 30,
  "phases": "01-setup,02-tests,03-security,04-docs,05-final",
  "commander_extra_instructions": "",
  "worker_extra_instructions": ""
}
```

### 配置说明

| 字段 | 说明 | 默认值 |
|------|------|--------|
| `commander_agent` | 主 OC 用哪个 Agent | `"opencode"` |
| `worker_agent` | 工人 OC 用哪个 Agent | `"opencode"` |
| `project_dir` | 目标项目绝对路径 | `"."` |
| `timeout_minutes` | 每轮超时时间 | `30` |
| `phases` | 阶段列表（逗号分隔） | 见模板 |
| `commander_extra_instructions` | 给主 OC 的额外指令 | `""` |
| `worker_extra_instructions` | 给工人 OC 的额外指令 | `""` |

## 第五步：验证配置

配置完成后，运行验证：

```bash
cd agent-loop
./manage.sh status
```

确认：
- 所有阶段文件存在
- 配置文件格式正确
- 项目目录存在

## 第六步：告知用户

告诉用户：

```
配置完成！你可以：

1. 启动：./manage.sh start
2. 后台运行：nohup ./loop.sh &
3. 查看状态：./manage.sh status
4. 查看日志：./manage.sh log
5. 停止：./manage.sh stop
6. 重置：./manage.sh reset

建议先用 './manage.sh start' 看一轮效果，确认正常后再后台运行。
```

## 注意事项

1. **项目目录必须是绝对路径**，不能用 `~` 或相对路径
2. **Agent 必须配置为自动批准**，否则会卡在权限确认
   - OpenCode：`~/.config/opencode/opencode.json` 设 `"permission": {"*": "allow"}`
   - Claude Code：loop.sh 自动加 `--dangerously-skip-permissions`
3. **阶段文件名必须与配置中的 phases 一致**，如 `01-setup` 对应 `phases/01-setup.md`
4. **每个阶段控制在 20 分钟内**，太大会导致超时
