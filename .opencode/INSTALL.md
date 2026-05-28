# Installing Maxi for OpenCode

## Prerequisites

- [OpenCode.ai](https://opencode.ai) installed

## Installation

Add maxi to the `plugin` array in your `opencode.json` (global or project-level):

```json
{
  "plugin": ["maxi-superpowers@git+https://github.com/amoutiers/maxi-superpowers.git"]
}
```

Restart OpenCode. The plugin installs through OpenCode's plugin manager and
registers all skills.

Verify by asking: "Tell me about your maxi pipeline"

OpenCode uses its own plugin install. If you also use Claude Code, Codex, or
another harness, install Maxi separately for each one.

## Updating

OpenCode installs Maxi through a git-backed package spec. Some OpenCode
and Bun versions pin that resolved git dependency in a lockfile or cache, so a
restart may not pick up the newest Maxi commit. If updates do not appear,
clear OpenCode's package cache or reinstall the plugin.

To pin a specific version:

```json
{
  "plugin": ["maxi-superpowers@git+https://github.com/amoutiers/maxi-superpowers.git#v1.0.0"]
}
```

## Troubleshooting

### Plugin not loading

1. Check logs: `opencode run --print-logs "hello" 2>&1 | grep -i maxi`
2. Verify the plugin line in your `opencode.json`
3. Make sure you're running a recent version of OpenCode

### Skills not found

1. Use `skill` tool to list what's discovered
2. Check that the plugin is loading (see above)

### Tool mapping

When skills reference Claude Code tools:
- `TodoWrite` → `todowrite`
- `Task` with subagents → `@mention` syntax
- `Skill` tool → OpenCode's native `skill` tool
- File operations → your native tools

## Getting Help

- Report issues: https://github.com/amoutiers/maxi-superpowers/issues
- Full documentation: https://github.com/amoutiers/maxi-superpowers/blob/main/README.md
