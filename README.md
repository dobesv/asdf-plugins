# asdf-plugins

A single [asdf](https://asdf-vm.com) plugin repository that installs multiple
CLI tools via a dispatcher pattern. Add one plugin per tool, all pointing at
this same repo.

## Supported tools

| Tool | Source |
|------|--------|
| `harnx` | <https://github.com/dobesv/harnx/releases> |
| `luchta` | <https://github.com/dobesv/luchta/releases> |
| `rclone` | <https://github.com/rclone/rclone/releases> |

## Install

Add (or update) every supported tool with a single command:

```bash
curl -fsSL https://raw.githubusercontent.com/dobesv/asdf-plugins/master/install-all.sh | bash
```

Or add a single tool:

```bash
asdf plugin add harnx https://github.com/dobesv/asdf-plugins.git
asdf install harnx latest
asdf set -u harnx latest
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
