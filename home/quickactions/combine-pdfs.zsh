# Combine PDFs — Finder Quick Action body (files arrive as "$@").
# Merges the selection name-sorted into combined-<timestamp>.pdf beside the
# first file. @QPDF@ is substituted with the nix store path at build time.
if (($# < 2)); then
  /usr/bin/osascript -e 'display notification "Select at least two PDFs" with title "Quick Action"'
  exit 0
fi
files=(${(o)@}) # name-sorted, so page order is predictable
out="${files[1]:h}/combined-$(date +%Y%m%d-%H%M%S).pdf"
if @QPDF@ --empty --pages "${files[@]}" -- "$out"; then
  /usr/bin/osascript -e "display notification \"Combined $# PDFs → ${out:t}\" with title \"Quick Action\""
else
  /usr/bin/osascript -e 'display notification "Combine failed" with title "Quick Action"'
fi
