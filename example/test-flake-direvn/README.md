# flake + direnv dev environment demo

Python (FastAPI) backend + React (Vite) frontend, with the entire dev
environment declared per-repo via **nix flakes + direnv**, and a local
k8s dev loop via **Tilt + kind**.

| This is a example of the new pattern being adopted across my entire personal codebase

## The layering

```
home-manager        → your user base: shell, git, direnv itself, starship binary
  └─ flake.nix      → this repo's toolchain: python, uv, node, pnpm, tilt, kubectl, kind
      └─ uv / pnpm  → this repo's libraries: pyproject.toml + uv.lock, package.json + pnpm-lock.yaml
```

`cd` into the repo → direnv loads the flake dev shell (cached by
nix-direnv, instant after first build) and prepends it to PATH.
`cd` out → it all unloads. Nothing global ever changes.

- **flake.nix** — _tools_, pinned to a nixpkgs revision by flake.lock
- **pyproject.toml / package.json** — _libraries_, pinned by their own lockfiles
- **.envrc** — glue: `use flake`, repo-local `STARSHIP_CONFIG`, `.env.local` secrets
- **.config/starship.toml** — per-repo prompt (loaded via `STARSHIP_CONFIG`)
- **.vscode/** — repo settings + recommended extensions; `mkhl.direnv`
  makes VS Code itself see the flake's tools

## Quickstart

```sh
direnv allow   # once, after cloning — builds the dev shell AND installs
               # backend (.venv) + frontend (node_modules) deps automatically
```

Dep installs are driven by `.envrc` on entry, mtime-guarded against the
manifests/lockfiles so they're a no-op (~0.2s total entry) unless
something changed. Prefer no side effects on `cd`? Swap the install
commands in `.envrc` for an `echo "deps stale — run uv sync / pnpm install"`.

Run locally (two terminals):

```sh
cd backend  && uv run uvicorn main:app --reload   # :8000
cd frontend && pnpm dev                           # :5173, proxies /api → :8000
```

Run in a local k8s cluster instead:

```sh
kind create cluster --name flake-demo   # or use the shared dev cluster
tilt up                                 # builds images, deploys k8s/, live-syncs code
```

Tear down: `tilt down` / `kind delete cluster --name flake-demo`.

## Tests / build

```sh
cd backend  && uv run pytest
cd frontend && pnpm build
```

## Composing with the shared dev-cluster repo (`../cluster`)

This repo only knows _its own_ services. The shared cluster base owns the
cluster itself (kind config, ingress, shared infra). Two ways to compose:

1. Point this repo at the shared cluster's context — add it to
   `allow_k8s_contexts()` in the Tiltfile and just `tilt up` here.
2. Or have the base repo's Tiltfile `include('../test-flake-direvn/Tiltfile')`
   so one `tilt up` in the cluster repo brings up infra + all app repos.

## Secrets (1Password, ESO-for-dev pattern)

Same shape as the cluster's external-secrets-operator + 1Password Connect,
mirrored onto the laptop:

| cluster                  | laptop                                               |
| ------------------------ | ---------------------------------------------------- |
| ESO operator + Connect   | home-manager: `op` CLI + `use_onepassword` direnv fn |
| ClusterSecretStore       | 1Password vault `dev`                                |
| ExternalSecret manifest  | committed `.env.tpl` of `op://` refs                 |
| secret sync into pod env | direnv entry → env vars in your shell                |

Naming: `op://dev/<repo-name>/<kebab-field>` (sections optional:
`.../db/url`); cross-project secrets live on a `shared` item. Point the
cluster's Connect token at the same `dev` vault and both sides consume
the same items.

Failure is soft by design: op missing / signed out / no CLI integration →
the shell still loads, secrets just don't, with a warning. `.env.local`
(gitignored) remains for un-vaulted local overrides and wins over vault
values. One-time per machine: 1Password app → Settings → Developer →
"Integrate with 1Password CLI".

## Gotchas

- **git + flakes**: once this folder is `git init`-ed, nix only sees
  _tracked_ files — `git add flake.nix` or `use flake` fails with
  "path does not exist".
- **mise**: not needed here. The flake dev shell does mise's job
  (per-repo tool pinning) but pins the whole closure. Keep repos on one
  system or the other, not both.
- **pnpm 11**: build-script approvals live in `pnpm-workspace.yaml`
  (`allowBuilds`), needed for esbuild's postinstall.
