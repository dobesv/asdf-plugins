#!/usr/bin/env bash
# Install the latest version of each tool and run its version command.
set -uo pipefail

# tool -> version command (run as `<binary> <flag>`)
declare -A VERSION_CMD=(
  [harnx]="--version"
)

pass=0
fail=0

for tool in "${!VERSION_CMD[@]}"; do
  echo "=== $tool ==="
  if ! asdf plugin list 2>/dev/null | grep -qx "$tool"; then
    echo "  SKIP: plugin '$tool' not added (run ./install-all.sh first)"
    continue
  fi

  echo "  versions: $(asdf list-all "$tool" | tr '\n' ' ')"

  if ! asdf install "$tool" latest; then
    echo "  FAIL: install"
    fail=$((fail + 1))
    continue
  fi

  latest="$(asdf latest "$tool")"
  asdf shell "$tool" "$latest" 2>/dev/null || asdf local "$tool" "$latest"

  flag="${VERSION_CMD[$tool]}"
  if "$tool" "$flag"; then
    echo "  PASS"
    pass=$((pass + 1))
  else
    echo "  FAIL: version command"
    fail=$((fail + 1))
  fi
done

echo "=== results: ${pass} passed, ${fail} failed ==="
[ "$fail" -eq 0 ]
