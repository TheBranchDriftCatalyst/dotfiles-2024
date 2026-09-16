# Finder Quick Actions (right-click → Quick Actions), declaratively.
#
# A Quick Action is a .workflow bundle in ~/Library/Services: an Info.plist
# whose NSServices block declares the menu label + file-type filter, and a
# document.wflow wrapping one Run Shell Script action (files as "$@").
# Templates and the per-action shell live as REAL files in ./quickactions/
# (IDE-highlighted, shellcheck-able); this module only substitutes @TOKENS@
# and assembles bundles. No Automator involved. Darwin-only: imported from
# darwin.nix, never home/default.nix.
#
# HARD-WON: bundles must be COPIED into ~/Library/Services, never
# home.file-symlinked — the Quick Actions gallery walks the dir with lstat
# semantics, so a symlinked bundle is never a directory to it and silently
# drops out (pbs still registers it as a legacy Service: a deceptive
# half-working state). Same bug class mac-app-util exists for with .apps.
# Also required for gallery classification (diffed against a known-good
# Automator quick action): NSRequiredContext=Finder in Info.plist and the
# serviceApplication*/serviceInput=…fileSystemObject.image/serviceOutput
# keys in workflowMetaData.
{
  pkgs,
  lib,
  ...
}:

let
  im = pkgs.imagemagick;

  # loadScript file {tokens} → script text with @TOKEN@s substituted.
  loadScript =
    file: tokens:
    builtins.replaceStrings (builtins.attrNames tokens) (builtins.attrValues tokens) (
      builtins.readFile file
    );

  # mkQuickAction: fill the two plist templates and assemble the bundle.
  mkQuickAction =
    {
      name,
      label,
      fileTypes,
      script,
    }:
    let
      id = builtins.substring 0 4 (builtins.hashString "md5" name);
      infoPlist =
        builtins.replaceStrings
          [ "@LABEL@" "@FILETYPES@" ]
          [
            label
            (lib.concatMapStrings (t: "<string>${t}</string>") fileTypes)
          ]
          (builtins.readFile ./quickactions/Info.plist.tpl);
      wflow =
        builtins.replaceStrings
          [ "@COMMAND@" "@ID@" ]
          [
            (lib.escapeXML script)
            id
          ]
          (builtins.readFile ./quickactions/document.wflow.tpl);
    in
    pkgs.runCommand "${name}.workflow"
      {
        inherit infoPlist wflow;
        passAsFile = [
          "infoPlist"
          "wflow"
        ];
      }
      ''
        mkdir -p $out/Contents
        cp $infoPlistPath $out/Contents/Info.plist
        cp $wflowPath $out/Contents/document.wflow
      '';

  # THE source of truth: one row per action. Everything else (bundle set,
  # pbs enablement labels) derives from this list — add a row + a .zsh file
  # and you're done.
  actions = [
    {
      name = "resize-image";
      label = "🖼 Resize Image…";
      fileTypes = [ "public.image" ];
      tokens = { };
    }
    {
      name = "convert-image";
      label = "🖼 Convert Image…";
      fileTypes = [ "public.image" ];
      tokens."@MAGICK@" = "${im}/bin/magick";
    }
    {
      name = "halve-image";
      label = "🖼 Halve Image (50%)";
      fileTypes = [ "public.image" ];
      tokens = { };
    }
    {
      name = "strip-metadata";
      label = "🕶 Strip Metadata";
      fileTypes = [ "public.image" ];
      tokens."@EXIFTOOL@" = "${pkgs.exiftool}/bin/exiftool";
    }
    {
      name = "combine-pdfs";
      label = "📄 Combine PDFs";
      fileTypes = [ "com.adobe.pdf" ];
      tokens."@QPDF@" = "${pkgs.qpdf}/bin/qpdf";
    }
    {
      name = "compress-pdf";
      label = "📄 Compress PDF";
      fileTypes = [ "com.adobe.pdf" ];
      tokens."@GS@" = "${pkgs.ghostscript}/bin/gs";
    }
    {
      name = "convert-mp4";
      label = "🎬 Convert to MP4";
      fileTypes = [ "public.movie" ];
      tokens."@FFMPEG@" = "${pkgs.ffmpeg}/bin/ffmpeg";
    }
    {
      name = "compress-video";
      label = "🎬 Compress Video";
      fileTypes = [ "public.movie" ];
      tokens."@FFMPEG@" = "${pkgs.ffmpeg}/bin/ffmpeg";
    }
    {
      name = "extract-audio";
      label = "🔊 Extract Audio";
      fileTypes = [ "public.movie" ];
      tokens."@FFMPEG@" = "${pkgs.ffmpeg}/bin/ffmpeg";
    }
    {
      name = "sha256-clipboard";
      label = "#️⃣ SHA-256 → Clipboard";
      fileTypes = [ "public.item" ];
      tokens = { };
    }
    {
      name = "clean-zip";
      label = "🗜 Clean Zip";
      fileTypes = [ "public.item" ];
      tokens = { };
    }
    {
      name = "prettify-json";
      label = "📝 Prettify JSON";
      fileTypes = [ "public.json" ];
      tokens."@JQ@" = "${pkgs.jq}/bin/jq";
    }
  ];

  # Derived: bundle set keyed by the action's kebab name (the menu shows
  # NSMenuItem's label — the on-disk bundle name is invisible to users)…
  bundles = builtins.listToAttrs (
    map (a: {
      name = "${a.name}.workflow";
      value = mkQuickAction {
        inherit (a) name label fileTypes;
        script = loadScript (./quickactions + "/${a.name}.zsh") a.tokens;
      };
    }) actions
  );
  # …and the pbs enablement labels (must match NSMenuItem exactly — they do,
  # by construction).
  labels = map (a: a.label) actions;

  # Enablement: macOS only auto-enables actions saved by Automator itself;
  # drop-ins register but stay OFF. Stamp pbs NSServicesStatus via
  # export → plistlib merge → import (defaults -dict-add corrupts non-ASCII
  # labels). See quickactions/README.md for the full lore.
  # `defaults` is called by ABSOLUTE path: home-manager activation runs with a
  # restricted PATH that excludes /usr/bin, so a bare `defaults` raises
  # FileNotFoundError and the enablement silently no-ops (the caller ends in
  # `|| true`). Same reason the invocation below uses /usr/bin/python3.
  enableScript = pkgs.writeText "enable-quick-actions.py" ''
    import plistlib, subprocess, sys
    raw = subprocess.run(["/usr/bin/defaults", "export", "pbs", "-"], capture_output=True, check=True).stdout
    d = plistlib.loads(raw) if raw.strip() else {}
    svc = d.setdefault("NSServicesStatus", {})
    entry = {"enabled_context_menu": True, "enabled_services_menu": True,
             "presentation_modes": {"ContextMenu": True, "ServicesMenu": True}}
    changed = False
    for label in ${builtins.toJSON labels}:
        key = f"(null) - {label} - runWorkflowAsService"
        if svc.get(key) != entry:
            svc[key] = dict(entry)
            changed = True
    if changed:
        p = subprocess.run(["/usr/bin/defaults", "import", "pbs", "-"], input=plistlib.dumps(d))
        sys.exit(p.returncode)
  '';
in
{
  # magick on PATH generally too — the convert action pins the store path,
  # but having it interactive matches the "image tooling lives here" intent.
  home.packages = [
    im
    pkgs.exiftool
  ];

  # Idempotent wipe-and-copy per managed bundle (see header: copies, never
  # symlinks); unmanaged bundles are left alone. Then enable + rescan.
  home.activation.installQuickActions = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    svc="$HOME/Library/Services"
    $DRY_RUN_CMD mkdir -p "$svc"
    ${lib.concatStringsSep "\n" (
      lib.mapAttrsToList (dest: src: ''
        $DRY_RUN_CMD rm -rf "$svc/${dest}"
        $DRY_RUN_CMD cp -RL ${src} "$svc/${dest}"
        $DRY_RUN_CMD chmod -R u+w "$svc/${dest}"
      '') bundles
    )}
    $DRY_RUN_CMD /usr/bin/python3 ${enableScript} || true
    # Re-register with the Services scanner so the menu updates without re-login.
    $DRY_RUN_CMD killall pbs 2>/dev/null || true
    $DRY_RUN_CMD /System/Library/CoreServices/pbs -update || true
  '';
}
