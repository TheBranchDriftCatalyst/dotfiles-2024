# catalyst dotfiles — everything after layer 0.
#   just            list recipes
#   just check      evaluate the flake (fast, no build)
#   just build      compile — CHANGES NOTHING
#   just switch     activate
#   just test       full end-to-end in a throwaway container

set shell := ["bash", "-uc"]

# darwin configs are named by real hostname; linux targets are generic.
host := if os() == "macos" { `hostname -s` } else if arch() == "aarch64" { "linux-generic-arm" } else { "linux-generic" }
image := "catalyst-dotfiles-nix"

default:
    @just --list

# Evaluate the flake without building. First gate.
check:
    nix flake check --all-systems

# Show what this flake exposes.
show:
    nix flake show

# Compile the config. Does NOT touch your system — the primary safety gate.
build:
    #!/usr/bin/env bash
    set -euo pipefail
    if [[ "$(uname -s)" == "Darwin" ]]; then
      nix run nix-darwin -- build --flake ".#{{host}}" |& (command -v nom >/dev/null && nom || cat)
    else
      nix build ".#homeConfigurations.{{host}}.activationPackage" \
        |& (command -v nom >/dev/null && nom || cat)
    fi

# Exact package-level diff between the current generation and a fresh build.
diff: build
    #!/usr/bin/env bash
    set -euo pipefail
    current=$([[ "$(uname -s)" == "Darwin" ]] && echo /run/current-system || echo ~/.local/state/nix/profiles/home-manager)
    nix run nixpkgs#nvd -- diff "$current" ./result

# Activate. Run `just build` and `just diff` first.
# Prefers nh (tree output + built-in nvd diff); falls back to the raw
# rebuild if nh isn't installed yet (first bootstrap).
switch:
    #!/usr/bin/env bash
    set -euo pipefail
    if [[ "$(uname -s)" == "Darwin" ]]; then
      # ── one password prompt, and it happens HERE ──────────────────────
      # nh escalates only at the activation step, which lands minutes into
      # the run — long after you have looked away, and then it blocks on a
      # prompt nobody is watching. Priming the sudo timestamp up front moves
      # the prompt to the one moment you are definitely still at the keyboard.
      # sudo cannot prompt without a TTY, so a non-interactive runner (an
      # agent's bash, a CI step, `just switch` piped into something) dies right
      # here instead of minutes later inside nh. Failing this early is correct;
      # the stock sudo message just does not say WHY a rebuild wanted a
      # password, so say it.
      if ! sudo -v; then
        echo >&2
        echo "!! switch needs root: nh escalates at the activation step." >&2
        if [ ! -t 0 ]; then
          echo "   No TTY here, so sudo had nothing to prompt on. Run \`just switch\`" >&2
          echo "   from a real terminal — or prime the timestamp there first with" >&2
          echo "   \`sudo -v\`, and this will reuse it." >&2
        fi
        exit 1
      fi
      # The default timestamp grace is 5 minutes and a cold rebuild blows
      # straight past it, which is the other way this turns into a second
      # prompt. Refresh in the background until the recipe exits.
      # The parent-liveness check is load-bearing, not belt-and-braces: a
      # successful `sudo -n true` REFRESHES the timestamp, so a loop guarded only
      # on the cache sustains its own exit condition and would orphan forever if
      # this recipe were SIGKILLed past the trap. `$$` is the recipe's pid even
      # inside the subshell, so the loop dies with it either way.
      ( while kill -0 "$$" 2>/dev/null && sudo -n true 2>/dev/null; do sleep 50; done ) &
      _sudo_keepalive=$!
      trap 'kill "${_sudo_keepalive}" 2>/dev/null || true' EXIT
      if command -v nh >/dev/null; then
        # nh buffers activation output and drops it on darwin (nh#233, see
        # switch-raw below), so an activation-script failure can pass silently.
        # Activation entries that matter write a durable log; surface it here
        # rather than trusting what nh chose to print.
        nh darwin switch .
        for _log in ~/.claude/.ecc-install.log; do
          [ -s "$_log" ] || continue
          if grep -qi 'error\|failed\|SETUP_FAILED' "$_log"; then
            echo
            echo "!! activation reported a failure in $(basename "$_log"):"
            sed 's/^/     /' "$_log"
          fi
        done
      else
        sudo nix run nix-darwin -- switch --flake ".#{{host}}"
      fi
    else
      if command -v nh >/dev/null; then
        nh home switch . -c "{{host}}"
      else
        nix run home-manager/master -- switch --flake ".#{{host}}"
      fi
    fi

