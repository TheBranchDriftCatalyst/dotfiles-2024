# Strip Metadata — Finder Quick Action body (files arrive as "$@").
# -all= wipes EVERYTHING (GPS, timestamps, camera serial, embedded thumbs);
# orientation + ICC are copied back so the clean copy doesn't render rotated
# or color-shifted. Original untouched; output lands beside it as _clean.
# @EXIFTOOL@ is substituted with the nix store path at build time.
n=0
for f in "$@"; do
  base="${f%.*}"
  ext="${f##*.}"
  @EXIFTOOL@ -all= -tagsfromfile @ -Orientation -ICC_Profile:all \
    -o "${base}_clean.${ext}" "$f" >/dev/null 2>&1 && ((n++))
done
/usr/bin/osascript -e "display notification \"Stripped metadata from $n image(s) → _clean copies\" with title \"Quick Action\""
