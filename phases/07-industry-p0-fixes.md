# 阶段 07：行业模块补全（P0 修复）

## 目标
根据 INDUSTRY_AUDIT.md 的发现，补全制造业、零售业、物流业的核心缺失，使其可落地使用。

## 背景
审计发现 3 个重行业有表但缺流程完整性：
- 制造业：有 BOM/工单/质检/原材料表，但缺工序管理、工单状态机不完整
- 零售业：有 POS/会员/门店表，但缺 POS 日结流程、促销规则
- 物流业：有运单/车辆/仓储表，但运单状态机不完整、缺签收流程

## 具体任务

### 任务 1：制造业 — 工单状态机 + 工序管理

**工单状态机**：检查 work_orders 表的 status 流转是否完整
- 应有状态：draft(草稿) → planned(已排产) → in_progress(生产中) → completed(已完工) → closed(已入库)
- 检查 work-orders 模块的 routes.ts 是否有状态流转 API
- 检查状态变更是否有校验（如未质检不能入库）

**工序管理**：如果当前没有 work_order_operations 表
- 创建迁移文件：work_order_operations 表（operation_name, sequence, planned_hours, actual_hours, status, operator）
- 在 work-orders 模块中添加工序 CRUD API
- 工单完工时自动汇总工序工时

**BOM 多层展开**：检查 bom 模块是否支持递归展开
- 如果只支持单层，添加递归查询逻辑
- 成本滚加：原材料成本 × 用量 × (1 + 损耗率)

### 任务 2：零售业 — POS 日结 + 促销规则

**POS 日结**：检查 pos 模块是否有日结功能
- 检查 pos_transactions 表是否有 settle_status 字段
- 添加日结 API：汇总当日交易、按支付方式分组、生成日结报表
- 添加月结 API：汇总当月日结数据

**促销规则引擎**：检查 promotions 表是否被使用
- 如果有表但没逻辑，在 rulesExecutor 中添加促销规则
- 支持：满减、折扣、买赠三种基本促销类型
- POS 交易时自动匹配适用促销

### 任务 3：物流业 — 运单状态机 + 签收流程

**运单状态机**：检查 shipments 表的 status 流转
- 应有状态：pending(待取件) → picked_up(已取件) → in_transit(运输中) → delivering(派送中) → delivered(已签收) → exception(异常)
- 检查 shipments 模块是否有状态流转 API
- 状态变更时自动写入 tracking_logs

**签收流程**：
- 添加签收 API（POST /api/shipments/:id/sign）
- 签收时记录：签收人、签收时间、签收照片（attachments）
- 签收后自动更新运单状态

### 任务 4：通用 — 行业演示数据

为每个重行业生成完整的演示数据脚本：
- 制造业：3 个 BOM、5 个工单（不同状态）、10 个质检记录
- 零售业：50 笔 POS 交易、20 个会员、3 个促销活动
- 物流业：30 个运单（不同状态）、10 个车辆、5 个仓储记录

### 任务 5：验证

- [ ] 制造业：创建工单 → 排产 → 报工 → 质检 → 入库，全流程跑通
- [ ] 零售业：POS 交易 → 日结 → 月结，促销自动匹配
- [ ] 物流业：创建运单 → 取件 → 运输 → 派送 → 签收，轨迹自动记录
- [ ] npm run check 通过

## 成功标准

- 3 个重行业的核心流程完整可跑
- 演示数据脚本可一键导入
- npm run check 通过
- INDUSTRY_AUDIT.md 中标记的 P0 差距全部消除

## 时间限制

30 分钟（分多轮完成）
