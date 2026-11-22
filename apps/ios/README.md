# WearWise iOS Foundation

This branch contains the first graphical, photo-first WearWise milestone. Full
product requirements are in
[docs/eng-development-requirements.md](../../docs/eng-development-requirements.md).

## Product target

The app targets people with color vision deficiency and low vision. Users can
photograph garments, manage a local photo wardrobe, and later view three outfits
made from their own clothing images.

Total blindness is out of scope. VoiceOver and optional voice narration remain
supported, but the primary flow uses visible graphical controls. Microphone
permission is not requested in this milestone.

## Included in this milestone

- Black-and-white, Dynamic Type-aware home screen.
- Large icon-and-text actions with a minimum 56 pt tap height.
- Photo wardrobe grouped by garment slot.
- Existing garments can be reopened to correct their slot, name, color, and tags.
- Camera capture and photo-library import.
- Local image compression, thumbnail generation, and JSON metadata persistence.
- Default two-column photo grid and a single-column layout at larger text sizes.
- Fixed-aspect photo cards and a named placeholder when a local image is missing.
- Free-text occasion input with four local presets.
- Backend presets and occasion resolution with local cache/fallback.
- Three local photo outfit cards with outfit detail and source labels.
- Same-slot replacement with local fallback.
- Saved-plan persistence and a recent-plan card on the home screen.

## Architecture

```text
SwiftUI View
→ GarmentStore (@MainActor)
    → Local Photo Files
    → garments.json
→ Image Processor
```

Views do not call remote services or parse API JSON. The first milestone has no
network dependency; the occasion layer is isolated behind API and service
protocols. Photos are never sent to the backend.

## API configuration

The default API address is:

```text
http://127.0.0.1:8000
```

For a physical device, set this environment variable in the Xcode scheme:

```text
WEARWISE_API_BASE_URL=http://<Mac-LAN-IP>:8000
```

The bundled `NSAppTransportSecurity` exception only enables local network
development. Do not use it for a public backend.

## Photo storage

Store locally:

```text
garment_id
local_photo_path
thumbnail_path
captured_at
name
slot
category
colors
pattern
fit
material
formality_score
warmth_score
user_confirmed
source
```

Photos and thumbnails are stored in Application Support under
`WearWiseGarments`; metadata is saved in `garments.json`. No photo is written to
the repository, sent to a backend, or included in logs.

Deleting or resetting the Simulator app removes its local wardrobe.

## Open and run

The shared Xcode project is committed:

```bash
cd apps/ios
open WearWise.xcodeproj
```

Choose the shared `WearWise` scheme and run on an iOS 17 or newer Simulator.
The Simulator has no camera; use **从相册选择** to test the local photo flow.

`project.yml` remains the source of truth for regeneration. If XcodeGen is
installed, run `xcodegen generate` after changing that file.

Run the persistence and missing-photo tests:

```bash
xcodebuild test \
  -project WearWise.xcodeproj \
  -scheme WearWise \
  -destination "platform=iOS Simulator,name=iPhone 17" \
  CODE_SIGNING_ALLOWED=NO
```

The first milestone also requires screenshots at the default text size and at
200% Dynamic Type.

The occasion/recommendation suite also covers empty input, local matches,
snake-case decoding, network fallback, 422 responses, 304 cache reuse, UUID
mapping, reduced result counts, replacement, and saved-plan reload.

## AI request states

The client calls only `WEARWISE_API_BASE_URL`; AI provider credentials remain on
the backend. Endpoint timeouts are 5 seconds for presets, 15 for occasion
resolution, 20 for recommendations, 15 for revisions, and 8 for current weather
when that endpoint is available. A recommendation timeout preserves existing
results and offers retry or local rules. Source labels distinguish AI results,
local rules, cached results, fallback results, and manual adjustments.

## AI-backed request states

The app calls only `WEARWISE_API_BASE_URL`; model credentials remain on the
backend. Request timeouts are endpoint-specific: 5 seconds for presets, 15 for
occasion resolution, 20 for recommendations, 15 for revisions, and 8 for
current weather when that endpoint is available. A recommendation timeout keeps
existing results visible and offers retry or local rules. Source labels are
derived from backend provider/source/fallback values and manual local changes.

## Acceptance flow

```text
App opens in black-and-white high-contrast UI
→ “我的衣柜” button is visible with icon and label
→ add a garment photo from camera or photo library
→ save the local photo record
→ garment thumbnail appears in the wardrobe
→ restart the app and confirm the photo and metadata remain
```

Do not commit private photos, recordings, API keys, generated build output, or
credentials.
