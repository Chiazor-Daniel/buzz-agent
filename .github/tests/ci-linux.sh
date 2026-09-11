#!/usr/bin/env bash
# CI system test for Linux / macOS / WSL.
# Uses a bogus NVIDIA key (no real secrets required for CI).
set -uo pipefail

PASS=0; FAIL=0
ok()  { echo "  PASS: $1"; PASS=$((PASS+1)); }
bad() { echo "  FAIL: $1"; FAIL=$((FAIL+1)); }

# macOS ships no GNU coreutils 'timeout' — use perl for the same job timeout.
run_t() { perl -e 'alarm shift; exec @ARGV' "$@"; }

KEY="nvapi-XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX"

# ── macOS: force the Homebrew Node path ────────────────────────────────────────
if [ "$(uname -s)" = "Darwin" ]; then
  for cmd in node npm npx; do
    p="$(command -v "$cmd" 2>/dev/null || true)"
    [ -n "$p" ] && mv "$p" "$p.ci-hidden" 2>/dev/null || true
  done
  HOMEBREW_PREFIX="$(brew --prefix node@22 2>/dev/null)"
  PATH="$HOMEBREW_PREFIX/bin:$PATH"
fi

# ── C1: setup runs to completion with a bogus key ──────────────────────────────

BUZZ_SETUP_KEY="$KEY" ./setup.sh > /tmp/setup.log 2>&1
grep -q "Done!" /tmp/setup.log && ok "C1 setup ran to completion" || { bad "C1 setup failed"; cat /tmp/setup.log; exit 1; }
if grep -q "Installing the code agent engine" /tmp/setup.log || grep -q "Code agent engine already installed" /tmp/setup.log; then
  ok "C1 engine present"
else
  bad "C1 engine missing"
fi

# ── C2: engine branded to buzz ─────────────────────────────────────────────────

BRAND=$(node -e "
  const p = require(require('path').join(
    require('child_process').execSync('npm root -g').toString().trim(),
    '@earendil-works/pi-coding-agent/package.json'
  ));
  console.log(p.piConfig && p.piConfig.name || '')
")
[ "$BRAND" = "buzz" ] && ok "C2 piConfig.name = buzz" || bad "C2 piConfig.name = $BRAND"

# ── C3: help text fully branded ────────────────────────────────────────────────

export PATH="$HOME/bin:$PATH"
HELP=$(BUZZ_NO_BANNER=1 buzz -h 2>&1)
echo "$HELP" | grep -q "buzz - AI coding assistant" && ok "C3 help title says buzz" || bad "C3 help title: $(echo "$HELP" | head -1)"
if echo "$HELP" | grep -qi "Update pi," || echo "$HELP" | grep -q "\[source|self|pi\]"; then
  bad "C3 'pi' leaks: $(echo "$HELP" | grep -i 'update pi\|source|self' | head -1)"
else
  ok "C3 no 'pi' leaks in help"
fi

# ── C4: --version passthrough ──────────────────────────────────────────────────

VER=$(BUZZ_NO_BANNER=1 buzz --version 2>&1)
echo "$VER" | grep -qE "^[0-9]+\.[0-9]+\.[0-9]+" && ok "C4 --version: $(echo "$VER" | tail -1)" || bad "C4 --version: $VER"

# ── C5: proxy boots + bogus key → friendly 403 ────────────────────────────────

PY="$HOME/.buzz-proxy-venv/bin/python"
[ -x "$PY" ] || PY="python3"

nohup "$PY" "$HOME/bin/nvidia-proxy/main.py" > /tmp/proxy.log 2>&1 &
for i in $(seq 1 20); do
  curl -sf -m 2 http://127.0.0.1:8888/health >/dev/null 2>&1 && break
  sleep 1
done
curl -sf -m 2 http://127.0.0.1:8888/health >/dev/null 2>&1 && ok "C5 proxy healthy" || { bad "C5 proxy dead"; cat /tmp/proxy.log; }

RESP=$(run_t 60 buzz-chat "hi" 2>&1)
echo "$RESP" | grep -q "rejected your API key" && ok "C5 friendly 403" || bad "C5 403 output: $(echo "$RESP" | tail -3)"

# ── C6: missing-key guard fires before agent starts ────────────────────────────

KF="$HOME/.config/nvidia/api.key"
if [ -f "$KF" ]; then
  mv "$KF" "$KF.bak"
  MISSING=$(run_t 30 buzz "ignored" 2>&1 || true)
  mv "$KF.bak" "$KF"
  echo "$MISSING" | grep -q "no API key found" && ok "C6 missing-key guard" || bad "C6 guard: $(echo "$MISSING" | head -3)"
fi

# ── done ───────────────────────────────────────────────────────────────────────

echo
echo "RESULT: $PASS passed, $FAIL failed"
exit $((FAIL > 0))