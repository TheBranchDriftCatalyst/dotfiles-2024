# ─────────────────────────────────────────────────────────────────────────────
# aliases.zsh :: curated command library — sourced by home/zsh.nix (store path)
#
# CURATION CONTRACT: everything below is COMMENTED OUT except the safety block.
# Each block has an operator note (what / deps / example). Uncomment a block
# when you actually reach for it, rebuild, and it's live. Anything still
# commented after a few months is a deletion candidate.
#
# Not ported from the old 30_aliases.zsh (see git history / `protecht`):
# the mathiasbynens tail (python2 server/json, recursive tree, en1 phpserver),
# watch() (shadowed the nix `watch`, wanted brew fswatch), gchange/iap (gcloud
# and iap_curl aren't installed), ifactive (pcregrep), k=kubectl (abbr k8
# covers it), and the brew-era update pipeline.
# ─────────────────────────────────────────────────────────────────────────────

# ── ACTIVE: safety rails ──────────────────────────────────────────────────
# Interactive cp/mv prompt before clobbering; nocorrect stops zsh "fixing"
# filenames; zmv gets its wildcard-rename mode. (rm is aliased to gomi in
# home/zsh.nix — deletes go to the trash can, not the void.)
autoload -Uz zmv
alias zmv='noglob zmv -W'
alias cp='nocorrect cp -i'
alias mv='nocorrect mv -i'
alias mkdir='nocorrect mkdir'

# ── global aliases: pipeline power ────────────────────────────────────────
# note: type anywhere in a command line, not just the head. `cmd G err L`
#       = `cmd | grep err | less`. P picks a k8s pod via fzf; A is the awk
#       field-picker (`ps aux A 2` prints column 2). deps: fzf, kubectl.
alias -g L='| less'
alias -g G='| grep'
alias -g X='| xargs'
alias -g N=" >/dev/null 2>&1"
alias -g N1=" >/dev/null"
alias -g N2=" 2>/dev/null"
alias -g VI='| xargs -o nvim'
alias -g CSV="| sed 's/,,/, ,/g;s/,,/, ,/g' | column -s, -t"
alias -g H='| head'
alias -g T='| tail'
alias -g CP='| pbcopy'                              # macOS
alias -g CC='| tee /dev/tty | pbcopy'               # macOS
alias -g P='$(kubectl get pods | fzf-tmux --header-lines=1 --reverse --multi --cycle | awk "{print \$1}")'
alias -g F='| fzf --height 30 --reverse --multi --cycle'
awk_alias2() {
  local -a options fields words
  while (( $#argv > 0 )); do
    case "$1" in
      -*) options+=("$1") ;;
      <->) fields+=("$1") ;;
      *) words+=("$1") ;;
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
alias galias="alias | command grep -E '^[A-Z]'"     # list the globals

# ── quality-of-life aliases ───────────────────────────────────────────────
# note: small habits. `yy` copies the last command to the clipboard (macOS),
#       `reload` restarts the shell, `path` prints PATH one-per-line.
alias du='du -h'
alias job='jobs -l'
alias grep='grep --color=auto'
alias fgrep='fgrep --color=auto'
alias egrep='egrep --color=auto'
alias suvim='nvim -N -u NONE -i NONE'               # nvim, no config, no swap
alias yy="fc -ln -1 | tr -d '\n' | pbcopy"          # macOS
alias reload="exec ${SHELL} -l"
alias path='echo -e ${PATH//:/\\n}'
alias week='date +%V'

# ── network lookups ───────────────────────────────────────────────────────
# note: `ip` = public IP via OpenDNS; localip/ips are macOS-only (ipconfig/
#       ifconfig). digga = the useful parts of dig. deps: dig, openssl.
# alias ip="dig +short myip.opendns.com @resolver1.opendns.com"
# alias localip="ipconfig getifaddr en0"              # macOS
# alias ips="ifconfig -a | grep -o 'inet6\? \(addr:\)\?\s\?\(\(\([0-9]\+\.\)\{3\}[0-9]\+\)\|[a-fA-F0-9:]\+\)' | awk '{ sub(/inet6? (addr:)? ?/, \"\"); print }'"
digga() {
  if [[ -z "$1" ]]; then
    echo "❌ Usage: digga <domain>"
    return 1
  fi
  echo "🔍 DNS lookup for: $1"
  dig +nocmd "$1" any +multiline +noall +answer
}

