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
