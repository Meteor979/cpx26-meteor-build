(function () {
  "use strict";

  const TARGET = {
    casual: 2,
    smart_casual: 3,
    business: 4,
    formal: 5
  };
  const FORMALITY_LABEL = {
    casual: "休闲",
    smart_casual: "智能休闲",
    business: "商务",
    formal: "正式"
  };
  const SLOT_LABEL = {
    top: "上装",
    bottom: "下装",
    shoes: "鞋",
    outerwear: "外套"
  };

  function normalize(value) {
    return String(value || "")
      .toLowerCase()
      .replace(/[，。！？、,.!?：:；;“”"'‘’（）()\s]/g, "");
  }

  function resolveOccasion(query, formalityHint) {
    const value = normalize(query);
    if (/去夜店|夜店|夜生活|派对|酒吧|clubbing/.test(value)) {
      return {
        id: "night-out",
        name: "夜店",
        formality: "casual",
        keywords: ["夜间社交", "个人表达", "轻松"],
        source: "本地语义"
      };
    }
    if (/实习面试|面试|校招/.test(value)) {
      return {
        id: "internship-interview",
        name: "实习面试",
        formality: "business",
        keywords: ["专业", "清晰", "可靠"],
        source: "本地语义"
      };
    }
    if (/社团演讲|社团汇报|路演/.test(value)) {
      return {
        id: "club-speech",
        name: "社团演讲",
        formality: "business",
        keywords: ["可信", "清晰", "可接近"],
        source: "本地语义"
      };
    }
    if (/第一次约会|初次约会|约会/.test(value)) {
      return {
        id: "first-date",
        name: "初次约会",
        formality: "smart_casual",
        keywords: ["自然", "干净", "低压迫感"],
        source: "本地语义"
      };
    }
    return {
      id: "fallback-general",
      name: query.trim() || "通用场合",
      formality: formalityHint || "smart_casual",
      keywords: ["整洁", "自然", "可接近"],
      source: "本地备用"
    };
  }

  function scoreOutfit(items, occasion) {
    const target = TARGET[occasion.formality];
    const average =
      items.reduce((sum, item) => sum + item.formality, 0) / items.length;
    let score = 6 - Math.abs(average - target) * 2;
    const categories = new Set(items.map((item) => item.category));
    if (occasion.id === "night-out") {
      items.forEach((item) => {
        if (item.formality <= 2) score += 1.4;
        if (item.formality >= 4) score -= 2.2;
      });
      if (categories.has("sneakers")) score += 1.1;
      if (categories.has("knitwear") || categories.has("t_shirt")) score += 0.7;
      if (categories.has("blazer")) score -= 1.5;
    } else if (
      occasion.id === "internship-interview" ||
      occasion.id === "club-speech"
    ) {
      items.forEach((item) => {
        if (item.formality >= 3) score += 0.75;
      });
      if (
        categories.has("trousers") ||
        categories.has("shirt") ||
        categories.has("loafers") ||
        categories.has("blazer")
      ) {
        score += 1.2;
      }
      if (categories.has("sneakers")) score -= 0.8;
    }
    return Math.round(score * 1000) / 1000;
  }

  function createRecommendations(garments, occasion) {
    const grouped = { top: [], bottom: [], shoes: [], outerwear: [] };
    garments.forEach((garment) => {
      if (grouped[garment.slot]) grouped[garment.slot].push(garment);
    });
    const missing = ["top", "bottom", "shoes"].filter(
      (slot) => grouped[slot].length === 0
    );
    if (missing.length) {
      return {
        error: "还缺少：" + missing.map((slot) => SLOT_LABEL[slot]).join("、"),
        outfits: []
      };
    }

    const candidates = [];
    grouped.top.forEach((top) => {
      grouped.bottom.forEach((bottom) => {
        grouped.shoes.forEach((shoe) => {
          [null, ...grouped.outerwear].forEach((outerwear) => {
            const items = [top, bottom, shoe];
            if (outerwear) items.push(outerwear);
            candidates.push({
              items,
              score: scoreOutfit(items, occasion),
              signature: items.map((item) => item.id).sort().join("|")
            });
          });
        });
      });
    });

    candidates.sort(
      (first, second) =>
        second.score - first.score ||
        first.signature.localeCompare(second.signature)
    );
    const selected = candidates.slice(0, 3).map((candidate, index) => {
      const titles =
        occasion.id === "night-out"
          ? ["轻松，有个人表达", "保持轻松，增加层次", "更适合走动"]
          : occasion.id === "internship-interview"
            ? ["清晰，可信", "稳妥的专业感", "更轻松的正式表达"]
            : ["清晰自然", "温和协调", "利落明确"];
      const lead =
        occasion.id === "night-out"
          ? "整体更接近夜间社交，避免像商务会面。"
          : occasion.id === "internship-interview"
            ? "整体面向实习面试，强调清楚、可靠和正式表达。"
            : "整体正式度与当前场合匹配。";
      return {
        id: `outfit-${index + 1}`,
        title: titles[index],
        items: candidate.items,
        score: candidate.score,
        source: "本地样例",
        reasons: [
          lead,
          `${candidate.items[0].name}与${candidate.items[1].name}形成清楚的上下装关系。`,
          `正式度接近${FORMALITY_LABEL[occasion.formality]}，并直接使用本地衣柜照片。`
        ],
        tradeoffs:
          occasion.id === "night-out"
            ? ["部分偏商务单品会削弱夜间社交感。"]
            : ["单套方案仍值得通过详情页再次确认。"]
      };
    });

    return {
      outfits: selected,
      countReason:
        selected.length < 3 ? "当前衣柜组合有限，只展示可组成的方案。" : ""
    };
  }

  function replaceItem(outfit, replacement, garments) {
    const current = outfit.items.find(
      (item) => item.slot === replacement.slot
    );
    if (!current) return outfit;
    const items = outfit.items.map((item) =>
      item.id === current.id ? replacement : item
    );
    return {
      ...outfit,
      id: outfit.id + "-edited",
      title: `已替换${replacement.name}`,
      items,
      source: "手动调整",
      reasons: [
        `${replacement.name}已替换同槽位衣物，其他单品保持不变。`,
        "当前为本地手动调整结果。"
      ]
    };
  }

  window.WearWiseEngine = {
    SLOT_LABEL,
    FORMALITY_LABEL,
    createRecommendations,
    replaceItem,
    resolveOccasion
  };
})();
