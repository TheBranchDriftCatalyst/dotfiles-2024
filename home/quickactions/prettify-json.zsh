# Prettify JSON — Finder Quick Action body (files arrive as "$@").
# jq . → .pretty.json copy beside the original; invalid JSON is reported,
# never half-written. @JQ@ is substituted with the nix store path at build time.
n=0
bad=0
for f in "$@"; do
  base="${f%.json}"
  if @JQ@ . "$f" >"${base}.pretty.json" 2>/dev/null; then
    ((n++))
  else
    rm -f "${base}.pretty.json"
    ((bad++))
  fi
done
msg="Prettified $n JSON file(s)"
((bad > 0)) && msg+=" — $bad invalid"
/usr/bin/osascript -e "display notification \"$msg\" with title \"Quick Action\""
