# buzz agent

> Your coding agent. Your key. Your terminal. Free cloud inference.

buzz wraps the [pi coding agent](https://www.npmjs.com/package/@earendil-works/pi-coding-agent) with a local NVIDIA NIM proxy so your API key never touches the agent runtime. Get a free NVIDIA cloud key, paste it once, and use buzz every day.

---

## Install (pick your OS)

**Zero manual installs** — setup downloads Node.js 22, Python 3, and all proxy dependencies for you. You only need **git** and an internet connection.

| OS | Method | One-liner |
|---|---|---|
| Linux / Ubuntu / Debian / Fedora / WSL | setup.sh | `git clone https://github.com/Chiazor-Daniel/buzz-agent && cd buzz-agent && ./setup.sh` |
| macOS | setup.sh | Install [Homebrew](https://brew.sh) first, then the same line above. |
| Windows (native) | setup.ps1 | `git clone https://github.com/Chiazor-Daniel/buzz-agent; cd buzz-agent; powershell -ExecutionPolicy Bypass -File .\bin\setup.ps1` |
| Windows (WSL) | setup.sh | Install [WSL](https://aka.ms/installwsl), install Ubuntu inside it, then the Linux one-liner. |

> **macOS note:** Homebrew is required (it installs Xcode Command Line Tools, Node, and Python automatically). One-time setup: `/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"`

> **Windows native note:** Windows 11 ships with winget (used by setup.ps1). On Windows 10, install [App Installer](https://aka.ms/getwinget) from the Store first.

---

## Just type buzz

```bash
buzz "write a hello world in Python"
buzz-code "find the bug in main.py"
buzz-chat "what is a TLS handshake?"
```

Works from any project folder — buzz is a normal CLI command.

---

## Your key is yours

buzz never logs, exports, or shares your NVIDIA key.

```
~/.config/nvidia/api.key          ← only the proxy reads this (chmod 600)
~/.buzz-proxy-venv/               ← proxy's Python packages (isolated)
~/.pi/agent/models.json           ← provider set to proxy on :8888 (apiKey = "not-used")
buzz → proxy on :8888 → NVIDIA cloud    ← your key stays on disk, never in the agent
```

---

## Troubleshooting

**buzz: command not found**
Your shell hasn't picked up `~/bin` yet. Reopen your terminal or run:
```bash
export PATH="$HOME/bin:$PATH"
```
On Windows, setup.ps1 adds `~/bin` to your PATH automatically — close and reopen your terminal.

**proxy failed to start**
Check the key exists: `ls -l ~/.config/nvidia/api.key`. If it's missing, re-run setup.

**npm errors on Linux (EACCES / EPERM)**
Fix npm's global prefix:
```bash
npm config set prefix ~/.npm-global
echo 'export PATH="$HOME/.npm-global/bin:$PATH"' >> ~/.bashrc
source ~/.bashrc
```
Then re-run setup.sh.

**macOS: "xcode-select: note: install requested for Xcode Command Line Tools"**
Run `xcode-select --install` if prompted during setup, then re-run setup.sh.

**"Your API key was rejected (HTTP 403)"**
Regenerate your key at https://build.nvidia.com and paste it again:
```bash
nano ~/.config/nvidia/api.key
```
