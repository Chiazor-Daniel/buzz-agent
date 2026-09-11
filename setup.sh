#!/usr/bin/env bash
# One-shot setup for the buzz agent on any Linux box.
# Install: git clone .../buzz-agent && cd buzz-agent && ./setup.sh
set -euo pipefail

GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; NC='\033[0m'

# Already root (containers, some VPS)? Skip sudo entirely.
if [ "$(id -u)" -eq 0 ]; then SUDO=""; else SUDO="sudo"; fi

echo -e "${GREEN}==> buzz agent setup${NC}"

# 1. Node.js 22.19+ (required by the engine; Ubuntu's apt ships 18, which is too old)
need_node() {
  node -e "const p=process.versions.node.split('.').map(Number); process.exit(p[0]>22||(p[0]===22&&p[1]>=19)?0:1)" 2>/dev/null
}
if ! command -v node >/dev/null 2>&1 || ! need_node; then
  echo -e "${YELLOW}Installing Node.js 22...${NC}"
  if command -v apt-get >/dev/null 2>&1; then
    command -v curl >/dev/null 2>&1 || $SUDO apt-get install -y curl
    curl -fsSL https://deb.nodesource.com/setup_22.x | $SUDO bash - >/dev/null 2>&1
    $SUDO apt-get install -y nodejs
  elif command -v dnf >/dev/null 2>&1; then
    $SUDO dnf install -y nodejs npm
    if ! need_node; then
      command -v curl >/dev/null 2>&1 || $SUDO dnf install -y curl
      curl -fsSL https://rpm.nodesource.com/setup_22.x | $SUDO bash - >/dev/null 2>&1
      $SUDO dnf install -y nodejs
    fi
  else
    echo "Install Node.js 22+ from https://nodejs.org then re-run this script."
    exit 1
  fi
  need_node || { echo "${RED}Node.js is still too old — install Node 22+ from https://nodejs.org and re-run.${NC}"; exit 1; }
fi

# 2. pi (the coding agent runtime)
if ! command -v pi >/dev/null 2>&1; then
  echo -e "${YELLOW}Installing the code agent engine...${NC}"
  if ! npm install -g @earendil-works/pi-coding-agent --no-audit --no-fund --no-progress >/dev/null 2>"$HOME/.buzz-engine-install.log"; then
    echo "${RED}Engine install failed. See $HOME/.buzz-engine-install.log${NC}"
    exit 1
  fi
else
  echo "Code agent engine already installed."
fi

# 2b. Apply buzz branding so every user-facing name is "buzz"
#     (update prompt now says 'buzz update', window title, changelog, etc.)
PI_PKG="$(npm root -g)/@earendil-works/pi-coding-agent/package.json"
if [ -f "$PI_PKG" ]; then
  python3 - "$PI_PKG" <<'PYEOF'
import json, sys
path = sys.argv[1]
with open(path) as f:
    data = json.load(f)
cfg = data.setdefault("piConfig", {})
if cfg.get("name") != "buzz":
    cfg["name"] = "buzz"
    with open(path, "w") as f:
        json.dump(data, f, indent=2, ensure_ascii=False)
    print("Buzz branding applied to the engine.")
else:
    print("Buzz branding already applied.")
PYEOF
else
  echo -e "${YELLOW}Warning: could not find the engine's package.json for branding.${NC}"
fi

# 2c. Scrub the last visible "pi" mentions from the engine's built-in help
#     ("buzz update [source|self|pi]  Update pi, extensions, ..." -> engine/buzz)
ENGINE_DIST="$(npm root -g)/@earendil-works/pi-coding-agent/dist"
if [ -d "$ENGINE_DIST" ]; then
  python3 - "$ENGINE_DIST" <<'PYEOF'
import sys, pathlib
root = pathlib.Path(sys.argv[1])
rep = {
    "Update pi, extensions, or model catalogs": "Update the engine, extensions, or model catalogs",
    "Update pi, installed packages, or model catalogs.": "Update the engine, installed packages, or model catalogs.",
    "Update pi only": "Update the agent only",
    "update pi only": "update the agent only",
    "Update pi and installed packages": "Update the agent and installed packages",
    "Update pi and all extensions": "Update the agent and all extensions",
    "self works as alias to pi": "self works as alias to the agent",
    "[source|self|pi]": "[source|self|engine]",
}
targets = list((root / "cli").glob("*.js")) + list((root / "bundle").glob("**/*.js")) + list(root.glob("package-manager-cli.js"))
seen = set()
for f in targets:
    if f in seen or not f.is_file():
        continue
    seen.add(f)
    s = f.read_text()
    orig = s
    for a, b in rep.items():
        s = s.replace(a, b)
    if s != orig:
        f.write_text(s)
        print(f"  help text branded in {f.relative_to(root)}")
