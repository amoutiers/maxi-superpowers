# Bind the execution engine to its Maxi owner

Set `maxi_owner_skill` to the absolute `SKILL.md` path actually loaded for
the current Maxi owner. Derive its physical skills root once:

```bash
maxi_skills_root="$(cd -P "$(dirname "$maxi_owner_skill")/.." && pwd)"
bash "$maxi_skills_root/using-maxi/resolve-skill.sh" "$maxi_owner_skill" writing-plans
```

Use the helper's single stdout path to load the complete delegated skill
into the current context. Redirecting the body to a file is not loading it.
Use `subagent-driven-development` or `finishing-a-development-branch` as
the second argument for those handoffs. The same resolver works for native
owners such as `analyze`.

Registry names identify capabilities. During this Maxi operation, nested
`superpowers:<name>` references also select the bundled copy under
`maxi_skills_root`. Resolve its prompts and scripts relative to that copy.
Carry this root in existing dispatch briefs so children use the same engine.
Announce the root once, retain it through the operation, and reload required
instructions after context loss.

If resolution or the complete read fails, stop before that handoff and
report the missing path. A co-installed standalone Superpowers plugin or
client repository cannot substitute for the loaded owner's snapshot.
Vendored skill bodies remain unchanged; this is the Maxi invocation boundary.
