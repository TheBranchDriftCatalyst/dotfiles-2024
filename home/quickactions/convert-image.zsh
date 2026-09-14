# Convert Image… — Finder Quick Action body (files arrive as "$@").
# Format picker → ImageMagick conversion beside the original.
# @MAGICK@ is substituted with the nix store path at build time.
FMT=$(/usr/bin/osascript -e 'choose from list {"png","jpeg","webp","heic","tiff","avif","gif"} with title "Convert Image" with prompt "Target format:" default items {"png"}') || exit 0
[[ "$FMT" == "false" ]] && exit 0
n=0
for f in "$@"; do
  base="${f%.*}"
  @MAGICK@ "$f" "${base}.${FMT}" && ((n++))
done
/usr/bin/osascript -e "display notification \"Converted $n image(s) to $FMT\" with title \"Quick Action\""
