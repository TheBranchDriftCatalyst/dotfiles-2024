# How this actually works

No subshells, no shims, no wrapper processes. The entire mechanism is
**immutable packages + symlink farms + one PATH line**. This document walks the
machinery bottom-up, then explains exactly how the dotfiles ride on top of it.

## The four layers

### 1. The store — `/nix/store/`

Every package is a directory named by a cryptographic hash of *everything that
built it* — source, compiler, flags, dependencies:

```
/nix/store/mybady8qj35dgfqnghkm4jj1c1pl7p4y-eza-0.23.5/bin/eza
```

Store paths are immutable and read-only. Two versions of a tool coexist as two
directories; installing something can never overwrite or break something else.
This is why "works on my machine" stops being a sentence you say.

### 2. Profiles — symlink farms

"Installed" means "symlinked". Your user profile is a directory of links into
the store:

```
/etc/profiles/per-user/dj/bin/eza -> /nix/store/…-home-manager-path/bin/eza
                                       └─> /nix/store/…-eza-0.23.5/bin/eza
```

No copying, no `/usr/local`, no package database to corrupt. The farm *is* the
database.

### 3. PATH — the one line of "injection"

`/etc/zshenv` (written by nix-darwin) sources a script that prepends:

```
$HOME/.nix-profile/bin
/etc/profiles/per-user/$USER/bin     ← your home-manager packages
/run/current-system/sw/bin           ← system-level (darwin) packages
/nix/var/nix/profiles/default/bin    ← nix itself
```

That is the *entire* runtime mechanism. It feels transparent because it is —
plain `$PATH`, resolved by your shell like anything else.

### 4. Generations — snapshots you can flip between

```
/nix/var/nix/profiles/system-1-link   ← first activation
/nix/var/nix/profiles/system-2-link
/nix/var/nix/profiles/system-3-link   ← current
```

`just switch` builds a **new** symlink tree and atomically repoints one link.
`just rollback` repoints it back. Nothing is ever mutated in place — only
repointed — which is why activation is near-instant and undo is guaranteed.

A generation is a **pure function of the `.nix` files + `flake.lock`**. Same
inputs → bit-identical environment, on this Mac or any Linux box. That's the
entire trick behind "my terminal on any machine".

### Bonus: ephemeral execution

`nix run "nixpkgs#cowsay"` installs nothing: it pulls the package into the
store, runs the binary straight out of it, and leaves PATH untouched. Same
store, zero footprint. (Quote flake refs in zsh — our `extended_glob` setopt
makes bare `#` a glob operator.)

## How the dotfiles ride on this

Two deliberately different modes, chosen per file (**the hybrid rule**):

### Generated configs — pure store, read-only

`~/.zshrc`, `~/.config/git/config`, starship, tmux, ghostty, mise configs are
**compiled from the `home/*.nix` modules** into the store, and symlinked into
place by home-manager:

```
~/.zshrc -> /nix/store/…-home-manager-files/.zshrc     (read-only)
```

You don't edit these files — you edit the module that generates them, then
`just switch`. In exchange they are versioned, rollback-able, and identical on
every machine. Store-mode payload files that are too real-file-shaped to inline
in nix (tmux.conf, gitmessage, editorconfig.ini) live in **`home/dotfiles/`** —
the store twin of repo-root **`dotfiles/`**, which is the live set. Same word
on purpose: the directory encodes the mode, and a file moves between the two
only when its mode changes. The generated `.zshrc` is also the **orchestrator**: home-manager
emits compinit, plugin loading, and tool hooks in a controlled order (see
below).

### Live payload — editable without a rebuild

A small set of files are **out-of-store symlinks** pointing back into this
repo's working tree, because the application itself writes to them at runtime:

```
~/Library/Application Support/Code/User/settings.json -> <repo>/dotfiles/vscode/settings.json
~/.claude/settings.json                               -> <repo>/dotfiles/claude/settings.json
~/.claude/CLAUDE.md                                   -> <repo>/dotfiles/claude/CLAUDE.md
~/.claude/agents, commands, hooks                     -> <repo>/dotfiles/claude/…
```

(`hooks/` is a deliberate decider exception — operator-authored, but iterated
like the prompt, so it rides the live link.)

The rest of `~/.claude` (projects/, plugins/, sessions, caches) is runtime
state and stays a real, unmanaged directory — nix only plants links inside it.

Shell config and nvim were live once too; both melted into pure store
(2026-09). Nvim's plugins now come from nixpkgs so nothing writes into its
config, and the shell's command library moved to `home/zsh/*.zsh` — real,
syntax-highlighted files, but store-sourced. Editing them is rebuild-per-tweak,
and in exchange every generation snapshot captures the whole shell.

The command library runs a **curation contract** (see the header of each file
in `home/zsh/`): blocks are commented out with an operator note until actually
used. Uncomment → `just switch` → live. Still commented in a few months →
deletion candidate.

### The zsh startup order (load-bearing)

```
/etc/zshenv          nix-darwin: PATH + fpath           (layer 3 above)
~/.zshenv            home-manager: session vars
~/.zshrc             home-manager generated, in order:
  ├─ fpath += <store>/zsh/completions  (mkOrder 400 — BEFORE compinit)
  ├─ compinit                          (once; compdef exists from here on)
  ├─ plugins (abbr, autosuggest, syntax highlighting)
  ├─ source <store>/zsh/{aliases,functions,fzf-git}.zsh   (curated payload)
  ├─ keybindings, setopts, zstyles     (declared inline in home/zsh.nix)
  ├─ tool hooks: starship, direnv, zoxide, mise
  └─ fzf keybindings                   (guarded on a real TTY)
```

There is exactly one init mechanism: home-manager's `initContent` merge order.
The old numbered-file loop (`00_guards` first, everything depending on it) is
gone — the old setup also ran compinit three times, too late; the ordering
above is enforced by the module system and covered by the container test.

## Division of labour

| Manager | Owns | Never owns |
|---|---|---|
| **nix** | every CLI tool, shell config, fonts, macOS defaults | GUI apps, project runtimes |
| **homebrew** (driven *by* nix-darwin) | GUI casks + Mac App Store, kernel-extension apps | CLI tools |
| **mise** | per-project runtimes (`.tool-versions` / `mise.toml`) | anything global |

The rule that keeps three managers from becoming the old mess: **if a project
pins it → mise; if you use it everywhere → nix; if it has a .app or a kext →
brew.** Homebrew runs with `cleanup = "zap"`, so a cask exists only while a
`.nix` file says so.

## Edit workflows, quick reference

| You want to… | Do |
|---|---|
| add/change an alias or shell function | edit `home/zsh/*.zsh` (or `home/zsh.nix`) → `just switch` |
| tweak nvim | edit `home/nvim/` → `just switch` |
| add a CLI tool | add to `home/packages.nix` → `just switch` |
| add a GUI app | add cask in `hosts/<hostname>/default.nix` → `just switch` |
| change git/tmux/starship/ghostty config | edit the module in `home/` → `just switch` |
| change a macOS default | `hosts/<hostname>/default.nix` → `just switch` |
| undo any of the above | `just rollback` |
| update everything | `just update && just build && just diff` → `just switch` |
