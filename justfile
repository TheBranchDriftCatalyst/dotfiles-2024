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
      if command -v nh >/dev/null; then
        nh darwin switch .
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

# ── testing ─────────────────────────────────────────────────────────────────

# Full end-to-end: build + activate + assert, in a throwaway container.
# Proves homeConfigurations and every shared home/ module.
# Cannot prove darwinConfigurations — that needs `just build` on macOS.
# The named volume caches /nix between runs — without it every iteration
# re-downloads ~100 packages. `just test-clean` drops the cache too.
test:
    docker build -f test/Dockerfile -t {{image}} .
    docker run --rm -v catalyst-nix-store:/nix {{image}} ./test/run.sh

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
