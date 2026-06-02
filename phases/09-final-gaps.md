# 阶段 09：最终补全

## 目标
补全最后 3 个缺失项，确保所有行业模块完整可跑。

## 具体任务

### 任务 1：工序管理模块

创建 work_order_operations 表和 CRUD API：

**迁移文件**：`backend/src/industries/manufacturing/migrations/002_work_order_operations.ts`
```
work_order_operations 表：
- id INTEGER PRIMARY KEY
- work_order_id INTEGER (关联 work_orders)
- operation_name TEXT (工序名称，如：切割/焊接/组装/喷漆)
- sequence INTEGER (工序顺序)
- planned_hours REAL (计划工时)
- actual_hours REAL (实际工时)
- status TEXT (pending/in_progress/completed)
- operator TEXT (操作员)
- notes TEXT
- attributes TEXT (JSON)
- created_at / updated_at
```

**模块**：`backend/src/modules/industries/manufacturing/work-order-operations/`
- service.ts — CRUD + 按工单查询 + 工时汇总
- routes.ts — REST API
- module.json — 注册模块

**关联逻辑**：工单完工时自动汇总所有工序的 actual_hours

### 任务 2：运单签收 API

在 shipments/routes.ts 中添加签收路由：
```
POST /api/shipments/:id/sign
body: { receiver_name, signature, notes }
```

调用 service.ts 中已有的 transitionStatus('已签收') 逻辑。
签收后自动写入 tracking_logs。

### 任务 3：验证演示数据脚本

运行 3 个演示数据脚本，验证：
- `bash scripts/import-manufacturing-demo.sh` — 制造业数据能导入
- `bash scripts/import-retail-demo.sh` — 零售业数据能导入
- `bash scripts/import-logistics-demo.sh` — 物流业数据能导入

如果有报错，修复脚本。

### 任务 4：最终验证

- [ ] npm run check 通过
- [ ] 工单：创建 → 添加工序 → 排产 → 报工 → 完工（自动汇总工时）
- [ ] 运单：创建 → 取件 → 运输 → 派送 → 签收（自动写轨迹）
- [ ] POS：交易 → 日结 → 月结
- [ ] 演示数据：3 个脚本都能成功导入

## 成功标准

- 工序管理表和 API 存在
- 运单签收 API 可用
- 3 个演示数据脚本可成功运行
- npm run check 通过

## 时间限制

20 分钟
