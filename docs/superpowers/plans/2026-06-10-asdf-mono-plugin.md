# asdf mono-plugin Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a single asdf plugin repo (`dobesv/asdf-plugins`) that installs CLI tools via a dispatcher pattern, with `harnx` as the first supported tool.

**Architecture:** A 3-script `bin/` dispatcher derives the tool name from the plugin directory's basename, sources `lib/tools/<name>.bash`, and calls its `list_all_versions`/`download_tool`/`install_tool` functions. Shared helpers live in `lib/utils.bash`. Adding a tool later = adding one `lib/tools/<name>.bash` file.

**Tech Stack:** Bash, asdf plugin contract, GitHub Releases API, `shellcheck` for linting.

---

## Reference facts (verified)

- harnx tags: `harnx/v<version>` (e.g. `harnx/v0.32.4`).
- harnx asset: `harnx-v<version>-<rust-target>.tar.gz`, containing one `harnx` binary at archive root.
- Targets: `x86_64-unknown-linux-musl`, `aarch64-unknown-linux-musl`, `x86_64-apple-darwin`, `aarch64-apple-darwin`.
- Download URL: `https://github.com/dobesv/harnx/releases/download/harnx/v<version>/harnx-v<version>-<target>.tar.gz`.
- Plugin repo URL: `https://github.com/dobesv/asdf-plugins.git`.

## File structure

| File | Responsibility |
|------|----------------|
| `lib/utils.bash` | Shared helpers: error_exit, curl_wrapper, OS/arch detection, download/extract, GitHub release listing, version sort, binary install |
| `bin/list-all` | Dispatcher → `list_all_versions` |
| `bin/download` | Dispatcher → `download_tool` |
| `bin/install` | Dispatcher → `install_tool` |
| `lib/tools/harnx.bash` | harnx version listing, download, install |
| `install-all.sh` | Add/update all plugins listed in `TOOLS` |
| `test-all.sh` | Install latest of each tool + smoke-test its version command |
| `README.md` | Usage, supported tools, how to add a tool |
| `CLAUDE.md` | Contributor guide for adding tools |
| `LICENSE` | MIT |
| `.gitignore`, `.tool-versions` | Repo hygiene / pinned versions |

Note: shellcheck is the primary verification tool. Full `asdf install` smoke tests require asdf installed locally and are run via `test-all.sh` at the end. Each task verifies its script parses and lints cleanly; functional behavior of `lib/utils.bash` helpers is checked by sourcing and calling them directly.

---

### Task 1: Shared helpers — `lib/utils.bash`

**Files:**
- Create: `lib/utils.bash`

- [ ] **Step 1: Write `lib/utils.bash`**

```bash
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
  echo "$(get_os)_$(get_arch)"
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
  chmod +x "$dest"
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
  curl_wrapper -fsSL "https://api.github.com/repos/${repo}/releases" ||
    error_exit "failed to fetch releases for ${repo}"
}

# Print release tag_names, newline-separated. Optional grep filter as $2.
list_github_versions() {
  local repo="$1" filter="${2:-}"
  local tags
  tags="$(github_releases "$repo" | grep -oE '"tag_name":[[:space:]]*"[^"]+"' | sed -E 's/.*"tag_name":[[:space:]]*"([^"]+)".*/\1/')"
  if [ -n "$filter" ]; then
    echo "$tags" | grep -E "$filter"
  else
    echo "$tags"
  fi
}
```

- [ ] **Step 2: Lint and source-check**

Run:
```bash
shellcheck lib/utils.bash && bash -c 'source lib/utils.bash && get_platform && echo "abc" | sort_versions'
```
Expected: shellcheck prints nothing (exit 0); the source line prints a platform like `linux_amd64`. (The `sort_versions` of `abc` is a no-op smoke check that it runs without error.)

- [ ] **Step 3: Verify version sort ordering**

Run:
```bash
bash -c 'source lib/utils.bash; printf "0.31.0\n0.32.4\n0.30.1\n0.32.10\n" | sort_versions | tr "\n" " "'
```
Expected: `0.30.1 0.31.0 0.32.4 0.32.10 ` (numeric, not lexical, ordering).

