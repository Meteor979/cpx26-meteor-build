# WearWise iOS Development Blueprint

Owner: iOS development, testing, and release owner.

Formal implementation has not started. Full requirements are in
[docs/eng-development-requirements.md](../../docs/eng-development-requirements.md).

## Product target

The app targets people with color vision deficiency and low vision. Users can
photograph garments, manage a local photo wardrobe, and view three outfits made
from their own clothing images.

Total blindness is out of scope. VoiceOver and optional voice narration remain
supported, but the primary flow uses visible graphical controls.

## Required architecture

```text
SwiftUI View
→ Wardrobe ViewModel
    → Local Photo Store
    → Garment Recognition Service
→ Recommendation ViewModel
    → Photo Collage Mapper
→ Optional Voice Assistant
→ RecommendationService
```

## Required interface behavior

- Black-and-white, high-contrast design.
- Buttons contain both an icon and text and are at least 56 pt high.
- Selection, disabled, warning, and error states use shape, outline, labels, or
  symbols in addition to color.
- The wardrobe displays local garment thumbnails.
- Each recommendation displays the actual garment photos associated with its
  item IDs.
- Missing photos render a labeled placeholder.
- Main content remains usable at 200% Dynamic Type.
- Voice narration is opt-in and cannot cover a control or block the visual flow.

## Photo storage

Store locally:

```text
garment_id
local_photo_path
thumbnail
captured_at
```

Never add these fields to recommendation requests. The client combines response
item IDs with local wardrobe records when rendering a recommendation.

## Required directories

After implementation branches begin:

```text
apps/ios/
├── project.yml
├── WearWise/
│   ├── WearWiseApp.swift
│   ├── ContentView.swift
│   ├── WardrobeView.swift
│   ├── GarmentPhotoStore.swift
│   ├── RecommendationView.swift
│   ├── PhotoCollageView.swift
│   ├── OptionalVoiceAssistant.swift
│   ├── WearWiseModels.swift
│   └── Info.plist
└── README.md
```

## First executable milestone

```text
App opens in black-and-white high-contrast UI
→ “我的衣柜” button is visible with icon and label
→ add a garment photo from camera or photo library
→ save the local photo record
→ garment thumbnail appears in the wardrobe
```

The first milestone also requires a screenshot at the default text size and at a
larger accessibility size.

## Acceptance flow

```text
打开照片衣柜
添加一件上装
保存主图
输入第一次去女朋友家吃饭
选择自然
生成三套搭配
确认三套都显示衣柜照片
打开一套详情
替换鞋
确认保存
```

Do not commit private photos, recordings, API keys, generated build output, or
credentials.
