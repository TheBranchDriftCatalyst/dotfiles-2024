# Extract Audio — Finder Quick Action body (files arrive as "$@").
# AAC 192k → .m4a beside the original (re-encode: container-safe for any input).
# @FFMPEG@ is substituted with the nix store path at build time.
n=0
for f in "$@"; do
  base="${f%.*}"
  @FFMPEG@ -y -i "$f" -vn -c:a aac -b:a 192k "${base}.m4a" </dev/null >/dev/null 2>&1 && ((n++))
done
/usr/bin/osascript -e "display notification \"Extracted audio from $n file(s) → .m4a\" with title \"Quick Action\""
