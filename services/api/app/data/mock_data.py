from typing import Any, Dict, List

PRESET_VERSION = 1
PRESET_GENERATED_AT = "2026-11-20T10:00:00+08:00"
FALLBACK_GENERATED_AT = "2026-11-21T00:00:00+08:00"

PRESETS: List[Dict[str, Any]] = [
    {
        "id": "first-date",
        "name": "初次约会",
        "aliases": ["第一次约会", "首次约会", "初次见面的约会"],
        "description": "保持整洁、亲近和低压迫感。",
        "target_formality": "smart_casual",
        "allowed_formality": ["casual", "smart_casual"],
        "required_slots": ["top", "bottom", "shoes"],
        "style_keywords": ["干净", "亲近", "自然", "低压迫感"],
        "avoid_rules": [
            "避免全套正装",
            "避免明显舞台化",
            "避免颜色和配饰过度抢眼",
        ],
        "explanation_guidelines": [
            "解释正式程度是否自然",
            "解释颜色之间是否协调",
            "解释是否适合当前温度",
        ],
        "source": "precomputed",
        "version": 1,
        "generated_at": PRESET_GENERATED_AT,
    },
    {
        "id": "anniversary-date",
        "name": "纪念日约会",
        "aliases": ["结婚纪念日约会", "纪念日", "周年约会", "结婚纪念日"],
        "description": "在日常穿搭上增加适度的精致感和仪式感。",
        "target_formality": "smart_casual",
        "allowed_formality": ["smart_casual", "business"],
        "required_slots": ["top", "bottom", "shoes"],
        "style_keywords": ["精致", "温和", "浪漫", "仪式感"],
        "avoid_rules": [
            "避免完全日常",
            "避免过度夸张",
            "避免冰冷和攻击性的全黑组合",
        ],
        "explanation_guidelines": [
            "解释整体是否比日常略精致",
            "解释单品之间是否形成统一风格",
            "保留至少一处轻松元素",
        ],
        "source": "precomputed",
        "version": 1,
        "generated_at": PRESET_GENERATED_AT,
    },
    {
        "id": "salon-performance",
        "name": "沙龙表演",
        "aliases": ["沙龙", "演奏会", "节目演出", "小型演出"],
        "description": "兼顾舞台辨识度、行动便利和现场气质。",
        "target_formality": "smart_casual",
        "allowed_formality": ["casual", "smart_casual", "business"],
        "required_slots": ["top", "bottom", "shoes"],
        "style_keywords": ["舞台辨识度", "层次感", "便于行动", "个人表达"],
        "avoid_rules": [
            "避免妨碍行动的紧身下装",
            "避免距离较远时完全缺少层次",
            "避免与表演主题冲突的过度商务化",
        ],
        "explanation_guidelines": [
            "解释颜色和轮廓在舞台上的可识别度",
            "解释衣物是否方便活动和演奏",
            "解释个人风格是否明确",
        ],
        "source": "precomputed",
        "version": 1,
        "generated_at": PRESET_GENERATED_AT,
    },
    {
        "id": "club-speech",
        "name": "社团演讲",
        "aliases": ["社团汇报", "社团分享", "社团路演"],
        "description": "专业可信，但不因为全套正装而产生距离感。",
        "target_formality": "business",
        "allowed_formality": ["smart_casual", "business"],
        "required_slots": ["top", "bottom", "shoes"],
        "style_keywords": ["可信", "清晰", "利落", "可接近"],
        "avoid_rules": [
            "避免过强休闲感",
            "避免全套正装造成的僵硬距离感",
            "避免过多分散注意力的图案",
        ],
        "explanation_guidelines": [
            "解释正式程度是否适合公开表达",
            "解释整体轮廓是否利落",
            "解释是否方便走动和上台",
        ],
        "source": "precomputed",
        "version": 1,
        "generated_at": PRESET_GENERATED_AT,
    },
]