- [ ] **Step 4: Commit**

```bash
git add lib/utils.bash
git commit -m "feat: add shared utils.bash helpers"
```

---

### Task 2: Dispatcher scripts — `bin/list-all`, `bin/download`, `bin/install`

**Files:**
- Create: `bin/list-all`, `bin/download`, `bin/install`

- [ ] **Step 1: Write `bin/list-all`**

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

command -v list_all_versions >/dev/null 2>&1 ||
  error_exit "Tool '${tool_name}' does not implement list_all_versions"

list_all_versions
```

- [ ] **Step 2: Write `bin/download`**

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

command -v download_tool >/dev/null 2>&1 ||
  error_exit "Tool '${tool_name}' does not implement download_tool"

download_tool "$ASDF_INSTALL_TYPE" "$ASDF_INSTALL_VERSION" "$ASDF_DOWNLOAD_PATH"
```

- [ ] **Step 3: Write `bin/install`**

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

command -v install_tool >/dev/null 2>&1 ||
  error_exit "Tool '${tool_name}' does not implement install_tool"

install_tool "$ASDF_INSTALL_TYPE" "$ASDF_INSTALL_VERSION" "$ASDF_DOWNLOAD_PATH" "$ASDF_INSTALL_PATH"
```

- [ ] **Step 4: Make executable**

Run:
```bash
chmod +x bin/list-all bin/download bin/install
```

- [ ] **Step 5: Lint**

Run:
```bash
shellcheck bin/list-all bin/download bin/install
```
Expected: no output (exit 0). Note: shellcheck may warn SC1090/SC1091 about the non-constant `source "$tool_script"`. If it does, add `# shellcheck source=/dev/null` on the line above each dynamic `source` and re-run until clean.

- [ ] **Step 6: Commit**

```bash
git add bin/list-all bin/download bin/install
git commit -m "feat: add bin dispatcher scripts"
```

---

### Task 3: harnx tool definition — `lib/tools/harnx.bash`

**Files:**
- Create: `lib/tools/harnx.bash`

- [ ] **Step 1: Write `lib/tools/harnx.bash`**

```bash
#!/usr/bin/env bash
# harnx - https://github.com/dobesv/harnx
# Release tags are formatted "harnx/v<version>"; assets are
# "harnx-v<version>-<rust-target>.tar.gz" containing a single `harnx` binary.

readonly HARNX_REPO="dobesv/harnx"

list_all_versions() {
  # Tags look like "harnx/v0.32.4" -> strip "harnx/v", keep x.y.z, sort.
  list_github_versions "$HARNX_REPO" |
    sed -n 's#^harnx/v##p' |
    grep -E '^[0-9]+\.[0-9]+\.[0-9]+$' |
    sort_versions |
    tr '\n' ' '
}

# Map the current platform to harnx's Rust target triple.
get_harnx_target() {
  local os arch
  os="$(get_os)"
  arch="$(get_arch)"
  case "${os}_${arch}" in
    linux_amd64) echo "x86_64-unknown-linux-musl" ;;
    linux_arm64) echo "aarch64-unknown-linux-musl" ;;
    darwin_amd64) echo "x86_64-apple-darwin" ;;
    darwin_arm64) echo "aarch64-apple-darwin" ;;
    *) error_exit "harnx does not support platform: ${os}_${arch}" ;;
  esac
}

get_download_url() {
  local version="$1" target
  target="$(get_harnx_target)"
  echo "https://github.com/${HARNX_REPO}/releases/download/harnx/v${version}/harnx-v${version}-${target}.tar.gz"
}

download_tool() {
  local install_type="$1" version="$2" download_path="$3"
  [ "$install_type" = "version" ] ||
    error_exit "harnx only supports version installs, not ref installs"

  local url archive
  url="$(get_download_url "$version")"
  archive="${download_path}/harnx.tar.gz"

  mkdir -p "$download_path"
  download_file "$url" "$archive"
  extract_tar_gz "$archive" "$download_path"
  rm -f "$archive"
}

install_tool() {
  local install_type="$1" version="$2" download_path="$3" install_path="$4"
  install_binary "${download_path}/harnx" "${install_path}/bin/harnx" "harnx"
}
```

