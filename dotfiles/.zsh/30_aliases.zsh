#====================================================================
# 🎯 CATALYST ALIASES & FUNCTIONS - BATTLE-TESTED & OPTIMIZED
#====================================================================

#====================================================================
# 📦 CORE SYSTEM ALIASES 
#====================================================================

# Enhanced file operations with safety checks
autoload -Uz zmv
alias zmv='noglob zmv -W'
alias cp="${ZSH_VERSION:+nocorrect} cp -i"
alias mv="${ZSH_VERSION:+nocorrect} mv -i"
alias mkdir="${ZSH_VERSION:+nocorrect} mkdir"

# Essenti#====================================================================
# 🔐 NETWORK & SECURITY UTILITIES
#====================================================================

# 🔍 Enhanced DNS Lookup
digga() {
  if [[ -z "$1" ]]; then
    echo "❌ Usage: digga <domain>"
    return 1
  fi
  echo "🔍 DNS lookup for: $1"
  dig +nocmd "$1" any +multiline +noall +answer
}

# 🔒 SSL Certificate Inspector
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

# 🔤 Unicode Escape Encoder
escape() {
  if [[ -z "$*" ]]; then
    echo "❌ Usage: escape <text_to_encode>"
    return 1
  fi
  
  printf "\x%s" $(printf "$@" | xxd -p -c1 -u)
  # Print newline unless piping
  [[ -t 1 ]] && echo ""
}

# 🎨 Data URL Creator
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

#====================================================================
# 🚀 EDITOR & FILE OPERATIONS
#====================================================================