# The raw activation path, bypassing nh — for when nh misbehaves
# (it has a known silent-failure edge on darwin: nix-community/nh#233).
switch-raw:
    #!/usr/bin/env bash
    set -euo pipefail
    if [[ "$(uname -s)" == "Darwin" ]]; then
      sudo nix run nix-darwin -- switch --flake ".#{{host}}"
    else
      nix run home-manager/master -- switch --flake ".#{{host}}"
    fi

# Roll back to the previous generation.
rollback:
    #!/usr/bin/env bash
    if [[ "$(uname -s)" == "Darwin" ]]; then
      sudo nix run nix-darwin -- --rollback
    else
      nix run home-manager/master -- generations
      echo "pick one above and run its activate script"
    fi

# Update all flake inputs.
update:
    nix flake update

gc:
    nix-collect-garbage --delete-older-than 30d

# One formatter for the whole repo (treefmt: nixfmt + shfmt + stylua +
# prettier). `just fmt-check` is the CI/no-write flavor.
fmt:
    nix fmt

fmt-check:
    nix fmt -- --ci

# Register the repo's pre-commit gate (gitleaks + lint). Bootstrap does this
# too; run it after any manual clone.
hooks:
    git config core.hooksPath .githooks
    @echo "✔ hooks registered — commits now gated by .githooks/pre-commit"

# Run the pre-commit checks against the working tree without committing.
lint:
    git stash -q --keep-index 2>/dev/null || true
    -.githooks/pre-commit
    git stash pop -q 2>/dev/null || true

# ── catalyst config (1Password-backed, never in git) ─────────────────────────
# ~/.catalyst/config.yaml carries org-identifying data and this repo is public,
# so the file lives in ~/.catalyst and 1Password only. The LOCAL copy is
# authoritative — catalyst writes it — so syncing is always a deliberate act.
# `just switch` warns when the two have drifted; these move them.

# Upload the local config.yaml to 1Password (creates the document first time).
catalyst-config-push:
    #!/usr/bin/env bash
    set -euo pipefail
    f="$HOME/.catalyst/config.yaml"
    item="catalyst-config-$(scutil --get LocalHostName 2>/dev/null || hostname -s)"
    [[ -f "$f" ]] || { echo "no $f to push" >&2; exit 1; }
    if op document get "$item" --vault dev --out-file /dev/null --force >/dev/null 2>&1; then
      op document edit "$item" "$f" --vault dev
      echo "✔ pushed $f → 1Password (dev/$item)"
    else
      op document create "$f" --title "$item" --vault dev
      echo "✔ created 1Password document dev/$item from $f"
    fi

# Overwrite the local config.yaml with 1Password's copy. Backs up first.
catalyst-config-pull:
    #!/usr/bin/env bash
    set -euo pipefail
    f="$HOME/.catalyst/config.yaml"
    item="catalyst-config-$(scutil --get LocalHostName 2>/dev/null || hostname -s)"
    [[ -f "$f" ]] && cp "$f" "$f.bak" && echo "backed up → $f.bak"
    mkdir -p "$(dirname "$f")"
    op document get "$item" --vault dev --out-file "$f" --force
    chmod 600 "$f"
    echo "✔ pulled 1Password (dev/$item) → $f"

# Show what differs between the local config.yaml and the 1Password copy.
catalyst-config-diff:
    #!/usr/bin/env bash
    set -euo pipefail
    t=$(mktemp); trap 'rm -f "$t"' EXIT
    item="catalyst-config-$(scutil --get LocalHostName 2>/dev/null || hostname -s)"
    op document get "$item" --vault dev --out-file "$t" --force >/dev/null
    diff -u "$t" "$HOME/.catalyst/config.yaml" \
      --label '1Password' --label 'local' && echo "✔ in sync"

