# CLI pack (2026-09) — the "OP" additions, all upstream HM modules,
# colored from the machine LIVERY (catalyst.palette).
{ config, ... }:

let p = config.catalyst.palette; in

{
  # Encrypted, syncable, SQLite-backed shell history with TUI search.
  # Sync is OFF until a server is chosen (atuin register / self-host on the
  # homelab) — local-only atuin already beats HISTFILE.
  programs.atuin = {
    enable = true;
    enableZshIntegration = true;
    settings = {
      enter_accept = true; # Enter runs the picked command; Tab edits it
      filter_mode_shell_up_key_binding = "session";
    };
  };

  # TUI file manager with image previews (works in Ghostty).
  programs.yazi = {
    enable = true;
    enableZshIntegration = true; # `yy` = cd-on-quit wrapper
    theme.mgr = {
      hovered = { bg = p.mid; bold = true; };
      cwd = { fg = p.accent; bold = true; };
      border_style = { fg = p.mid; };
      marker_selected = { fg = p.glow; bg = p.glow; };
      count_selected = { fg = p.deep; bg = p.glow; };
    };
  };

  programs.lazygit = {
    enable = true;
    settings.gui.theme = {
      activeBorderColor = [ p.glow "bold" ];
      inactiveBorderColor = [ p.mid ];
      selectedLineBgColor = [ p.mid ];
      optionsTextColor = [ p.accent ];
      cherryPickedCommitBgColor = [ p.mid ];
      cherryPickedCommitFgColor = [ p.glow ];
      unstagedChangesColor = [ p.sunTop ];
      defaultFgColor = [ "default" ];
    };
  };

  # Prebuilt nix-index DB (flake input wires the module): command-not-found
  # tells you which package has a missing binary, and comma runs one ad hoc:
  #   , cowsay moo
  programs.nix-index.enable = true;
  programs.nix-index-database.comma.enable = true;

  # bat carries a generated "livery" syntax theme (delta shares it through
  # bat's cache). Deliberately small: background/accents from the palette,
  # readable defaults for the rest.
  programs.bat = {
    enable = true;
    config.theme = "livery";
    themes.livery.src = builtins.toFile "livery.tmTheme" ''
      <?xml version="1.0" encoding="UTF-8"?>
      <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
      <plist version="1.0"><dict>
        <key>name</key><string>livery</string>
        <key>settings</key><array>
          <dict><key>settings</key><dict>
            <key>background</key><string>${p.deep}</string>
            <key>foreground</key><string>#f2f2f7</string>
            <key>caret</key><string>${p.glow}</string>
            <key>selection</key><string>${p.mid}</string>
            <key>lineHighlight</key><string>${p.mid}</string>
          </dict></dict>
          <dict><key>scope</key><string>comment</string>
            <key>settings</key><dict><key>foreground</key><string>#8a8aa5</string></dict></dict>
          <dict><key>scope</key><string>string</string>
            <key>settings</key><dict><key>foreground</key><string>${p.sunTop}</string></dict></dict>
          <dict><key>scope</key><string>constant</string>
            <key>settings</key><dict><key>foreground</key><string>${p.sunBot}</string></dict></dict>
          <dict><key>scope</key><string>keyword, storage</string>
            <key>settings</key><dict><key>foreground</key><string>${p.glow}</string></dict></dict>
          <dict><key>scope</key><string>entity.name.function, support.function</string>
            <key>settings</key><dict><key>foreground</key><string>${p.accent}</string></dict></dict>
          <dict><key>scope</key><string>variable, entity.name</string>
            <key>settings</key><dict><key>foreground</key><string>#f2f2f7</string></dict></dict>
          <dict><key>scope</key><string>entity.name.tag, markup.heading</string>
            <key>settings</key><dict><key>foreground</key><string>${p.glow}</string></dict></dict>
          <dict><key>scope</key><string>invalid</string>
            <key>settings</key><dict><key>foreground</key><string>#ff5555</string></dict></dict>
        </array>
      </dict></plist>
    '';
  };
}
