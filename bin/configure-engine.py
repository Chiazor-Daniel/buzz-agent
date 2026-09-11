#!/usr/bin/env python3
"""Point the engine's nvidia provider at the local proxy and set the buzz theme.

Cross-platform: called by setup.sh (Linux/macOS/WSL) and setup.ps1 (Windows).
Only stdlib, so it runs under any Python 3.
"""
import json
import pathlib

HOME = pathlib.Path.home()
MODELS = HOME / ".pi" / "agent" / "models.json"
SETTINGS = HOME / ".pi" / "agent" / "settings.json"


def patch_models():
    if not MODELS.exists():
        print(
            "Note: ~/.pi/agent/models.json not found yet. It is created on first "
            "run of 'buzz' — run setup again once if the proxy URL is not set."
        )
        return
    data = json.loads(MODELS.read_text())
    providers = data.setdefault("providers", {})
    nvidia = providers.setdefault("nvidia", {})
    nvidia["api"] = "openai-completions"
    nvidia["apiKey"] = "not-used"
    nvidia["baseUrl"] = "http://127.0.0.1:8888/v1"
    MODELS.write_text(json.dumps(data, indent=2, ensure_ascii=False) + "\n")
    print("nvidia provider -> 127.0.0.1:8888 (proxy).")


def patch_settings():
    if not SETTINGS.exists():
        print("Note: settings.json not found yet. On first run, type: /theme buzz")
        return
    data = json.loads(SETTINGS.read_text())
    if data.get("theme") != "buzz":
        data["theme"] = "buzz"
        SETTINGS.write_text(json.dumps(data, indent=2, ensure_ascii=False) + "\n")
        print("Default theme set to buzz.")
    else:
        print("Default theme already set to buzz.")


def main():
    patch_models()
    patch_settings()


if __name__ == "__main__":
    main()