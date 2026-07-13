---
title: "Added tsgolint support to asdf mono-plugin with bare-binary download pattern"
date: 2026-07-13
category: "integration-issues"
problem_type: integration_issue
component: "asdf-plugins mono-plugin"
root_cause: "bare-binary release assets require direct download without archive extraction"
resolution_type: code_fix
severity: low
tags:
  - asdf
  - bare-binary
  - calver
  - github-releases
  - tool-integration
plan_ref: "robinnagpal-newsela/oxlint-tsgolint add-github-release-install-scripts branch"
---

## Problem

Integrating tsgolint into the asdf mono-plugin required handling bare-binary release assets (no archive wrapper) and documenting oxlint's non-standard PATH discovery mechanism.

## Symptoms

- tsgolint GitHub releases publish bare binaries named `tsgolint-<os>-<arch>` without `.tar.gz` or `.zip` wrapper
- `--version` flag returns exit code 2 (not supported)
- oxlint ignores PATH when locating tsgolint for type-aware linting

## Investigation Steps

1. Examined existing tool scripts (harnx: tar.gz, rclone: zip) to understand extraction patterns
2. Inspected tsgolint release assets at `robinnagpal-newsela/oxlint-tsgolint/releases` — found bare binaries only
3. Tested `tsgolint --version` locally — returned exit 2, unusable for test verification
4. Tested `tsgolint --help` — returned exit 0, suitable for VERSION_CMD in test-all.sh
5. Checked oxlint documentation — confirmed `OXLINT_TSGOLINT_PATH` environment variable requirement

## Root Cause

tsgolint uses a simpler release artifact pattern than other tools in the repo: bare binaries instead of archived binaries. The existing `download_tool` pattern assumed archive extraction; tsgolint required direct binary download.

## Solution

Created `lib/tools/tsgolint.bash` with direct-binary download pattern:

**download_tool implementation:**
```bash
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
```

Key differences from harnx/rclone:
- No `extract_tar_gz` or `extract_zip` call
- `download_file` writes directly to `${download_path}/tsgolint`
- No intermediate archive file to clean up

**test-all.sh VERSION_CMD:**
```bash
declare -A VERSION_CMD=(
  # ...
  [tsgolint]="--help"  # --version returns exit 2
)
```

**README documentation:**
```markdown
- `tsgolint` — oxlint does **not** find tsgolint on `PATH`. After installing,
  point oxlint's type-aware linting at the installed binary by exporting
  `OXLINT_TSGOLINT_PATH="$(asdf which tsgolint)"`
```

## Why This Works

- Bare binaries skip extraction entirely — `download_file` places the executable directly in download_path
- `--help` returns exit 0, suitable for smoke-test verification in test-all.sh
- CalVer tags (`v2026.06.24`) match the standard `^[0-9]+\.[0-9]+\.[0-9]+$` regex after stripping `v` prefix
- `OXLINT_TSGOLINT_PATH` environment variable bridges oxlint to asdf-installed tsgolint binary

## Prevention Strategies

**When adding new tools:**
1. Check release asset format first — bare binaries skip extraction step
2. Test `--version` before adding to VERSION_CMD — some CLIs use `--help` or `-V` instead
3. Document non-standard discovery mechanisms (like `OXLINT_TSGOLINT_PATH`) in tool script header and README

**Template for bare-binary tools:**
```bash
download_tool() {
  local install_type="$1" version="$2" download_path="$3"
  local url
  url="$(get_download_url "$version")"
  mkdir -p "$download_path"
  download_file "$url" "${download_path}/<toolname>"
}
```

## Related Issues

- Tool script: `lib/tools/tsgolint.bash`
- Test config: `test-all.sh` VERSION_CMD declaration
- README section: "Notes" for OXLINT_TSGOLINT_PATH documentation
