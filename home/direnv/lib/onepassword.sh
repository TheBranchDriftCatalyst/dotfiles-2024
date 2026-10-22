# shellcheck shell=bash
# ─────────────────────────────────────────────────────────────────────────────
# onepassword.sh :: direnv helpers — installed to ~/.config/direnv/lib/
#
#   use_onepassword      [tpl]              op:// refs in tpl → exported env
#   use_onepassword_file <op://ref> <dest>   one secret/document → a real file
#   use_onepassword_tpl  tpl [out] [mode]    whole template → a real file
#
# ESO-for-dev: the cluster syncs secrets via external-secrets-operator +
# 1Password Connect; this is the laptop-side mirror. Repos commit an .env.tpl
# of op:// references (never values) and call `use_onepassword` from .envrc —
# entering the repo materializes them as env vars. use_onepassword_tpl is the
# same pattern for tools that only read credentials from a config file (an
# .npmrc, a kubeconfig) rather than the environment; use_onepassword_file is
# for a single whole-file secret op inject cannot render (a Connect
# credential, a keypair). Requires the 1Password app's "Integrate with CLI"
# toggle for biometrics.
#
# CONTRACT
#   - direnv sources every ~/.config/direnv/lib/*.sh BEFORE direnvrc and
#     before the .envrc, so these run with the full direnv stdlib in scope
#     (has, watch_file, direnv_layout_dir). This file is NOT standalone bash
#     — it is only ever sourced by direnv.
#   - Sourcing must be silent. lib/*.sh is sourced WITHOUT the `>&2` redirect
#     direnvrc gets, so a stray stdout write here corrupts direnv's output.
#     Define functions; print nothing at load time.
#   - Every function is soft-fail: a missing/locked `op`, an absent template,
#     or a failed render logs and returns 0. A broken vault must never break
#     the shell.
#   - Every function is safe under `strict_env` (errexit/nounset/pipefail),
#     which any .envrc may switch on before calling us.
#   - No `trap` anywhere: direnv installs its own EXIT trap (__dump_at_exit)
#     and ours would silently replace it. Cleanup is explicit on each path.
#   - All output goes through _op_say below, not log_status/log_error: those
#     fork `direnv log` once per line, hard-code a "direnv: " prefix, and a
#     forced red that overrides anything we set. A printf builtin owns the
#     whole line and costs no process.
#
# Caching: renders live in $(direnv_layout_dir)/op/ (usually .direnv/op/),
# one <template-slug>.hash (+ .env, for use_onepassword) pair per template,
# so two templates in the same project both stay warm. A render is reused
# while the template's CONTENT is unchanged (sha256, not mtime — a `touch`
# or a checkout with a new mtime but old bytes is not a cache miss) and the
# render is younger than $OP_ENV_CACHE_TTL_MINUTES (default 480 = 8h; 0
# disables caching entirely). The hash catches an edited ref immediately;
# the clock catches a secret ROTATED behind an unchanged template. Bust by
# hand with `op_cleanup` (home/direnv.nix) or `rm -rf .direnv/op`.
#
# $_OP_* colours/glyphs come from home/direnv.nix (catalyst.palette), and are
# blank by default below so this file is self-contained under direct test.
# ─────────────────────────────────────────────────────────────────────────────

: "${_OP_OK:=}" "${_OP_BAD:=}" "${_OP_SUBJ:=}" "${_OP_NUM:=}" "${_OP_DIM:=}" "${_OP_OFF:=}"
if [[ -n "${NO_COLOR:-}" ]]; then
  _OP_OK='' _OP_BAD='' _OP_SUBJ='' _OP_NUM='' _OP_DIM='' _OP_OFF=''
fi

_op_say() {
  [[ -z "${DIRENV_LOG_FORMAT-x}" ]] && return 0 # explicitly emptied = quiet
  local colour="$1" glyph="$2" subject="$3"
  shift 3
  printf '%s%s%s %sop%s %s%-13s%s %s%s%s\n' \
    "$colour" "$glyph" "$_OP_OFF" "$_OP_DIM" "$_OP_OFF" \
    "$_OP_SUBJ" "$subject" "$_OP_OFF" \
    "$_OP_DIM" "$*" "$_OP_OFF" >&2
}
# Distinct GLYPHS, not just colour: NO_COLOR and colour-blind readers get the
# same signal, and a grep for ✗ finds every failure.
_op_ok() { _op_say "$_OP_OK" "◈" "$@"; }
_op_bad() { _op_say "$_OP_BAD" "✗" "$@"; }
# continuation line for a remedy — indented under the failure it explains
_op_tip() {
  [[ -z "${DIRENV_LOG_FORMAT-x}" ]] && return 0
  printf '%s   ↳ %s%s\n' "$_OP_DIM" "$*" "$_OP_OFF" >&2
}

