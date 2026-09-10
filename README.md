# buzz agent

Your personal **AI coding agent** on NVIDIA's free cloud — reads your code, writes files, runs commands, fixes bugs, reviews PRs, and refactors whole projects. No local GPU, no paid API, no infra. Just a Linux box + one free key.

```
  ██████╗ ██╗   ██╗███████╗███████╗
  ██╔══██╗██║   ██║╚══███╔╝╚══███╔╝   your AI coding agent
  ██████╔╝██║   ██║  ███╔╝   ███╔╝     engine: NVIDIA Nemotron
  ██╔══██╗██║   ██║ ███╔╝   ███╔╝      tools: read bash edit write
  ██████╔╝╚██████╔╝███████╗███████╗
  ╚═════╝  ╚═════╝ ╚══════╝╚══════╝
```

Built on the [pi coding agent](https://pi.dev) runtime, backed by:

- **NVIDIA Nemotron Lightning** (`nemotron-3.5-lightning-30b-a3b`) — fast daily driver
- **NVIDIA Nemotron Ultra** (`nemotron-3-ultra-550b-a55b`) — heavy lifting

Both served by NVIDIA's free NIM cloud.

> ## Screenshots
>
> **Terminal (buzz TUI)** — *screenshot coming soon*
>
> **Web view (sharable sessions)** — *screenshot coming soon*

The whole thing is rebranded: the window title, the header, and the update prompt all say **buzz** (`buzz update` just updates the engine under the hood), and the terminal ships with a honey-and-amber theme that also colors exported session pages.

## What you get

It's a full coding agent, not a chatbot. Give it a goal; it works until the task is done.

| Command | Uses | Good for |
|---|---|---|
| `buzz` | Nemotron Lightning (30B) | everyday coding, fast iteration |
| `buzz-code` | Nemotron Ultra (550B) | hard problems, big refactors |
| `buzz-chat "..."` | Lightning (default) | quick answers, no agent overhead |
| `bin/nvidia-proxy` | any NVIDIA model | OpenAI-compatible endpoint (`localhost:8888`) |

### The agent's tools (real work, not chat)

- **read** / **grep** / **find** / **ls** — explores your codebase
- **edit** / **write** — changes code in your project
- **bash** — runs commands, builds, tests, git

so you can say:

```bash
buzz "add dark mode to src/App.css and update the toggle in App.js, then run the test suite"
buzz-code "./src/auth is a mess — find the security holes, fix them, and write tests"
buzz "setup a new express + sqlite project in ./blog and scaffold the models, routes, and migrations"
```

It keeps a **session**, so you can continue a conversation across restarts (`/continue`, `/resume`) and ask follow-ups on the same task. Full interactive terminal UI — themes, colors, inline diffs.

## Quick start (3 steps)

```bash
git clone https://github.com/Chiazor-Daniel/buzz-agent
cd buzz-agent
./setup.sh
```

setup.sh will:
1. Install Node.js if missing
2. `npm install -g @earendil-works/pi-coding-agent` and **rebrand it** so every screen says `buzz` (update prompt, titles)
3. Copy `buzz`, `buzz-code`, `buzz-chat` into `~/bin`
4. Ask for your **free** NVIDIA API key and save it to `~/.config/nvidia/api.key` (mode 600)
5. Point pi's `nvidia` provider at your local key-hiding proxy
6. Install the **buzz theme** (honey/amber TUI + matching exported web pages) as the default

Then (new terminal):

```bash
buzz "add an /api/health route to ./server and a test for it"

buzz-code "find the performance bottleneck in ./src and fix it"

buzz-chat "what is a TLS handshake?"
```

`buzz` and `buzz-code` **auto-start the proxy** on first use (and `setup.sh` can also install it as a background service), so it really is one command — no keys to remember, nothing else to run. Skip the banner with `BUZZ_NO_BANNER=1`.

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

## How the key stays hidden

```
Your terminal/git repo     ~/.config/nvidia/api.key (mode 600)
         │                            │
         │ no key anywhere            │ only file that holds it
         ▼                            ▼
    pi agent ──► local proxy :8888 ──► NVIDIA free cloud
```

- pi is configured with `apiKey: "not-used"` and talks only to `127.0.0.1:8888`
- the proxy (`bin/nvidia-proxy`) loads the key from `~/.config/nvidia/api.key` and forwards to `https://integrate.api.nvidia.com/v1`
- no NVIDIA key ever appears in your shell, env, config, or repo

The proxy auto-starts on demand. For a persistent background proxy on login:

```bash
mkdir -p ~/.config/systemd/user
cp nvidia-proxy.service ~/.config/systemd/user/
systemctl --user enable --now nvidia-proxy
```

## Using the proxy directly (optional)

The proxy also exposes an OpenAI-compatible endpoint on `localhost:8888` for any OpenAI-SDK tools:

```bash
curl http://127.0.0.1:8888/health
curl http://127.0.0.1:8888/v1/models
curl http://127.0.0.1:8888/v1/chat/completions -H 'Content-Type: application/json' \
  -d '{"model":"nvidia/nemotron-3.5-lightning-30b-a3b","messages":[{"role":"user","content":"hi"}]}'
```

(To run it manually instead of auto-start: `python3 ~/bin/nvidia-proxy/main.py`)

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