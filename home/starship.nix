# starship — the prompt, fully declarative.
#
# Converted from dotfiles/starship.toml (409 lines, ~60% commented-out
# experiments). Pruned in the move:
#   - custom.docker_count  ran `docker ps` on EVERY prompt render
#   - memory_usage         always-on RAM readout, subprocess per prompt
#   - git_metrics          computes a diff per prompt
#   - kubernetes / time    were already disabled = true
# The synthwave identity (🚀/💥, 🌴 branch, neon hex styles) is kept intact.
#
# Deploy: edit here → `just switch`.
{ ... }:

{
  programs.starship = {
    enable = true;
    enableZshIntegration = true;

    settings = {
      # ── the frame ─────────────────────────────────────────────────────
      # ╭─ ctx: dir · git · langs · infra ····· time
      # ╰─🚀
      format = builtins.concatStringsSep "" [
        "[╭─](fg:surface)"
        "$username$hostname"
        "$directory"
        "$git_branch$git_commit$git_state$git_status"
        "$python$docker_context$aws"
        "$nix_shell$direnv"
        "$fill"
        "$cmd_duration$jobs$shlvl$sudo"
        "$time"
        "$line_break"
        "[╰─](fg:surface)$status$character"
      ];
      right_format = "$battery";

      palette = "synthwave";
      palettes.synthwave = {
        neon_pink = "#ff2e97";
        neon_cyan = "#5ee7ff";
        neon_violet = "#9d6bff";
        neon_yellow = "#ffef00";
        surface = "#4a3b78";
      };

      fill = {
        symbol = "·";
        style = "fg:surface";
      };

      # ❄️ inside a nix devshell / nix develop — you live here now
      nix_shell = {
        symbol = "❄️ ";
        format = "[$symbol$state]($style) ";
        style = "bold neon_cyan";
        impure_msg = "[impure](bold red)";
        pure_msg = "[pure](bold neon_cyan)";
        unknown_msg = "[shell](bold neon_violet)";
      };

      # 🔓 sudo credentials currently cached — know when you're hot
      sudo = {
        disabled = false;
        symbol = "🔓 ";
        format = "[$symbol]($style)";
        style = "bold neon_pink";
      };

      # exit status with signal names (💥 says "failed", this says WHY)
      status = {
        disabled = false;
        format = "[$symbol$common_meaning$signal_name$maybe_int]($style) ";
        symbol = "✘ ";
        map_symbol = true;
        pipestatus = true;
        style = "bold red";
      };

      time = {
        disabled = false;
        time_format = "%H:%M";
        format = "[$time]($style) ";
        style = "fg:neon_violet";
      };

      character = {
        success_symbol = "[🚀](bold green) ";
        error_symbol = "[💥](bold red) ";
      };

      directory = {
        truncation_length = 2;
        truncate_to_repo = true;
        truncation_symbol = "⚓/";
        format = "[$path]($style)[$read_only]($read_only_style) ";
        style = "fg:neon_cyan bold";
        read_only = "🔒";
        read_only_style = "fg:red bold";
      };

      direnv = {
        disabled = false;
        symbol = "";
        format = "[$symbol$loaded]($style) ";
        loaded_msg = "🟢 ";
        unloaded_msg = "⚠️ ";
        allowed_msg = "🟢 ";
        not_allowed_msg = "🚫 ";
        denied_msg = "🔴 ";
      };

      git_branch = {
        symbol = "🌴 ";
        format = "[$symbol$branch]($style) ";
        style = "bold neon_pink";
      };

      git_status = {
        format = "[($all_status$ahead_behind)]($style) ";
        style = "fg:neon_pink bold";
        conflicted = "​⚔️​ \${count} ";
        ahead = "​⬆️​ \${count} ";
        behind = "​⬇️​ \${count} ";
        diverged = "🔀 \${ahead_count}/\${behind_count} ";
        staged = "​✔️​ \${count} ";
        modified = "​✏️​ \${count} ";
        deleted = "​🗑️​ \${count} ";
        untracked = "​❓​\${count} ";
        stashed = "​🏦​ (\${count}) ";
      };

      git_commit = {
        commit_hash_length = 8;
        style = "bold white";
      };

      git_state = {
        format = "[\\($state( $progress_current of $progress_total)\\)]($style) ";
      };

      cmd_duration = {
        min_time = 2000;
        show_milliseconds = true;
        format = "[⌛ $duration]($style) ";
        style = "fg:neon_yellow bold";
      };

      jobs = {
        threshold = 1;
        symbol = "✦";
        format = "[$symbol$number]($style) ";
        style = "fg:neon_pink bold";
      };

      username = {
        show_always = false;
        style_user = "bold cyan";
        style_root = "bold red";
        format = "[$user]($style)";
      };

      hostname = {
        ssh_only = true;
        style = "bold cyan";
        format = "[$hostname]($style) ";
      };

      python = {
        symbol = "🐍 ";
        format = "via [$symbol\${version}(\\(@ \${virtualenv}\\) )]($style) ";
        style = "bold yellow";
      };

      docker_context = {
        symbol = "🐳 ";
        format = "via [$symbol$context]($style) ";
        style = "bold neon_cyan";
      };

      aws = {
        symbol = "🌐 ";
        format = "[$symbol$profile(\\($region\\))]($style) ";
        style = "bold cyan";
      };

      battery = {
        full_symbol = "🔋 ";
        charging_symbol = "🔌 ";
        discharging_symbol = "⚡ ";
        empty_symbol = "🪫 ";
        format = "[$symbol$percentage]($style) ";
        display = [
          { threshold = 10; style = "bold red"; }
          { threshold = 30; style = "bold yellow"; }
        ];
      };

      shlvl = {
        disabled = false;
        threshold = 2;              # only when nested — depth 1 is just life
        symbol = "🕳️ ";
        format = "[$symbol$shlvl]($style) ";
        style = "bold neon_violet";
      };
    };
  };
}
