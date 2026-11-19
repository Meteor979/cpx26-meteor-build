# AI and Third-Party Tools Disclosure

The team must keep this file current before submission. List only tools actually used.

| Tool or service | Purpose | Where used | License or account |
|---|---|---|---|
| Codex | AI-assisted planning and code generation | Development, documentation, tests | Pending final disclosure |
| AI provider | Ranking and explanation, if enabled | Backend only | Model, provider, and key source to be confirmed |
| FastAPI | Backend framework | Backend | Open-source dependency |
| SwiftUI | iOS user interface | iOS client | Apple framework |
| AMD Creative Factory Image | Required poster core visual | Poster | Event-provided access |

## Data boundary

- Garment photos remain on the iOS device.
- The backend receives structured garment metadata only.
- API keys remain in server environment variables or local `.env`.
- No user identity, body measurements, or face photos are sent to the AI provider.

## Fallback disclosure

If the live AI provider is unavailable, the client may show deterministic rule-based results or bundled sample responses. The response `source` field must identify `mock`, `remote_api`, or `fallback`.

