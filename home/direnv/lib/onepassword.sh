# shellcheck shell=bash
# ─────────────────────────────────────────────────────────────────────────────
# onepassword.sh :: direnv helpers — installed to ~/.config/direnv/lib/
#
# ESO-for-dev: the cluster syncs secrets via external-secrets-operator +
# 1Password Connect; this is the laptop-side mirror. Repos commit an .env.tpl
# of op:// references (never values) and call `use_onepassword` from .envrc —
# entering the repo materializes them as env vars.
# Requires the 1Password app's "Integrate with CLI" toggle for biometrics.
#
# CONTRACT
#   - direnv sources every ~/.config/direnv/lib/*.sh BEFORE direnvrc and
#     before the .envrc, so these run with the full direnv stdlib in scope
#     (has, watch_file, direnv_layout_dir, log_status, log_error). This file
#     is NOT standalone bash — it is only ever sourced by direnv.
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
# ─────────────────────────────────────────────────────────────────────────────

# Cache format written by use_onepassword. Bumping this string invalidates
# every cache on disk (the loader refuses a header it does not recognize),
# which is the migration path for any change to the payload below.
__OP_ENV_CACHE_VERSION='# op-env v1'

# __op_env_cache_file — absolute path of this directory's rendered env cache.
# Anchored on direnv_layout_dir (honours a repo-local `direnv_layout_dir`
# override) rather than a hardcoded $PWD/.direnv.
__op_env_cache_file() {
  echo "$(direnv_layout_dir)/op-env.cache"
}

