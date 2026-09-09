# catalyst dotfiles — Nix edition

One flake. macOS and any Linux distro, from the same module set.

```sh
# macOS
darwin-rebuild switch --flake .#dj-mac

# Linux — any distro, including boxes you don't own
home-manager switch --flake .#dj-linux
```

## Why this exists

The previous setup ran three package managers with overlapping responsibility —
Homebrew, [afx](https://github.com/babarot/afx), and mise — and **15 tools were declared in
two of them at once**, with `~/bin` silently shadowing `$HOMEBREW_PREFIX/bin` via PATH order.

Consolidating onto afx alone was impossible: **`tmux` publishes source tarballs only**, and
**`eza` ships no darwin release assets**. nixpkgs builds both. That is the entire argument for
this rewrite — it is the only option that removes the overlap *and* delivers a terminal that
installs on Linux.

The old system is preserved on the **`protecht`** branch and still works.

## Layout

```
flake.nix              inputs: nixpkgs, home-manager, nix-darwin, sops-nix
hosts/dj-mac/          nix-darwin: macOS defaults, Homebrew casks, fonts
hosts/dj-linux/        standalone home-manager overrides
home/
  default.nix          shared, imported by BOTH platforms
  packages.nix         the portable tool layer — replaces afx AND Brewfile.core
  zsh.nix              prompt-critical; see below
  git.nix tmux.nix starship.nix neovim.nix ghostty.nix catalyst.nix
  darwin.nix linux.nix platform-conditional
dotfiles/              raw payload, live-symlinked (editable without a rebuild)
```

## The hybrid symlink rule

home-manager normally symlinks config read-only into `/nix/store`. That is correct for
reproducibility and miserable for iteration. So:

| Path | Mode | Why |
|---|---|---|
| `~/.zsh/*` | **live** (`mkOutOfStoreSymlink`) | you edit aliases constantly |
| `~/.config/nvim` | **live** | lazy.nvim writes at runtime |
| everything else | pure store | reproducible, read-only |

## Things that bit us, encoded here so they can't recur

- **`compinit` must run before `40_functions.zsh`**, which calls `compdef`. home-manager emits
  compinit ahead of `initContent`, which is why the source loop lives there.
- **afx was load-bearing beyond packages** — its `local` package is what sourced
  `~/.zsh/[0-9]*.zsh`. `home/zsh.nix` is that replacement. Without it you get a shell with zero
  aliases, silently.
- **`tmux.conf` hardcoded `/bin/zsh`**, which under Nix is the wrong zsh. Now `${pkgs.zsh}/bin/zsh`.
- **Three competing fzf configs** collapsed into `programs.fzf`.
- **`.curlrc` had `-k`**, disabling TLS verification for every curl on the machine. Removed.
- **`.gitconfig` carried a plaintext PAT** and an employer email globally. Credentials are gone;
  identity is now `includeIf`-scoped by directory.

## What Homebrew still does

nix-darwin **does not install Homebrew** — it drives `brew bundle` for GUI apps. Casks are
declared in `hosts/dj-mac` with `cleanup = "zap"`, so unlisted apps are removed. `little-snitch`
installs a kernel extension and can never be a Nix package.

Nerd fonts, `1password-cli`, `ngrok` and `session-manager-plugin` moved to nixpkgs and are no
longer casks.

## Status

Skeleton written; **not yet validated** — Nix is not installed on this machine, so nothing here
has been evaluated. Gates, in order:

1. `nix flake check`
2. `darwin-rebuild build --flake .#dj-mac` — compiles, **changes nothing**
3. Docker: provision `.#dj-linux` in a clean Debian container; assert a silent interactive shell
4. `darwin-rebuild switch`

### Known gaps

- afx `plugin.env`/`snippet` aliases (`exa`→`eza` set, `rm=gomi`, `g=lazygit`, `cat=bat`,
  `BAT_PAGER`) are ported into `home/zsh.nix`. `dotfiles/.config/afx/` remains as reference
  until the fzf snippet functions (`fzf_git_add` and friends) are ported too.
- The two babarot gists supply `gcp-context` and `kube-context`, called from the tmux
  `status-left`. Not yet packaged.
- `sops-nix` is wired as a flake input but no secrets are declared yet.
