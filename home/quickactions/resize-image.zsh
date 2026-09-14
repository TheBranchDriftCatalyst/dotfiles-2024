# Resize Image… — Finder Quick Action body (files arrive as "$@").
# Prompts WxH (exact, sips -z) or a single number (fit longest side, sips -Z);
# writes suffixed copies, never touches the original.
SIZE=$(/usr/bin/osascript -e 'text returned of (display dialog "Resize to WxH (exact), or a single number (fit longest side):" default answer "1920x1080" with title "Resize Image")') || exit 0
n=0
for f in "$@"; do
  base="${f%.*}"
  ext="${f##*.}"
  if [[ "$SIZE" == *x* ]]; then
    W="${SIZE%x*}"
    H="${SIZE#*x}"
    /usr/bin/sips -z "$H" "$W" "$f" --out "${base}_${W}x${H}.${ext}" >/dev/null && ((n++))
  else
    /usr/bin/sips -Z "$SIZE" "$f" --out "${base}_${SIZE}.${ext}" >/dev/null && ((n++))
  fi
done
/usr/bin/osascript -e "display notification \"Resized $n image(s) to $SIZE\" with title \"Quick Action\""
