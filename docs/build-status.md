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
| `GET /health` | 后端 | 完成 | `feat/api-foundation` | `56f3f6f` | Python 3.9.6；pytest 2 passed；Mac 环境 GET /health 200 | 响应包含 ok、UTC timestamp 和空 providers |
| `GET /v1/presets` | 后端 | Mock | `feat/api-context` | `9beadf7` | Python 3.14.7；pytest 14 passed；presets HTTP 200；version=1 HTTP 304；Python 3.9.x 待独立 Mac 验证 | 返回 sample-data 的 4 个固定预设，不访问外网 |
| `POST /v1/occasions/resolve` | 后端 | Mock | `feat/api-context` | `9beadf7` | pytest 14 passed；精确 first-date 200；alias club-speech 200；fallback confidence 0.35；空查询 422；Python 3.9.x 待独立 Mac 验证 | 本地规范化、名称/alias/关键词匹配与低置信度 fallback |
| `POST /v1/weather/current` | 后端 | 未开始 | `feat/api-context` | - | - | 坐标不得持久化 |
| `POST /v1/recommendations` | 后端 | Mock | `feat/api-recommendation` | `9c2e2da` | Python 3.14.7；pytest 25 passed；UUID 请求 HTTP 200，返回 3 套；Python 3.9.x 待独立 Mac 验证 | `rule_engine_mock`，fallback_used=true；item_ids 均来自请求且无照片字段 |
| `POST /v1/outfits/revise` | 后端 | Mock | `feat/api-recommendation` | `9c2e2da` | pytest 25 passed；替换鞋 HTTP 200；top/bottom ID 不变，仅鞋 ID 变化 | 完整 Outfit 响应；不调用 AI |
| `POST /v1/garments/analyze` | 后端 | 未开始 | `feat/api-garment` | - | - | 先返回固定识别结果 |
| `POST /v1/garments/match` | 后端 | 未开始 | `feat/api-garment` | - | - | 先返回固定商品候选 |

## 3. iOS 页面

| 页面/能力 | 负责人 | 状态 | 分支 | Commit | Mock 可用 | 真实接口已联调 | 备注 |
|---|---|---|---|---|---|---|---|
| Xcode 工程与导航 | iOS | 未开始 | `feat/ios-foundation` | - | - | - | 需求冻结后创建共享 Scheme |
| 黑白高对比首页与图形按钮 | iOS | 未开始 | `feat/ios-foundation` | - | - | - | 按钮含图标和文字 |
| 场合搜索与解析 | iOS | 未开始 | `feat/ios-occasion` | - | - | - | 大尺寸输入框和预设按钮 |
| 照片衣柜与添加衣物 | iOS | 未开始 | `feat/ios-wardrobe` | - | - | - | 本地主图和缩略图 |
| AI 衣物识别审核 | iOS | 未开始 | `feat/ios-garment-recognition` | - | - | - | 用户确认后保存 |
| 标签与商品候选 | iOS | 未开始 | `feat/ios-garment-match` | - | - | - | 不鉴定正版 |
| 三套照片搭配与详情 | iOS | 未开始 | `feat/ios-recommendation` | - | - | - | item ID 映射本地照片 |
| 替换、确认与可选语音 | iOS | 未开始 | `feat/ios-outfit-edit` | - | - | - | 图形主路径，声音可选 |
| 公开网页照片穿搭 Demo | iOS/前端 | 未开始 | `feat/web-demo` | - | - | - | 黑白界面和样例照片 |

## 4. 里程碑

| 检查点 | 目标 | 状态 | 最后验证 |
|---|---|---|---|
| 开始后 1 小时 | iOS 工程可启动；后端 `/health` 可运行 | 后端完成，iOS 待验证 | 本地 Windows：Python 3.14.7，pytest 2 passed；独立 Mac：Python 3.9.6，pytest 2 passed，`/health` HTTP 200（`56f3f6f`） |
| 开始后 3 小时 | 黑白图形首页和照片衣柜列表可运行 | 后端完成，前端待联调 | presets 200/304、occasions exact/alias/fallback/422 已验证；pytest 14 passed |
| 开始后 6 小时 | 三套照片推荐、替换和确认本地闭环 | 未开始 | - |
| 开始后 14 小时 | iOS 调用推荐 Mock 并映射本地照片 | 未开始 | - |
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
