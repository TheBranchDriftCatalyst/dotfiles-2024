# Clean Zip — Finder Quick Action body (files arrive as "$@").
# Zips the selection WITHOUT .DS_Store / __MACOSX / ._* resource-fork junk.
# Assumes one Finder selection = one directory (true for a multi-select in a
# window); archive lands beside the first item, named after it (or archive-*).
first="$1"
dir="${first:h}"
if (($# == 1)); then
  name="${first:t:r}"
else
  name="archive-$(date +%H%M%S)"
fi
out="$dir/${name}.zip"
cd "$dir" || exit 1
items=()
for f in "$@"; do items+=("${f:t}"); done
/usr/bin/zip -r -X "$out" "${items[@]}" -x '*.DS_Store' -x '__MACOSX/*' -x '*/._*' >/dev/null &&
  /usr/bin/osascript -e "display notification \"Zipped $# item(s) → ${out:t}\" with title \"Quick Action\"" ||
  /usr/bin/osascript -e 'display notification "Zip failed" with title "Quick Action"'
