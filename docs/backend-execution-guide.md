# WearWise Backend Execution Guide

这份文档把后端工作拆成可以直接执行、测试和验收的小任务。即使不熟悉 FastAPI、
Mock 或 Provider，也应按这里给出的顺序完成，不要一开始就接真实 AI 或搜索服务。

## 1. 先理解几个词

- **API**：前端调用后端的一个入口。例如健康检查入口是 `GET /health`。
- **请求**：前端发给后端的数据。
- **响应**：后端返回给前端的数据。
- **JSON**：两边交换数据使用的文本格式。
- **Mock**：预先写死的假数据。它不是“假装系统完成”，而是让前端先按稳定的数据结构
  开发。例如无论请求是什么，Mock 都返回三套固定搭配。
- **Provider**：真正连接外部服务的代码。例如天气 Provider、视觉 Provider。
- **Fallback**：主服务失败时的备用结果。推荐接口失败时应返回规则搭配，而不是空白页。
- **Contract**：前后端约定的字段。当前以 `specs/openapi.yaml` 和
  `specs/examples/sample-data.json` 为准。

## 2. 工作边界

后端负责人只修改：

```text
services/api/**
specs/**
.github/workflows/api-test.yml
.github/workflows/deploy-api.yml
.env.example
```

不要修改：

```text
apps/ios/**
design/**
WearWise.xcodeproj
```

接口字段需要变化时，必须在同一提交中修改 OpenAPI 和样例数据，并通知 iOS 负责人。
不能只改 Python 模型，让前端自己猜字段。

### Python 3.9 兼容规则

- FastAPI 后端的最低支持版本是 Python 3.9，开发、CI 和部署环境都必须满足。
- 类型标注使用 `Optional`、`List`、`Dict` 和 `Tuple`，从 `typing` 导入。
- 禁止使用 `X | None`、`int | None`、`list[...]`、`dict[...]` 等只适用于较新
  Python 的写法，避免 Mac 与 Windows 环境不一致。
- 更换 Python 版本后必须删除或清空旧虚拟环境并重新创建 `.venv`，不能复用旧
  Python 解释器生成的依赖。
- 每次提交报告必须写明实际 Python 版本，并附上 `python --version` 的结果。

## 3. 第一天的第一个里程碑

先建立独立分支：

```bash
git clone https://github.com/Meteor979/cpx26-meteor-build.git
cd cpx26-meteor-build
git switch dev
git switch -c feat/api-foundation
```

第一阶段只做下面这件事：

```text
创建 FastAPI 项目
→ GET /health 返回 JSON
→ 本地可以启动
→ 有至少一个自动测试
→ 推到 feat/api-foundation
```

第一版只创建这些文件：

```text
services/api/
├── app/
│   ├── __init__.py
│   ├── main.py
│   ├── config.py
│   ├── models.py
│   └── routers/
│       ├── __init__.py
│       └── system.py
├── tests/
│   └── test_health.py
├── requirements.txt
└── README.md
```

目标响应：

```json
{
  "status": "ok",
  "timestamp": "2026-11-21T10:00:00+08:00",
  "providers": []
}
```

启动和验收：

macOS / Linux：

```bash
cd services/api
python -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
uvicorn app.main:app --reload --port 8000
```

Windows PowerShell：

```powershell
cd services\api
py -3 -m venv .venv
.\.venv\Scripts\Activate.ps1
python -m pip install -r requirements.txt
python -m uvicorn app.main:app --reload --port 8000
```

另一个终端：

```bash
curl.exe http://127.0.0.1:8000/health
pytest -q
```

完成标准：

- 浏览器能打开 `http://127.0.0.1:8000/docs`。
- `/health` 返回 HTTP 200 和 JSON。
- `pytest -q` 至少有一个通过测试。
- 没有提交 `.env`、Key 或虚拟环境。
- 推送分支并把 commit SHA 发给 iOS 负责人。

第一里程碑预计 1–2 小时。不要在它跑通前开始 AI。

## 4. P0 任务顺序

### 任务 1：共享模型和 Mock 数据

文件：

```text
services/api/app/models.py
services/api/app/data/mock_data.py
services/api/tests/test_models.py
```

要求：

- 字段与 `specs/openapi.yaml` 一致。
- 读取或复用 `specs/examples/sample-data.json` 中已经确认的样例。
- 不要加入 `local_photo_path` 到推荐请求。
- 推荐请求中的 `user_confirmed` 必须是 `true`。
- Mock 至少包含：
  - 4 个场合策略。
  - 1 组衣物。
  - 3 套已经确认的推荐结果。
  - 1 个 fallback 推荐结果。

验收：

```bash
pytest -q services/api/tests/test_models.py
```

### 任务 2：预设和场合解析

接口：

```text
GET /v1/presets
POST /v1/occasions/resolve
```

规则：

1. 后端先匹配精确名称和别名。
2. 再匹配已缓存的策略。
3. 仍然未命中才调用 AI Provider。
4. AI 不可用时返回通用 fallback 策略。

Mock 示例：

```text
“第一次约会” → first-date
“社团汇报” → club-speech
“不认识的表达” → generated 或 fallback
```

完成标准：

