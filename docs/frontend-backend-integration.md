# Frontend and Backend Integration Workflow

这份文档用于避免 iOS 前端和 FastAPI 后端各自完成后才发现无法连接。核心原则是：
前端先使用固定样例完成界面，后端同时实现同一份样例；双方在第一天前半段完成
第一次真实联调。

## 1. 唯一事实来源

双方只认以下文件：

```text
specs/openapi.yaml
specs/examples/sample-data.json
```

接口字段以 OpenAPI 为准，具体内容以 sample-data 为准。
工程进度单独记录在 [build-status.md](build-status.md)，不能写进接口文件。

不能以以下内容作为接口约定：

- 聊天里临时说的一句话。
- AI 生成的一段代码。
- 某个数据库表的字段名。
- 某个 AI Provider 返回的原始 JSON。
- iOS 本地模型或 Python Pydantic 模型中单独的字段。

## 2. 谁负责什么

iOS 负责人：

```text
apps/ios/**
Xcode 工程、模拟器、页面、网络层和交互
```

后端负责人：

```text
services/api/**
后端测试、部署、Provider
```

共享文件：

```text
specs/openapi.yaml
specs/examples/sample-data.json
docs/backend-execution-guide.md
docs/frontend-backend-integration.md
docs/build-status.md
```

共享文件每次只能有一个负责人修改。建议后端提出字段变更，iOS 负责人确认后再合并。
目录和角色的完整权威规则见 [CONTRIBUTING.md](../CONTRIBUTING.md)。

## 3. 前端不等待后端

在真实接口完成前，iOS 使用以下本地数据：

```text
PresetListResponse
OccasionResolveResponse
WeatherResponse
RecommendationResponse
```

前端必须通过独立的网络层转换：

```text
SwiftUI View
  → ViewModel
  → Wardrobe Photo Store
  → Photo Collage Mapper
  → Optional Voice Assistant
  → RecommendationService protocol
      ├─ LocalMockService
      └─ RemoteAPIService
```

页面不能直接依赖 `URLSession`，也不能在 View 中解析 JSON。这样真实接口变化时，
只需要修改网络层。

前端第一轮使用本地 Mock 完成：

```text
选择或添加衣物照片
→ 输入场合并确认
→ 选择表达方向
→ 三套照片推荐
→ 点击一套查看详情
→ 点击按钮换鞋
→ 确认保存
```

## 4. 后端第一次交付

后端第一个检查点不是“推荐算法完成”，而是：

```text
GET /health
GET /v1/presets
POST /v1/occasions/resolve（Mock）
POST /v1/weather/current（Mock）
POST /v1/recommendations（Mock）
```

所有响应必须与 `sample-data.json` 一致。后端应在本机启动，iOS 可以通过：

```text
http://127.0.0.1:8000
```

进行第一次联调。模拟器访问本机服务有问题时，再使用局域网地址或部署地址。

## 5. 接口变更协议

任何共享字段都不能直接改。

变更顺序：

```text
提出问题
→ 修改 OpenAPI
→ 修改 sample-data
→ 双方确认
→ 前后端同时修改
→ 重新联调
```

一条有效的变更消息应包含：

```text
接口：
旧字段：
新字段：
修改原因：
旧样例：
新样例：
需要 iOS 修改的位置：
```

不能只发“接口改好了，你拉一下”。

## 6. 检查点

| 时间 | iOS | 后端 | 必须完成 |
|---|---|---|---|
| 开始后 1 小时 | 工程启动、黑白界面和照片衣柜骨架 | FastAPI 启动、/health | 两个工程可独立运行 |
| 开始后 3 小时 | 添加衣物照片、场合和确认 | presets、occasions、weather | 字段解析一致 |
| 开始后 6 小时 | 三套照片卡片、换鞋和本地状态 | recommendations Mock | 第一次真实接口调用 |
| 开始后 10 小时 | 真机照片推荐和替换 | 推荐规则首版 | 核心流程联调 |
| 开始后 14 小时 | 真机完成照片衣柜到确认 | revise 首版 | 完整演示闭环 |
| 第一天结束 | 可演示版本 | 部署地址或明确阻塞 | 不允许双方各自“快完成” |
| 第二天 09:00 | 功能冻结 | 功能冻结 | 只修阻断问题 |

## 7. 第一次联调只做一条路径

不要同时测试全部功能。第一次联调固定使用：

```text
点击“我的衣柜”并看到已有衣物照片
→ 输入“第一次约会”并确认
→ 选择“自然”
→ 本地命中 first-date
→ 选择已确认样例衣物
→ POST /v1/recommendations
→ 解码三套结果
→ 将 item IDs 映射到本地照片并显示三套照片卡片
```

这条路径通过后，再测试：

```text
未命中场合 → AI/fallback
推荐失败 → fallback
替换单品 → revise
图片识别
标签匹配
```

## 8. 每个检查点必须交换什么

iOS 负责人发送：

```text
当前可运行的页面：
使用的接口：
请求 JSON：
期望响应：
实际响应：
截图或错误日志：
```

后端负责人发送：

```text
分支：
Commit SHA：
服务地址：
完成的接口：
当前 Mock / Remote 状态：
curl 请求和响应：
pytest 结果：
已知问题：
```

只发送代码链接或“已经完成”不算交付。

## 9. 防止前端和后端跑偏

每次合并前检查：

- 字段名大小写一致。
- 枚举值一致。
- 时间格式一致。
- 数组为空时的处理一致。
- 错误响应使用相同结构。
- `fallback_used` 和 `result_count_reason` 有正确值。
- 推荐结果中的衣物 ID 可以映射到请求衣物。
- iOS 没有把本地照片路径发给后端。
- 后端没有新增 iOS 不知道的必填字段。

## 10. 后端落后时的处理

后端没有按检查点完成时，不修改前端的数据结构。按以下顺序降级：

1. 前端继续使用同一个 JSON 样例。
2. 后端先返回固定 Mock，不接真实 AI。
3. 公共网页 Demo 继续使用静态数据。
4. 把真实 AI、商品搜索和图片相似搜索降到 P1。

不能因为后端未完成，让 iOS 页面临时改变字段或把核心逻辑全部塞进 View。

## 11. 前端阻塞时的处理

如果 iOS 暂时不会实现某个页面，先按以下最小版本：

- 不做复杂动画。
- 只做一套主流程，不做多主题。
- 图片使用本地样例。
- 商品候选只显示两个固定结果。
- 不使用数据库，先用 JSON 文件持久化。
- 接受能力不足的部分先展示固定状态，但不伪造真实 API 成功。

## 12. AI 使用规则

AI 可以用于写代码，但不能代替接口确认。

每次让 AI 实现功能时，先提供：

```text
1. specs/openapi.yaml
2. specs/examples/sample-data.json
3. 当前只实现哪一个页面或接口
```

要求 AI：

- 不新增共享字段。
- 不修改不属于本模块的文件。
- 先说明如何运行和测试。
- 完成后给出真实 JSON 或截图。
- 外部服务不可用时使用 Mock/fallback。

## 13. 下一步动作

开始活动后的前 45 分钟：

1. 双方打开同一个 OpenAPI。
2. 后端运行 `/health`。
3. iOS 验证“照片衣柜→场合→确认→三套照片卡片”。
4. 双方确认第一个联调接口。
5. 固定一个 3 小时后的联调时间。

只要第一次联调发生在开始后 6 小时内，双方的技能限制可以通过模块化、Mock 和
AI 辅助得到控制；如果拖到第二天才第一次连接，风险会非常高。
