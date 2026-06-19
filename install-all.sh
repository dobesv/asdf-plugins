#!/usr/bin/env bash
# Add (or update) every tool plugin from this repo into asdf.
set -euo pipefail

readonly REPO_URL="https://github.com/dobesv/asdf-plugins.git"
readonly TOOLS=(
  harnx
  luchta
  rclone
)

command -v asdf >/dev/null 2>&1 || {
  echo "asdf is not installed. See https://asdf-vm.com" >&2
  exit 1
}

for tool in "${TOOLS[@]}"; do
  if asdf plugin list 2>/dev/null | grep -qx "$tool"; then
    current_url="$(asdf plugin list --urls 2>/dev/null | awk -v t="$tool" '$1==t {print $2}')"
    if [ "$current_url" = "$REPO_URL" ]; then
      echo "Updating $tool..."
      asdf plugin update "$tool"
    else
      echo "Re-adding $tool (URL changed)..."
      asdf plugin remove "$tool"
      asdf plugin add "$tool" "$REPO_URL"
    fi
  else
    echo "Adding $tool..."
    asdf plugin add "$tool" "$REPO_URL"
  fi
done

echo "Done."
