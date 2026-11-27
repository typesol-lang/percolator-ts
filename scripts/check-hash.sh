#!/bin/sh
# Checks that a build of the port is the binary the recorded comparison ran on.
#   sh scripts/check-hash.sh [target/percolator.so]
set -eu
SO="${1:-target/percolator.so}"
EXPECTED=c6dc6b24c4f0a8cfb801eaf542e27db66357a2051b41b6012aba8ffb30f55b9c
EXPECTED_SIZE=1362912
[ -f "$SO" ] || { echo "$SO missing: run pnpm build" >&2; exit 1; }
if command -v sha256sum >/dev/null 2>&1; then got=$(sha256sum "$SO" | cut -c1-64); else got=$(shasum -a 256 "$SO" | cut -c1-64); fi
size=$(wc -c <"$SO" | tr -d ' ')
echo "$SO: sha256 $got, $size bytes"
if [ "$got" = "$EXPECTED" ] && [ "$size" = "$EXPECTED_SIZE" ]; then
  echo "as expected"
else
  echo "expected sha256 $EXPECTED, $EXPECTED_SIZE bytes" >&2
  exit 1
fi
