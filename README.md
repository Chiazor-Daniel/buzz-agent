# pi-nvidia-agent

Run the [pi coding agent](https://pi.dev) on **NVIDIA's free cloud models** — no local GPU, no paid API, no server. Just a Linux box and a free NVIDIA key, and you get a full coding agent that works out of the box.

Uses **NVIDIA Nemotron Lightning** (`nemotron-3.5-lightning-30b-a3b`) for fast answers and **Nemotron Ultra** (`nemotron-3-ultra-550b-a55b`) for heavier coding tasks — both served free by NVIDIA's NIM cloud.

## What you get

| Command | Uses | Good for |
|---|---|---|
| `pi-nvidia` | Nemotron Lightning (30B) | everyday coding, fast answers |
| `pi-nvidia-code` | Nemotron Ultra (550B) | hard problems, big refactors |
| `nvidia-chat "..."` | Lightning (default) | quick one-off prompts without the agent |
| `bin/nvidia-proxy` | any NVIDIA model | local OpenAI-compatible endpoint (`localhost:8888`) for tools that speak OpenAI |

The `pi` agent has real tools: read, bash, edit, write files — so it can actually work on your projects, not just chat.

## Quick start (3 steps)

```bash
git clone https://github.com/Chiazor-Daniel/pi-nvidia-agent
cd pi-nvidia-agent
./setup.sh
```

setup.sh will:
1. Install Node.js if missing
2. `npm install -g @earendil-works/pi-coding-agent`
3. Copy the `pi-nvidia*` scripts into `~/bin`
4. Ask for your **free** NVIDIA API key and save it to `~/.config/nvidia/api.key` (mode 600)

Then (new terminal):

```bash
pi-nvidia "write a python script that prints a fibonacci sequence"

pi-nvidia-code "review the auth code in ./src and find security issues"

nvidia-chat "what is a TLS handshake?"
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
NVIDIA_MODEL="nvidia/nemotron-3-super-120b-a12b" nvidia-chat "hi"
pi --provider nvidia --model "nvidia/nemotron-3.5-lightning-30b-a3b" "question"
```

Browse all free model IDs at build.nvidia.com (copy any model's API code — the env var to set is `NVIDIA_API_KEY`).

## Security notes

- **Never commit your key.** `.gitignore` excludes `*.key` / `api.key`. Keys are read from `$NVIDIA_API_KEY` or `~/.config/nvidia/api.key`, never from the repo.
- Your key grants free-tier access only (rate-limited), but treat it like a password anyway.
- If you think a key leaked (committed, pasted in chat, etc.) — regenerate it at build.nvidia.com.

## Troubleshooting

**`pi: command not found`**
Reopen your terminal (npm global bin may need PATH refresh): `npm prefix -g` → add its `/bin` to PATH.

**`401` / `Unauthorized`**
Check the key: `head -c 20 ~/.config/nvidia/api.key` (should start `nvapi-`) and that there's no trailing newline issue. Regenerate if needed.

**Rate limited**
Free tier caps requests/minute. Wait a bit or switch to a heavier/smaller model.

**`pi` says "no provider"**
Run with explicit flags: `pi --provider nvidia --model nvidia/nemotron-3.5-lightning-30b-a3b`