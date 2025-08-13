# Enable Powerlevel10k instant prompt. Should stay close to the top of ~/.zshrc.
# Initialization code that may require console input (password prompts, [y/n]
# confirmations, etc.) must go above this block; everything else may go below.
# if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
#   source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
# fi

# .zshrc
#   zshenv -> zprofile -> zshrc (current)
#
# | zshenv   : always
# | zprofile : if login shell
# | zshrc    : if interactive shell
# | zlogin   : if login shell, after zshrc
# | zlogout  : if login shell, after logout
#
# https://zsh.sourceforge.io/Doc/Release/Files.html#Files
#

# Return if zsh is called from Vim
if [[ -n $VIMRUNTIME ]]; then
  return 0
fi

# Move this to setups or somewhere elese in the afx provisioning process
# only add successfuly commands to the history
zshaddhistory() { whence ${${(z)1}[1]} >| /dev/null || return 1 }
eval "$(saml2aws --completion-script-zsh)"

source <(kubectl completion zsh)
source <(helm completion zsh)
source <(skaffold completion zsh)
source <(minikube completion zsh)
source <(docker completion zsh)

export PATH="${KREW_ROOT:-$HOME/.krew}/bin:$PATH"

# export fpath=(${ASDF_DATA_DIR:-$HOME/.asdf}/completions $fpath)
# export PATH="$HOME/.asdf/shims:$PATH"

source <(afx init)
source <(afx completion zsh)

eval "$(fzf --zsh)"

# word split: `-`, `_`, `.`, `=`
export WORDCHARS='*?[]~&;!#$%^(){}<>'

. "$HOME/.cargo/env"

eval "$(mise activate zsh)"

export STARSHIP_CONFIG=~/starship.toml

eval "$(starship init zsh)"

autoload -Uz compinit
compinit

autoload -Uz colors
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # This loads nvm
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"  # This loads nvm bash_completion
# The following lines have been added by Docker Desktop to enable Docker CLI completions.
fpath=(/Users/hdaniels/.docker/completions $fpath)
autoload -Uz compinit
compinit
# End of Docker CLI completions
