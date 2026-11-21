# iOS Client Development Blueprint

Owner: iOS development, testing, and release owner.

Formal implementation has not started. The complete product and engineering
requirements are in
[docs/eng-development-requirements.md](../../docs/eng-development-requirements.md).

## Required architecture

```text
SwiftUI View
→ AssistantCoordinator
→ VoiceSession
→ SFSpeechRecognizer + AVAudioEngine
→ AVSpeechSynthesizer
→ DeterministicDressingPlanner
→ RecommendationService
```

The app must not depend on tapping cards or business buttons. The primary flow is
continuous foreground speech recognition, with automatic listening resume after
each assistant response.

## Required permissions

The app needs a one-time system request for:

- Microphone.
- Speech recognition.

`Info.plist` must include both concise usage descriptions. Native recognition
must use on-device processing. Do not silently fall back to cloud recognition.

## Required directories

After the requirements commit is merged, create:

```text
apps/ios/
├── project.yml
├── WearWise/
│   ├── WearWiseApp.swift
│   ├── ContentView.swift
│   ├── AssistantCoordinator.swift
│   ├── VoiceSession.swift
│   ├── CuePlayer.swift
│   ├── WearWiseModels.swift
│   └── Info.plist
└── README.md
```

Only the iOS owner modifies the generated `WearWise.xcodeproj`.

## First executable milestone

On a physical iPhone:

```text
App opens
→ permission requested once
→ assistant says “说开始”
→ listening cue plays
→ user says “开始”
→ app asks for the occasion
```

This milestone is not complete until the following cycle works reliably:

```text
assistant finishes speaking
→ recognition starts again automatically
→ the assistant does not recognize its own voice
→ user speech produces exactly one state transition
```

## Build commands

Once `project.yml` exists on the development branch:

```bash
cd apps/ios
xcodegen generate
xcodebuild \
  -project WearWise.xcodeproj \
  -scheme WearWise \
  -sdk iphonesimulator \
  -destination "platform=iOS Simulator,name=iPhone 17" \
  CODE_SIGNING_ALLOWED=NO \
  build
```

Simulator audio does not replace physical-device microphone testing.

## Required acceptance flow

```text
开始
第一次去女朋友家吃饭
确认
自然
A
换鞋
开始穿衣
左
右
完成
完成
完成
完成
重新开始
```

Do not commit recordings, private photos, API keys, generated build output, or
credentials.
