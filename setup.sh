#!/usr/bin/env bash
# One-shot setup: install pi + wire up NVIDIA-backed agent on your Linux box.
set -euo pipefail

GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'

echo -e "${GREEN}==> pi-nvidia-agent setup${NC}"

# 1. Node.js (required by pi)
if ! command -v node >/dev/null 2>&1; then
  echo -e "${YELLOW}Installing Node.js...${NC}"
  if command -v dnf >/dev/null 2>&1; then
    sudo dnf install -y nodejs npm
  elif command -v apt-get >/dev/null 2>&1; then
    sudo apt update && sudo apt install -y nodejs npm
  else
    echo "Install Node.js from https://nodejs.org then re-run this script."
    exit 1
  fi
fi

# 2. pi (the coding agent CLI)
if ! command -v pi >/dev/null 2>&1; then
  echo -e "${YELLOW}Installing pi coding agent...${NC}"
  npm install -g @earendil-works/pi-coding-agent
fi

# 3. Copy scripts into ~/bin
mkdir -p "$HOME/bin"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
for f in pi-nvidia pi-nvidia-code nvidia-chat; do
  cp "$SCRIPT_DIR/bin/$f" "$HOME/bin/$f"
  chmod +x "$HOME/bin/$f"
done
mkdir -p "$HOME/bin/nvidia-proxy"
cp "$SCRIPT_DIR/bin/nvidia-proxy"/* "$HOME/bin/nvidia-proxy/"

echo -e "${GREEN}==> Scripts installed to ~/bin${NC}"

# 4. NVIDIA API key
KEY_FILE="$HOME/.config/nvidia/api.key"
if [ ! -f "$KEY_FILE" ]; then
  echo -e "${YELLOW}NVIDIA API key not found.${NC}"
  echo "1. Get a FREE key at: https://build.nvidia.com"
  echo "   (pick any model -> 'Get API Key' -> copy it)"
  read -r -p "2. Paste your nvapi-... key: " KEY
  [ -n "$KEY" ] || { echo "No key entered. Aborting (you can re-run)."; exit 1; }
  mkdir -p "$HOME/.config/nvidia"
  printf '%s\n' "$KEY" > "$KEY_FILE"
  chmod 600 "$KEY_FILE"
  echo "Key saved to $KEY_FILE (mode 600)."
else
  echo "Key already present at $KEY_FILE."
fi

echo -e "${GREEN}==> Re-opening terminal or run 'source ~/.profile' to use them.${NC}"
echo -e "${GREEN}Try it:${NC} pi-nvidia \"hi, give me a one-line greeting\""
echo -e "${YELLOW}Note: pi AWS proxy etc. not needed — it talks straight to NVIDIA's free cloud.${NC}"