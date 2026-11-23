(function () {
  "use strict";

  const TARGET = {
    casual: 2,
    smart_casual: 3,
    business: 4,
    formal: 5
  };
  const FORMALITY_LABEL = {
    casual: "Casual",
    smart_casual: "Smart casual",
    business: "Business",
    formal: "Formal"
  };
  const SLOT_LABEL = {
    top: "Tops",
    bottom: "Bottoms",
    shoes: "Shoes",
    outerwear: "Outerwear"
  };

  function normalize(value) {
    return String(value || "")
      .toLowerCase()
      .replace(/[，。！？、,.!?：:；;“”"'‘’（）()\s]/g, "");
  }

  function resolveOccasion(query, formalityHint) {
    const value = normalize(query);
    if (/去夜店|夜店|夜生活|派对|酒吧|clubbing|nightclub|nightout|party/.test(value)) {
      return {
        id: "night-out",
        name: "Night out",
        formality: "casual",
        keywords: ["nightlife", "self-expression", "relaxed"],
        source: "Local rules"
      };
    }
    if (/实习面试|面试|校招|interview/.test(value)) {
      return {
        id: "internship-interview",
        name: "Internship interview",
        formality: "business",
        keywords: ["professional", "clear", "credible"],
        source: "Local rules"
      };
    }
    if (/社团演讲|社团汇报|路演|clubpresentation|clubspeech/.test(value)) {
      return {
        id: "club-speech",
        name: "Club presentation",
        formality: "business",
        keywords: ["credible", "clear", "approachable"],
        source: "Local rules"
      };
    }
    if (/第一次约会|初次约会|约会|firstdate|date/.test(value)) {
      return {
        id: "first-date",
        name: "First date",
        formality: "smart_casual",
        keywords: ["natural", "clean", "low-pressure"],
        source: "Local rules"
      };
    }
    return {
      id: "fallback-general",
      name: query.trim() || "General occasion",
      formality: formalityHint || "smart_casual",
      keywords: ["clean", "natural", "approachable"],
      source: "Fallback rules"
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
        error: "Missing: " + missing.map((slot) => SLOT_LABEL[slot]).join(", "),
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
          ? ["Relaxed with personal expression", "Easy layers for the night", "Ready to move"]
          : occasion.id === "internship-interview"
            ? ["Clear and credible", "A composed professional look", "Formal without feeling stiff"]
            : ["Clear and natural", "Softly balanced", "Sharp and composed"];
      const lead =
        occasion.id === "night-out"
          ? "The combination reads as social and mobile rather than business-like."
          : occasion.id === "internship-interview"
            ? "The combination supports a clear, credible internship interview."
            : "The formality is aligned with the selected occasion.";
      return {
        id: `outfit-${index + 1}`,
        title: titles[index],
        items: candidate.items,
        score: candidate.score,
        source: "Local demo rules",
        reasons: [
          lead,
          `${candidate.items[0].name} and ${candidate.items[1].name} create a clear top-to-bottom relationship.`,
          `The formality is close to ${FORMALITY_LABEL[occasion.formality]}, using photos from the local wardrobe only.`
        ],
        tradeoffs:
          occasion.id === "night-out"
            ? ["Any business-leaning piece can weaken the nightlife tone."]
            : ["Review the outfit once more before confirming it."]
      };
    });

    return {
      outfits: selected,
      countReason:
        selected.length < 3 ? "The current wardrobe supports fewer than three distinct outfits." : ""
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
      title: `Updated with ${replacement.name}`,
      items,
      source: "Manual adjustment",
      reasons: [
        `${replacement.name} replaced the previous same-slot item while the rest of the outfit stayed locked.`,
        "This is a local manual adjustment."
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
