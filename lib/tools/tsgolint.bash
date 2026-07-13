#!/usr/bin/env bash
# tsgolint - https://github.com/robinnagpal-newsela/oxlint-tsgolint
# Release tags are formatted "v<calver>" (e.g. "v2026.06.24"); assets are bare
# binaries named "tsgolint-<os>-<arch>" (no archive) for linux/darwin on
# amd64/arm64.
#
# Note: oxlint does NOT find tsgolint on PATH. Point oxlint --type-aware at this
# binary by exporting OXLINT_TSGOLINT_PATH to the installed binary path, e.g.
#   export OXLINT_TSGOLINT_PATH="$(asdf which tsgolint)"

readonly TSGOLINT_REPO="robinnagpal-newsela/oxlint-tsgolint"

list_all_versions() {
  # Tags look like "v2026.06.24" -> strip leading "v", keep calver, sort.
  list_github_versions "$TSGOLINT_REPO" |
    sed -n 's#^v##p' |
    grep -E '^[0-9]+\.[0-9]+\.[0-9]+$' |
    sort_versions |
    tr '\n' ' '
}

# Map the current platform to tsgolint's <os>-<arch> asset naming. tsgolint uses
# the same darwin/linux and amd64/arm64 names as get_os/get_arch.
get_tsgolint_platform() {
  local os arch
  os="$(get_os)"
  arch="$(get_arch)"
  case "${os}_${arch}" in
    linux_amd64 | linux_arm64 | darwin_amd64 | darwin_arm64) echo "${os}-${arch}" ;;
    *) error_exit "tsgolint does not support platform: ${os}_${arch}" ;;
  esac
}

get_download_url() {
  local version="$1" platform
  platform="$(get_tsgolint_platform)"
  echo "https://github.com/${TSGOLINT_REPO}/releases/download/v${version}/tsgolint-${platform}"
}

download_tool() {
  local install_type="$1" version="$2" download_path="$3"
  [ "$install_type" = "version" ] ||
    error_exit "tsgolint only supports version installs, not ref installs"

  local url
  url="$(get_download_url "$version")"

  mkdir -p "$download_path"
  # Asset is a bare binary, not an archive; download it directly.
  download_file "$url" "${download_path}/tsgolint"
}

# shellcheck disable=SC2034
install_tool() {
  local install_type="$1" version="$2" download_path="$3" install_path="$4"
  install_binary "${download_path}/tsgolint" "${install_path}/bin/tsgolint" "tsgolint"
}
