#!/usr/bin/env bash
# luchta - https://github.com/dobesv/luchta
# Release tags are formatted "luchta/v<version>"; assets are
# "luchta-v<version>-<rust-target>.tar.gz" containing a single `luchta` binary.

readonly LUCHTA_REPO="dobesv/luchta"

list_all_versions() {
  # Tags look like "luchta/v0.1.1" -> strip "luchta/v", keep x.y.z, sort.
  list_github_versions "$LUCHTA_REPO" |
    sed -n 's#^luchta/v##p' |
    grep -E '^[0-9]+\.[0-9]+\.[0-9]+$' |
    sort_versions |
    tr '\n' ' '
}

# Map the current platform to luchta's Rust target triple.
get_luchta_target() {
  local os arch
  os="$(get_os)"
  arch="$(get_arch)"
  case "${os}_${arch}" in
    linux_amd64) echo "x86_64-unknown-linux-musl" ;;
    linux_arm64) echo "aarch64-unknown-linux-musl" ;;
    darwin_amd64) echo "x86_64-apple-darwin" ;;
    darwin_arm64) echo "aarch64-apple-darwin" ;;
    *) error_exit "luchta does not support platform: ${os}_${arch}" ;;
  esac
}

get_download_url() {
  local version="$1" target
  target="$(get_luchta_target)"
  echo "https://github.com/${LUCHTA_REPO}/releases/download/luchta/v${version}/luchta-v${version}-${target}.tar.gz"
}

download_tool() {
  local install_type="$1" version="$2" download_path="$3"
  [ "$install_type" = "version" ] ||
    error_exit "luchta only supports version installs, not ref installs"

  local url archive
  url="$(get_download_url "$version")"
  archive="${download_path}/luchta.tar.gz"

  mkdir -p "$download_path"
  download_file "$url" "$archive"
  extract_tar_gz "$archive" "$download_path"
  rm -f "$archive"
}

# shellcheck disable=SC2034
install_tool() {
  local install_type="$1" version="$2" download_path="$3" install_path="$4"
  install_binary "${download_path}/luchta" "${install_path}/bin/luchta" "luchta"
}
