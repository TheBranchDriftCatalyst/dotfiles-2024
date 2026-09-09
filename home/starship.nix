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
      right_format = "$battery";

      character = {
        success_symbol = "[🚀](bold green) ";
        error_symbol = "[💥](bold red) ";
      };

      directory = {
        truncation_length = 2;
        truncate_to_repo = true;
        truncation_symbol = "⚓/";
        format = "[$path]($style)[$read_only]($read_only_style) ";
        style = "fg:#00FFFF bold";
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
        style = "bold #ff2975";
      };

      git_status = {
        format = "[($all_status$ahead_behind)]($style) ";
        style = "fg:#FF00FF bold";
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
        style = "fg:#FFEF00 bold";
      };

      jobs = {
        threshold = 1;
        symbol = "✦";
        format = "[$symbol$number]($style) ";
        style = "fg:#FF00FF bold";
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
        style = "bold #00dfff";
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

      shlvl.disabled = false;
    };
  };
}
