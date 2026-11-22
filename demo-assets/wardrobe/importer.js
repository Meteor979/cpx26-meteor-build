const STORAGE_KEY = "wearwise.demo.wardrobe.v1";
const SLOTS = new Set(["top", "bottom", "shoes", "outerwear"]);

function validateGarment(item, seenIds) {
  const required = [
    "id",
    "name",
    "slot",
    "category",
    "colors",
    "formality_score",
    "asset_path",
    "thumbnail_path"
  ];

  for (const key of required) {
    if (item[key] === undefined || item[key] === null || item[key] === "") {
      throw new Error(`Garment ${item.id ?? "<unknown>"} is missing ${key}.`);
    }
  }

  if (seenIds.has(item.id)) {
    throw new Error(`Duplicate garment id: ${item.id}`);
  }
  seenIds.add(item.id);

  if (!SLOTS.has(item.slot)) {
    throw new Error(`Invalid garment slot: ${item.slot}`);
  }
  if (!Number.isInteger(item.formality_score) || item.formality_score < 1 || item.formality_score > 5) {
    throw new Error(`Invalid formality score for ${item.id}.`);
  }
  if (item.warmth_score !== null) {
    throw new Error(`Warmth scoring is pending for ${item.id}; expected null.`);
  }
}

export async function loadDemoWardrobe(manifestUrl = "./manifest.json") {
  const response = await fetch(manifestUrl);
  if (!response.ok) {
    throw new Error(`Unable to load wardrobe manifest: HTTP ${response.status}`);
  }

  const manifest = await response.json();
  if (!Array.isArray(manifest.garments) || manifest.garments.length === 0) {
    throw new Error("Wardrobe manifest contains no garments.");
  }

  const seenIds = new Set();
  const manifestUrlObject = new URL(manifestUrl, window.location.href);
  const garments = manifest.garments.map((item) => {
    validateGarment(item, seenIds);
    return {
      ...item,
      asset_url: new URL(item.asset_path, manifestUrlObject).href,
      thumbnail_url: new URL(item.thumbnail_path, manifestUrlObject).href
    };
  });

  return { ...manifest, garments };
}

export function groupGarmentsBySlot(garments) {
  return garments.reduce(
    (groups, garment) => {
      groups[garment.slot].push(garment);
      return groups;
    },
    { top: [], bottom: [], shoes: [], outerwear: [] }
  );
}

export function storeDemoWardrobe(wardrobe) {
  localStorage.setItem(
    STORAGE_KEY,
    JSON.stringify({
      stored_at: new Date().toISOString(),
      manifest: wardrobe
    })
  );
}

export function clearStoredDemoWardrobe() {
  localStorage.removeItem(STORAGE_KEY);
}

export function getStoredDemoWardrobe() {
  const value = localStorage.getItem(STORAGE_KEY);
  return value ? JSON.parse(value) : null;
}
