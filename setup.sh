#!/usr/bin/env bash
# One-shot setup for the buzz agent on Linux, WSL, and macOS.
# Install: git clone .../buzz-agent && cd buzz-agent && ./setup.sh
#
# Everything is installed for you: Node.js 22, Python 3, and the proxy's
# Python packages (in a private venv). The only outside requirement is git.
set -euo pipefail

GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Already root (containers, some VPS)? Skip sudo entirely.
if [ "$(id -u)" -eq 0 ]; then SUDO=""; else SUDO="sudo"; fi

# macOS vs Linux (WSL included) — both get bash scripts; only package
# managers differ.
if [ "$(uname -s)" = "Darwin" ]; then OS="macos"; HOMEBREW_PREFIX="${HOMEBREW_PREFIX:-/opt/homebrew}"; else OS="linux"; fi

echo -e "${GREEN}==> buzz agent setup${NC}"

# 1. Node.js 22.19+ (required by the engine; Ubuntu's apt ships 18, which is too old)
need_node() {
  node -e "const p=process.versions.node.split('.').map(Number); process.exit(p[0]>22||(p[0]===22&&p[1]>=19)?0:1)" 2>/dev/null
}
if ! command -v node >/dev/null 2>&1 || ! need_node; then
  echo -e "${YELLOW}Installing Node.js 22...${NC}"
  if [ "$OS" = "macos" ]; then
    if ! command -v brew >/dev/null 2>&1; then
      echo "Install Homebrew first (https://brew.sh — it needs Xcode Command Line Tools), then re-run this script."
      exit 1
    fi
    brew install node@22 >/dev/null
    # node@22 is keg-only; put it on PATH for the rest of this script.
    export PATH="$HOMEBREW_PREFIX/opt/node@22/bin:$PATH"
  elif command -v apt-get >/dev/null 2>&1; then
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

# 3. Python 3 (needed by the key-hiding proxy) — install it if missing, then
#    create a private venv with the proxy's packages so we never touch the
#    system Python or trip PEP 668 "externally-managed" protections.
if ! command -v python3 >/dev/null 2>&1; then
  echo -e "${YELLOW}Installing Python 3...${NC}"
  if [ "$OS" = "macos" ]; then
    brew install python3 >/dev/null
  elif command -v apt-get >/dev/null 2>&1; then
    $SUDO apt-get update -qq && $SUDO apt-get install -y python3 python3-venv python3-pip
  elif command -v dnf >/dev/null 2>&1; then
    $SUDO dnf install -y python3 python3-pip
  else
    echo "Install Python 3 from https://python.org then re-run this script."
    exit 1
  fi
fi

VENV="$HOME/.buzz-proxy-venv"
PY="python3"

ensure_pip_if_missing() {
  python3 -m pip --version >/dev/null 2>&1 && return 0
  echo -e "${YELLOW}Installing Python pip...${NC}"
  if [ "$OS" = "macos" ]; then
    brew install python3 >/dev/null 2>&1
  elif command -v apt-get >/dev/null 2>&1; then
    $SUDO apt-get install -y python3-venv python3-pip >/dev/null 2>&1
  else
    $SUDO dnf install -y python3-pip >/dev/null 2>&1
  fi
}

make_proxy_python() {
  if [ ! -x "$VENV/bin/python" ]; then
    python3 -m venv "$VENV" >/dev/null 2>&1 \
      || { ensure_pip_if_missing; python3 -m venv "$VENV" >/dev/null 2>&1 || true; }
  fi
  if [ -x "$VENV/bin/python" ]; then
    "$VENV/bin/python" -m pip install -q --disable-pip-version-check \
      -r "$SCRIPT_DIR/bin/nvidia-proxy/requirements.txt" >/dev/null \
      && { PY="$VENV/bin/python"; return; }
  fi
  # No venv possible — use user site-packages (with the PEP 668 escape hatch).
  python3 -m pip install --user -q --disable-pip-version-check \
      -r "$SCRIPT_DIR/bin/nvidia-proxy/requirements.txt" >/dev/null 2>&1 \
    || python3 -m pip install --user --break-system-packages -q --disable-pip-version-check \
      -r "$SCRIPT_DIR/bin/nvidia-proxy/requirements.txt" >/dev/null 2>&1 \
    || true
}

echo -e "${YELLOW}Setting up the proxy's Python environment...${NC}"
make_proxy_python
echo "Proxy Python environment ready."

# 4. Apply buzz branding + scrub the engine's built-in help text
$PY "$SCRIPT_DIR/bin/brand-engine.py"

# 5. Copy scripts into ~/bin
mkdir -p "$HOME/bin"
for f in buzz buzz-code buzz-chat lib-pi; do
  cp "$SCRIPT_DIR/bin/$f" "$HOME/bin/$f"
  chmod +x "$HOME/bin/$f"
done
mkdir -p "$HOME/bin/nvidia-proxy"
cp "$SCRIPT_DIR/bin/nvidia-proxy"/* "$HOME/bin/nvidia-proxy/"
echo -e "${GREEN}==> Scripts installed to ~/bin${NC}"

# 6. NVIDIA API key
KEY_FILE="$HOME/.config/nvidia/api.key"
if [ ! -f "$KEY_FILE" ]; then
  echo -e "${YELLOW}NVIDIA API key not found.${NC}"
  echo "1. Get a FREE key at: https://build.nvidia.com"
  echo "   (pick any model -> 'Get API Key' -> copy the nvapi-... value)"
  read -r -p "2. Paste your key: " KEY || KEY=""
  [ -n "$KEY" ] || { echo "No key entered. Aborting (re-run when ready)."; exit 1; }
  mkdir -p "$HOME/.config/nvidia"
  printf '%s\n' "$KEY" > "$KEY_FILE"
  chmod 600 "$KEY_FILE"
  echo "Key saved to $KEY_FILE (mode 600)."
else
  echo "Key already present at $KEY_FILE."
fi

# 7. Buzz theme (honey/amber TUI + HTML export look) as the default theme
THEMES_DIR="$HOME/.pi/agent/themes"
mkdir -p "$THEMES_DIR"
cp "$SCRIPT_DIR/theme/buzz.json" "$THEMES_DIR/buzz.json"
echo -e "${GREEN}==> Installed buzz theme${NC}"

# 8. Point engine at the proxy and set default theme
$PY "$SCRIPT_DIR/bin/configure-engine.py"

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
if [ "$OS" = "linux" ]; then
  echo "Optional persistent proxy:"
  echo "  systemctl --user enable --now $SCRIPT_DIR/nvidia-proxy.service"
else
  echo "The proxy auto-starts with every 'buzz' command (no service needed on macOS)."
fi