# 📝 Smart Vim launcher
v() {
  if [[ $# -eq 0 ]]; then
    echo "📝 Opening current directory in Vim..."
    vim .
  else
    vim "$@"
  fi
}

# 📂 Smart Open launcher  
o() {
  if [[ $# -eq 0 ]]; then
    echo "📂 Opening current directory..."
    open .
  else
    open "$@"
  fi
}

# 🌳 Enhanced Tree View
# tree() {
#   if ! command -v tree &>/dev/null; then
#     echo "❌ tree command not found"
#     echo "💡 Install with: brew install tree"
#     return 1
#   fi
  
#   tree -aC -I '.git|node_modules|bower_components|.DS_Store|target|build|dist' 
#     --dirsfirst "$@" | less -FRNX
# }

alias du='du -h'
alias job='jobs -l'
alias grep='grep --color=auto'
alias fgrep='fgrep --color=auto'
alias egrep='egrep --color=auto'
alias suvim='vim -N -u NONE -i NONE'

# Enable kubectl if available
if (( $+commands[kubectl] )); then
  alias k=kubectl
fi

#====================================================================
# 🌟 GLOBAL ALIASES - PIPELINE POWER
#====================================================================

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

# Enhanced AWK global alias
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

#====================================================================
# 🛠️ SYSTEM UTILITIES
#====================================================================

alias galias="alias | command grep -E '^[A-Z]'"
alias yy="fc -ln -1 | tr -d '\n' | pbcopy"
alias reload="exec ${SHELL} -l"
alias path='echo -e ${PATH//:/\\n}'
alias week='date +%V'

#====================================================================
# ☁️ CLOUD & DEVOPS
#====================================================================

# Google Cloud Configuration Switcher
gchange() {
  if ! command -v gcloud &>/dev/null; then
    echo "❌ gcloud not found" >&2
    return 1
  fi
  local config=$(gcloud config configurations list | fzf-tmux --reverse --header-lines=1 | awk '{print $1}')
  [[ -n "$config" ]] && gcloud config configurations activate "$config"
}

# IAP Curl with fuzzy selection
if (( $+commands[iap_curl] )); then
  alias iap='iap_curl $(iap_curl --list | fzf --height 30% --reverse)'
fi


alias chrome-insecure="open -a Google\ Chrome --args --disable-web-security --allow-running-insecure-content --user-data-dir=''"
alias week='date +%V'

# 📦 Modernized System Update
alias update='echo "🚀 Starting system update..."; xcode-select --install 2>/dev/null; sudo softwareupdate -i -a; brew update && brew upgrade && brew cleanup; if command -v npm &>/dev/null; then npm install npm -g && npm update -g; fi; if command -v gem &>/dev/null; then sudo gem update --system && gem update && gem cleanup; fi; echo "✅ System update complete!"'

alias ip="dig +short myip.opendns.com @resolver1.opendns.com"
alias localip="ipconfig getifaddr en0"
alias ips="ifconfig -a | grep -o 'inet6\? \(addr:\)\?\s\?\(\(\([0-9]\+\.\)\{3\}[0-9]\+\)\|[a-fA-F0-9:]\+\)' | awk '{ sub(/inet6? (addr:)? ?/, \"\"); print }'"

# Show active network interfaces
alias ifactive="ifconfig | pcregrep -M -o '^[^\t:]+:([^\n]|\n\t)*status: active'"

# Flush Directory Service cache
alias flush="dscacheutil -flushcache && killall -HUP mDNSResponder"

# Clean up LaunchServices to remove duplicates in the “Open With” menu
alias lscleanup="/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -kill -r -domain local -domain system -domain user && killall Finder"


# 🗑️ Nuclear Trash Disposal
emptytrash() {
  echo "🗑️  Emptying ALL trash (requires sudo)..."
  sudo rm -rfv /Volumes/*/.Trashes 2>/dev/null
  sudo rm -rfv ~/.Trash 2>/dev/null
  sudo rm -rfv /private/var/log/asl/*.asl 2>/dev/null
  sqlite3 ~/Library/Preferences/com.apple.LaunchServices.QuarantineEventsV* 'delete from LSQuarantineEvent' 2>/dev/null
  echo "✅ Trash emptied successfully!"
}

# 💼 Job Management
alias fs="du -hs"
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

# 🍺 Homebrew Force Update (DEPRECATED - brew cask is now just brew)
# This function is kept for legacy compatibility but should be replaced with standard brew commands
# Reload the shell (i.e. invoke as a login shell)
alias reload="exec ${SHELL} -l"

# Print each PATH entry on a separate line
alias path='echo -e ${PATH//:/\\n}'

# replaced with ohmyzsh extract plugin
# extract () {
#   if [ -f $1 ] ; then
#     case $1 in
#       *.tar.bz2)        tar xjf $1        ;;
#       *.tar.gz)         tar xzf $1        ;;
#       *.bz2)            bunzip2 $1        ;;
#       *.rar)            unrar x $1        ;;
#       *.gz)             gunzip $1         ;;
#       *.tar)            tar xf $1         ;;
#       *.tbz2)           tar xjf $1        ;;
#       *.tgz)            tar xzf $1        ;;
#       *.zip)            unzip $1          ;;
#       *.Z)              uncompress $1     ;;
#       *.7z)             7zr e $1          ;;
#       *)                echo "'$1' cannot be extracted via extract()" ;;
#     esac
#   else
#     echo "'$1' is not a valid file"
#   fi
# }

# 🔍 Enhanced Port Scanner
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


#====================================================================
# 🐳 DOCKER OPERATIONS - MODERNIZED & BATTLE-TESTED
#====================================================================

alias dpa='docker ps -a'
alias di='docker images'
alias dps='docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"'

# 🔍 Smart Docker Container ID Finder
did() {
  if [[ -z "$1" ]]; then
    echo "❌ Usage: did <container_name_or_id>"
    return 1
  fi
  docker ps -a --format "{{.ID}}" --filter "name=$1" | head -1
}

# 🚀 Enhanced Container Start
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

# 🛑 Enhanced Container Stop
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

# 📊 Enhanced Container Status
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

# 🧹 Docker Cleanup Operations
dclean() {
  echo "🧹 Cleaning exited containers..."
  docker container prune -f && echo "✅ Cleanup complete"
}

diclean() {
  echo "🧹 Cleaning dangling images..."
  docker image prune -f && echo "✅ Image cleanup complete"
}

# 📝 Enhanced Docker Logs with Error Handling
dlogs() {
  local container="$1"
  if [[ -z "$container" ]]; then
    echo "❌ Usage: dlogs <container_name> [docker_logs_options]"
    echo "   Examples:"
    echo "     dlogs myapp -f        # Follow logs"
    echo "     dlogs myapp --tail 50 # Last 50 lines"
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

# ☢️ NUCLEAR DOCKER CLEANUP (USE WITH EXTREME CAUTION)
dnuke() {
  echo "☢️  WARNING: This will DESTROY ALL Docker data!"
  echo "   - All containers (running and stopped)"
  echo "   - All images"
  echo "   - All volumes"
  echo "   - All networks"
  echo ""
  echo "Press Ctrl+C to cancel, Enter to continue..."
  read
  
  echo "🧹 Stopping all containers..."
  docker stop $(docker ps -aq) 2>/dev/null || true
  
  echo "🗑️  Removing all containers..."
  docker container prune -f
  
  echo "🗑️  Removing all images..."
  docker image prune -af
  
  echo "🗑️  Removing all volumes..."
  docker volume prune -f
  
  echo "🗑️  Removing all networks..."
  docker network prune -f
  
  echo "☢️  Nuclear cleanup complete! Docker environment reset."
}

#====================================================================
# ⚡ FILE SYSTEM WATCH HELPERS - OPTIMIZED
#====================================================================

declare -i last_called=0
declare -i throttle_by=5

# 🚦 Throttle function execution
@throttle() {
  local -i now=$(date +%s)
  if (($now - $last_called >= $throttle_by)); then
    "$@"
  fi
  last_called=$(date +%s)
}

# 🔄 Debounce function execution 
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

# 👀 Enhanced File System Watcher
watch() {
  if ! command -v fswatch &>/dev/null; then
    echo "❌ fswatch not found!"
    echo "💡 Install with: brew install fswatch"
    return 1
  fi
  
  if [[ $# -lt 2 ]]; then
    echo "❌ Usage: watch <path> <command>"
    echo "   Example: watch ./src 'npm run build'"
    return 1
  fi
  
  local localpath="$1"; shift
  local rest="$*"
  
  if [[ ! -e "$localpath" ]]; then
    echo "❌ Path does not exist: $localpath"
    return 1
  fi
  
  echo "👀 Watching: $localpath"
  echo "🔄 Running: $rest"
  echo "Press Ctrl+C to stop..."
  
  fswatch -0 -o --event Updated "$localpath" | xargs -0 -I file zsh -c "@debounce eval $rest"
}

#====================================================================
# 🛠️ ENHANCED UTILITY FUNCTIONS
#====================================================================

# 📁 Create directory and enter it
mkd() {
  if [[ -z "$1" ]]; then
    echo "❌ Usage: mkd <directory_name>"
    return 1
  fi
  mkdir -p "$@" && cd "$_" && echo "✅ Created and entered: $(pwd)"
}

# 🔍 Navigate to Finder location
cdf() {
  local finder_path
  finder_path=$(osascript -e 'tell app "Finder" to POSIX path of (insertion location as alias)' 2>/dev/null)
  if [[ -n "$finder_path" ]]; then
    cd "$finder_path" && echo "📂 Changed to Finder location: $(pwd)"
  else
    echo "❌ Could not get Finder location"
    return 1
  fi
}

# 📦 Smart Archive Creator with optimal compression
targz() {
  if [[ $# -eq 0 ]]; then
    echo "❌ Usage: targz <file_or_directory> [...]"
    return 1
  fi
  
  local tmpFile="${*%/}.tar"
  echo "📦 Creating archive: $tmpFile"
  
  tar -cvf "$tmpFile" --exclude=".DS_Store" --exclude="node_modules" --exclude=".git" "$@" || return 1

  local size
  if command -v stat &>/dev/null; then
    size=$(stat -f"%z" "$tmpFile" 2>/dev/null || stat -c"%s" "$tmpFile" 2>/dev/null)
  fi

  local cmd="gzip"  # Default to gzip
  if (( size < 52428800 )) && command -v zopfli &>/dev/null; then
    cmd="zopfli"  # Use zopfli for files < 50MB
  elif command -v pigz &>/dev/null; then
    cmd="pigz"    # Use parallel gzip if available
  fi

  echo "🗜️  Compressing with $cmd ($(( size / 1000 )) kB)..."
  "$cmd" -v "$tmpFile" || return 1
  [[ -f "$tmpFile" ]] && rm "$tmpFile"

  local zippedSize
  if command -v stat &>/dev/null; then
    zippedSize=$(stat -f"%z" "$tmpFile.gz" 2>/dev/null || stat -c"%s" "$tmpFile.gz" 2>/dev/null)
  fi

  echo "✅ Created: $tmpFile.gz ($(( zippedSize / 1000 )) kB)"
}

# 📏 Enhanced File/Directory Size Calculator
# Unset du alias inside the function or use command builtin
function fs {
  local arg="-sh"
  if command -v gdu &>/dev/null; then
    arg="-sbh"
    local du_cmd="gdu"
  else
    local du_cmd="command du"  # Bypass alias
  fi

  if [[ $# -gt 0 ]]; then
    eval "$du_cmd $arg -- \"$@\""
  else
    echo "📊 Current directory contents:"
    setopt LOCAL_OPTIONS NULL_GLOB
    local targets=(.* *)  # includes dotfiles and regular
    eval "$du_cmd $arg -- \"${(@q)targets}\"" | sort -hr
  fi
}

# # Use Git’s colored diff when available
# hash git &>/dev/null;
# if [ $? -eq 0 ]; then
# 	function diff() {
# 		git diff --no-index --color-words "$@";
# 	}
# fi;

# Create a data URL from a file
# 🌐 Modern Development Servers
server() {
  local port="${1:-8000}"
  local ip="localhost"
  
  echo "🚀 Starting HTTP server on http://$ip:$port/"
  echo "📁 Serving: $(pwd)"
  echo "Press Ctrl+C to stop"
  
  # Try Python 3 first, then Python 2
  if command -v python3 &>/dev/null; then
    sleep 1 && open "http://$ip:$port/" &
    python3 -m http.server "$port"
  elif command -v python &>/dev/null; then
    sleep 1 && open "http://$ip:$port/" &
    python -m SimpleHTTPServer "$port"
  else
    echo "❌ Python not found - cannot start server"
    return 1
  fi
}

# 🐘 PHP Development Server
phpserver() {
  local port="${1:-4000}"
  local ip=$(ipconfig getifaddr en1 2>/dev/null || ipconfig getifaddr en0 2>/dev/null || echo "localhost")
  
  if ! command -v php &>/dev/null; then
    echo "❌ PHP not found"
    return 1
  fi
  
  echo "🐘 Starting PHP server on http://$ip:$port/"
  echo "📁 Serving: $(pwd)"
  sleep 1 && open "http://$ip:$port/" &
  php -S "$ip:$port"
}

# 📊 File Compression Comparison
gz() {
  if [[ -z "$1" ]]; then
    echo "❌ Usage: gz <filename>"
    return 1
  fi
  
  if [[ ! -f "$1" ]]; then
    echo "❌ File not found: $1"
    return 1
  fi
  
  local origsize=$(wc -c < "$1")
  local gzipsize=$(gzip -c "$1" | wc -c)
  local ratio=$(echo "scale=2; $gzipsize * 100 / $origsize" | bc -l 2>/dev/null || echo "N/A")
  
  printf "📄 Original: %'d bytes
" "$origsize"
  printf "🗜️  Gzipped:  %'d bytes (%s%%)
" "$gzipsize" "$ratio"
}

# 📋 Pretty JSON Formatter
json() {
  if [[ $# -eq 0 ]]; then
    echo "❌ Usage: json '<json_string>' OR echo '<json>' | json"
    return 1
  fi
  
  local json_tool="cat"
  if command -v python3 &>/dev/null; then
    json_tool="python3 -m json.tool"
  elif command -v python &>/dev/null; then
    json_tool="python -m json.tool"
  fi
  
  local highlighter="cat"
  if command -v pygmentize &>/dev/null; then
    highlighter="pygmentize -l javascript"
  elif command -v bat &>/dev/null; then
    highlighter="bat --language=json --style=plain"
  fi
  
  if [[ -t 0 ]]; then  # argument provided
    echo "$*" | $json_tool | $highlighter
  else  # pipe input
    $json_tool | $highlighter
  fi
}

# Start an HTTP server from a directory, optionally specifying the port
function server() {
	local port="${1:-8000}";
	sleep 1 && open "http://localhost:${port}/" &
	# Set the default Content-Type to `text/plain` instead of `application/octet-stream`
	# And serve everything as UTF-8 (although not technically correct, this doesn’t break anything for binary files)
	python -c $'import SimpleHTTPServer;\nmap = SimpleHTTPServer.SimpleHTTPRequestHandler.extensions_map;\nmap[""] = "text/plain";\nfor key, value in map.items():\n\tmap[key] = value + ";charset=UTF-8";\nSimpleHTTPServer.test();' "$port";
}

# Start a PHP server from a directory, optionally specifying the port
# (Requires PHP 5.4.0+.)
function phpserver() {
	local port="${1:-4000}";
	local ip=$(ipconfig getifaddr en1);
	sleep 1 && open "http://${ip}:${port}/" &
	php -S "${ip}:${port}";
}

# Compare original and gzipped file size
function gz() {
	local origsize=$(wc -c < "$1");
	local gzipsize=$(gzip -c "$1" | wc -c);
	local ratio=$(echo "$gzipsize * 100 / $origsize" | bc -l);
	printf "orig: %d bytes\n" "$origsize";
	printf "gzip: %d bytes (%2.2f%%)\n" "$gzipsize" "$ratio";
}

# Syntax-highlight JSON strings or files
# Usage: `json '{"foo":42}'` or `echo '{"foo":42}' | json`
function json() {
	if [ -t 0 ]; then # argument
		python -mjson.tool <<< "$*" | pygmentize -l javascript;
	else # pipe
		python -mjson.tool | pygmentize -l javascript;
	fi;
}

# Run `dig` and display the most useful info
function digga() {
	dig +nocmd "$1" any +multiline +noall +answer;
}

# UTF-8-encode a string of Unicode symbols
function escape() {
	printf "\\\x%s" $(printf "$@" | xxd -p -c1 -u);
	# print a newline unless we’re piping the output to another program
	if [ -t 1 ]; then
		echo ""; # newline
	fi;
}

# Show all the names (CNs and SANs) listed in the SSL certificate
# for a given domain
function getcertnames() {
	if [ -z "${1}" ]; then
		echo "ERROR: No domain specified.";
		return 1;
	fi;

	local domain="${1}";
	echo "Testing ${domain}…";
	echo ""; # newline

	local tmp=$(echo -e "GET / HTTP/1.0\nEOT" \
		| openssl s_client -connect "${domain}:443" -servername "${domain}" 2>&1);

	if [[ "${tmp}" = *"-----BEGIN CERTIFICATE-----"* ]]; then
		local certText=$(echo "${tmp}" \
			| openssl x509 -text -certopt "no_aux, no_header, no_issuer, no_pubkey, \
			no_serial, no_sigdump, no_signame, no_validity, no_version");
		echo "Common Name:";
		echo ""; # newline
		echo "${certText}" | grep "Subject:" | sed -e "s/^.*CN=//" | sed -e "s/\/emailAddress=.*//";
		echo ""; # newline
		echo "Subject Alternative Name(s):";
		echo ""; # newline
		echo "${certText}" | grep -A 1 "Subject Alternative Name:" \
			| sed -e "2s/DNS://g" -e "s/ //g" | tr "," "\n" | tail -n +2;
		return 0;
	else
		echo "ERROR: Certificate not found.";
		return 1;
	fi;
}

# # `s` with no arguments opens the current directory in Sublime Text, otherwise
# # opens the given location
# function s() {
# 	if [ $# -eq 0 ]; then
# 		subl .;
# 	else
# 		subl "$@";
# 	fi;
# }

# `v` with no arguments opens the current directory in Vim, otherwise opens the
# given location
function v() {
	if [ $# -eq 0 ]; then
		vim .;
	else
		vim "$@";
	fi;
}

# `o` with no arguments opens the current directory, otherwise opens the given
# location
function o() {
	if [ $# -eq 0 ]; then
		open .;
	else
		open "$@";
	fi;
}

# `tre` is a shorthand for `tree` with hidden files and color enabled, ignoring
# the `.git` directory, listing directories first. The output gets piped into
# `less` with options to preserve color and line numbers, unless the output is
# small enough for one screen.
function tree() {
	tree -aC -I '.git|node_modules|bower_components' --dirsfirst "$@" | less -FRNX;
}