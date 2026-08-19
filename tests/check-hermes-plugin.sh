#!/usr/bin/env bash
# Exercises the Hermes adapter through its public registration and hook surface.
set -euo pipefail

ROOT="$(git rev-parse --show-toplevel)"

PYTHONDONTWRITEBYTECODE=1 REPO_ROOT="$ROOT" python3 - <<'PY'
import importlib.util
import json
import os
import re
import shutil
import sys
import tempfile
from collections import Counter
from pathlib import Path

sys.dont_write_bytecode = True

ROOT = Path(os.environ["REPO_ROOT"])
PLUGIN = ROOT / ".hermes-plugin"
SKILLS = ROOT / "skills"
MAPPING = SKILLS / "using-superpowers" / "references" / "hermes-tools.md"
USING_MAXI = SKILLS / "using-maxi" / "SKILL.md"


class FakeContext:
    def __init__(self):
        self.skill_calls = []
        self.hooks = {}

    def register_skill(self, name, path):
        assert isinstance(path, Path), f"{name} was registered as {type(path).__name__}"
        assert path.is_file(), f"{name} path does not exist: {path}"
        self.skill_calls.append((name, path))

    def register_hook(self, event, hook):
        self.hooks[event] = hook


def load_plugin(plugin_path):
    spec = importlib.util.spec_from_file_location(
        f"maxi_hermes_{plugin_path.parent.name}_{plugin_path.name}", plugin_path
    )
    module = importlib.util.module_from_spec(spec)
    assert spec.loader is not None
    spec.loader.exec_module(module)
    return module


def in_directory(path):
    previous = Path.cwd()
    os.chdir(path)
    return previous


def expected_skills(skills_dir):
    return {
        entry.name
        for entry in skills_dir.iterdir()
        if (entry / "SKILL.md").is_file()
    }


def body_without_frontmatter(path):
    parts = path.read_text(encoding="utf-8").split("---\n", 2)
    assert len(parts) == 3 and not parts[0], f"unexpected frontmatter: {path}"
    return parts[2]


assert PLUGIN.is_dir(), f"missing Hermes plugin directory: {PLUGIN}"
assert (PLUGIN / "__init__.py").is_file(), "missing Hermes plugin module"
manifest = (PLUGIN / "plugin.yaml").read_text(encoding="utf-8")
package = json.loads((ROOT / "package.json").read_text(encoding="utf-8"))
mapping_text = MAPPING.read_text(encoding="utf-8").strip()
using_maxi_lines = [
    line.strip()
    for line in body_without_frontmatter(USING_MAXI).splitlines()
    if line.strip()
    and line.strip() != "```"
    and (len(line.strip()) > 12 or line.lstrip().startswith("#") or line.strip().startswith("<"))
]
assert using_maxi_lines, "using-maxi has no non-trivial body lines to protect"
manifest_fields = {
    line.split(":", 1)[0]
    for line in manifest.splitlines()
    if line and not line.startswith((" ", "-")) and ":" in line
}
assert manifest_fields == {"name", "version", "description", "provides_hooks"}
assert re.search(r"^name: maxi$", manifest, re.MULTILINE)
assert re.search(rf"^version: {re.escape(package['version'])}$", manifest, re.MULTILINE)
assert re.findall(r"^  - (.+)$", manifest, re.MULTILINE) == ["pre_llm_call"]

with tempfile.TemporaryDirectory() as tmp:
    tmp_path = Path(tmp)
    source_module = PLUGIN / "__init__.py"

    for layout in ("clone", "flat"):
        root = tmp_path / layout
        plugin_dir = root / ".hermes-plugin" if layout == "clone" else root
        plugin_dir.mkdir(parents=True)
        shutil.copy2(source_module, plugin_dir / "__init__.py")
        shutil.copytree(SKILLS, root / "skills")

        module = load_plugin(plugin_dir / "__init__.py")
        context = FakeContext()
        module.register(context)
        expected = expected_skills(root / "skills")
        assert Counter(name for name, _ in context.skill_calls) == Counter({name: 1 for name in expected})
        assert all(isinstance(path, Path) for _, path in context.skill_calls)
        assert set(context.hooks) == {"pre_llm_call"}

        project = root / "project"
        (project / "docs" / "maxi").mkdir(parents=True)
        outside = root / "outside"
        outside.mkdir()
        hook = context.hooks["pre_llm_call"]

        previous = in_directory(outside)
        try:
            assert hook(is_first_turn=True) is None
            in_directory(project)
            first = hook(is_first_turn=True, future_hook_keyword=True)
            assert isinstance(first, dict) and set(first) == {"context"}
            bootstrap = first["context"]
            assert bootstrap.count('skill_view("maxi:using-maxi")') == 1
            assert bootstrap.count(mapping_text) == 1
            assert not any(line in bootstrap for line in using_maxi_lines)
            assert len(bootstrap) < 10_000
            assert hook(is_first_turn=False) is None
        finally:
            os.chdir(previous)

assert not list(ROOT.rglob("__pycache__")), "the check created __pycache__"
print("Hermes plugin checks passed")
PY
