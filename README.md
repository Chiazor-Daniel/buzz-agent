# buzz agent

Your personal AI coding agent on **NVIDIA's free cloud models** — no local GPU, no paid API, no server. Just a Linux box and a free NVIDIA key, and you get a coding agent that actually *works* on your projects, out of the box.

Powered by the [pi coding agent](https://pi.dev) runtime, backed by:

- **NVIDIA Nemotron Lightning** (`nemotron-3.5-lightning-30b-a3b`) — fast, daily driver
- **NVIDIA Nemotron Ultra** (`nemotron-3-ultra-550b-a55b`) — heavy lifting

Both served free by NVIDIA's NIM cloud.

## What you get

| Command | Uses | Good for |
|---|---|---|
| `buzz` | Nemotron Lightning (30B) | everyday coding, fast answers |
| `buzz-code` | Nemotron Ultra (550B) | hard problems, big refactors |
| `buzz-chat "..."` | Lightning (default) | quick one-off prompts, no agent overhead |
| `bin/nvidia-proxy` | any NVIDIA model | local OpenAI-compatible endpoint (`localhost:8888`) for tools that speak OpenAI |

The agent has real tools: **read, bash, edit, write** — so it can work on your code, not just chat.

## Quick start (3 steps)

```bash
git clone https://github.com/Chiazor-Daniel/buzz-agent
cd buzz-agent
./setup.sh
```

setup.sh will:
1. Install Node.js if missing
2. `npm install -g @earendil-works/pi-coding-agent`
3. Copy `buzz`, `buzz-code`, `buzz-chat` into `~/bin`
4. Ask for your **free** NVIDIA API key and save it to `~/.config/nvidia/api.key` (mode 600)

Then (new terminal):

```bash
buzz "write a python script that prints a fibonacci sequence"

buzz-code "review the auth code in ./src and find security issues"

buzz-chat "what is a TLS handshake?"
```

## Getting the FREE API key

1. Go to **https://build.nvidia.com**
2. Create a free account
3. Open any model page and click **Get API Key**
4. Copy the `nvapi-...` value
5. Either paste it during setup.sh, or save it manually:

```bash
mkdir -p ~/.config/nvidia
echo "nvapi-YOUR-KEY-HERE" > ~/.config/nvidia/api.key
chmod 600 ~/.config/nvidia/api.key
```

NVIDIA's free tier is rate-limited but plenty for personal coding use. No credit card.

## Using the proxy (optional)

Expose an OpenAI-compatible endpoint on `localhost:8888` that forwards to NVIDIA:

```bash
cd ~/bin/nvidia-proxy
python3 -m pip install -r requirements.txt
python3 main.py
```

Then point any OpenAI SDK at `http://127.0.0.1:8888/v1`.

```bash
curl http://127.0.0.1:8888/health
curl http://127.0.0.1:8888/v1/models
```

## Switching models

Every script reads env vars, so you can override without editing anything:

```bash
NVIDIA_MODEL="nvidia/nemotron-3-super-120b-a12b" buzz-chat "hi"
pi --provider nvidia --model "nvidia/nemotron-3.5-lightning-30b-a3b" "question"
```

Browse all free model IDs at build.nvidia.com (copy any model's API code — the env var to set is `NVIDIA_API_KEY`).

## Security notes

- **Never commit your key.** `.gitignore` excludes `*.key` / `api.key`. Keys are read from `$NVIDIA_API_KEY` or `~/.config/nvidia/api.key`, never from the repo.
- Your key grants free-tier access only (rate-limited), but treat it like a password anyway.
- If you think a key leaked (committed, pasted in chat, etc.) — regenerate it at build.nvidia.com.

## Troubleshooting

**`buzz: command not found`**
Reopen your terminal (npm global bin may need PATH refresh): `npm prefix -g` → add its `/bin` to PATH. Also confirm `setup.sh` copied the scripts to `~/bin` and `~/bin` is on PATH.

**`401` / `Unauthorized`**
Check the key: `head -c 20 ~/.config/nvidia/api.key` (should start `nvapi-`) and that there's no trailing-newline issue. Regenerate if needed.

**Rate limited**
Free tier caps requests/minute. Wait a bit or switch models.

**`pi` says "no provider"**
Run with explicit flags: `pi --provider nvidia --model nvidia/nemotron-3.5-lightning-30b-a3b`