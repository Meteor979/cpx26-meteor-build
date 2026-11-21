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
- Camera capture and photo-library import.
- Local image compression, thumbnail generation, and JSON metadata persistence.
- Default two-column photo grid and a single-column layout at larger text sizes.
- Fixed-aspect photo cards and a named placeholder when a local image is missing.
- An explicit next-step state for occasion recommendations.

## Architecture

```text
SwiftUI View
→ GarmentStore (@MainActor)
    → Local Photo Files
    → garments.json
→ Image Processor
```

Views do not call remote services or parse API JSON. The first milestone has no
network dependency and does not send photos anywhere.

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

## Generate and run

On macOS with Xcode and XcodeGen:

```bash
cd apps/ios
xcodegen generate
open WearWise.xcodeproj
```

Choose the shared `WearWise` scheme and run on an iOS 17 or newer Simulator.
The Simulator has no camera; use **从相册选择** to test the local photo flow.

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
