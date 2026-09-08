# starship — the live prompt. (The repo also carried an 80K .p10k.zsh, which
# was dead: p10k is commented out in the afx manifest and starship has been
# the real prompt for some time. It is not carried forward.)
{ ... }:

{
  programs.starship = {
    enable = true;
    enableZshIntegration = true;
    settings = {
      add_newline = false;
      command_timeout = 1000;

      directory = {
        truncation_length = 4;
        truncate_to_repo = false;
      };

      git_status.disabled = false;
      kubernetes.disabled = false;
      aws.disabled = false;

      # Keep the prompt fast; these are rarely useful and cost a subprocess.
      package.disabled = true;
      nodejs.disabled = true;
      python.disabled = true;
    };
  };
}
