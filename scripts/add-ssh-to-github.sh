#!/usr/bin/env bash
# Provision this machine's SSH key to GitHub — layer-0 key bootstrap.
#
#   GH_TOKEN=ghp_xxx scripts/add-ssh-to-github.sh
#   scripts/add-ssh-to-github.sh          # prompts for the PAT (hidden)
#
# PAT needs the `admin:public_key` scope (classic) or read/write on
# "Git SSH keys" (fine-grained). The token is read from the environment or a
# hidden prompt — NEVER passed as an argument, so it can't leak via `ps` or
# shell history.
#
# Idempotent: existing key is reused, an already-uploaded key is detected,
# known_hosts pinning is append-only.
set -euo pipefail

KEY="${SSH_KEY_PATH:-$HOME/.ssh/id_ed25519}"
TITLE="${SSH_KEY_TITLE:-$(whoami)@$(hostname -s) $(date +%Y-%m-%d)}"

ok()   { printf '\033[0;32m✔\033[0m %s\n' "$*"; }
info() { printf '\033[1;34m→\033[0m %s\n' "$*"; }
die()  { printf '\033[0;31m✖\033[0m %s\n' "$*" >&2; exit 1; }

# ── 1. keypair ───────────────────────────────────────────────────────────────
if [ -f "$KEY" ]; then
  ok "key exists: $KEY"
else
  info "generating ed25519 keypair…"
  ssh-keygen -t ed25519 -C "$(whoami)@$(hostname -s)" -f "$KEY" -N "" -q
  ok "generated $KEY"
fi
PUB="$(cat "$KEY.pub")"

# ── 2. pin github.com ────────────────────────────────────────────────────────
touch "$HOME/.ssh/known_hosts"
if ! grep -q "^github.com" "$HOME/.ssh/known_hosts" 2>/dev/null; then
  ssh-keyscan -t ed25519 github.com 2>/dev/null >> "$HOME/.ssh/known_hosts"
  ok "github.com pinned in known_hosts"
else
  ok "github.com already in known_hosts"
fi

# ── 3. token ─────────────────────────────────────────────────────────────────
TOKEN="${GH_TOKEN:-${GITHUB_TOKEN:-}}"
if [ -z "$TOKEN" ]; then
  printf 'GitHub PAT (admin:public_key scope, input hidden): '
  read -rs TOKEN; echo
fi
[ -n "$TOKEN" ] || die "no token provided"

api() {
  curl -fsS -H "Authorization: Bearer $TOKEN" \
       -H "Accept: application/vnd.github+json" "$@"
}

# ── 4. upload (skip if this exact key is already there) ──────────────────────
key_body="$(printf '%s' "$PUB" | awk '{print $1" "$2}')"
if api https://api.github.com/user/keys | grep -qF "$(printf '%s' "$key_body" | awk '{print $2}')"; then
  ok "key already registered on GitHub"
else
  info "uploading key as \"$TITLE\"…"
  api -X POST https://api.github.com/user/keys \
      -d "{\"title\":\"$TITLE\",\"key\":\"$key_body\"}" >/dev/null \
    || die "upload failed — does the PAT have admin:public_key scope?"
  ok "key uploaded"
fi

# ── 5. verify ────────────────────────────────────────────────────────────────
info "verifying ssh auth…"
out="$(ssh -o BatchMode=yes -T git@github.com 2>&1 || true)"
case "$out" in
  *"successfully authenticated"*) ok "GitHub SSH auth works: ${out%%!*}!" ;;
  *) die "auth check failed: $out" ;;
esac
