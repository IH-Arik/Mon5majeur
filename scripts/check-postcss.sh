#!/bin/sh
# Supply-chain guard: postcss.config.* files must stay tiny and readable.
# The known malware appends a ~32KB single-line payload to these files.
# Usage: scripts/check-postcss.sh   (also run by .githooks/pre-commit and CI)
MAX_BYTES=500
MAX_LINE=120
bad=0
for f in $(git ls-files | grep -E '(^|/)postcss\.config\.[cm]?js$|(^|/)postcss\.config\.mjs$' | sort -u); do
  [ -f "$f" ] || continue
  size=$(wc -c < "$f" | tr -d ' ')
  longest=$(awk '{ if (length($0)>m) m=length($0) } END { print m+0 }' "$f")
  if [ "$size" -ge "$MAX_BYTES" ] || [ "$longest" -ge "$MAX_LINE" ]; then
    echo "BLOCKED: $f looks tampered (size=${size}B, longest line=${longest} chars)."
    bad=1
  fi
done
if [ "$bad" -ne 0 ]; then
  echo "Do NOT commit. Restore with: git checkout origin/main -- <file>"
  echo "Then: delete node_modules + package-lock.json, run 'npm install', and check the file size again."
  exit 1
fi
