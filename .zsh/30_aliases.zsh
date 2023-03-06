autoload -Uz zmv
alias zmv='noglob zmv -W'

alias cp="${ZSH_VERSION:+nocorrect} cp -i"
alias mv="${ZSH_VERSION:+nocorrect} mv -i"
alias mkdir="${ZSH_VERSION:+nocorrect} mkdir"

alias du='du -h'
alias job='jobs -l'
alias grep='grep --color=auto'
alias fgrep='fgrep --color=auto'
alias egrep='egrep --color=auto'

# Use plain vim.
alias suvim='vim -N -u NONE -i NONE'

# if (( $+commands[kubectl] )); then
#   alias k=kubectl
# fi

# Global aliases
alias -g L='| less'
alias -g G='| grep'
alias -g X='| xargs'
alias -g N=" >/dev/null 2>&1"
alias -g N1=" >/dev/null"
alias -g N2=" 2>/dev/null"
alias -g VI='| xargs -o vim'
alias -g CSV="| sed 's/,,/, ,/g;s/,,/, ,/g' | column -s, -t"
alias -g H='| head'
alias -g T='| tail'

alias -g CP='| pbcopy'
alias -g CC='| tee /dev/tty | pbcopy'
alias -g P='$(kubectl get pods | fzf-tmux --header-lines=1 --reverse --multi --cycle | awk "{print \$1}")'
alias -g F='| fzf --height 30 --reverse --multi --cycle'

awk_alias2() {
  local -a options fields words
  while (( $#argv > 0 ))
  do
    case "$1" in
      -*)
        options+=("$1")
        ;;
      <->)
        fields+=("$1")
        ;;
      *)
        words+=("$1")
        ;;
    esac
    shift
  done
  if (( $#fields > 0 )) && (( $#words > 0 )); then
    awk '$'$fields[1]' ~ '${(qqq)words[1]}''
  elif (( $#fields > 0 )) && (( $#words == 0 )); then
    awk '{print $'$fields[1]'}'
  fi
}
alias -g A="| awk_alias2"

# list galias
alias galias="alias | command grep -E '^[A-Z]'"
alias yy="fc -ln -1 | tr -d '\n' | pbcopy"

if (( $+commands[iap_curl] )); then
  alias iap='iap_curl $(iap_curl --list | fzf --height 30% --reverse)'
fi

gchange() {
  if ! type gcloud &>/dev/null; then
    echo "gcloud not found" >&2
    return 1
  fi
  gcloud config configurations activate $(gcloud config configurations list | fzf-tmux --reverse --header-lines=1 | awk '{print $1}')
}
