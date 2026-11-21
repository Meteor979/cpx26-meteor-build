# WearWise Build Status

这个文件记录工程进度。接口必须始终以 `specs/openapi.yaml` 为准，测试数据必须与
`specs/examples/sample-data.json` 一致；不要用本文件代替接口契约。

```text
Contract version: 0.4.0
Last updated: 2026-11-21
Status owner: iOS/backend integration coordinator
```

正式产品开发从本状态文件提交后开始。仓库中未提交的本地原型不计入工程进度，
也不能用 `git add .` 带入正式基线。

## 1. 状态定义

| 状态 | 含义 |
|---|---|
| 未开始 | 还没有可运行代码 |
| Mock | 已返回与样例一致的数据，但不调用真实外部服务 |
| 实现 | 主要逻辑已经完成，仍需联调 |
| 联调 | iOS 已成功调用真实后端并解码 |
| 完成 | 测试通过、可从干净环境运行、证据已提交 |
| 阻塞 | 有明确的外部依赖或错误，需要介入 |

只有具备运行证据才能把状态改成“实现”“联调”或“完成”。证据包括 commit SHA、
测试命令、curl 响应、截图或公开地址。

## 2. 后端接口

| 接口 | 负责人 | 状态 | 分支 | Commit | 测试/证据 | 备注 |
|---|---|---|---|---|---|---|
| `GET /health` | 后端 | 实现 | `feat/api-foundation` | `56f3f6f` | Python 3.14.7；pytest: 2 passed；`/health`: HTTP 200，providers=[] | 等待 Mac 独立环境复测后改为完成 |
| `GET /v1/presets` | 后端 | 未开始 | `feat/api-context` | - | - | 先使用固定预设 |
| `POST /v1/occasions/resolve` | 后端 | 未开始 | `feat/api-context` | - | - | 本地匹配后再 AI |
| `POST /v1/weather/current` | 后端 | 未开始 | `feat/api-context` | - | - | 坐标不得持久化 |
| `POST /v1/recommendations` | 后端 | 未开始 | `feat/api-core` | - | - | Mock 优先 |
| `POST /v1/outfits/revise` | 后端 | 未开始 | `feat/api-core` | - | - | 保持其他槽位锁定 |
| `POST /v1/garments/analyze` | 后端 | 未开始 | `feat/api-garment` | - | - | 先返回固定识别结果 |
| `POST /v1/garments/match` | 后端 | 未开始 | `feat/api-garment` | - | - | 先返回固定商品候选 |

## 3. iOS 页面

| 页面/能力 | 负责人 | 状态 | 分支 | Commit | Mock 可用 | 真实接口已联调 | 备注 |
|---|---|---|---|---|---|---|---|
| Xcode 工程与导航 | iOS | 未开始 | `feat/ios-foundation` | - | - | - | 需求冻结后创建共享 Scheme |
| 持续前台语音与自动恢复聆听 | iOS | 未开始 | `feat/ios-voice-loop` | - | - | - | 设备端识别、回声隔离和真机验证 |
| 语音场合理解 | iOS | 未开始 | `feat/ios-occasion` | - | - | - | 开始/确认/重新说路径 |
| 衣柜列表与添加衣物 | iOS | 未开始 | `feat/ios-wardrobe` | - | - | - | 照片保存在本地 |
| AI 衣物识别审核 | iOS | 未开始 | `feat/ios-garment-recognition` | - | - | - | 用户确认后保存 |
| 标签与商品候选 | iOS | 未开始 | `feat/ios-garment-match` | - | - | - | 不鉴定正版 |
| 三套推荐与语音详情 | iOS | 未开始 | `feat/ios-recommendation` | - | - | - | A/B/C、比较和理由口令 |
| 替换、确认与穿衣顺序 | iOS | 未开始 | `feat/ios-outfit-edit` | - | - | - | 换鞋后重新生成步骤 |
| 公开网页纯语音 Demo | iOS/前端 | 未开始 | `feat/web-demo` | - | - | - | 需求冻结后按基线实现 |

## 4. 里程碑

| 检查点 | 目标 | 状态 | 最后验证 |
|---|---|---|---|
| 开始后 1 小时 | iOS 工程可启动；后端 `/health` 可运行 | 后端实现，iOS 待验证 | Python 3.14.7；pytest: 2 passed；`/health`: HTTP 200（`56f3f6f`） |
| 开始后 3 小时 | 场合、天气和预设接口 Mock 可用 | 未开始 | - |
| 开始后 6 小时 | iOS 第一次调用推荐 Mock 接口 | 未开始 | - |
| 开始后 14 小时 | 推荐、替换、确认完整闭环 | 未开始 | - |
| 第一天结束 | 可演示版本和部署地址 | 未开始 | - |
| 第二天 09:00 | 前后端功能冻结 | 未开始 | - |

## 5. 更新规则

1. 后端每完成一个检查点，填写自己的接口行和里程碑。
2. iOS 每完成一个页面，填写自己的页面行。
3. Commit 必须填写真实短 SHA。
4. 测试/证据填写命令结果、curl、截图或公开 URL。
5. 阻塞项必须写清楚“错误、已尝试、需要谁处理”。
6. 双方不要同时修改同一行。
7. 完成状态必须由接口双方共同确认。
8. 每次更新表格时同步修改顶部 `Last updated`。

## 6. 每个检查点回报模板

```text
负责人：
分支：
Commit SHA：
完成内容：
运行命令：
测试结果：
请求示例：
响应示例：
公开地址：
当前状态：Mock / 实现 / 联调 / 完成 / 阻塞
阻塞或已知问题：
```

## 7. 状态文件与协议文件的区别

```text
openapi.yaml
  = 接口必须长什么样

sample-data.json
  = 接口在样例场景中返回什么

build-status.md
  = 谁做到哪一步、什么时候完成、证据在哪里
```

协议字段变化时修改前两份文件；工程进度变化时只修改本文件。