- [ ] **Step 2: Lint**

Run:
```bash
shellcheck lib/tools/harnx.bash
```
Expected: no output. SC2034 may flag `install_type`/`version` as unused in `install_tool` — that is intentional (the asdf contract passes them). If flagged, prefix the function with `# shellcheck disable=SC2034` or keep the params; re-run until clean.

- [ ] **Step 3: Verify version listing against real GitHub**

Run:
```bash
bash -c 'source lib/utils.bash; source lib/tools/harnx.bash; list_all_versions'
```
Expected: a space-separated ascending list of versions ending with at least `0.32.4` (e.g. `... 0.31.0 0.32.0 0.32.1 0.32.2 0.32.3 0.32.4 `). No `harnx/v` prefixes.

- [ ] **Step 4: Verify download URL construction**

Run:
```bash
bash -c 'source lib/utils.bash; source lib/tools/harnx.bash; get_download_url 0.32.4'
```
Expected: a URL of the form `https://github.com/dobesv/harnx/releases/download/harnx/v0.32.4/harnx-v0.32.4-<your-target>.tar.gz`. Confirm it resolves:
```bash
bash -c 'source lib/utils.bash; source lib/tools/harnx.bash; curl -fsSIL "$(get_download_url 0.32.4)" >/dev/null && echo OK'
```
Expected: `OK`.

- [ ] **Step 5: Commit**

```bash
git add lib/tools/harnx.bash
git commit -m "feat: add harnx tool definition"
```

---

### Task 4: Helper scripts — `install-all.sh`, `test-all.sh`

**Files:**
- Create: `install-all.sh`, `test-all.sh`

- [ ] **Step 1: Write `install-all.sh`**

```bash
#!/usr/bin/env bash
# Add (or update) every tool plugin from this repo into asdf.
set -euo pipefail

readonly REPO_URL="https://github.com/dobesv/asdf-plugins.git"
readonly TOOLS=(
  harnx
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
```

- [ ] **Step 2: Write `test-all.sh`**

```bash
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
```

- [ ] **Step 3: Make executable and lint**

Run:
```bash
chmod +x install-all.sh test-all.sh && shellcheck install-all.sh test-all.sh
```
Expected: no output (exit 0).

- [ ] **Step 4: Commit**

```bash
git add install-all.sh test-all.sh
git commit -m "feat: add install-all and test-all helper scripts"
```

---

### Task 5: Repo hygiene — `LICENSE`, `.gitignore`, `.tool-versions`

**Files:**
- Create: `LICENSE`, `.gitignore`, `.tool-versions`

- [ ] **Step 1: Write `LICENSE` (MIT)**

```
MIT License

Copyright (c) 2026 Dobes Vandermeer

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```

- [ ] **Step 2: Write `.gitignore`**

```
.idea/
.vscode/
.claude/
.DS_Store
test/
*.tmp
```

- [ ] **Step 3: Write `.tool-versions`**

```
harnx 0.32.4
```

- [ ] **Step 4: Commit**

```bash
git add LICENSE .gitignore .tool-versions
git commit -m "chore: add LICENSE, gitignore, tool-versions"
```

---

### Task 6: Documentation — `README.md`, `CLAUDE.md`

**Files:**
- Create: `README.md`, `CLAUDE.md`

- [ ] **Step 1: Write `README.md`**

````markdown
# asdf-plugins

