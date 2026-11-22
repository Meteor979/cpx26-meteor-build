const fs = require("node:fs");
const vm = require("node:vm");

const context = vm.createContext({ window: {}, console });
vm.runInContext(
  fs.readFileSync("apps/web-demo/data.js", "utf8"),
  context
);
vm.runInContext(
  fs.readFileSync("apps/web-demo/engine.js", "utf8"),
  context
);

const data = context.window.WEARWISE_DEMO_DATA;
const engine = context.window.WearWiseEngine;

function assert(condition, message) {
  if (!condition) throw new Error(message);
}

const night = engine.resolveOccasion("去夜店", "business");
const interview = engine.resolveOccasion("实习面试", "casual");
assert(night.id === "night-out", "Night club must resolve to night-out");
assert(night.formality === "casual", "Night club must remain casual");
assert(
  interview.id === "internship-interview",
  "Interview must resolve independently"
);
assert(interview.formality === "business", "Interview must use business");

const nightResult = engine.createRecommendations(data.garments, night);
const interviewResult = engine.createRecommendations(
  data.garments,
  interview
);
assert(nightResult.outfits.length === 3, "Expected three night outfits");
assert(
  interviewResult.outfits.length === 3,
  "Expected three interview outfits"
);
assert(
  nightResult.outfits[0].items.map((item) => item.id).join("|") !==
    interviewResult.outfits[0].items.map((item) => item.id).join("|"),
  "Night and interview first outfits must differ"
);
assert(
  nightResult.outfits[0].reasons[0].includes("夜间社交"),
  "Night reasons must describe nightlife"
);
assert(
  interviewResult.outfits[0].reasons[0].includes("实习面试"),
  "Interview reasons must describe the interview"
);

const replacement = data.garments.find(
  (garment) =>
    garment.slot === "shoes" &&
    garment.id !== nightResult.outfits[0].items.find((item) => item.slot === "shoes").id
);
const revised = engine.replaceItem(
  nightResult.outfits[0],
  replacement,
  data.garments
);
assert(revised.source === "手动调整", "Replacement source must be manual");
assert(
  revised.items.some((item) => item.id === replacement.id),
  "Replacement must update the shoe"
);
assert(
  revised.items.filter((item) => item.slot !== "shoes").every(
    (item) =>
      nightResult.outfits[0].items.some(
        (original) => original.id === item.id
      )
  ),
  "Other slots must remain unchanged"
);

console.log("WearWise web engine tests passed.");