# __op_env_load <cache> <ttl-minutes> <template>
#
# Sources <cache> iff it is (a) our format, (b) rendered from <template>,
# (c) newer than it, and (d) inside the TTL. Returns 0 on a hit, 1 on any miss
# — the caller then renders. Deliberately fork-free on the hit path:
# EPOCHSECONDS is a bash-5 builtin, and the key count rides in the header so
# nothing has to re-scan the file. `date` is only reached on bash < 5.
__op_env_load() {
  local cache="$1" ttl="$2" tpl="$3"
  local header="" ts="" keys="" now=""

  [[ -f $cache ]] || return 1
  # A template edited after the render wins over any TTL.
  [[ $cache -nt $tpl ]] || return 1

  IFS= read -r header <"$cache" || return 1
  [[ $header == "$__OP_ENV_CACHE_VERSION "* ]] || return 1

  # header: "# op-env v1 keys=<n> ts=<epoch> tpl=<path>" — tpl last, because a
  # path may contain spaces and takes the whole remainder of the line.
  keys="${header##*keys=}"
  keys="${keys%% *}"
  ts="${header##*ts=}"
  ts="${ts%% *}"
  [[ $ts =~ ^[0-9]+$ ]] || return 1
  # Two .envrc calls with different templates share one cache file; without
  # this the second would silently inherit the first one's environment.
  [[ ${header##*tpl=} == "$tpl" ]] || return 1

  now="${EPOCHSECONDS:-}"
  [[ -n $now ]] || now="$(date +%s)"
  (((now - ts) < (ttl * 60))) || return 1

  # shellcheck disable=SC1090
  source "$cache" || return 1
  log_status "1password: loaded ${keys:-?} secret(s) from cache (no prompt)"
  return 0
}

# use_onepassword [template] — render op:// refs into exported env.
#
# CACHED. Every new shell re-runs .envrc, and an uncached `op inject` is a
# biometric prompt each time — unusable in practice. The rendered env is kept
# at <layout-dir>/op-env.cache (0600, gitignored) and reused until the
# template changes or the TTL lapses.
#
# This is a deliberate reversal of the earlier "secrets touch disk only for
# milliseconds" stance: the values now persist, 0600, inside the repo's
# .direnv/. That is the same exposure .env.local already carries, and
# .direnv/ is gitignored, so the trade buys a usable prompt-free shell.
# Tune with OP_ENV_CACHE_TTL_MINUTES (default 480 = 8h); set it to 0 to
# disable caching entirely. Bust it by hand with:
#   rm .direnv/op-env.cache
use_onepassword() {
  local tpl="${1:-.env.tpl}"
  local cache ttl layout tmp render err n rc

  if [[ ! -f $tpl ]]; then
    log_error "use_onepassword: no $tpl in $PWD — skipping"
    return 0
  fi
  # The ONLY correct reload trigger. Note we never watch the cache itself:
  # watching a file we rewrite makes direnv reload on every prompt.
  watch_file "$tpl"

  ttl="${OP_ENV_CACHE_TTL_MINUTES:-480}"
  if [[ ! $ttl =~ ^[0-9]+$ ]]; then
    log_error "use_onepassword: OP_ENV_CACHE_TTL_MINUTES='$ttl' is not a whole number — treating as 0 (no cache)"
    ttl=0
  fi

  cache="$(__op_env_cache_file)"
  layout="${cache%/*}"

  if ((ttl > 0)) && __op_env_load "$cache" "$ttl" "$tpl"; then
    return 0
  fi

  if ! has op; then
    __op_env_fallback "$cache" "$ttl" "op CLI not on PATH"
    return 0
  fi

  mkdir -p "$layout" || {
    log_error "use_onepassword: cannot create $layout — secrets NOT loaded"
    return 0
  }

  # Render inside the layout dir, not /tmp: same filesystem as the cache (so
  # the install below is an atomic rename, never a half-written cache another
  # shell can source) and one less place secrets land. umask 077 covers the
  # window before the explicit chmod.
  tmp="$(umask 077 && mktemp "$layout/op-env.XXXXXX")" || {
    log_error "use_onepassword: cannot create temp file in $layout — secrets NOT loaded"
    return 0
  }

  # 2>&1 >/dev/null captures op's diagnostics while dropping its stdout
  # (it echoes the -o path). Runs in an `if` so errexit cannot abort here.
  if err="$(op inject -f -i "$tpl" -o "$tmp" 2>&1 >/dev/null)"; then
    # Do NOT use the stdlib dotenv() — it watch_files its input, and watching
    # a file we rewrite makes direnv reload on every prompt. Render to a bash
    # snippet once here so the cache-hit path is a plain `source`.
    # "${direnv:-direnv}": direnv exports its own absolute path as $direnv;
    # the binary is not guaranteed to be on the .envrc's PATH.
    if render="$("${direnv:-direnv}" dotenv bash "$tmp")"; then
      n="$(grep -c '^[A-Za-z_][A-Za-z0-9_]*=' "$tmp")" || n=0
      if __op_env_write "$cache" "$layout" "$n" "$tpl" "$render"; then
        # shellcheck disable=SC1090
        source "$cache"
        log_status "1password: loaded $n secret(s) from $tpl"
      else
        # Cache unwritable is not fatal — export for this shell anyway.
        eval "$render"
        log_error "use_onepassword: could not write $cache — loaded $n secret(s) UNCACHED (expect a prompt per shell)"
      fi
      rm -f "$tmp"
      return 0
    fi
    rc="parse of rendered $tpl failed"
  else
    rc="op inject failed: ${err%%$'\n'*}"
  fi

  rm -f "$tmp"
  __op_env_fallback "$cache" "$ttl" "$rc"
  return 0
}

# __op_env_write <cache> <layout> <keys> <template> <render> — publish the
# cache atomically. A concurrent shell either sees the old cache or the new
# one, never a truncated one, because mv(1) within a filesystem is a rename.
__op_env_write() {
  local cache="$1" layout="$2" keys="$3" tpl="$4" render="$5"
  local staged now
  now="${EPOCHSECONDS:-}"
  [[ -n $now ]] || now="$(date +%s)"

  staged="$(umask 077 && mktemp "$layout/op-env.stage.XXXXXX")" || return 1
  {
    printf '%s keys=%s ts=%s tpl=%s\n' "$__OP_ENV_CACHE_VERSION" "$keys" "$now" "$tpl"
    printf '%s\n' "$render"
  } >"$staged" || {
    rm -f "$staged"
    return 1
  }
  chmod 600 "$staged" || {
    rm -f "$staged"
    return 1
  }
  mv -f "$staged" "$cache" || {
    rm -f "$staged"
    return 1
  }
}

# __op_env_fallback <cache> <ttl> <reason> — op could not render. A stale
# cache beats an empty environment, but say so loudly: the values may predate
# a rotation. Ignores the TTL's expiry — that is what "stale" means here — but
# still honours ttl=0, which asks for no cache at all, fallback included.
__op_env_fallback() {
  local cache="$1" ttl="$2" reason="$3"
  local header="" keys="?"

  if ((ttl > 0)) && [[ -f $cache ]]; then
    IFS= read -r header <"$cache" || header=""
    if [[ $header == "$__OP_ENV_CACHE_VERSION "* ]]; then
      keys="${header##*keys=}"
      keys="${keys%% *}"
      # shellcheck disable=SC1090
      if source "$cache"; then
        log_error "use_onepassword: $reason — using STALE cache ($keys secret(s))"
        return 0
      fi
    fi
  fi
  log_error "use_onepassword: $reason — secrets NOT loaded"
}

# use_onepassword_file <op://vault/item/field> <dest> — materialize a FILE
# secret that `op inject` cannot render: 1Password Connect credentials, a
# keypair, a kubeconfig. The env-var half of the pattern is use_onepassword
# above; this is the file half.
#
# Cached by design: an existing non-empty $dest is left alone, so entering the
# repo costs nothing after the first time. Delete the file to re-fetch. Same
# soft-fail contract as use_onepassword — a missing/locked op warns, it never
# breaks the shell.
use_onepassword_file() {
  local ref="${1:-}" dest="${2:-}"
  local dir tmp err

  if [[ -z $ref || -z $dest ]]; then
    log_error "use_onepassword_file: usage: use_onepassword_file <op://vault/item/field> <dest>"
    return 0
  fi
  # -s not -f: a 0-byte dest is a failed earlier fetch, not a cache hit.
  if [[ -s $dest ]]; then
    return 0
  fi

  if ! has op; then
    log_error "use_onepassword_file: op CLI not on PATH — $dest NOT materialized"
    return 0
  fi

  dir="${dest%/*}"
  if [[ $dir == "$dest" ]]; then
    dir="." # bare filename, no slash
  elif [[ -z $dir ]]; then
    dir="/" # dest is a root-level path like /creds.json
  fi
  mkdir -p "$dir" || {
    log_error "use_onepassword_file: cannot create $dir — $dest NOT materialized"
    return 0
  }

  # Stage beside $dest so the install is an atomic rename and readers never
  # see a partial credential; umask 077 closes the pre-chmod window.
  tmp="$(umask 077 && mktemp "$dir/.op-file.XXXXXX")" || {
    log_error "use_onepassword_file: cannot create temp file in $dir — $dest NOT materialized"
    return 0
  }

  # op read writes the field verbatim; --out-file keeps the bytes off stdout
  # so a binary/JSON credential is never echoed into the log.
  # --force: mktemp already created $tmp, and without it op stops to ask
  # whether to overwrite — an invisible prompt that would hang direnv.
  if err="$(op read "$ref" --out-file "$tmp" --force 2>&1 >/dev/null)"; then
    # An empty read is a failure with a zero exit status: installing it would
    # poison the "$dest exists" cache check on every future entry.
    if [[ ! -s $tmp ]]; then
      rm -f "$tmp"
      log_error "use_onepassword_file: $ref read back empty — $dest NOT materialized"
      return 0
    fi
    if chmod 600 "$tmp" && mv -f "$tmp" "$dest"; then
      log_status "1password: materialized $dest"
      return 0
    fi
    rm -f "$tmp"
    log_error "use_onepassword_file: could not install $dest — NOT materialized"
    return 0
  fi

  rm -f "$tmp"
  log_error "use_onepassword_file: op read failed for $ref: ${err%%$'\n'*} — $dest NOT materialized"
  return 0
}