# Delete rendered op:// secret caches. direnv re-renders on the next `cd`, at
# the cost of one biometric prompt. No arg = this repo; `all` = everywhere
# under $HOME, which is the only way to reach projects you no longer enter.
op-cache-clear scope="here":
    #!/usr/bin/env bash
    set -euo pipefail
    if [[ "{{scope}}" == "all" ]]; then
      find "$HOME" -name op-env.cache -type f -print -delete 2>/dev/null || true
    else
      find . -name op-env.cache -type f -print -delete
    fi
    echo "✔ cleared (deleted files listed above, if any)"

# ── testing ─────────────────────────────────────────────────────────────────

# Full end-to-end: build + activate + assert, in a throwaway container.
# Proves homeConfigurations and every shared home/ module.
# Cannot prove darwinConfigurations — that needs `just build` on macOS.
# The named volume caches /nix between runs — without it every iteration
# re-downloads ~100 packages. `just test-clean` drops the cache too.
test:
    docker build -f test/Dockerfile -t {{image}} .
    docker run --rm -v catalyst-nix-store:/nix {{image}} ./test/run.sh

# The direnv helper library, end to end: real direnv, stubbed `op` CLI.
# Seconds, no container — this is the gate for anything under home/direnv/.
test-direnv:
    ./test/direnv/run.sh

# Same suite, but against what home-manager actually installed into ~/.config.
test-direnv-installed:
    ./test/direnv/run.sh ~/.config/direnv/lib/onepassword.sh

# The sketchybar popup state machine, with `sbar` stubbed — no bar process, no
# macOS, sub-second. Section 2 is a regression test for the mach IPC DEADLOCK
# that froze the bar several times a day: it fails if the sbar.delay guard in
# widgets.lua is ever "simplified" away (full writeup in harness.lua).
# Seconds, no container — the gate for anything under darwin/sketchybar/.
test-sketchybar:
    ./test/sketchybar/run.sh

# The mach send contract both IPC patches depend on. A send timeout ALONE does
# NOT bound a send — the library retries on interrupt and reuses the original
# timeout — which is exactly the bug that shipped once already. Fails loudly if
# MACH_SEND_INTERRUPT is ever dropped from darwin/patches/ (full writeup at the
# top of send_bounded_test.c). Real mach IPC, no bar process, ~5s.
test-mach:
    ./test/mach/run.sh

# Interactive shell in the test container, for poking at failures.
test-shell:
    docker build -f test/Dockerfile -t {{image}} .
    docker run --rm -it -v catalyst-nix-store:/nix {{image}}

# Tear down test artifacts.
test-clean:
    -docker rmi {{image}}
    -docker volume rm catalyst-nix-store
    -rm -f result result-*

# ── vm / containers (colima replaces Docker Desktop) ────────────────────────

# Start the container VM. k8s=true adds a k3s cluster inside it
# (replaces minikube/k3d from the old setup).
vm k8s="false":
    #!/usr/bin/env bash
    set -euo pipefail
    if [[ "{{k8s}}" == "true" ]]; then
      colima start --cpu 4 --memory 8 --disk 60 --kubernetes
    else
      colima start --cpu 4 --memory 8 --disk 60
    fi
    docker context use colima >/dev/null
    colima status

vm-stop:
    colima stop

vm-destroy:
    colima delete --force

# Absorb settings the app wrote into ~/.claude/settings.json back into the repo.
# That file is app-owned on purpose — it is rewritten by rename(2), so it cannot
# be a symlink (the long version is in home/claude.nix's header). The Stop hook
# runs this after every turn, so it is normally a no-op by the time you reach
# for it; it is here for the times you want to look.
claude-sync:
    ./scripts/claude-settings-sync.sh

# The other direction: repo -> ~/.claude/settings.json, for when the tracked
# copy was hand-edited. Refuses while the live file holds anything unabsorbed,
# so it cannot overwrite a setting the app made and the repo has not seen.
# Rare by design — settings normally change through /config, not by editing JSON.
claude-push:
    ./scripts/claude-settings-sync.sh --push