_op_count() { grep -c '^[A-Za-z_][A-Za-z0-9_]*=' "$1" 2>/dev/null || true; }
_op_fingerprint() { shasum -a 256 <"$1" | cut -d' ' -f1; }

# _op_stale <file> <ttl-minutes> — true iff <file> is older than the TTL.
# `date -r FILE` means "use FILE's mtime" on both BSD and GNU date; `stat`
# does not agree across the two. Caller is responsible for ttl<=0 (that
# means "no cache at all", handled at the call site, not here).
_op_stale() {
  local file="$1" ttl_min="$2" age
  age=$(($(date +%s) - $(date -r "$file" +%s 2>/dev/null || echo 0)))
  ((age >= ttl_min * 60))
}

# Cache files are named for their template, slashes flattened: readable, and
# stable across edits so a render overwrites rather than orphans.
_op_slug() { printf '%s' "${1//\//%}"; }

_op_cache_dir() {
  local d
  d="$(direnv_layout_dir)/op"
  mkdir -p "$d" || return 1
  chmod 700 "$d" 2>/dev/null
  printf %s "$d"
}

# Absolute AND symlink-resolved. git rev-parse reports a physical path, so a
# logical $PWD (/tmp vs /private/tmp, any symlinked home) would never prefix-
# match it — and this guard's "outside the work tree" branch fails OPEN.
_op_realpath() {
  local p="$1" d
  case "$p" in /*) ;; *) p="$PWD/$p" ;; esac
  if d="$(cd "$(dirname "$p")" 2>/dev/null && pwd -P)"; then
    printf '%s/%s' "$d" "$(basename "$p")"
  else
    printf '%s' "$p"
  fi
}

# Safe to write plaintext secrets here? git check-ignore is the authority —
# it honours nested .gitignore, info/exclude and core.excludesFile.
_op_gitignored() {
  local root abs
  root="$(git rev-parse --show-toplevel 2>/dev/null)" || return 0
  [[ -n "$root" ]] || return 0
  root="$(_op_realpath "$root")"
  abs="$(_op_realpath "$1")"
  case "$abs" in
    "$root"/*) ;;
    *) return 0 ;; # outside the work tree
  esac
  git check-ignore -q -- "$abs" 2>/dev/null
}

# ── failure state, per direnv load ──────────────────────────────────────────
#   $_OP_ERR   short reason for the last failure; callers fold it into one line
#   $_OP_DOWN  failure was session-wide, so later hooks skip op entirely
#   $_OP_HINT  remedy line already printed

# op's stderr is one ~300-char line: log prefix, reason, support URL.
_op_err_brief() {
  local raw brief
  raw="$(tr -s '[:space:]' ' ' <"$1" 2>/dev/null)"
  case "$raw" in
    "[ERROR] "*)
      raw="${raw#\[ERROR\] }"
      raw="${raw#* }" # date
      raw="${raw#* }" # time
      ;;
  esac
  raw="${raw%%If you*re still having trouble*}"

  case "$raw" in
    *"connect to the 1Password desktop app"* | *"connecting to desktop app"*)
      _OP_DOWN=1 brief="desktop app refused the CLI connection" ;;
    *authorization* | *"timed out"* | *timeout*)
      _OP_DOWN=1 brief="biometric approval never came back" ;;
    *"not signed in"* | *"no account"* | *"session expired"*)
      _OP_DOWN=1 brief="no usable op session" ;;
    *) # template-specific: keep op's wording, but never wrap the terminal
      brief="${raw% }"
      [[ "${#brief}" -gt 110 ]] && brief="${brief:0:109}…" ;;
  esac
  _OP_ERR="$brief"
}

_op_is_down() { [[ -n "${_OP_DOWN:-}" ]]; }

# Session-wide failures get a remedy; a bad op:// ref already reads as one.
_op_hint() {
  [[ -n "${_OP_HINT:-}" ]] && return 0
  _OP_HINT=1
  case "$_OP_ERR" in
    "desktop app refused"*)
      _op_tip "update the 1Password desktop app and restart it, then check Settings → Developer → Integrate with 1Password CLI" ;;
    "biometric approval"*)
      _op_tip "approve the 1Password prompt, or set OP_SERVICE_ACCOUNT_TOKEN for shells with nobody at the keyboard" ;;
    "no usable op session"*)
      _op_tip "run \`op signin\` in a terminal, then reload this shell" ;;
  esac
}

_op_gave_up() {
  local tpl="$1" out="$2" reason="$3"
  if [[ -f "$out" ]]; then
    _op_bad "$tpl" "$out kept, now stale · $reason"
  else
    _op_bad "$tpl" "$out NOT rendered · $reason"
  fi
}

# _op_fallback_eval <tpl> <rendered> <reason> — a stale-but-PARSEABLE cache
# beats an empty environment, but say so loudly: the values may predate a
# rotation. Evals it on a hit. Prints the harder cold-failure message and
# returns 1 if there is nothing usable to fall back to.
_op_fallback_eval() {
  local tpl="$1" rendered="$2" reason="$3" dotenv_out
  if [[ -f "$rendered" ]] && dotenv_out="$("${direnv:-direnv}" dotenv bash "$rendered" 2>/dev/null)"; then
    _op_bad "$tpl" "using STALE cache ($(_op_count "$rendered") secret(s)) · $reason"
    eval "$dotenv_out"
    return 0
  fi
  _op_bad "$tpl" "secrets NOT loaded · $reason"
  return 1
}

# ── op ──────────────────────────────────────────────────────────────────────

# Detection only — never signs in, since a cold signin is interactive and
# would hang an automation shell. op finds its own credentials; this string
# exists so the log line can name the tier. See home/direnv.nix.
_op_auth_mode() {
  if [[ -n "${OP_SERVICE_ACCOUNT_TOKEN:-}" ]]; then
    echo "service account"
    return 0
  fi
  # shellcheck disable=SC2206  # ${!prefix@} expands to variable NAMES only —
  # safe, bash-generated identifiers, nothing here can glob or word-split.
  local -a sessions=(${!OP_SESSION_@})
  if ((${#sessions[@]} > 0)); then
    echo "op session"
    return 0
  fi
  echo "biometric"
}

# Atomic: render to a sibling temp, then rename. No tool ever reads a partial
# config, and a failed render never truncates a good one. Reports nothing —
# sets $_OP_ERR so the caller can say it once.
_op_render() {
  local tpl="$1" dest="$2" mode="${3:-600}" dir tmp
  dir="$(dirname "$dest")"
  mkdir -p "$dir" || return 1
  tmp="$(umask 077 && mktemp "$dir/.op-render.XXXXXXXX")" || return 1 # same fs → mv is a rename
  chmod "$mode" "$tmp"
  if op inject -f -i "$tpl" -o "$tmp" >/dev/null 2>"$tmp.err"; then
    chmod "$mode" "$tmp" # op may have recreated it under the ambient umask
    rm -f "$tmp.err"
    mv -f "$tmp" "$dest"
    return 0
  fi
  _op_err_brief "$tmp.err"
  rm -f "$tmp" "$tmp.err"
  return 1
}

# ── hooks ───────────────────────────────────────────────────────────────────

# use_onepassword [template] — render op:// refs into exported env. CACHED:
# every new shell re-runs .envrc, and an uncached `op inject` is a biometric
# prompt each time — unusable in practice. See the caching note up top for
# the invalidation rule and $OP_ENV_CACHE_TTL_MINUTES.
#
# This is a deliberate reversal of the earlier "secrets touch disk only for
# milliseconds" stance: the values now persist, 0600, inside the repo's
# .direnv/. That is the same exposure .env.local already carries, and
# .direnv/ is gitignored (checked below, not just assumed), so the trade
# buys a usable prompt-free shell.
use_onepassword() {
  local tpl="${1:-.env.tpl}" dir base rendered fp ttl auth dotenv_out
  if [[ ! -f "$tpl" ]]; then
    _op_bad "$tpl" "no such template in $PWD · skipped"
    return 0
  fi
  # The ONLY correct reload trigger. Note we never watch the cache itself:
  # watching a file we rewrite makes direnv reload on every prompt.
  watch_file "$tpl"

  dir="$(_op_cache_dir)" || {
    _op_bad "$tpl" "secrets NOT loaded · cannot create $(direnv_layout_dir)/op"
    return 0
  }
  if ! _op_gitignored "$dir"; then
    _op_bad "$tpl" "secrets NOT loaded · $dir is in this repo and NOT gitignored"
    _op_tip "add .direnv/ to .gitignore"
    return 0
  fi

  base="$dir/$(_op_slug "$tpl")"
  rendered="$base.env"
  fp="$(_op_fingerprint "$tpl")"

  ttl="${OP_ENV_CACHE_TTL_MINUTES:-480}"
  if [[ ! "$ttl" =~ ^[0-9]+$ ]]; then
    _op_bad "$tpl" "OP_ENV_CACHE_TTL_MINUTES='$ttl' is not a whole number · treating as 0 (no cache)"
    ttl=0
  fi

  # Not the stdlib dotenv(): it watch_files its input, and watching a file
  # under .direnv reloads direnv on every prompt. $tpl is the right trigger.
  # Parsed (not just hash-checked) before being declared a hit: a cache that
  # matches by content but fails to parse must fall through, not export
  # nothing while claiming success.
  if ((ttl > 0)) && [[ -f "$rendered" ]] \
    && [[ "$fp" == "$(cat "$base.hash" 2>/dev/null)" ]] \
    && ! _op_stale "$rendered" "$ttl" \
    && dotenv_out="$("${direnv:-direnv}" dotenv bash "$rendered" 2>/dev/null)"; then
    _op_ok "$tpl" "$_OP_NUM$(_op_count "$rendered")$_OP_DIM secret(s) · cached"
    eval "$dotenv_out"
    return 0
  fi

  # || true on every _op_fallback_eval below: it can legitimately return 1
  # (nothing to fall back to), and under strict_env's errexit a bare failing
  # statement aborts right here, never reaching the return 0 that follows.
  if ! has op; then
    _op_fallback_eval "$tpl" "$rendered" "op CLI not on PATH" || true
    return 0
  fi
  if _op_is_down; then
    _op_fallback_eval "$tpl" "$rendered" "op already unavailable this load" || true
    return 0
  fi

  # Staged, not rendered straight to $rendered: a new render that fails to
  # parse must leave any existing good cache alone rather than clobber it.
  auth="$(_op_auth_mode)"
  local staged="$base.new"
  if _op_render "$tpl" "$staged"; then
    if dotenv_out="$("${direnv:-direnv}" dotenv bash "$staged" 2>/dev/null)"; then
      mv -f "$staged" "$rendered"
      printf '%s\n' "$fp" >"$base.hash" # only after a render that also parses
      _op_ok "$tpl" "$_OP_NUM$(_op_count "$rendered")$_OP_DIM secret(s) · $auth"
      eval "$dotenv_out"
      return 0
    fi
    rm -f "$staged"
    _op_fallback_eval "$tpl" "$rendered" "parse of rendered $tpl failed" || true
    return 0
  fi

  _op_hint
  _op_fallback_eval "$tpl" "$rendered" "$_OP_ERR" || true
  return 0
}

# use_onepassword_file <op://vault/item/field> <dest> — materialize a FILE
# secret that `op inject` cannot render: 1Password Connect credentials, a
# keypair, a kubeconfig. The env-var half of the pattern is use_onepassword
# above; the whole-TEMPLATE file half is use_onepassword_tpl below.
#
# Cached by design: an existing non-empty $dest is left alone, so entering the
# repo costs nothing after the first time. Delete the file to re-fetch. Same
# soft-fail contract as use_onepassword — a missing/locked op warns, it never
# breaks the shell.
use_onepassword_file() {
  local ref="${1:-}" dest="${2:-}"
  local dir tmp err auth

  if [[ -z $ref || -z $dest ]]; then
    _op_bad "use_onepassword_file" "usage: use_onepassword_file <op://vault/item/field> <dest>"
    return 0
  fi
  # -s not -f: a 0-byte dest is a failed earlier fetch, not a cache hit.
  if [[ -s $dest ]]; then
    return 0
  fi

  # Refused outright: plaintext secrets that the next `git add -A` would
  # commit. Add it to .gitignore or render outside the repo.
  if ! _op_gitignored "$dest"; then
    _op_bad "$ref" "refusing to materialize secrets to $dest · in this repo and NOT gitignored"
    return 0
  fi

  if ! has op; then
    _op_bad "$ref" "$dest NOT materialized · op CLI not on PATH"
    return 0
  fi
  if _op_is_down; then
    _op_bad "$ref" "$dest NOT materialized · op already unavailable this load"
    return 0
  fi

  dir="${dest%/*}"
  if [[ $dir == "$dest" ]]; then
    dir="." # bare filename, no slash
  elif [[ -z $dir ]]; then
    dir="/" # dest is a root-level path like /creds.json
  fi
  mkdir -p "$dir" || {
    _op_bad "$ref" "$dest NOT materialized · cannot create $dir"
    return 0
  }

  # Stage beside $dest so the install is an atomic rename and readers never
  # see a partial credential; umask 077 closes the pre-chmod window.
  tmp="$(umask 077 && mktemp "$dir/.op-file.XXXXXX")" || {
    _op_bad "$ref" "$dest NOT materialized · cannot create temp file in $dir"
    return 0
  }

  auth="$(_op_auth_mode)"
  # op read writes the field verbatim; --out-file keeps the bytes off stdout
  # so a binary/JSON credential is never echoed into the log.
  # --force: mktemp already created $tmp, and without it op stops to ask
  # whether to overwrite — an invisible prompt that would hang direnv.
  if err="$(op read "$ref" --out-file "$tmp" --force 2>&1 >/dev/null)"; then
    # An empty read is a failure with a zero exit status: installing it would
    # poison the "$dest exists" cache check on every future entry.
    if [[ ! -s $tmp ]]; then
      rm -f "$tmp"
      _op_bad "$ref" "$dest NOT materialized · read back empty"
      return 0
    fi
    if chmod 600 "$tmp" && mv -f "$tmp" "$dest"; then
      _op_ok "$ref" "→ $dest · $auth"
      return 0
    fi
    rm -f "$tmp"
    _op_bad "$ref" "$dest NOT materialized · could not install"
    return 0
  fi

  rm -f "$tmp"
  _op_bad "$ref" "$dest NOT materialized · op read failed: ${err%%$'\n'*}"
}

# use_onepassword_tpl <template> [output] [mode] — render a WHOLE template
# (unlike use_onepassword_file above, this is one or more op:// refs inline
# in an arbitrary config file, not a single vault item) to a real file, for
# tools that take no env var for a secret (npm/pnpm's registry token, a
# kubeconfig assembled from vaulted cluster creds). Exports nothing — point
# the tool at $out yourself (NPM_CONFIG_USERCONFIG, KUBECONFIG, …), which
# keeps this usable for fixed-path readers too. Same content-hash cache as
# use_onepassword, no TTL (the output file itself is the only copy — delete
# it, or run op_cleanup, to force a re-render).
use_onepassword_tpl() {
  local tpl="${1:-}" out="${2:-}" mode="${3:-600}" dir base fp auth
  if [[ -z "$tpl" ]]; then
    _op_bad "use_onepassword_tpl" "usage: use_onepassword_tpl <template> [output] [mode]"
    return 0
  fi
  if [[ ! -f "$tpl" ]]; then
    _op_bad "$tpl" "no such template in $PWD · skipped"
    return 0
  fi
  if [[ -z "$out" ]]; then
    out="${tpl%.tpl}"
    if [[ "$out" == "$tpl" ]]; then
      _op_bad "$tpl" "no .tpl suffix · pass an explicit output path"
      return 0
    fi
  fi
  watch_file "$tpl"

  # Refused outright: plaintext secrets that the next `git add -A` would
  # commit. Add it to .gitignore or render outside the repo.
  if ! _op_gitignored "$out"; then
    _op_bad "$tpl" "refusing to render secrets to $out · in this repo and NOT gitignored"
    return 0
  fi

  dir="$(_op_cache_dir)" || {
    _op_gave_up "$tpl" "$out" "cannot create $(direnv_layout_dir)/op"
    return 0
  }
  base="$dir/$(_op_slug "$tpl")"
  fp="$(_op_fingerprint "$tpl")"

  # $out is the artifact; the fingerprint says which template it came from.
  if [[ -f "$out" && "$fp" == "$(cat "$base.hash" 2>/dev/null)" ]]; then
    _op_ok "$tpl" "$out · current"
    return 0
  fi

  if ! has op; then
    _op_gave_up "$tpl" "$out" "op CLI not on PATH"
    return 0
  fi
  if _op_is_down; then
    _op_gave_up "$tpl" "$out" "op already unavailable this load"
    return 0
  fi

  auth="$(_op_auth_mode)"
  if _op_render "$tpl" "$out" "$mode"; then
    printf '%s\n' "$fp" >"$base.hash"
    _op_ok "$tpl" "→ $out $_OP_NUM(0$mode)$_OP_DIM · $auth"
  else
    _op_gave_up "$tpl" "$out" "$_OP_ERR"
    _op_hint
  fi
}