- “第一次约会”不调用外部 AI。
- 未命中时有明确的 `match_type=generated` 或 `fallback`。
- 响应包含正式程度、允许层级、必需槽位、关键词和避免项。

### 任务 3：自动天气

接口：

```text
POST /v1/weather/current
```

输入只有粗略经纬度、时区和请求 ID。输出：

```text
temperature_c
feels_like_c
condition
precipitation_probability
wind_speed_kph
```

要求：

- 坐标校验范围。
- 不写入数据库，不写进日志。
- 天气 Provider 失败时返回 `status=unavailable` 或使用 60 分钟内缓存。
- iOS 没有定位权限时不会调用此接口，而是显示阻塞页。

### 任务 4：推荐规则

接口：

```text
POST /v1/recommendations
```

必须按以下顺序实现：

1. 校验请求字段和衣物 ID。
2. 根据 `formality_score` 计算层级。
3. 按层级和槽位建立候选。
4. 生成上装、下装、鞋子完整的组合。
5. 检查天气：下雨时优先封闭鞋，温度低时考虑外套。
6. 去重并最多返回三套。
7. 调用可替换文本 AI 生成解释。
8. AI 失败时使用模板理由返回 `fallback_used=true`。

固定层级：

```text
1–2 → casual
3   → smart_casual
4   → business
5   → formal
```

完成标准：

- 三套搭配中的衣物 ID 全部来自请求。
- 不重复使用同一件衣物。
- 缺少上装、下装或鞋子返回 `INSUFFICIENT_WARDROBE`。
- AI 超时不导致 500。
- Mock 模式完全不访问外网。

### 任务 5：单品替换

接口：

```text
POST /v1/outfits/revise
```

要求：

- `base_item_ids` 和替换单品来自请求。
- 替换前后槽位相同。
- 其他槽位保持不变。
- AI 失败时仍返回修改后的组合和模板理由。

### 任务 6：衣物识别和商品匹配 Mock

接口：

```text
POST /v1/garments/analyze
POST /v1/garments/match
```

第一阶段只返回 `specs/examples/sample-data.json` 中的固定结果：

- 上传一张图片，返回衬衫特征。
- 标签包含 UNIQLO 和 123456 时，返回固定商品候选。
- 不调用真实图片识别和网页搜索。

完成标准：

- 图片缺失返回 422。
- 非图片格式返回 415。
- 匹配不到时返回 `not_found`，不能编造商品。
- 商品匹配不声称“正版已鉴定”。

## 5. 真实 Provider 阶段

只有在所有 P0 Mock 接口通过后才开始。

环境变量至少支持：

```text
WEATHER_PROVIDER=mock
VISION_PROVIDER=mock
TEXT_AI_PROVIDER=mock
SEARCH_PROVIDER=mock
```

每种 Provider 都要有：

```text
mock
remote
fallback
```

接入顺序：

1. 文本 AI 解释和场合解析。
2. 天气 Provider。
3. 图片特征识别。
4. 标签和商品搜索。

商品图片反向搜索风险最高。一天内无法稳定完成时，保留结构化属性搜索和
商品货号搜索，不要把整个演示阻塞在全网图片搜索上。

## 6. 检查点

每个检查点必须推送并回报，不能只说“快好了”。

| 时间 | 必须完成 |
|---|---|
| 开始后 2 小时 | `/health`、项目启动、测试框架 |
| 开始后 5 小时 | 模型中、预设、场合解析 Mock |
| 开始后 9 小时 | 天气接口、推荐规则首版 |
| 开始后 14 小时 | 推荐三套、替换和 fallback |
| 开始后 18 小时 | 两个衣物识别接口 Mock |
| 第一天结束 | 公开 HTTPS 地址或明确部署阻塞 |
| 第二天 09:00 | 功能冻结，只修阻断问题 |

每 2–3 小时至少要有一个可运行提交。连续 1 小时没有可运行结果或卡在同一错误
30 分钟，应立即发送错误信息，不要继续独自猜。

## 7. 每次交付必须报告

```text
分支：
Commit SHA：
完成的功能：
可以运行的命令：
测试结果：
请求示例：
响应示例：
当前 Provider：mock / remote / fallback
公开地址：
仍存在的问题：
```

只发送代码链接不算完成，必须有运行证据。

## 8. 给 AI 的固定工作提示

后面的消息可以直接使用：

```text
请先完整阅读：
1. specs/openapi.yaml
2. specs/examples/sample-data.json
3. docs/backend-execution-guide.md

本次只实现一个垂直任务，不修改其他接口字段，不修改 apps/ios 或 design。
先列出要修改的文件和验收命令，再写代码。
完成后必须运行 pytest 和至少一个 curl 请求，并把真实输出发给我。
如果没有真实 API Key，就实现 mock 和 fallback，不要伪造“已经联网成功”。
```

## 9. 完成边界

完成不等于“代码写出来了”。满足以下条件才算完成：

- 从干净环境按 README 能启动。
- 自动测试通过。
- 接口响应符合 OpenAPI。
- Mock 和 fallback 不依赖外网。
- 没有泄露 Key、照片或精确位置。
- iOS 能按固定字段完成联调。
- 部署地址可由另一台设备访问。
