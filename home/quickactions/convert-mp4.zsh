# Convert to MP4 — Finder Quick Action body (files arrive as "$@").
# H.264 + AAC + faststart (streams/scrubs well everywhere) → .mp4 copy.
# @FFMPEG@ is substituted with the nix store path at build time.
n=0
for f in "$@"; do
  base="${f%.*}"
  @FFMPEG@ -y -i "$f" -c:v libx264 -crf 23 -preset veryfast \
    -c:a aac -b:a 192k -movflags +faststart "${base}.mp4" </dev/null >/dev/null 2>&1 && ((n++))
done
/usr/bin/osascript -e "display notification \"Converted $n video(s) to MP4\" with title \"Quick Action\""
