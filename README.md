# catalyst dotfiles — Nix edition

One flake. macOS and any Linux distro, from the same module set.

```sh
# macOS
darwin-rebuild switch --flake  .   # hostname auto-selects

# Linux — any distro, including boxes you don't own
home-manager switch --flake .#linux-generic
```

**New here?** Read [docs/METHODOLOGY.md](docs/METHODOLOGY.md) — how the store,
symlink farms, PATH, and generations actually work, and how the dotfiles ride
on them (generated-vs-live, the zsh startup order, edit workflows).

## Why this exists

The previous setup ran three package managers with overlapping responsibility —
Homebrew, [afx](https://github.com/babarot/afx), and mise — and **15 tools were declared in
two of them at once**, with `~/bin` silently shadowing `$HOMEBREW_PREFIX/bin` via PATH order.

Consolidating onto afx alone was impossible: **`tmux` publishes source tarballs only**, and
**`eza` ships no darwin release assets**. nixpkgs builds both. That is the entire argument for
this rewrite — it is the only option that removes the overlap _and_ delivers a terminal that
installs on Linux.

The old system is preserved on the **`protecht`** branch and still works.

## Layout

```
flake.nix              inputs: nixpkgs, home-manager, nix-darwin, sops-nix
hosts/teakbookM5DJ/          nix-darwin: macOS defaults, Homebrew casks, fonts
hosts/linux-generic/        standalone home-manager overrides
home/
  default.nix          shared, imported by BOTH platforms
  packages.nix         the portable tool layer — replaces afx AND Brewfile.core
  zsh.nix              prompt-critical; see below
  git.nix tmux.nix starship.nix neovim.nix ghostty.nix catalyst.nix claude.nix
  darwin.nix linux.nix platform-conditional
  dotfiles/            raw payload, STORE mode (read-only, rebuild-per-tweak)
dotfiles/              raw payload, LIVE mode (symlinked, editable without a rebuild)
```

Two directories named `dotfiles`, deliberately: **`home/dotfiles/` is the
store set, repo-root `dotfiles/` is the live set.** Same kind of content —
real config files with real extensions — the location encodes the mode.
A file moves between them only when its mode changes (see the decider below).

## The hybrid symlink rule

home-manager normally symlinks config read-only into `/nix/store`. That is correct for
reproducibility and miserable for iteration. So:

| Path                                                       | Mode                             | Why                                                                               |
| ---------------------------------------------------------- | -------------------------------- | --------------------------------------------------------------------------------- |
| `~/Library/…/Code/User/settings.json`                      | **live** (`mkOutOfStoreSymlink`) | VS Code writes to it at runtime                                                   |
| `~/.claude/{settings.json, CLAUDE.md, agents/, commands/}` | **live** (`mkOutOfStoreSymlink`) | Claude Code writes via `/config`, `/memory`, `/agents`                            |
| `~/.claude/hooks/`                                         | **live** (deliberate exception)  | app never writes them, but hook scripts iterate like prompts, not like nix config |
| everything else                                            | pure store                       | reproducible, read-only                                                           |

**The `dotfiles/` folder is exactly the set of files that need symlinks — and
the ability decider is: does the _application itself_ write to the file?**
VS Code updates settings.json from its own UI, and you want those edits
persisted back into this repo — so it lives in `dotfiles/` behind a live
symlink. If only you (or nix) ever write a file, it's static config and
belongs in a `home/` module, not here. One deliberate exception:
`dotfiles/claude/hooks/` — nothing but the operator writes those scripts, but
they get tuned as often as the prompt they sit next to, so they ride the live
link rather than paying rebuild-per-tweak.

Shell config and nvim used to be live too; both melted into pure store
(2026-09): nvim's plugins now come from nixpkgs (no lazy-lock.json to write),
and the shell's command library lives in `home/zsh/*.zsh` under the curation
contract described in those files. Editing either is now rebuild-per-tweak.

## Things that bit us, encoded here so they can't recur

- **`compinit` must run before any `compdef`** (home/zsh/functions.zsh uses one). home-manager
  emits compinit ahead of `initContent`, which is why all shell payload is sourced from there.
- **afx was load-bearing beyond packages** — its `local` package sourced `~/.zsh/[0-9]*.zsh`.
  The first migration re-implemented that loop inside `home/zsh.nix`; the second melt (2026-09)
  deleted the loop and the `~/.zsh` directory entirely — HM's `initContent` is the only init
  mechanism now. A vendored 2015 `_git` completion had been silently shadowing zsh's modern one
  the whole time; the vendored `Completion/` dir is gone with it.
- **`tmux.conf` hardcoded `/bin/zsh`**, which under Nix is the wrong zsh. Now `${pkgs.zsh}/bin/zsh`.
- **Three competing fzf configs** collapsed into `programs.fzf`.
- **`.curlrc` had `-k`**, disabling TLS verification for every curl on the machine. Removed.
- **`.gitconfig` carried a plaintext PAT** and an employer email globally. Credentials are gone;
  identity is now `includeIf`-scoped by directory.

## What Homebrew still does

nix-darwin **does not install Homebrew** — it drives `brew bundle` for GUI apps. Casks are
declared in `hosts/<hostname>` with `cleanup = "zap"`, so unlisted apps are removed. `little-snitch`
installs a kernel extension and can never be a Nix package.

Nerd fonts, `1password-cli`, `ngrok` and `session-manager-plugin` moved to nixpkgs and are no
longer casks.

## Secrets: 1Password provisioning (new machine)

The dev-secrets layer is declarative — `op` CLI from `home/packages.nix`
(nixpkgs `_1password-cli`, cross-platform) and the `use_onepassword` direnv
function from `home/zsh.nix`. Only authentication is manual, once per machine:

**macOS**

1. `just switch` — installs `op` and the 1Password app (cask, `hosts/<hostname>`).
2. Open 1Password, sign in to the account.
3. Settings → Developer → **Integrate with 1Password CLI** (biometric auth for `op`).
4. Verify: `op vault list` → Touch ID prompt → vault list.

**Linux**

1. `just switch` — same `op` from the shared package list.
2. Desktop flow (optional): install the 1Password app from the **vendor's**
   deb/rpm/flatpak — nixpkgs' `_1password-gui` needs NixOS's polkit module for
   CLI integration, which generic distros can't provide — then enable
   Settings → Developer → CLI integration, same as macOS.
3. Headless flow: `op account add --address <acct>.1password.com --email <email>`
   then `eval $(op signin)` per session; or export `OP_SERVICE_ACCOUNT_TOKEN`
   for fully non-interactive use (CI, servers).
4. Verify: `op vault list`.

Repos consume secrets by committing an `.env.tpl` of `op://` references and
calling `use_onepassword` from `.envrc` — entering the repo materializes them
as env vars (ESO-for-dev; naming: `op://dev/<repo-name>/<kebab-field>`).

## Status

Skeleton written; **not yet validated** — Nix is not installed on this machine, so nothing here
has been evaluated. Gates, in order:

1. `nix flake check`
2. `darwin-rebuild build --flake  .   # hostname auto-selects` — compiles, **changes nothing**
3. Docker: provision `.#linux-generic` in a clean Debian container; assert a silent interactive shell
4. `darwin-rebuild switch`

### Known gaps

- afx is fully retired: its aliases live in `home/zsh.nix`, its fzf helper functions in
  `home/zsh/fzf-git.zsh`, and its 81 packages in `home/packages.nix`. The `.config/afx`
  directory is deleted; the `protecht` branch keeps the original YAMLs if archaeology is needed.
- The two babarot gists supply `gcp-context` and `kube-context`, called from the tmux
  `status-left`. Not yet packaged.
- `sops-nix` is wired as a flake input but no secrets are declared yet.
