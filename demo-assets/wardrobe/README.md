# WearWise Demo Wardrobe

This directory is a self-contained demo wardrobe for the public web prototype
and future one-click iOS demo import.

## Contents

```text
tops/            4 top garments
bottoms/         9 trousers, jeans and alternative bottoms
shoes/           10 pairs of shoes
outerwear/       5 jackets, overshirts and coats
thumbnails/      360 px previews for every asset
contact-sheets/  Category review sheets
manifest.json    IDs, classification, formality and asset paths
```

All full images are resized to at most 720 px on the longest side. The original
files are not copied into the repository.

## Formality scale

```text
1  casual, very relaxed
2  casual
3  smart casual
4  business
5  formal
```

The mapping is a demo classification based on visible garment construction. It
is not a universal fashion rule and may be edited in `manifest.json`.

## Warmth scoring

The weather module has not been integrated. Every entry therefore has:

```json
"warmth_score": null
```

Do not assign a fake warmth score. A later weather task must add a documented
warmth mapping and update the importer before weather-aware recommendations are
enabled.

## Image rights

The images were supplied by the WearWise team from `D:/CPX`. The original source
URLs and licenses were not included. Before the repository is made public,
confirm that the team has permission to redistribute every image. If a source
cannot be confirmed, replace that image before publishing.

## Web import

The web demo can load `manifest.json`, group entries by `slot`, and render
`thumbnail_path` or `asset_path`. No server is required.

Suggested import sequence:

```text
fetch manifest.json
→ validate unique IDs
→ group garments by slot
→ map recommendations by item ID
→ render only paths that exist
→ show a named placeholder if an image is missing
```

For a working local preview:

```bash
cd /path/to/cpx26-meteor-build
python3 -m http.server 4173
open http://127.0.0.1:4173/demo-assets/wardrobe/preview.html
```

`preview.html` validates the manifest, groups all 28 garments by category, and
provides a one-click “Import demo wardrobe” action that stores the manifest in
browser-local storage.

The reusable browser helper is `importer.js`.

```js
import {
  loadDemoWardrobe,
  groupGarmentsBySlot,
  storeDemoWardrobe
} from "./importer.js";

const wardrobe = await loadDemoWardrobe();
const grouped = groupGarmentsBySlot(wardrobe.garments);
storeDemoWardrobe(wardrobe);
```

## iOS one-click import

The current iOS wardrobe API expects an integer `warmthScore`, while this
manifest intentionally stores `null`. Full one-click import into the current
iOS app must therefore wait for a small importer/model update:

```text
warmthScore: Int?
warmthScoringStatus: "pending"
```

Once that migration is added, the importer should:

1. Copy full images and thumbnails into Application Support.
2. Generate stable UUIDs.
3. Preserve the manifest formality score.
4. Preserve `warmth_score=null`.
5. Save all entries through `GarmentStore`.
6. Skip duplicate IDs on repeated imports.

Do not assign `warmthScore=3` merely to satisfy the old model; that would make
the UI and recommendations claim a score that was never reviewed.

## Recommended demo outfits

The manifest intentionally provides enough combinations for three photo cards:

```text
relaxed:   graphic tee + light-wash jeans + platform sneakers + denim jacket
balanced:  navy polo + cream linen trousers + orange loafers + rust overshirt
polished:  white tee + navy plaid trousers + brown boots + belted trench
```

These are starter suggestions only and should be expressed as deterministic
local-demo results.
