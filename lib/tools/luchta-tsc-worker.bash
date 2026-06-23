#!/usr/bin/env bash
# luchta-tsc-worker - https://github.com/dobesv/typescript-go
# Release tags are formatted "v<version>" (date-based, e.g. v2026.06.22);
# assets are raw binaries named "luchta-tsc-worker-<os>-<arch>".

readonly LUCHTA_TSC_WORKER_REPO="dobesv/typescript-go"

list_all_versions() {
  # Tags look like "v2026.06.22" -> strip "v", keep date-style x.y.z, sort.
  list_github_versions "$LUCHTA_TSC_WORKER_REPO" |
    sed -n 's#^v##p' |
    grep -E '^[0-9]+\.[0-9]+\.[0-9]+$' |
    sort_versions |
    tr '\n' ' '
}

get_download_url() {
  local version="$1" os arch
  os="$(get_os)"
  arch="$(get_arch)"
  echo "https://github.com/${LUCHTA_TSC_WORKER_REPO}/releases/download/v${version}/luchta-tsc-worker-${os}-${arch}"
}

download_tool() {
  local install_type="$1" version="$2" download_path="$3"
  [ "$install_type" = "version" ] ||
    error_exit "luchta-tsc-worker only supports version installs, not ref installs"

  local url
  url="$(get_download_url "$version")"

  mkdir -p "$download_path"
  download_file "$url" "${download_path}/luchta-tsc-worker"
}

# shellcheck disable=SC2034
install_tool() {
  local install_type="$1" version="$2" download_path="$3" install_path="$4"
  install_binary "${download_path}/luchta-tsc-worker" "${install_path}/bin/luchta-tsc-worker" "luchta-tsc-worker"
}