PYEOF
fi

# 3. Python (needed by the proxy)
if ! command -v python3 >/dev/null 2>&1; then
  echo "Install python3, then re-run this script."
  exit 1
fi

# 4. Copy scripts into ~/bin
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
mkdir -p "$HOME/bin"
for f in buzz buzz-code buzz-chat lib-pi; do
  cp "$SCRIPT_DIR/bin/$f" "$HOME/bin/$f"
  chmod +x "$HOME/bin/$f"
done
mkdir -p "$HOME/bin/nvidia-proxy"
cp "$SCRIPT_DIR/bin/nvidia-proxy"/* "$HOME/bin/nvidia-proxy/"
echo -e "${GREEN}==> Scripts installed to ~/bin${NC}"

# 5. NVIDIA API key
KEY_FILE="$HOME/.config/nvidia/api.key"
if [ ! -f "$KEY_FILE" ]; then
  echo -e "${YELLOW}NVIDIA API key not found.${NC}"
  echo "1. Get a FREE key at: https://build.nvidia.com"
  echo "   (pick any model -> 'Get API Key' -> copy the nvapi-... value)"
  read -r -p "2. Paste your key: " KEY
  [ -n "$KEY" ] || { echo "No key entered. Aborting (re-run when ready)."; exit 1; }
  mkdir -p "$HOME/.config/nvidia"
  printf '%s\n' "$KEY" > "$KEY_FILE"
  chmod 600 "$KEY_FILE"
  echo "Key saved to $KEY_FILE (mode 600)."
else
  echo "Key already present at $KEY_FILE."
fi

# 6. Point pi's nvidia provider at the local key-hiding proxy
#    The proxy loads the key from ~/.config/nvidia/api.key, so the agent never
#    needs the key itself ("apiKey: not-used") — no key in env, config, or shell.
PI_MODELS="$HOME/.pi/agent/models.json"
if [ -f "$PI_MODELS" ]; then
  python3 - "$PI_MODELS" <<'PYEOF'
import json, sys, time
path = sys.argv[1]
with open(path) as f:
    data = json.load(f)
providers = data.setdefault("providers", {})
providers.setdefault("nvidia", {})
providers["nvidia"]["api"] = "openai-completions"
providers["nvidia"]["apiKey"] = "not-used"
providers["nvidia"]["baseUrl"] = "http://127.0.0.1:8888/v1"
with open(path, "w") as f:
    json.dump(data, f, indent=2, ensure_ascii=False)
print("nvidia provider -> 127.0.0.1:8888 (proxy).")
PYEOF
else
  echo -e "${YELLOW}Note: ~/.pi/agent/models.json not found yet. It will be created when you first run 'buzz' — if the proxy URL isn't set then, run setup.sh again once.${NC}"
fi

# 7. Buzz theme (honey/amber TUI + HTML export look) as the default theme
THEMES_DIR="$HOME/.pi/agent/themes"
mkdir -p "$THEMES_DIR"
cp "$SCRIPT_DIR/theme/buzz.json" "$THEMES_DIR/buzz.json"
echo -e "${GREEN}==> Installed buzz theme${NC}"

PI_SETTINGS="$HOME/.pi/agent/settings.json"
if [ -f "$PI_SETTINGS" ]; then
  python3 - "$PI_SETTINGS" <<'PYEOF'
import json, sys
path = sys.argv[1]
with open(path) as f:
    data = json.load(f)
if data.get("theme") != "buzz":
    data["theme"] = "buzz"
    with open(path, "w") as f:
        json.dump(data, f, indent=2)
    print("Default theme set to buzz.")
PYEOF
else
  echo -e "${YELLOW}Note: settings.json not found yet. On first run, type: /theme buzz${NC}"
fi

echo -e "${GREEN}==> Done! Reopen your terminal (or 'source ~/.profile').${NC}"
echo
echo "Try it:"
echo "  buzz \"write a one-line hello world\""
echo "  buzz-code \"review this project for bugs\""
echo "  buzz-chat \"what is a TLS handshake?\""
echo
echo -e "${YELLOW}How it works: your key lives only in ~/.config/nvidia/api.key.${NC}"
echo "The proxy on :8888 reads it and forwards to NVIDIA's free cloud."
echo "buzz talks to the proxy and never sees the key."
echo
echo "Optional persistent proxy:"
echo "  systemctl --user enable --now $(pwd)/nvidia-proxy.service"