# Installing Maxi for OpenCode

## Prerequisites

- OpenCode V1 1.18.30 or V2 2.0.4 or later

## Package installation

OpenCode V1 reads the `plugin` array in `opencode.json`:

```json
{
  "plugin": ["maxi-superpowers@git+https://github.com/amoutiers/maxi-superpowers.git"]
}
```

OpenCode V2 reads the `plugins` array. The package root `index.js` exports
the V2 plugin and preserves the named V1 plugin:

```json
{
  "plugins": ["maxi-superpowers@git+https://github.com/amoutiers/maxi-superpowers.git"]
}
```

Use the field for your installed OpenCode version, then restart OpenCode.
The bootstrap appears only in root sessions located in projects containing
`docs/maxi/`. Child sessions do not receive it. All 34 Maxi and Superpowers
skills are registered in V2; V1 uses its existing skill discovery.

For a repository checkout, OpenCode can also discover
`.opencode/plugins/maxi.js` directly from the project. Use one installation
path per OpenCode configuration so the plugin is not registered twice.

Verify in a Maxi project by asking: "Tell me about your maxi pipeline".
Install Maxi separately for other harnesses.

## Updating

OpenCode installs the git-backed package spec through its package manager.
A resolved git dependency can remain pinned in a lockfile or cache after a
restart. If an update does not appear, clear OpenCode's package cache or
reinstall the plugin. To pin a release, append its tag to the git URL.

## Troubleshooting

### Plugin not loading

1. Check OpenCode logs for `maxi`.
2. Verify `plugin` on V1 or `plugins` on V2 in `opencode.json`.
3. Check that the package installation or local plugin path exists.

### Skills not found

1. Use the native `skill` tool to inspect discovery.
2. Check OpenCode logs for plugin setup or skill registration errors.

### Tool mapping

When skills reference Claude Code tools:

- `TodoWrite` maps to `todowrite` on V1. On V2, track the plan in a Markdown file.
- `Task` maps to `task` on V1 and `subagent` on V2.
- `Skill` maps to OpenCode's native `skill` tool.
- File operations use OpenCode's native tools.

## Getting Help

- Report issues: https://github.com/amoutiers/maxi-superpowers/issues
- Full documentation: https://github.com/amoutiers/maxi-superpowers/blob/main/README.md
