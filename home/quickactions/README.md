# Finder Quick Actions, declaratively

`quick-actions.nix` assembles each action from the files here — no Automator:

```
Info.plist.tpl       NSServices block: menu label + file-type filter (@LABEL@, @FILETYPES@)
document.wflow.tpl   one Run Shell Script action (@COMMAND@, @ID@)
<action>.zsh         the actual script; files arrive as "$@"; @TOKENS@ = nix store paths
```

Add an action: drop a `.zsh` here, add a `bundles` entry in the module, switch.
User input happens via `osascript` dialogs (`display dialog`, `choose from list`)
— quick actions run in the GUI session, so real dialogs pop.

## Hard-won macOS lore (2026-09, macOS Tahoe)

1. **Copy, never symlink.** The Services scanner ignores `home.file`-symlinked
   `.workflow` bundles for menu purposes — a symlink is never a directory to
   its lstat-based walk. Activation wipe-and-copies real bundles into
   `~/Library/Services`. (Same bug class mac-app-util exists for with `.app`s.)

2. **Drop-in workflows are registered but NOT enabled.** macOS only auto-enables
   actions saved by Automator itself. The enable state lives in the `pbs`
   preferences domain, `NSServicesStatus`, keyed
   `"(null) - <menu label> - runWorkflowAsService"`. Activation stamps it via
   `defaults export pbs` → python `plistlib` merge → `defaults import pbs`
   (plain `defaults write -dict-add` corrupts non-ASCII labels — our emoji got
   stored as literal `\Ud83d` text), then `killall pbs` + `pbs -update` +
   `killall Finder`. Even Jamf-land never solved this without the plist write —
   their threads end at "open it in Automator and re-save".

3. **Placement inconsistency: they land in the _Services_ submenu, not the
   _Quick Actions_ submenu.** Right-click → Services → 🖼 Resize Image… etc.
   Everything above makes them _work_ from Services; the Quick Actions
   row/gallery appears reserved for actions Automator itself registered (or
   modern Action Extensions). We match a known-good workflow's Info.plist and
   workflowMetaData key-for-key (NSRequiredContext=Finder,
   serviceApplicationBundleID/Path, `…fileSystemObject.image` input,
   `…nothing` output) and they still classify as Services.
   **Do NOT add NSIconName**: tested 2026-09 — with it present the entries
   vanish from the Services menu entirely (macOS silently drops menu items
   whose icon it can't resolve in this context); removing it restored them.
   Suspected remaining gate: a private registration step Automator performs on
   save. If this ever matters enough: create one action manually in Automator,
   diff every byte + the pbs domain before/after, and update this note.

4. **The "modern" route was evaluated and rejected (2026-09).** Shortcuts-app
   quick actions DO land in the real Quick Actions row, and a hand-built
   unsigned `.shortcut` plist (Run Shell Script + `WFQuickActionSurfaces:
[Finder]`) assembles fine — but importing one requires `shortcuts sign`,
   which hard-requires an iCloud sign-in this machine doesn't have (and the
   Shortcuts DB can't be provisioned as files). Native Action Extensions need
   a signed Xcode app. So: Services submenu it is — one submenu deeper,
   zero manual steps, fully reproducible from `just switch`.

Debugging kit:

```
/System/Library/CoreServices/pbs -update            # rescan ~/Library/Services
/System/Library/CoreServices/pbs -dump_pboard        # what's registered
defaults read pbs NSServicesStatus                   # what's enabled
killall pbs Finder                                   # drop caches
```
