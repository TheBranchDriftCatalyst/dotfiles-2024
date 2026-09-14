# Compress PDF — Finder Quick Action body (files arrive as "$@").
# Ghostscript /ebook preset (150dpi images) → _small copy beside the original.
# @GS@ is substituted with the nix store path at build time.
n=0
for f in "$@"; do
  base="${f%.*}"
  @GS@ -sDEVICE=pdfwrite -dCompatibilityLevel=1.4 -dPDFSETTINGS=/ebook \
    -dNOPAUSE -dQUIET -dBATCH -sOutputFile="${base}_small.pdf" "$f" && ((n++))
done
/usr/bin/osascript -e "display notification \"Compressed $n PDF(s) → _small copies\" with title \"Quick Action\""
