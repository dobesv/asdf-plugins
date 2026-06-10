#!/usr/bin/env bash
# Install the latest version of each tool and run its version command.
set -uo pipefail

command -v asdf >/dev/null 2>&1 || {
  echo "asdf is not installed. See https://asdf-vm.com" >&2
  exit 1
}

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
  # asdf honors ASDF_<TOOL>_VERSION for the current process; uppercase the
  # tool name and replace non-alphanumerics with underscores.
  tool_env="ASDF_${tool^^}_VERSION"
  tool_env="${tool_env//[^A-Z0-9_]/_}"
  export "${tool_env}=${latest}"

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
