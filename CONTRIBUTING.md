# Contribution Rules

## Branch ownership

- `feat/ios-*`: iOS development and testing owner.
- `feat/api-*`: Windows backend owner.
- `docs/*`: product and user research owner.
- `design/*`: visual and communication owner.

Create feature branches from `dev`. Merge completed features into `dev`. The iOS owner promotes a tested integration version from `dev` to `main`.

## Before merging

1. Run the relevant local tests.
2. Confirm no secret or personal data is staged.
3. Keep interface changes synchronized with `specs/openapi.yaml`.
4. Include a short description of the change, test result, and remaining risk.

## File ownership

- Only the iOS owner modifies `apps/ios/WearWise.xcodeproj`.
- Only the backend owner modifies `services/api` and `specs`.
- Product owners modify `docs`.
- Visual owners modify `design`.

## Feature freeze

After 09:00 on November 22, 2026, only changes that fix a build, demo, or submission blocker are allowed.