A single [asdf](https://asdf-vm.com) plugin repository that installs multiple
CLI tools via a dispatcher pattern. Add one plugin per tool, all pointing at
this same repo.

## Supported tools

| Tool | Source |
|------|--------|
| `harnx` | <https://github.com/dobesv/harnx/releases> |

## Install

Add a single tool:

```bash
asdf plugin add harnx https://github.com/dobesv/asdf-plugins.git
asdf install harnx latest
asdf global harnx latest
```

Or add/update every supported tool at once:

```bash
git clone https://github.com/dobesv/asdf-plugins.git
cd asdf-plugins
./install-all.sh
```

## How it works

When you run `asdf plugin add <tool> <this-repo-url>`, asdf clones this repo
into a plugin directory named `<tool>`. The scripts in `bin/` derive the tool
name from that directory's basename and source `lib/tools/<tool>.bash`, which
defines how to list versions, download, and install that specific tool. Shared
helpers live in `lib/utils.bash`.

## Platform support

Linux and macOS, `amd64` and `arm64`.

## Environment variables

- `GITHUB_API_TOKEN` — optional; sent as `Authorization: token` when listing
  GitHub releases, to avoid API rate limits.

## Adding a tool

See [CLAUDE.md](CLAUDE.md).

## License

MIT — see [LICENSE](LICENSE).
````

- [ ] **Step 2: Write `CLAUDE.md`**

````markdown
# Contributor guide

This repo is an asdf "mono-plugin": one repository that supports many tools
through a dispatcher. The `bin/` scripts (`list-all`, `download`, `install`)
are generic — they figure out which tool is being installed from the plugin
directory's basename and delegate to `lib/tools/<tool>.bash`.

## Architecture

- `bin/list-all`, `bin/download`, `bin/install` — generic dispatchers. Do not
  put tool-specific logic here.
- `lib/utils.bash` — shared helpers (download, extract, OS/arch detection,
  GitHub release listing, version sorting, binary install).
- `lib/tools/<tool>.bash` — one file per tool, sourced by the dispatchers.

## Adding a new tool

1. Create `lib/tools/<name>.bash` defining three functions:

   - `list_all_versions` — print available versions, space-separated, ascending.
     Usually: `list_github_versions "<owner>/<repo>" | <strip prefix> | sort_versions | tr '\n' ' '`.
   - `download_tool <install_type> <version> <download_path>` — reject `ref`
     installs, build the download URL (map `get_os`/`get_arch` to the tool's
     own naming), `download_file`, and `extract_tar_gz`/`extract_zip` into
     `download_path`.
   - `install_tool <install_type> <version> <download_path> <install_path>` —
     place the final binary at `<install_path>/bin/<name>` via `install_binary`.

   Use `lib/tools/harnx.bash` as the template.

2. Add `<name>` to the `TOOLS` array in `install-all.sh`.

3. Add `<name>` and its version flag to the `VERSION_CMD` map in `test-all.sh`.

4. Add a row to the "Supported tools" table in `README.md`.

## Helpers available in `lib/utils.bash`

`error_exit`, `command_exists`, `curl_wrapper`, `get_os`, `get_arch`,
`get_platform`, `download_file`, `extract_tar_gz`, `extract_zip`,
`install_binary`, `sort_versions`, `github_releases`, `list_github_versions`.

## Testing

```bash
shellcheck bin/* lib/utils.bash lib/tools/*.bash install-all.sh test-all.sh
./install-all.sh   # requires asdf
./test-all.sh      # installs latest of each tool and runs its version command
```
````

- [ ] **Step 3: Commit**

```bash
git add README.md CLAUDE.md
git commit -m "docs: add README and contributor guide"
```

---

### Task 7: Full integration smoke test

**Files:** none (verification only).

- [ ] **Step 1: Lint everything**

Run:
```bash
shellcheck bin/list-all bin/download bin/install lib/utils.bash lib/tools/harnx.bash install-all.sh test-all.sh
```
Expected: no output (exit 0).

- [ ] **Step 2: End-to-end install via asdf (requires asdf installed)**

Run:
```bash
asdf plugin add harnx "$PWD" && asdf list-all harnx && asdf install harnx latest && asdf shell harnx latest && harnx --version
```
Expected: version list prints (ending ~`0.32.4`), install succeeds, and `harnx --version` prints a version string.

If asdf is not installed locally, note that in the task result and rely on Steps 1 plus the Task 3 functional checks (version listing + URL resolution) as the verification.

- [ ] **Step 3: Cleanup test plugin**

Run:
```bash
asdf plugin remove harnx 2>/dev/null || true
```

---

## Done criteria

- `shellcheck` passes on all scripts.
- `asdf list-all harnx` returns versions including `0.32.4`.
- `asdf install harnx latest` followed by `harnx --version` works (or, absent local asdf, the Task 3 functional checks pass).
- README and CLAUDE.md document usage and how to add tools.
