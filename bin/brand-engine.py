#!/usr/bin/env python3
"""Apply buzz branding + help-text scrub to the installed engine.

Cross-platform: called by setup.sh (Linux/macOS/WSL) and setup.ps1 (Windows)
so the installer logic lives in exactly one place.
"""
import json
import os
import pathlib
import subprocess

REPLACEMENTS = {
    "Update pi, extensions, or model catalogs": "Update the engine, extensions, or model catalogs",
    "Update pi, installed packages, or model catalogs.": "Update the engine, installed packages, or model catalogs.",
    "Update pi only": "Update the agent only",
    "update pi only": "update the agent only",
    "Update pi and installed packages": "Update the agent and installed packages",
    "Update pi and all extensions": "Update the agent and all extensions",
    "self works as alias to pi": "self works as alias to the agent",
    "[source|self|pi]": "[source|self|engine]",
}

NPM = "npm.cmd" if os.name == "nt" else "npm"


def engine_root():
    out = subprocess.run(
        [NPM, "root", "-g"], capture_output=True, text=True
    )
    root = pathlib.Path(out.stdout.strip() or ".")
    return root / "@earendil-works/pi-coding-agent"


def brand_package(engine: pathlib.Path):
    pkg_path = engine / "package.json"
    if not pkg_path.exists():
        print("Warning: engine package.json not found — skipping branding.")
        return
    data = json.loads(pkg_path.read_text())
    cfg = data.setdefault("piConfig", {})
    if cfg.get("name") != "buzz":
        cfg["name"] = "buzz"
        pkg_path.write_text(json.dumps(data, indent=2, ensure_ascii=False) + "\n")
        print("Buzz branding applied to the engine.")
    else:
        print("Buzz branding already applied.")


def scrub_help(engine: pathlib.Path):
    dist = engine / "dist"
    if not dist.is_dir():
        print("Warning: engine dist not found — skipping help-text scrub.")
        return
    targets = list((dist / "cli").glob("*.js"))
    targets += list((dist / "bundle").glob("**/*.js"))
    targets += [dist / "package-manager-cli.js"]
    seen = set()
    for f in targets:
        if f in seen or not f.is_file():
            continue
        seen.add(f)
        s = f.read_text()
        orig = s
        for a, b in REPLACEMENTS.items():
            s = s.replace(a, b)
        if s != orig:
            f.write_text(s)
            print(f"  help text branded in {f.relative_to(dist)}")


def main():
    engine = engine_root()
    brand_package(engine)
    scrub_help(engine)


if __name__ == "__main__":
    main()