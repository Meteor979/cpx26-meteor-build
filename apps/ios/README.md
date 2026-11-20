# iOS Client

Owner: iOS development, testing, and release owner.

This directory will contain the SwiftUI app and `WearWise.xcodeproj` when the event begins.

Rules:

- Only the iOS owner modifies the Xcode project.
- Keep the shared scheme committed.
- Use local sample data before the backend is available.
- Handle mock, remote API, network failure, and fallback states.
- Require coarse while-in-use location at app launch and load weather as structured context.
- Do not show a standalone weather card or offer manual temperature fallback.
- Do not store API keys or personal photos in the repository.

