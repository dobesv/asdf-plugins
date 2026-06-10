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