# ── ssl certificate inspector ─────────────────────────────────────────────
# note: `getcertnames example.com` — prints CN + SANs from the live cert.
#       dep: openssl.
getcertnames() {
  if [[ -z "$1" ]]; then
    echo "❌ Usage: getcertnames <domain>"
    return 1
  fi
  local domain="$1"
  echo "🔒 Testing SSL certificate for: $domain"
  echo ""
  local tmp=$(echo -e "GET / HTTP/1.0
EOT" |
    openssl s_client -connect "$domain:443" -servername "$domain" 2>&1)
  if [[ "$tmp" = *"-----BEGIN CERTIFICATE-----"* ]]; then
    local certText=$(echo "$tmp" |
      openssl x509 -text -certopt "no_aux, no_header, no_issuer, no_pubkey,
      no_serial, no_sigdump, no_signame, no_validity, no_version")
    echo "📋 Common Name:"
    echo "$certText" | grep "Subject:" | sed -e "s/^.*CN=//" -e "s/\/emailAddress=.*//"
    echo ""
    echo "📋 Subject Alternative Names:"
    echo "$certText" | grep -A 1 "Subject Alternative Name:" |
      sed -e "2s/DNS://g" -e "s/ //g" | tr "," "
" | tail -n +2
    return 0
  else
    echo "❌ Certificate not found or connection failed"
    return 1
  fi
}

# ── encoders ──────────────────────────────────────────────────────────────
# note: `escape ✓` → \x-escaped bytes; `dataurl img.png` → base64 data: URL.
#       deps: xxd, openssl, file.
escape() {
  if [[ -z "$*" ]]; then
    echo "❌ Usage: escape <text_to_encode>"
    return 1
  fi
  printf "\x%s" $(printf "$@" | xxd -p -c1 -u)
  [[ -t 1 ]] && echo ""
}
dataurl() {
  if [[ -z "$1" ]]; then
    echo "❌ Usage: dataurl <filename>"
    return 1
  fi
  if [[ ! -f "$1" ]]; then
    echo "❌ File not found: $1"
    return 1
  fi
  local mimeType=$(file -b --mime-type "$1")
  if [[ $mimeType == text/* ]]; then
    mimeType="${mimeType};charset=utf-8"
  fi
  echo "📄 Creating data URL for: $1 ($mimeType)"
  echo "data:${mimeType};base64,$(openssl base64 -in "$1" | tr -d '
')"
}

# ── editor / opener shortcuts ─────────────────────────────────────────────
# note: `v` = nvim (current dir with no args); `o` = macOS open ditto.
v() {
  if [[ $# -eq 0 ]]; then
    echo "📝 Opening current directory in Vim..."
    nvim .
  else
    nvim "$@"
  fi
}
o() {                                               # macOS
  if [[ $# -eq 0 ]]; then
    echo "📂 Opening current directory..."
    open .
  else
    open "$@"
  fi
}

# ── job control ───────────────────────────────────────────────────────────
# note: `kj` kills every background job of this shell, with a count.
alias kj="killjobs"
killjobs() {
  local jobs_count=$(jobs | wc -l)
  if [[ $jobs_count -eq 0 ]]; then
    echo "ℹ️  No background jobs to kill"
    return 0
  fi
  echo "💀 Killing $jobs_count background jobs..."
  kill $(jobs | awk '{b=substr($1,2,1); c="%"; print c b}') 2>/dev/null
  echo "✅ All background jobs terminated"
}

# ── port scanner ──────────────────────────────────────────────────────────
# note: `whatsOnPort 3000 8080` — who's LISTENing. dep: lsof.
whatsOnPort() {
  if [[ $# -eq 0 ]]; then
    echo "❌ Usage: whatsOnPort <port1> [port2] [port3]..."
    return 1
  fi
  for port in "$@"; do
    echo "🔍 Checking port $port..."
    lsof -n -i:"$port" | grep LISTEN || echo "   ❌ Nothing listening on port $port"
    sleep 0.5
  done
}

# ── macOS housekeeping ────────────────────────────────────────────────────
# note: all macOS-only. flush = DNS cache; lscleanup = "Open With" dupes;
#       emptytrash = sudo nuke of every trash (TODO: also purge gomi storage).
alias flush="dscacheutil -flushcache && killall -HUP mDNSResponder"
alias lscleanup="/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -kill -r -domain local -domain system -domain user && killall Finder"
alias chrome-insecure="open -a Google\ Chrome --args --disable-web-security --allow-running-insecure-content --user-data-dir=''"
emptytrash() {
  echo "🗑️  Emptying ALL trash (requires sudo)..."
  # TODO: we need to add the gomi storage here for cleanup as well
  sudo rm -rfv /Volumes/*/.Trashes 2>/dev/null
  sudo rm -rfv ~/.Trash 2>/dev/null
  sudo rm -rfv /private/var/log/asl/*.asl 2>/dev/null
  sqlite3 ~/Library/Preferences/com.apple.LaunchServices.QuarantineEventsV* 'delete from LSQuarantineEvent' 2>/dev/null
  echo "✅ Trash emptied successfully!"
}

# ── docker suite ──────────────────────────────────────────────────────────
# note: needs a docker CLI on PATH (colima context — not currently in
#       packages.nix). did/dstart/dstop/dstatus/dlogs work by container NAME;
#       dnuke destroys EVERYTHING after an Enter confirm.
alias dpa='docker ps -a'
alias di='docker images'
alias dps='docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"'
did() {
  if [[ -z "$1" ]]; then
    echo "❌ Usage: did <container_name_or_id>"
    return 1
  fi
  docker ps -a --format "{{.ID}}" --filter "name=$1" | head -1
}
dstart() {
  local container="$1"
  if [[ -z "$container" ]]; then
    echo "❌ Usage: dstart <container_name>"
    return 1
  fi
  local id=$(did "$container")
  if [[ -z "$id" ]]; then
    echo "❌ Container '$container' not found"
    return 1
  fi
  echo "🚀 Starting container: $container"
  docker start "$id" && echo "✅ Container started successfully"
}
dstop() {
  local container="$1"
  if [[ -z "$container" ]]; then
    echo "❌ Usage: dstop <container_name>"
    return 1
  fi
  local id=$(did "$container")
  if [[ -z "$id" ]]; then
    echo "❌ Container '$container' not found"
    return 1
  fi
  echo "🛑 Stopping container: $container"
  docker stop "$id" && echo "✅ Container stopped successfully"
}
dstatus() {
  if [[ $# -eq 0 ]]; then
    docker ps -a --format 'table {{.Names}}\t{{.ID}}\t{{.Status}}\t{{.Ports}}'
  else
    local container="$1"
    local status=$(docker ps -a --format "{{.Status}}" --filter "name=$container")
    if [[ -n "$status" ]]; then
      echo "📊 $container: $status"
      [[ "$status" =~ ^Up ]] && return 0 || return 1
    else
      echo "❌ Container '$container' not found"
      return 1
    fi
  fi
}
dclean() {
  echo "🧹 Cleaning exited containers..."
  docker container prune -f && echo "✅ Cleanup complete"
}
diclean() {
  echo "🧹 Cleaning dangling images..."
  docker image prune -f && echo "✅ Image cleanup complete"
}
dlogs() {
  local container="$1"
  if [[ -z "$container" ]]; then
    echo "❌ Usage: dlogs <container_name> [docker_logs_options]"
    return 1
  fi
  local id=$(did "$container")
  if [[ -z "$id" ]]; then
    echo "❌ Container '$container' not found"
    return 1
  fi
  echo "📝 Showing logs for: $container"
  docker logs "$id" "${@:2}"
}
dnuke() {
  echo "☢️  WARNING: This will DESTROY ALL Docker data!"
  echo "Press Ctrl+C to cancel, Enter to continue..."
  read
  docker stop $(docker ps -aq) 2>/dev/null || true
  docker container prune -f
  docker image prune -af
  docker volume prune -f
  docker network prune -f
  echo "☢️  Nuclear cleanup complete! Docker environment reset."
}

# ── filesystem utilities ──────────────────────────────────────────────────
# note: mkd = mkdir + cd; cdf = cd to frontmost Finder window (macOS);
#       targz = tar with junk excluded, best available compressor (pigz is
#       installed, zopfli optional); fs = human-readable sizes, sorted.
mkd() {
  if [[ -z "$1" ]]; then
    echo "❌ Usage: mkd <directory_name>"
    return 1
  fi
  mkdir -p "$@" && cd "$_" && echo "✅ Created and entered: $(pwd)"
}
cdf() {                                             # macOS
  local finder_path
  finder_path=$(osascript -e 'tell app "Finder" to POSIX path of (insertion location as alias)' 2>/dev/null)
  if [[ -n "$finder_path" ]]; then
    cd "$finder_path" && echo "📂 Changed to Finder location: $(pwd)"
  else
    echo "❌ Could not get Finder location"
    return 1
  fi
}
targz() {
  if [[ $# -eq 0 ]]; then
    echo "❌ Usage: targz <file_or_directory> [...]"
    return 1
  fi
  local tmpFile="${*%/}.tar"
  echo "📦 Creating archive: $tmpFile"
  tar -cvf "$tmpFile" --exclude=".DS_Store" --exclude="node_modules" --exclude=".git" "$@" || return 1
  local size
  size=$(stat -f"%z" "$tmpFile" 2>/dev/null || stat -c"%s" "$tmpFile" 2>/dev/null)
  local cmd="gzip"
  if (( size < 52428800 )) && command -v zopfli &>/dev/null; then
    cmd="zopfli"
  elif command -v pigz &>/dev/null; then
    cmd="pigz"
  fi
  echo "🗜️  Compressing with $cmd ($(( size / 1000 )) kB)..."
  "$cmd" -v "$tmpFile" || return 1
  [[ -f "$tmpFile" ]] && rm "$tmpFile"
  local zippedSize
  zippedSize=$(stat -f"%z" "$tmpFile.gz" 2>/dev/null || stat -c"%s" "$tmpFile.gz" 2>/dev/null)
  echo "✅ Created: $tmpFile.gz ($(( zippedSize / 1000 )) kB)"
}
function fs {
  local arg="-sh"
  local du_cmd="command du"
  if [[ $# -gt 0 ]]; then
    eval "$du_cmd $arg -- \"$@\""
  else
    echo "📊 Current directory contents:"
    setopt LOCAL_OPTIONS NULL_GLOB
    local targets=(.* *)
    eval "$du_cmd $arg -- \"${(@q)targets}\"" | sort -hr
  fi
}

# ── dev servers & formatters ──────────────────────────────────────────────
# note: server = python3 http.server with auto-open; gz = compression ratio;
#       json = pretty-print + bat highlighting. deps: python3 (server only).
server() {
  local port="${1:-8000}"
  if ! command -v python3 &>/dev/null; then
    echo "❌ python3 not found - cannot start server"
    return 1
  fi
  echo "🚀 Starting HTTP server on http://localhost:$port/"
  echo "📁 Serving: $(pwd)"
  sleep 1 && open "http://localhost:$port/" &
  python3 -m http.server "$port"
}
gz() {
  if [[ -z "$1" || ! -f "$1" ]]; then
    echo "❌ Usage: gz <filename>"
    return 1
  fi
  local origsize=$(wc -c < "$1")
  local gzipsize=$(gzip -c "$1" | wc -c)
  local ratio=$(echo "scale=2; $gzipsize * 100 / $origsize" | bc -l 2>/dev/null || echo "N/A")
  printf "📄 Original: %'d bytes\n" "$origsize"
  printf "🗜️  Gzipped:  %'d bytes (%s%%)\n" "$gzipsize" "$ratio"
}
json() {
  if [[ $# -eq 0 && -t 0 ]]; then
    echo "❌ Usage: json '<json_string>' OR echo '<json>' | json"
    return 1
  fi
  if [[ -t 0 ]]; then
    echo "$*" | python3 -m json.tool | bat --language=json --style=plain
  else
    python3 -m json.tool | bat --language=json --style=plain
  fi
}

# ── throttle / debounce combinators ───────────────────────────────────────
# note: rate-limit any command: `@throttle make build`. Their only consumer
#       (the old watch()) is retired — kept for future fs-watch tooling.
declare -i last_called=0
declare -i throttle_by=5
@throttle() {
  local -i now=$(date +%s)
  if (($now - $last_called >= $throttle_by)); then
    "$@"
  fi
  last_called=$(date +%s)
}
@debounce() {
  local pid=$$
  if [[ ! -f ~/.executing-$pid ]]; then
    touch ~/.executing-$pid
    "$@"
    local retVal="$?"
    {
      sleep "$throttle_by"
      if [[ -f ~/.on-finish-$pid ]]; then
        "$@"
        rm -f ~/.on-finish-$pid
      fi
      rm -f ~/.executing-$pid
    } &
    return $retVal
  elif [[ ! -f ~/.on-finish-$pid ]]; then
    touch ~/.on-finish-$pid
  fi
}
