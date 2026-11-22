(function () {
  "use strict";

  function garmentIllustration(type, color, accent = "#ffffff") {
    const drawings = {
      shirt:
        '<path d="M140 105 230 58l56 48 56-48 90 47-38 104-55-23v198H233V186l-55 23Z" fill="' +
        color +
        '"/><path d="M230 58l56 48 56-48-24 76h-64Z" fill="' +
        accent +
        '" opacity=".9"/>',
      sweater:
        '<path d="M145 115 225 66h62l80 49-42 110-50-22v178H237V203l-50 22Z" fill="' +
        color +
        '"/><path d="M225 66h62l-31 43Z" fill="' +
        accent +
        '"/>',
      jeans:
        '<path d="M202 62h108l19 322h-67l-6-191-7 191h-67l-6-191-6 191h-67Z" fill="' +
        color +
        '"/><path d="M202 62h108v24H202Z" fill="' +
        accent +
        '" opacity=".8"/>',
      trousers:
        '<path d="M198 58h116l18 330h-73l-3-205-4 205h-73l-4-205-4 205h-73Z" fill="' +
        color +
        '"/><path d="M198 58h116v22H198Z" fill="' +
        accent +
        '" opacity=".75"/>',
      sneakers:
        '<path d="M92 303c43 1 75 15 110 52 27 29 63 32 126 37 50 4 74 20 70 45H91Z" fill="' +
        color +
        '"/><path d="M91 420h307v18H91Z" fill="' +
        accent +
        '"/>',
      loafers:
        '<path d="M104 326c56-4 90 18 116 48 28 32 73 40 142 44 51 3 69 19 64 40H104Z" fill="' +
        color +
        '"/><path d="M165 331c44 4 72 20 92 45-39 11-77-5-124-28Z" fill="' +
        accent +
        '" opacity=".75"/>',
      cardigan:
        '<path d="M128 129 213 67h86l85 62-45 118-42-25v177H215V222l-42 25Z" fill="' +
        color +
        '"/><path d="M256 70v329" stroke="' +
        accent +
        '" stroke-width="8"/><circle cx="256" cy="150" r="7" fill="' +
        accent +
        '"/><circle cx="256" cy="215" r="7" fill="' +
        accent +
        '"/><circle cx="256" cy="280" r="7" fill="' +
        accent +
        '"/>'
    };
    const svg =
      '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 512 512">' +
      '<rect width="512" height="512" fill="#efeff1"/>' +
      drawings[type] +
      "</svg>";
    return "data:image/svg+xml;charset=UTF-8," + encodeURIComponent(svg);
  }

  window.WEARWISE_DEMO_DATA = {
    presets: [
      ["初次约会", "smart_casual"],
      ["社团演讲", "business"],
      ["朋友聚餐", "casual"],
      ["实习面试", "business"]
    ],
    garments: [
      {
        id: "demo-shirt",
        name: "浅蓝牛津衬衫",
        slot: "top",
        category: "shirt",
        colors: ["浅蓝", "白"],
        formality: 3,
        photo: garmentIllustration("shirt", "#83a9d6")
      },
      {
        id: "demo-knit",
        name: "米白针织衫",
        slot: "top",
        category: "knitwear",
        colors: ["米白"],
        formality: 2,
        photo: garmentIllustration("sweater", "#ddd4c5")
      },
      {
        id: "demo-jeans",
        name: "深蓝直筒牛仔裤",
        slot: "bottom",
        category: "jeans",
        colors: ["深蓝"],
        formality: 2,
        photo: garmentIllustration("jeans", "#344d72")
      },
      {
        id: "demo-trousers",
        name: "黑色西装裤",
        slot: "bottom",
        category: "trousers",
        colors: ["黑"],
        formality: 4,
        photo: garmentIllustration("trousers", "#242426")
      },
      {
        id: "demo-sneakers",
        name: "白色运动鞋",
        slot: "shoes",
        category: "sneakers",
        colors: ["白"],
        formality: 2,
        photo: garmentIllustration("sneakers", "#f7f7f5", "#d4d4d6")
      },
      {
        id: "demo-loafers",
        name: "棕色乐福鞋",
        slot: "shoes",
        category: "loafers",
        colors: ["棕"],
        formality: 4,
        photo: garmentIllustration("loafers", "#65432f", "#b58d69")
      },
      {
        id: "demo-cardigan",
        name: "米色开衫",
        slot: "outerwear",
        category: "cardigan",
        colors: ["米色"],
        formality: 2,
        photo: garmentIllustration("cardigan", "#d7cbb6")
      }
    ],
    garmentIllustration
  };
})();
