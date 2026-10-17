#!/usr/bin/env bash
# Resolve a delegated skill beside the owner actually loaded by the harness.
set -euo pipefail

die() { echo "ERROR: $*" >&2; exit 1; }
[ "$#" -eq 2 ] || die 'usage: resolve-skill.sh ABSOLUTE_OWNER_SKILL.md SKILL_NAME'
owner="$1"
name="$2"
case "$owner" in /*/SKILL.md) ;; *) die 'owner must be an absolute SKILL.md path';; esac
[[ "$name" =~ ^[a-z][a-z0-9-]*$ ]] || die 'invalid skill name'
[ -f "$owner" ] && [ ! -L "$owner" ] || die 'loaded owner is missing or symlinked'
skills_root="$(cd -P "$(dirname "$owner")/.." && pwd)"
target="$skills_root/$name/SKILL.md"
[ -f "$target" ] && [ -r "$target" ] && [ ! -L "$target" ] || die "bundled skill unavailable: $name"
[ "$(cd -P "$skills_root/$name" && pwd)" = "$skills_root/$name" ] || die 'skill directory leaves its snapshot'
printf '%s\n' "$target"
