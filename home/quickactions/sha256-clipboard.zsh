# SHA-256 → Clipboard — Finder Quick Action body (files arrive as "$@").
# One file: the bare hash lands on the clipboard. Several: "hash  name"
# lines. Notification shows a truncated preview.
out=""
if (($# == 1)); then
  h=$(/usr/bin/shasum -a 256 "$1")
  out="${h%% *}"
else
  for f in "$@"; do
    h=$(/usr/bin/shasum -a 256 "$f")
    out+="${h%% *}  ${f:t}"$'\n'
  done
fi
printf '%s' "$out" | /usr/bin/pbcopy
/usr/bin/osascript -e "display notification \"Copied: $(printf '%s' "$out" | head -c 24)… ($# file(s))\" with title \"SHA-256\""
