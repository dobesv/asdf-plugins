#!/usr/bin/env bash
# rclone - https://rclone.org / https://github.com/rclone/rclone
# Release tags are formatted "v<version>"; assets are
# "rclone-v<version>-<os>-<arch>.zip" containing a single
# "rclone-v<version>-<os>-<arch>/rclone" binary alongside docs.

readonly RCLONE_REPO="rclone/rclone"

list_all_versions() {
  # Tags look like "v1.74.3" -> strip leading "v", keep x.y.z, sort.
  list_github_versions "$RCLONE_REPO" |
    sed -n 's#^v##p' |
    grep -E '^[0-9]+\.[0-9]+\.[0-9]+$' |
    sort_versions |
    tr '\n' ' '
}

# Map the current platform to rclone's <os>-<arch> naming. rclone uses "osx"
# for macOS and the same amd64/arm64 arch names as get_arch.
get_rclone_platform() {
  local os arch
  os="$(get_os)"
  arch="$(get_arch)"
  case "$os" in
    darwin) os="osx" ;;
  esac
  case "${os}_${arch}" in
    linux_amd64 | linux_arm64 | osx_amd64 | osx_arm64) echo "${os}-${arch}" ;;
    *) error_exit "rclone does not support platform: $(get_os)_${arch}" ;;
  esac
}

get_download_url() {
  local version="$1" platform
  platform="$(get_rclone_platform)"
  echo "https://github.com/${RCLONE_REPO}/releases/download/v${version}/rclone-v${version}-${platform}.zip"
}

download_tool() {
  local install_type="$1" version="$2" download_path="$3"
  [ "$install_type" = "version" ] ||
    error_exit "rclone only supports version installs, not ref installs"

  local url archive
  url="$(get_download_url "$version")"
  archive="${download_path}/rclone.zip"

  mkdir -p "$download_path"
  download_file "$url" "$archive"
  extract_zip "$archive" "$download_path"
  rm -f "$archive"
}

# shellcheck disable=SC2034
install_tool() {
  local install_type="$1" version="$2" download_path="$3" install_path="$4"
  # The zip extracts to rclone-v<version>-<os>-<arch>/rclone.
  local platform
  platform="$(get_rclone_platform)"
  install_binary \
    "${download_path}/rclone-v${version}-${platform}/rclone" \
    "${install_path}/bin/rclone" "rclone"
}
