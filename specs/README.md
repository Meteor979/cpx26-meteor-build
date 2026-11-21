# Interface Contract

`openapi.yaml` is the single source of truth for requests and responses. Both iOS and backend owners must agree before changing shared fields.

Current draft endpoints:

- `GET /health`: backend and provider health.
- `GET /v1/presets`: cached occasion suggestions and reusable policies.
- `POST /v1/occasions/resolve`: resolve a free-text occasion query into an editable strategy.
- `POST /v1/weather/current`: get structured local weather from coarse coordinates.
- `POST /v1/garments/analyze`: editable attributes recognized from a garment photo.
- `POST /v1/garments/match`: product candidates derived from label text, appearance features, or an optional appearance thumbnail.
- `POST /v1/recommendations`: up to three explainable outfits built from confirmed garments.
- `POST /v1/outfits/revise`: replace one garment while retaining the other locked items.

Shared rules:

- The client stores garment photos locally. Only a temporary compressed image is sent for analysis.
- AI analysis returns a draft. A user-confirmed `RecommendationGarment` is required before recommendation.
- Product matching returns candidates and source metadata. It does not verify authenticity.
- External AI and search providers are replaceable.
- Recommendation must return rule-based fallback data when remote AI fails.
- Recommendation DTOs never contain device-local photo paths.
- `formality_band` is derived on the backend: 1-2 casual, 3 smart casual, 4 business, 5 formal.
- Recommendation cache keys are computed by the client.
- The homepage starts with a free-text occasion search, not a mandatory preset picker.
- Client-side preset and alias matching runs before any remote occasion-resolution call.
- Automatic weather is optional and must never block the core audio flow.
- Coarse location is requested only when the user enables automatic weather.
- Weather is an automatic structured context rather than a primary visual card.
- Weather failures use a cache no older than 60 minutes, then bundled demo weather or a manual city path.
- The target users are people with color vision deficiency and low vision; total
  blindness is out of scope because users must be able to photograph garments.
- The primary flow uses large black-and-white controls with labels and icons.
- Color must never be the only signal for selected, disabled, warning, or error states.
- Users build a local photo wardrobe before requesting recommendations.
- Each recommendation must be rendered with the user's local garment photos by
  mapping response item IDs to local wardrobe records.
- Recommendation requests never contain local photo paths.
- Voice guidance is optional and must never block the graphical primary flow.
- Deterministic local rules generate dressing order; remote AI may explain but must not control safety-critical steps.

Shared sample fixtures are in [examples/sample-data.json](examples/sample-data.json). Both clients and the backend should use these fixtures before connecting a real provider.

