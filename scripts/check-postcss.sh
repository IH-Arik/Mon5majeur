#!/bin/sh
# Supply-chain guard: postcss.config.* files must stay tiny and readable.
# The known malware appends a ~32KB single-line payload to these files.
# Usage: scripts/check-postcss.sh   (also run by .githooks/pre-commit, pre-push, and CI)

MAX_BYTES=500
MAX_LINE=120
bad=0

tmp_files=$(mktemp 2>/dev/null || echo "/tmp/postcss_files_$$")
git ls-files | grep -E '(^|/)postcss\.config\.[cm]?js$|(^|/)postcss\.config\.mjs$' | sort -u > "$tmp_files"

while IFS= read -r f || [ -n "$f" ]; do
  [ -f "$f" ] || continue
  size=$(wc -c < "$f" | tr -d ' ')
  longest=$(awk '{ if (length($0)>m) m=length($0) } END { print m+0 }' "$f")

  malware_pattern=0
  if grep -q -E '(candidateBlocks|decodeAddress|withRpcEndpoints|_0x[0-9a-fA-F]+|windowsHide)' "$f" 2>/dev/null; then
    malware_pattern=1
  fi

  if [ "$size" -ge "$MAX_BYTES" ] || [ "$longest" -ge "$MAX_LINE" ] || [ "$malware_pattern" -eq 1 ]; then
    echo "BLOCKED: $f looks tampered (size=${size}B, longest line=${longest} chars, malware_match=${malware_pattern})."
    bad=1
  fi
done < "$tmp_files"

rm -f "$tmp_files"

if [ "$bad" -ne 0 ]; then
  echo "Do NOT commit or push. The file contains unauthorized/malicious payloads."
  echo "Restore the clean version using: git checkout HEAD -- <file>"
  exit 1
fi

echo "PostCSS check passed: all configs are clean."
exit 0