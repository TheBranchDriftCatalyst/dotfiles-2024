# Finder Quick Actions (right-click → Quick Actions), declaratively.
#
# A Quick Action is just a .workflow bundle in ~/Library/Services: an
# Info.plist whose NSServices block declares the menu label + file-type
# filter (NSSendFileTypes: public.image → only offered on images), and a
# document.wflow wrapping one Run Shell Script action (files as "$@").
# Nothing here needs Automator — mkQuickAction assembles the two plists,
# home.file links the bundles, and pbs -update registers them without a
# re-login. Darwin-only: imported from darwin.nix, never home/default.nix.
{
  pkgs,
  lib,
  ...
}:

let
  im = pkgs.imagemagick;

  # mkQuickAction name label fileTypes script → a Name.workflow bundle.
  # COMMAND_STRING is XML-escaped into the wflow plist; the script receives
  # the selected files as "$@" (inputMethod 1 = "as arguments").
  mkQuickAction =
    {
      name,
      label,
      fileTypes,
      script,
    }:
    pkgs.runCommand "${name}.workflow" { } ''
      c=$out/Contents
      mkdir -p $c
      cat > $c/Info.plist <<'PLIST'
      <?xml version="1.0" encoding="UTF-8"?>
      <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
      <plist version="1.0">
      <dict>
        <key>NSServices</key>
        <array>
          <dict>
            <key>NSBackgroundColorName</key><string>background</string>
            <key>NSMenuItem</key>
            <dict><key>default</key><string>${label}</string></dict>
            <key>NSMessage</key><string>runWorkflowAsService</string>
            <key>NSSendFileTypes</key>
            <array>${lib.concatMapStrings (t: "<string>${t}</string>") fileTypes}</array>
          </dict>
        </array>
      </dict>
      </plist>
      PLIST
      cat > $c/document.wflow <<'PLIST'
      <?xml version="1.0" encoding="UTF-8"?>
      <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
      <plist version="1.0">
      <dict>
        <key>AMApplicationBuild</key><string>528</string>
        <key>AMApplicationVersion</key><string>2.10</string>
        <key>AMDocumentVersion</key><string>2</string>
        <key>actions</key>
        <array>
          <dict>
            <key>action</key>
            <dict>
              <key>AMAccepts</key>
              <dict>
                <key>Container</key><string>List</string>
                <key>Optional</key><true/>
                <key>Types</key><array><string>com.apple.cocoa.path</string></array>
              </dict>
              <key>AMActionVersion</key><string>2.0.3</string>
              <key>AMProvides</key>
              <dict>
                <key>Container</key><string>List</string>
                <key>Types</key><array><string>com.apple.cocoa.path</string></array>
              </dict>
              <key>ActionBundlePath</key><string>/System/Library/Automator/Run Shell Script.action</string>
              <key>ActionName</key><string>Run Shell Script</string>
              <key>ActionParameters</key>
              <dict>
                <key>COMMAND_STRING</key><string>${lib.escapeXML script}</string>
                <key>CheckedForUserDefaultShell</key><true/>
                <key>inputMethod</key><integer>1</integer>
                <key>shell</key><string>/bin/zsh</string>
                <key>source</key><string></string>
              </dict>
              <key>BundleIdentifier</key><string>com.apple.RunShellScript</string>
              <key>CFBundleVersion</key><string>2.0.3</string>
              <key>CanShowSelectedItemsWhenRun</key><false/>
              <key>CanShowWhenRun</key><true/>
              <key>Class Name</key><string>RunShellScriptAction</string>
              <key>InputUUID</key><string>00000000-0000-0000-0000-00000000${
                builtins.substring 0 4 (builtins.hashString "md5" name)
              }1</string>
              <key>Keywords</key><array><string>Shell</string></array>
              <key>OutputUUID</key><string>00000000-0000-0000-0000-00000000${
                builtins.substring 0 4 (builtins.hashString "md5" name)
              }2</string>
              <key>UUID</key><string>00000000-0000-0000-0000-00000000${
                builtins.substring 0 4 (builtins.hashString "md5" name)
              }3</string>
            </dict>
          </dict>
        </array>
        <key>connectors</key><dict/>
        <key>workflowMetaData</key>
        <dict>
          <key>serviceInputTypeIdentifier</key><string>com.apple.Automator.fileSystemObject</string>
          <key>serviceProcessesInput</key><integer>0</integer>
          <key>workflowTypeIdentifier</key><string>com.apple.Automator.servicesMenu</string>
        </dict>
      </dict>
      </plist>
      PLIST
    '';

  notify = msg: ''/usr/bin/osascript -e 'display notification "${msg}" with title "Quick Action"' '';

  resizeImage = mkQuickAction {
    name = "resize-image";
    label = "🖼 Resize Image…";
    fileTypes = [ "public.image" ];
    script = ''
      SIZE=$(/usr/bin/osascript -e 'text returned of (display dialog "Resize to WxH (exact), or a single number (fit longest side):" default answer "1920x1080" with title "Resize Image")') || exit 0
      n=0
      for f in "$@"; do
        base="''${f%.*}"; ext="''${f##*.}"
        if [[ "$SIZE" == *x* ]]; then
          W="''${SIZE%x*}"; H="''${SIZE#*x}"
          /usr/bin/sips -z "$H" "$W" "$f" --out "''${base}_''${W}x''${H}.''${ext}" >/dev/null && ((n++))
        else
          /usr/bin/sips -Z "$SIZE" "$f" --out "''${base}_''${SIZE}.''${ext}" >/dev/null && ((n++))
        fi
      done
      ${notify "Resized $n image(s) to $SIZE"}
    '';
  };

  convertImage = mkQuickAction {
    name = "convert-image";
    label = "🖼 Convert Image…";
    fileTypes = [ "public.image" ];
    script = ''
      FMT=$(/usr/bin/osascript -e 'choose from list {"png","jpeg","webp","heic","tiff","avif","gif"} with title "Convert Image" with prompt "Target format:" default items {"png"}') || exit 0
      [[ "$FMT" == "false" ]] && exit 0
      n=0
      for f in "$@"; do
        base="''${f%.*}"
        ${im}/bin/magick "$f" "''${base}.''${FMT}" && ((n++))
      done
      ${notify "Converted $n image(s) to $FMT"}
    '';
  };

  halveImage = mkQuickAction {
    name = "halve-image";
    label = "🖼 Halve Image (50%)";
    fileTypes = [ "public.image" ];
    script = ''
      n=0
      for f in "$@"; do
        base="''${f%.*}"; ext="''${f##*.}"
        read W H < <(/usr/bin/sips -g pixelWidth -g pixelHeight "$f" | /usr/bin/awk '/pixelWidth/{w=$2}/pixelHeight/{h=$2}END{print w, h}')
        /usr/bin/sips -z $((H / 2)) $((W / 2)) "$f" --out "''${base}_50pct.''${ext}" >/dev/null && ((n++))
      done
      ${notify "Halved $n image(s)"}
    '';
  };
in
{
  # magick on PATH generally too — the convert action pins the store path,
  # but having it interactive matches the "image tooling lives here" intent.
  home.packages = [ im ];

  home.file = {
    "Library/Services/Resize Image.workflow".source = resizeImage;
    "Library/Services/Convert Image.workflow".source = convertImage;
    "Library/Services/Halve Image.workflow".source = halveImage;
  };

  # Register with the Services scanner so the menu updates without re-login.
  home.activation.refreshQuickActions = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    $DRY_RUN_CMD /System/Library/CoreServices/pbs -update || true
  '';
}
