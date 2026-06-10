#!/usr/bin/env bash
# Shared helpers for the asdf mono-plugin dispatcher and tool definitions.
# Sourced (not executed) by bin/* scripts before the per-tool script.

# Print a message to stderr and exit. Usage: error_exit "msg" [code]
error_exit() {
  echo "asdf-plugins: $1" >&2
  exit "${2:-1}"
}

command_exists() {
  command -v "$1" >/dev/null 2>&1
}

# curl with a User-Agent and optional GitHub auth to dodge rate limits.
curl_wrapper() {
  local args=(--header "User-Agent: dobesv/asdf-plugins")
  if [ -n "${GITHUB_API_TOKEN:-}" ]; then
    args+=(--header "Authorization: token ${GITHUB_API_TOKEN}")
  fi
  curl "${args[@]}" "$@"
}

# Normalize OS to darwin|linux.
get_os() {
  local os
  os="$(uname -s)"
  case "$os" in
    Darwin) echo "darwin" ;;
    Linux) echo "linux" ;;
    *) error_exit "unsupported OS: $os" ;;
  esac
}

# Normalize arch to amd64|arm64.
get_arch() {
  local arch
  arch="$(uname -m)"
  case "$arch" in
    x86_64 | amd64) echo "amd64" ;;
    arm64 | aarch64) echo "arm64" ;;
    *) error_exit "unsupported architecture: $arch" ;;
  esac
}

# Go-style platform string, e.g. linux_amd64.
get_platform() {
  local os arch
  os="$(get_os)"
  arch="$(get_arch)"
  echo "${os}_${arch}"
}

# Download a URL to a destination path.
download_file() {
  local url="$1" dest="$2"
  curl_wrapper -fsSL -o "$dest" "$url" || error_exit "failed to download: $url"
}

extract_tar_gz() {
  local archive="$1" dest="$2"
  mkdir -p "$dest"
  tar -xzf "$archive" -C "$dest" || error_exit "failed to extract: $archive"
}

extract_zip() {
  local archive="$1" dest="$2"
  mkdir -p "$dest"
  unzip -q -o "$archive" -d "$dest" || error_exit "failed to extract: $archive"
}

# Copy a binary into place and make it executable.
# Usage: install_binary <src> <dest> <name>
install_binary() {
  local src="$1" dest="$2" name="$3"
  [ -f "$src" ] || error_exit "${name}: binary not found at ${src}"
  mkdir -p "$(dirname "$dest")"
  cp "$src" "$dest" || error_exit "${name}: failed to copy binary"
  chmod +x "$dest" || error_exit "${name}: failed to chmod binary"
}

# Semantic version sort (rbenv/ruby-build trick). Reads stdin, writes stdout.
sort_versions() {
  sed 'h; s/[+-]/./g; s/.p\([[:digit:]]\)/.z\1/; s/$/.z/; G; s/\n/ /' |
    LC_ALL=C sort -t. -k 1,1n -k 2,2n -k 3,3n -k 4,4n -k 5,5n |
    awk '{print $2}'
}

# Fetch the raw releases JSON for a GitHub repo.
github_releases() {
  local repo="$1"
  curl_wrapper -fsSL "https://api.github.com/repos/${repo}/releases?per_page=100" ||
    error_exit "failed to fetch releases for ${repo}"
}

# Print release tag_names, newline-separated. Optional grep filter as $2.
list_github_versions() {
  local repo="$1" filter="${2:-}"
  local raw tags
  raw="$(github_releases "$repo")" || return 1
  tags="$(printf '%s' "$raw" | grep -oE '"tag_name":[[:space:]]*"[^"]+"' | sed -E 's/.*"tag_name":[[:space:]]*"([^"]+)".*/\1/')"
  if [ -n "$filter" ]; then
    printf '%s\n' "$tags" | grep -E "$filter"
  else
    printf '%s\n' "$tags"
  fi
}
