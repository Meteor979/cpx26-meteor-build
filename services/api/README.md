# Backend Service

Owner: Windows backend developer.

This directory will contain the FastAPI service, deterministic recommendation rules, replaceable AI provider, tests, and deployment configuration.

The service must support:

- `AI_PROVIDER=mock`
- `AI_PROVIDER=remote_api`
- `AI_PROVIDER=fallback`

The backend must not edit the Xcode project. API keys belong in environment variables only.

