import json
import os
from typing import Any, Dict, Optional, Protocol

import httpx


class TextAIProviderError(Exception):
    """Raised when a remote text provider cannot produce valid JSON."""


class TextAIProvider(Protocol):
    @property
    def name(self) -> str:
        ...

    def complete_json(
        self,
        system_prompt: str,
        payload: Dict[str, Any],
        request_id: str,
    ) -> Dict[str, Any]:
        ...


class RemoteTextAIProvider:
    def __init__(
        self,
        api_key: Optional[str],
        base_url: Optional[str],
        model: Optional[str],
        timeout_seconds: float,
    ) -> None:
        self._api_key = api_key
        self._base_url = base_url
        self._model = model
        self._timeout_seconds = timeout_seconds

    @property
    def name(self) -> str:
        return self._model or "remote_text_ai"

    def complete_json(
        self,
        system_prompt: str,
        payload: Dict[str, Any],
        request_id: str,
    ) -> Dict[str, Any]:
        if not self._api_key or not self._base_url or not self._model:
            raise TextAIProviderError(
                "Remote text AI is selected but its configuration is incomplete."
            )

        endpoint = self._base_url.rstrip("/")
        if not endpoint.endswith("/chat/completions"):
            endpoint = endpoint + "/v1/chat/completions"

        request_body = {
            "model": self._model,
            "temperature": 0.2,
            "max_tokens": 1200,
            "messages": [
                {"role": "system", "content": system_prompt},
                {
                    "role": "user",
                    "content": json.dumps(
                        payload,
                        ensure_ascii=False,
                    ),
                },
            ],
        }

        try:
            with httpx.Client(timeout=self._timeout_seconds) as client:
                response = client.post(
                    endpoint,
                    headers={
                        "Authorization": "Bearer %s" % self._api_key,
                        "Content-Type": "application/json",
                        "X-Request-ID": request_id,
                    },
                    json=request_body,
                )
                response.raise_for_status()
                body = response.json()
        except (httpx.HTTPError, ValueError) as error:
            raise TextAIProviderError("Text AI request failed.") from error

        try:
            content = body["choices"][0]["message"]["content"]
        except (KeyError, IndexError, TypeError) as error:
            raise TextAIProviderError("Text AI response shape is invalid.") from error

        if not isinstance(content, str):
            raise TextAIProviderError("Text AI response did not contain text.")

        cleaned = content.strip()
        if cleaned.startswith("```"):
            lines = cleaned.splitlines()
            if lines:
                lines = lines[1:]
            if lines and lines[-1].strip().startswith("```"):
                lines = lines[:-1]
            cleaned = "\n".join(lines).strip()

        try:
            parsed = json.loads(cleaned)
        except json.JSONDecodeError as error:
            raise TextAIProviderError("Text AI did not return valid JSON.") from error

        if not isinstance(parsed, dict):
            raise TextAIProviderError("Text AI JSON root must be an object.")
        return parsed


def get_text_ai_provider() -> Optional[TextAIProvider]:
    mode = os.getenv("TEXT_AI_PROVIDER", "mock").strip().lower()
    if mode != "remote_api":
        return None

    try:
        timeout_seconds = float(os.getenv("AI_TIMEOUT_SECONDS", "20"))
    except ValueError:
        timeout_seconds = 20.0

    return RemoteTextAIProvider(
        api_key=os.getenv("AI_API_KEY"),
        base_url=os.getenv("AI_BASE_URL"),
        model=os.getenv("AI_MODEL"),
        timeout_seconds=timeout_seconds,
    )
