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
from pathlib import Path

sys.dont_write_bytecode = True

ROOT = Path(os.environ["REPO_ROOT"])
PLUGIN = ROOT / ".hermes-plugin"
SKILLS = ROOT / "skills"
MAPPING = SKILLS / "using-superpowers" / "references" / "hermes-tools.md"


class FakeContext:
    def __init__(self):
        self.skills = {}
        self.hooks = {}

    def register_skill(self, name, path):
        assert isinstance(path, Path), f"{name} was registered as {type(path).__name__}"
        assert path.is_file(), f"{name} path does not exist: {path}"
        self.skills[name] = path

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


assert PLUGIN.is_dir(), f"missing Hermes plugin directory: {PLUGIN}"
assert (PLUGIN / "__init__.py").is_file(), "missing Hermes plugin module"
manifest = (PLUGIN / "plugin.yaml").read_text(encoding="utf-8")
package = json.loads((ROOT / "package.json").read_text(encoding="utf-8"))
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
        assert set(context.skills) == expected_skills(root / "skills")
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
            assert 'skill_view("maxi:using-maxi")' in bootstrap
            assert MAPPING.read_text(encoding="utf-8").strip() in bootstrap
            assert "## The Rule" not in bootstrap
            assert len(bootstrap) < 10_000
            assert hook(is_first_turn=False) is None
        finally:
            os.chdir(previous)

assert not list(ROOT.rglob("__pycache__")), "the check created __pycache__"
print("Hermes plugin checks passed")
PY
