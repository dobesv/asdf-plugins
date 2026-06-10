# asdf mono-plugin (`dobesv/asdf-plugins`) — Design

Date: 2026-06-10

## Purpose

Create a single asdf plugin repository that can install many CLI tools, modeled on
[SmartestEdu/asdf-plugins](https://github.com/SmartestEdu/asdf-plugins). The first
tool supported is **harnx** (installed from
<https://github.com/dobesv/harnx/releases>). The structure must make adding more
tools later a matter of dropping in one new file.

## Architecture: dispatcher pattern

One git repo, many tools. asdf is told the plugin name when it is added:

```
asdf plugin add harnx https://github.com/dobesv/asdf-plugins.git
```

asdf clones the repo into a plugin directory named after the first argument
(`harnx`). The `bin/` scripts derive the tool name from `basename "$plugin_dir"`,
source the matching `lib/tools/<tool_name>.bash`, and dispatch to its functions.
A second tool would be added with `asdf plugin add <other> <same-url>`, reusing
the same repo with a different plugin-dir name.

## File layout

```
.gitignore
.tool-versions
LICENSE              # MIT, Dobes Vandermeer
README.md            # usage, supported tools, how to add tools
CLAUDE.md            # contributor guide: how to add a new lib/tools/<name>.bash
install-all.sh       # TOOLS=(harnx); asdf plugin add/update loop
test-all.sh          # install latest of each tool, run its version command
bin/
  download           # dispatch -> download_tool
  install            # dispatch -> install_tool
  list-all           # dispatch -> list_all_versions
lib/
  utils.bash         # shared helpers
  tools/
    harnx.bash       # harnx tool definition
```

asdf's defaults cover everything else: binaries placed in `<install_path>/bin`
are added to PATH automatically, and `latest` resolution uses the sorted
`list-all` output. No `latest-stable`, `list-bin-paths`, `exec-env`, or
`uninstall` scripts are needed.

## `bin/*` dispatcher template

All three scripts share one template; they differ only in the function dispatched
and the `ASDF_*` env vars passed:

```bash
#!/usr/bin/env bash
set -euo pipefail
readonly script_dir="$(cd -P "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly plugin_dir="$(dirname "$script_dir")"
source "${plugin_dir}/lib/utils.bash"
readonly tool_name="$(basename "$plugin_dir")"
readonly tool_script="${plugin_dir}/lib/tools/${tool_name}.bash"
[ -f "$tool_script" ] || error_exit "Tool '${tool_name}' is not supported: ${tool_script}"
source "$tool_script"
command -v <fn> &>/dev/null || error_exit "Tool '${tool_name}' does not implement <fn>"
<fn> "$ASDF_..." ...
```

- `bin/download` → `download_tool  "$ASDF_INSTALL_TYPE" "$ASDF_INSTALL_VERSION" "$ASDF_DOWNLOAD_PATH"`
- `bin/install`  → `install_tool   "$ASDF_INSTALL_TYPE" "$ASDF_INSTALL_VERSION" "$ASDF_DOWNLOAD_PATH" "$ASDF_INSTALL_PATH"`
- `bin/list-all` → `list_all_versions`

## `lib/utils.bash` — shared helpers

Sourced by every bin script before the tool file:

- `error_exit(msg [,code])` — print to stderr, exit.
- `curl_wrapper(...)` — `curl` with a User-Agent header; sends
  `Authorization: token $GITHUB_API_TOKEN` when that env var is set.
- `get_os()` — normalize `uname -s` → `darwin` / `linux`.
- `get_arch()` — normalize `uname -m` → `amd64` / `arm64` (others error).
- `get_platform()` — `"$(get_os)_$(get_arch)"`.
- `download_file(url, dest)` — `curl_wrapper -fsSL -o`.
- `extract_tar_gz(archive, dest)` / `extract_zip(archive, dest)`.
- `install_binary(src, dest, name)` — mkdir, cp, chmod +x.
- `command_exists(cmd)`.
- `sort_versions()` — semantic version sort.
- `github_releases(repo)` — GET `api.github.com/repos/<repo>/releases`.
- `list_github_versions(repo [,filter])` — release tag_names, optional grep filter.

No checksum verification (matches the reference repo; relies on HTTPS).

## `lib/tools/harnx.bash` — harnx tool definition

Release facts (verified against `dobesv/harnx` v0.32.4):
- Tags are formatted `harnx/v<version>` (e.g. `harnx/v0.32.4`).
- The main binary asset is `harnx-v<version>-<rust-target>.tar.gz`.
- Each tarball contains a single executable `harnx` at the archive root.
- Targets: `x86_64-unknown-linux-musl`, `aarch64-unknown-linux-musl`,
  `x86_64-apple-darwin`, `aarch64-apple-darwin`.

Functions:

- `list_all_versions` — `list_github_versions "dobesv/harnx"`, strip the
  `harnx/v` prefix, keep `^\d+\.\d+\.\d+$`, `sort_versions`.
- `get_download_url version` — map platform to Rust target triple
  (linux → `*-unknown-linux-musl`, darwin → `*-apple-darwin`; amd64 → `x86_64`,
  arm64 → `aarch64`), then build
  `https://github.com/dobesv/harnx/releases/download/harnx/v${version}/harnx-v${version}-${target}.tar.gz`.
- `download_tool` — reject `ref` installs; `download_file` the tarball;
  `extract_tar_gz` into `download_path`.
- `install_tool` — `install_binary "$download_path/harnx" "$install_path/bin/harnx" "harnx"`.

## Helper scripts

- `install-all.sh` — `TOOLS=(harnx)` array; verify asdf present; for each tool
  `asdf plugin add <tool> <repo-url>`, updating or replacing if already present.
- `test-all.sh` — for each tool, list versions, install latest, run its version
  command (`harnx --version`), tally pass/fail.

## Adding a new tool later (documented in CLAUDE.md)

1. Create `lib/tools/<name>.bash` defining `list_all_versions`, `download_tool`,
   `install_tool`.
2. Add `<name>` to the `TOOLS` array in `install-all.sh`.
3. Add `<name>` and its version command to `test-all.sh`.
4. Document the tool in `README.md`.

## Testing strategy

- `shellcheck` on all `bin/*` and `lib/**/*.bash` scripts.
- `test-all.sh` performs a real `asdf install harnx latest` and runs
  `harnx --version` as a smoke test (requires asdf installed locally).
- Manual verification: `asdf list-all harnx` returns versions including `0.32.4`.

## Decisions

- **License:** MIT (Dobes Vandermeer).
- **Scope:** full scaffold including the `CLAUDE.md` contributor guide that the
  reference repo was missing.
- **Checksums:** none, matching the reference repo.