# Is ECC actually installed and active? Answers the question without guessing:
# every line is a fact read from disk or from Claude Code itself.
ecc-status:
    #!/usr/bin/env bash
    # no `set -e` — every probe must run even when the earlier ones fail
    want=$(grep -m1 'version = "' home/claude.nix | sed 's/.*"\(.*\)".*/\1/')
    enable=$(grep -m1 'enable = ' home/claude.nix | tr -d ' ;' | cut -d= -f2)
    stamp=~/.claude/.ecc-version
    settings=dotfiles/claude/settings.json
    printf '  %-22s %s\n' "declared (nix)" "enable=$enable version=$want"
    printf '  %-22s %s\n' "stamp file" "$([ -r $stamp ] && cat $stamp || echo '<absent — installer never completed>')"
    printf '  %-22s %s\n' "enabledPlugins" "$(jq -r '(.enabledPlugins // {}) | has("ecc@ecc")' $settings 2>/dev/null)"
    printf '  %-22s %s\n' "marketplace" "$(jq -r '(.extraKnownMarketplaces // {}) | keys | join(",") | select(.!="") // "<none>"' $settings 2>/dev/null)"
    # installed_plugins.json is the authoritative install record. NOT a glob of
    # ~/.claude/plugins/ — an earlier version of this recipe globbed '*ecc*'
    # there and always missed, because a marketplace install lands under
    # plugins/cache/<marketplace>/<name>/<version>/. It reported
    # "<not downloaded>" for an install that was present and working.
    registry=~/.claude/plugins/installed_plugins.json
    installpath=$(jq -r '.plugins["ecc@ecc"][0].installPath // empty' $registry 2>/dev/null)
    printf '  %-22s %s\n' "plugin content" "${installpath:-<not downloaded>}"
    # Hooks ship INSIDE the plugin (its hooks/hooks.json); settings.json carries
    # none for a plugin install. Both are printed because 0-in-settings is the
    # CORRECT reading here and used to look like a broken install.
    hooksjson="$installpath/hooks/hooks.json"
    if [ -n "$installpath" ] && [ -r "$hooksjson" ]; then
      printf '  %-22s %s\n' "hooks (plugin)" "$(jq -r '[(.hooks//{})[][]?.hooks[]?]|length' $hooksjson 2>/dev/null) entries / $(jq -r '(.hooks//{})|length' $hooksjson 2>/dev/null) events"
    else
      printf '  %-22s %s\n' "hooks (plugin)" "<no hooks.json in the install>"
    fi
    printf '  %-22s %s\n' "hooks in settings" "$(jq -r '[.hooks // {} | to_entries[] | .value[]?.hooks[]?.command] | map(select(test("ecc";"i"))) | length' $settings 2>/dev/null) (0 is correct for a plugin install)"
    # the authoritative check: ask Claude Code, not the filesystem
    if command -v claude >/dev/null; then
      printf '  %-22s %s\n' "claude plugin list" "$(claude plugin list 2>/dev/null | grep -i ecc || echo '<ecc not listed>')"
    fi
    echo
    on=$(jq -r '(.enabledPlugins // {}) | has("ecc@ecc")' $settings 2>/dev/null)
    have=$(cat $stamp 2>/dev/null)
    if [ "$enable" != true ]; then
      echo "  => OFF by declaration (enable = false)$([ "$on" = true ] && echo ' BUT STILL INSTALLED — nix will not remove it; use /plugin uninstall ecc@ecc')"
    elif [ "$on" = true ] && [ "$have" = "$want" ]; then
      echo "  => ON at the pinned version, installed by nix"
    elif [ "$on" = true ]; then
      echo "  => ON, but NOT installed by nix (stamp '${have:-absent}' != '$want')."
      echo "     Means it was installed by hand, or activation was skipped. The next"
      echo "     switch that actually runs activation will reconcile and stamp it."
    else
      echo "  => ARMED but NOT INSTALLED — activation has not run successfully yet"
    fi
    # `|| true` matters: this is the recipe's last command, so a missing log
    # would otherwise make `just ecc-status` exit 1 on a perfectly healthy box.
    if [ -s ~/.claude/.ecc-install.log ]; then
      echo; echo "  last install attempt (~/.claude/.ecc-install.log):"
      tail -4 ~/.claude/.ecc-install.log | sed 's/^/    /'
    fi || true
    exit 0
