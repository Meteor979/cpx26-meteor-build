# Interface Contract

`openapi.yaml` is the single source of truth for requests and responses. Both iOS and backend owners must agree before changing shared fields.

The initial contract should define:

- `GET /health`
- `POST /v1/recommendations`
- Occasion, weather, formality, and structured garment inputs.
- Outfit, item ID, explanation, source, fallback, and warning outputs.

