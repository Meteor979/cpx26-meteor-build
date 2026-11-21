# CrossPointX 2026 Team Repository

This repository contains the team's CrossPointX 2026 requirements, interface
contract, engineering rules, design materials, and future iOS/backend structure.

The current concept is WearWise, an accessibility-first outfit system for blind
and low-vision users. It recommends three explainable outfits from clothing the
user already owns, describes their aesthetic and social tone with audio, and
provides a repeatable sound-guided dressing sequence.

The primary interaction is a continuous foreground voice loop. After the
one-time operating-system microphone permission, the user can complete the core
flow with short commands such as "开始", "确认", "A", and "完成" without finding
or tapping interface controls. The iOS visual state is intentionally minimal and
follows Apple's clarity, deference, and depth principles.

The original occasion search, weather context, wardrobe capture, garment
recognition, product matching, outfit replacement, fallback, and public web demo
remain in scope. Location and image recognition are optional to the core audio
experience. See
[docs/product/accessible-wearwise-pivot.md](docs/product/accessible-wearwise-pivot.md).

## Development status

The requirements baseline is frozen. Formal product implementation has not yet
started. Any local prototype is exploratory and is not an accepted completion
until it follows the repository contract, is committed, and has runtime evidence.

Every developer and AI agent must read:

1. [CONTRIBUTING.md](CONTRIBUTING.md)
2. [Detailed development requirements](docs/eng-development-requirements.md)
3. [Accessibility product direction](docs/product/accessible-wearwise-pivot.md)
4. [Frontend/backend integration workflow](docs/frontend-backend-integration.md)
5. [Build status](docs/build-status.md)
6. [OpenAPI contract](specs/openapi.yaml)
7. [Shared sample data](specs/examples/sample-data.json)
8. [Page flow](design/page-flow.md)

## Repository structure

```text
apps/ios/          SwiftUI client and Xcode project
services/api/      FastAPI backend and recommendation logic
specs/             OpenAPI contract and request/response examples
design/            UI, poster, AMD proof assets, and source assets
docs/              Product, research, branch ownership, and compliance notes
.github/workflows/ GitHub Actions build and test workflows
```

## Branch model

- `main`: submission-ready versions that can build and run.
- `dev`: daily integration branch.
- `feat/*`: one focused feature per branch.
- `feat/web-*`: public interactive web demo.
- `docs/product-*`: product and user research documentation.
- `docs/eng-*`: engineering workflow and integration documentation.
- `design/*`: visual, poster, and submission assets.

The iOS development and testing owner is the only person who modifies `WearWise.xcodeproj`. The Windows backend owner does not modify iOS project files. Interface changes must be reflected in `specs/openapi.yaml`.

## Local development

Project code will be created during the event. Until then, this repository contains planning and compliance files only.

The backend owner should start with
[docs/backend-execution-guide.md](docs/backend-execution-guide.md), which defines
the first runnable milestone, task order, Mock policy, and acceptance evidence.

Both developers should follow
[docs/frontend-backend-integration.md](docs/frontend-backend-integration.md) to
keep the iOS client and backend on the same contract and integration schedule.
Track ownership, commits, tests, and integration status in
[docs/build-status.md](docs/build-status.md).

1. Copy `.env.example` to `.env` for local backend configuration.
2. Never commit `.env`, API keys, certificates, personal photos, or temporary build output.
3. Keep API keys on the backend only.
4. Keep garment originals on the iOS device. A temporary compressed image may be sent for explicit image analysis or appearance matching and must not be retained.
5. Use mock mode before a remote AI provider is configured.

## Required submission materials

- Public repository with the Apache License 2.0.
- Reachable demo or prototype link.
- Project description and all four team members.
- Poster PDF and Devpost project image.
- Raw, unedited AMD-generated image.
- AMD Creative Factory Gallery screenshot.
- Disclosure of frameworks, open-source libraries, AI tools, and third-party APIs.

The submission deadline is November 22, 2026 at 13:00 Beijing time.

