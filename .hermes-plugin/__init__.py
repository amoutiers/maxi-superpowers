import os
from pathlib import Path

BOOTSTRAP_MARKER = "maxi:using-maxi bootstrap for hermes"


def _skills_dir() -> str:
    """Locate the skills tree for clone and flattened plugin installs."""
    here = os.path.dirname(os.path.realpath(__file__))
    candidates = (
        os.path.realpath(os.path.join(here, "..", "skills")),
        os.path.realpath(os.path.join(here, "skills")),
    )
    for candidate in candidates:
        if os.path.isfile(os.path.join(candidate, "using-maxi", "SKILL.md")):
            return candidate
    raise RuntimeError(
        "maxi plugin: cannot find the skills/ tree "
        f"(looked at {candidates}). Reinstall the plugin."
    )


def _build_bootstrap(skills_dir: str) -> str:
    tools_path = os.path.join(
        skills_dir, "using-superpowers", "references", "hermes-tools.md"
    )
    with open(tools_path, encoding="utf-8") as tools_file:
        tool_mapping = tools_file.read().strip()

    return (
        "<EXTREMELY_IMPORTANT>\n"
        f"{BOOTSTRAP_MARKER}\n\n"
        "This is a Maxi project. Before responding, invoke "
        '`skill_view("maxi:using-maxi")` and follow that skill.\n\n'
        f"{tool_mapping}\n"
        "</EXTREMELY_IMPORTANT>"
    )


def register(ctx):
    skills_dir = _skills_dir()
    bootstrap = _build_bootstrap(skills_dir)

    for name in sorted(os.listdir(skills_dir)):
        skill_md = os.path.join(skills_dir, name, "SKILL.md")
        if os.path.isfile(skill_md):
            ctx.register_skill(name, Path(skill_md))

    def pre_llm_call(
        session_id=None,
        user_message=None,
        conversation_history=None,
        is_first_turn=None,
        model=None,
        platform=None,
        **kwargs,
    ):
        if is_first_turn and (Path.cwd() / "docs" / "maxi").is_dir():
            return {"context": bootstrap}
        return None

    ctx.register_hook("pre_llm_call", pre_llm_call)
