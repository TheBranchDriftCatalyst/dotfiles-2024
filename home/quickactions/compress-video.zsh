# Compress Video — Finder Quick Action body (files arrive as "$@").
# CRF 28 H.264 (visibly-fine, much smaller) → _small.mp4 beside the original.
# @FFMPEG@ is substituted with the nix store path at build time.
n=0
for f in "$@"; do
  base="${f%.*}"
  @FFMPEG@ -y -i "$f" -c:v libx264 -crf 28 -preset veryfast \
    -c:a aac -b:a 128k -movflags +faststart "${base}_small.mp4" </dev/null >/dev/null 2>&1 && ((n++))
done
/usr/bin/osascript -e "display notification \"Compressed $n video(s) → _small.mp4\" with title \"Quick Action\""
