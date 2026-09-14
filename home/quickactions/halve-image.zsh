# Halve Image (50%) — Finder Quick Action body (files arrive as "$@").
# No prompt; writes a _50pct copy beside the original.
n=0
for f in "$@"; do
  base="${f%.*}"
  ext="${f##*.}"
  read -r W H < <(/usr/bin/sips -g pixelWidth -g pixelHeight "$f" | /usr/bin/awk '/pixelWidth/{w=$2}/pixelHeight/{h=$2}END{print w, h}')
  /usr/bin/sips -z $((H / 2)) $((W / 2)) "$f" --out "${base}_50pct.${ext}" >/dev/null && ((n++))
done
/usr/bin/osascript -e "display notification \"Halved $n image(s)\" with title \"Quick Action\""
