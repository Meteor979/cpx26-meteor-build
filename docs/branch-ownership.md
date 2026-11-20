# Repository Branch Ownership

The canonical rules are in the root [CONTRIBUTING.md](../CONTRIBUTING.md).

| Branch | Owner | Scope |
|---|---|---|
| `main` | iOS development and testing owner | Tested, demo-ready releases only |
| `dev` | iOS development and testing owner | Daily integration |
| `feat/ios-*` | iOS development and testing owner | SwiftUI client, Xcode project, Simulator testing |
| `feat/api-*` | Windows backend owner | FastAPI, recommendation rules, AI provider, tests |
| `docs/product-*` | Product and user research owner | Research, scope, demo script, submission copy |
| `docs/eng-*` | iOS/backend integration coordinator | Engineering workflow and integration documentation |
| `design/*` | Visual and communication owner | UI, poster, AMD proof, expo materials |

Every feature branch starts from `dev`. The iOS owner validates the integrated build before promoting `dev` to `main`.

