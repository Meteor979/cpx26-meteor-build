# Contribution and AI Work Rules

本文件是仓库协作规则的唯一权威版本。其他协作文档与本文件冲突时，以本文件为准。

## 1. 角色与文件所有权

| 角色 | 主要目录 | 负责内容 |
|---|---|---|
| iOS 负责人 | `apps/ios/**` | SwiftUI、Xcode 工程、网络层、本地缓存、模拟器测试 |
| 后端负责人 | `services/api/**`、`.env.example`、后端 CI/CD | FastAPI、推荐规则、Provider、后端测试和部署 |
| 产品与用户研究负责人 | `docs/product/**`（新建） | 需求、访谈、范围、演示脚本和提交文案 |
| 视觉与传播负责人 | `design/**` | UI 规范、海报、AMD 证明和展示材料 |
| iOS/后端集成协调人 | `docs/build-status.md`、`docs/frontend-backend-integration.md`、`docs/backend-execution-guide.md`、根目录 `README.md` | 进度、接口联调、检查点和跨角色协调 |

同一文件同一时间只有一个编辑者。共享内容需要其他人确认时，先讨论，再由该文件
的负责人修改，不能多人同时直接编辑。

`design/page-flow.md` 由视觉负责人维护文件格式，涉及 SwiftUI 页面、状态和接口时
必须由 iOS 负责人确认。

### 共享接口文件

```text
specs/openapi.yaml
specs/examples/sample-data.json
```

由后端负责人实际修改，因为后端负责人负责 `specs/**`。任何接口字段变化都必须：

1. 通知 iOS 负责人。
2. 同时更新 OpenAPI 和 sample-data。
3. iOS 负责人确认会影响哪些 Swift 模型或页面。
4. 双方重新联调后才能把状态改为“联调”或“完成”。

## 2. 分支规则

- `main`：只放经过测试、可以现场演示的版本。
- `dev`：所有功能的日常集成分支。
- `feat/ios-*`：iOS 功能。
- `feat/api-*`：后端功能。
- `docs/product-*`：产品与用户研究文档。
- `docs/eng-*`：工程协作与联调文档。
- `design/*`：视觉和提交材料。

所有功能或文档分支从最新 `dev` 创建，通过 PR 合并回 `dev`。只有 iOS 负责人把
经过测试的 `dev` 合并到 `main`。

禁止：

- 直接向 `main` 推送功能代码。
- 使用强制推送覆盖其他人的提交。
- 多人同时修改同一分支的同一文件。
- 把其他人的未完成代码合并进 `dev`。

## 3. 开发顺序

```text
接口合同
→ Mock
→ iOS 本地页面
→ 第一次真实联调
→ 真实 Provider
→ 完整回归
→ 合并 main
```

Mock 是预先写好的固定 JSON 响应。它不是假装功能完成；它的作用是让 iOS 和后端
先按同一字段完成联调。真实 AI 或搜索不可用时必须保留 Mock/fallback。

## 4. 完成标准

只有满足以下条件才能标记“完成”：

- 代码已提交并推送。
- 测试命令通过。
- 接口响应符合 `specs/openapi.yaml`。
- iOS 能成功解码或页面能够运行。
- `docs/build-status.md` 填有 Commit SHA 和运行证据。
- 没有提交 `.env`、API Key、证书、个人照片或精确位置。
- 从干净环境按 README 可以复现。

“代码已生成”“页面看起来完成”或“AI 说已经完成”都不能单独作为完成证据。

## 5. 检查点与回报

每 2–3 小时必须有一个可运行提交。活动开始后的强制检查点：

| 时间 | 最低交付 |
|---|---|
| +1 小时 | iOS 工程可启动；后端 `/health` 可运行 |
| +3 小时 | 场合、天气和预设 Mock 可调用 |
| +6 小时 | iOS 第一次成功调用推荐 Mock 接口 |
| +14 小时 | 推荐、替换和确认完整闭环 |
| 第一天结束 | 可演示版本和公开后端地址，或明确阻塞 |
| 第二天 09:00 | 功能冻结 |

每次回报必须包含：

```text
负责人：
分支：
Commit SHA：
完成内容：
运行命令：
测试结果：
请求/响应或截图：
当前状态：未开始 / Mock / 实现 / 联调 / 完成 / 阻塞
仍存在的问题：
```

## 6. AI 助手工作规则

AI 可以写代码、测试和文档，但不能自行扩大工作范围。

使用 AI 前必须让它阅读：

```text
README.md
CONTRIBUTING.md
docs/frontend-backend-integration.md
docs/build-status.md
specs/openapi.yaml
specs/examples/sample-data.json
```

后端 AI 还必须阅读 `docs/backend-execution-guide.md`。

每次只允许 AI 实现一个垂直任务，例如“健康检查”或“推荐 Mock”。AI 必须：

- 不修改其他角色的目录。
- 不新增 iOS 不知道的共享字段。
- 外部服务不可用时实现 Mock/fallback。
- 运行测试并提供真实命令输出。
- 不把未验证代码描述成已经联调完成。
- 不自动把状态改为“完成”。

推荐给 AI 的固定提示：

```text
先阅读 README.md、CONTRIBUTING.md、docs/build-status.md、
specs/openapi.yaml 和 specs/examples/sample-data.json。
本次只实现一个垂直任务，不修改其他角色目录，不新增共享字段。
先说明修改文件和验收命令，再写代码。
完成后运行测试和实际请求，并报告真实结果。
```

## 7. 数据与隐私边界

- 衣物原图和标签原图保存在 iOS 本地。
- 图片识别或外形匹配时，只允许在用户明确操作后发送临时压缩图片。
- 临时图片不得用于训练、不得长期保存，日志不得记录图片内容或精确位置。
- 推荐接口只发送已确认的结构化衣物字段，不发送本地文件路径或照片。
- 天气接口只接收天气查询需要的粗略坐标，返回后不建立位置轨迹。
- API Key 只存在后端环境变量中。

## 8. 合并前检查

1. 从最新 `dev` 开始。
2. 运行相关测试。
3. 检查 staged 文件里没有秘密和个人数据。
4. 检查 OpenAPI 与 sample-data 是否同步。
5. 更新自己的 `build-status` 行。
6. 在 PR 描述中写明修改、测试和已知风险。
7. 等 CI 或双方人工验证后再合并。

## 9. 功能冻结

2026 年 11 月 22 日 09:00 后只允许修复构建、演示或提交阻断问题。冻结后不新增
页面、不更换 Provider、不重构架构、不修改共享接口，除非双方同意该问题会直接阻止提交。

