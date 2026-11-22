import ast
from pathlib import Path


def test_weather_code_parses_as_python_39() -> None:
    root = Path(__file__).resolve().parents[1] / "app"
    for source_file in root.rglob("*.py"):
        ast.parse(
            source_file.read_text(encoding="utf-8"),
            filename=str(source_file),
            feature_version=(3, 9),
        )
