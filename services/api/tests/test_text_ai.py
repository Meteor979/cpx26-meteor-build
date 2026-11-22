from app.services.text_ai import chat_completions_endpoint


def test_base_url_without_version_gets_v1_chat_path() -> None:
    assert (
        chat_completions_endpoint("https://aihubmix.com")
        == "https://aihubmix.com/v1/chat/completions"
    )


def test_base_url_with_v1_does_not_duplicate_version() -> None:
    assert (
        chat_completions_endpoint("https://aihubmix.com/v1")
        == "https://aihubmix.com/v1/chat/completions"
    )


def test_full_chat_completions_url_is_preserved() -> None:
    url = "https://example.com/v1/chat/completions"
    assert chat_completions_endpoint(url) == url
