#!/usr/bin/env python3
"""Append the common native-read recording contract to a Codex fixture prompt."""
from pathlib import Path
import shlex
import sys


def render(installed_argument, original):
    installed = Path(installed_argument)
    if (not installed.is_absolute() or str(installed) != installed_argument or
            any(char in installed_argument for char in '\0\r\n') or
            not installed.is_dir() or installed.resolve(strict=True) != installed):
        raise ValueError('expected the canonical, already byte-checked installed snapshot')
    original.decode('utf-8')
    if b'\0' in original:
        raise ValueError('a prompt argument cannot contain NUL')
    example = 'cat ' + shlex.quote(str(installed / 'using-maxi/SKILL.md'))
    contract = f'''TEST-ONLY native read evidence: the runner has already byte-checked this installed skills snapshot:
{installed}
Follow the loaded owner's instructions and its owner-bound installed resolver first. Read the path returned by that resolver. This recording protocol does not replace skill resolution and provides no fallback; the verified root above does not authorize changing snapshots. For every required evidence read, use one standalone native shell command per file, containing only cat and one literal absolute pathname, shell-quoted when needed. This example illustrates only command syntax after path resolution:
{example}
Keep the complete file output visible. Each read must finish with exit code 0 and no truncation. Run searches, diagnostics, status checks and helper invocations in separate commands. A batch of tool calls is allowed when each cat has its own complete successful result. Resolve absolute artifact paths from the actual fixture. Pass this same read-evidence instruction to every delegate, including reads of the builder prompt, canonical spec, canonical plan and review packages. Preserve the workflow and its existing phase and review boundaries.'''
    # A final non-LF byte makes $(cat rendered.txt) preserve the entire argument.
    # Original bytes, including all original final LFs, remain an exact prefix.
    return original + b'\n\n' + contract.encode('utf-8')


def main():
    if len(sys.argv) != 4:
        raise ValueError('usage: render-codex-fixture-prompt.py INSTALLED ORIGINAL OUTPUT')
    installed, original, output = sys.argv[1:]
    source, destination = Path(original), Path(output)
    if source.resolve() == destination.resolve():
        raise ValueError('original and rendered prompt must be distinct files')
    rendered = render(installed, source.read_bytes())
    destination.write_bytes(rendered)


if __name__ == '__main__':
    try:
        main()
    except (OSError, ValueError) as error:
        raise SystemExit(str(error))
