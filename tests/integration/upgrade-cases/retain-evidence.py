#!/usr/bin/env python3
"""Retain only upgrade project/Git proof, then inspect it without runtime homes."""
from pathlib import Path
import hashlib
import importlib.util
import json
import re
import shutil
import subprocess
import sys
import tempfile

sys.dont_write_bytecode = True

loader = importlib.util.spec_from_file_location('upgrade_checker', Path(__file__).with_name('check-evidence.py'))
checker = importlib.util.module_from_spec(loader)
loader.loader.exec_module(checker)


def require(ok, message):
    if not ok:
        raise ValueError(message)


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def run(*args, cwd=None):
    result = subprocess.run(args, cwd=cwd, capture_output=True, text=True)
    require(result.returncode == 0, f'proof command failed: {args[0]}: {result.stderr.strip()}')
    return result.stdout.strip()


def local_file(root, relative):
    relative = Path(relative)
    require(not relative.is_absolute() and '..' not in relative.parts, 'path outside proof fixture')
    path = root / relative
    require(path.is_file() and not path.is_symlink() and path.resolve().is_relative_to(root.resolve()),
            f'missing or symlinked proof dependency: {relative}')
    return path


def capture(directory):
    directory = directory.resolve(strict=True)
    evidence = json.loads((directory / 'evidence.json').read_text())
    target = directory / 'retained-proof'
    require(not target.exists(), 'refusing to overwrite retained proof')
    fixture = Path(evidence['fixture'])
    runtime = fixture.parent
    roots = [('main-final', fixture, fixture),
             ('main-terminal', Path(evidence['pre_done_fixture']), fixture),
             ('migration', Path(evidence['migration']['fixture']), Path(evidence['migration']['fixture']))]
    require(fixture.name == 'fixture' and runtime.resolve() == runtime and
            all(source.parent == runtime and source.name in {'fixture', 'pre-done-fixture', 'migration-fixture'}
                and source.resolve(strict=True) == source for _, source, _ in roots),
            'capture paths are outside controlled fixture siblings')
    target.mkdir()
    snapshots = {}
    for role, source, native_root in roots:
        destination = target / role
        files = destination / 'files'
        files.mkdir(parents=True)
        tracked = run('git', '-C', str(source), 'ls-files', '-z').split('\0')
        selected = {source / name for name in tracked if name and (source / name).exists()}
        for name in ('docs', '.superpowers'):
            for path in (source / name).rglob('*'):
                require(not path.is_symlink(), 'symlink in project proof')
                if path.is_file(): selected.add(path)
        for path in selected:
            require(not path.is_symlink() and path.resolve().is_relative_to(source), 'symlink outside fixture')
            relative = path.relative_to(source)
            require('.git' not in relative.parts, 'Git metadata must use the proof bundle')
            output = files / relative
            output.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(path, output)
        run('git', '-C', str(source), 'bundle', 'create', str(destination / 'history.bundle'), '--all', 'HEAD')
        snapshots[role] = {'native_root': str(native_root), 'captured_from': str(source),
                           'head': run('git', '-C', str(source), 'rev-parse', 'HEAD')}
    files = {str(p.relative_to(target)): sha(p) for p in sorted(target.rglob('*')) if p.is_file()}
    dependencies = [directory / 'evidence.json', directory / 'source-head.txt', directory / 'installed-plugin.json']
    for name in ('stages', 'installed-skills'):
        dependencies += [p for p in (directory / name).rglob('*') if p.is_file()]
    require((directory / 'installed-skills/x-develop/result-contract.sh').is_file(), 'missing retained installed snapshot')
    manifest = {'version': 1, 'runtime_root': str(runtime), 'source_head': (directory / 'source-head.txt').read_text().strip(),
                'snapshots': snapshots, 'files': files,
                'dependencies': {str(p.relative_to(directory)): sha(p) for p in sorted(dependencies)}}
    (target / 'manifest.json').write_text(json.dumps(manifest, indent=2) + '\n')
    return verify(directory)


def mapped(directory, manifest, role, native_path):
    native = Path(native_path)
    root = Path(manifest['snapshots'][role]['native_root'])
    require(native.is_absolute() and native.is_relative_to(root), 'native path outside fixture')
    return local_file(directory / 'retained-proof' / role / 'files', native.relative_to(root))


def verify(directory):
    directory = directory.resolve(strict=True)
    target = directory / 'retained-proof'
    manifest = json.loads((target / 'manifest.json').read_text())
    require(manifest['version'] == 1, 'unknown retained proof version')
    for base, files in ((target, manifest['files']), (directory, manifest['dependencies'])):
        for relative, digest in files.items():
            require(sha(local_file(base, relative)) == digest, f'changed proof dependency: {relative}')
    evidence = json.loads((directory / 'evidence.json').read_text())
    helper = directory / 'installed-skills/subagent-driven-development/scripts/review-package'
    receipts = []
    packages = []
    for role, entry, stage in (('main-terminal', evidence, 'resume'), ('migration', evidence['migration'], 'migration')):
        receipt = mapped(directory, manifest, role, entry['receipt'])
        report = mapped(directory, manifest, role, entry['final_review'])
        for key in ('projection', 'ledger', 'final_review', 'reviewer_dispatch_identity',
                    'full_review_package', 'fix_review_package', 'spec', 'tasks'):
            value = checker.field(receipt, key)
            if value != 'null':
                require(sha(mapped(directory, manifest, role, value)) == checker.field(receipt, key + '_sha256'),
                        f'receipt dependency mismatch: {key}')
        sessions = checker.stage_data(directory, stage)['sessions']
        final = checker.reviewer_terminal(sessions, entry['context'])
        spec = mapped(directory, manifest, role, checker.field(receipt, 'spec'))
        plan = spec.with_name('plan.md')
        reviews = checker.review_dispatch(sessions, entry['context'], spec.read_text(), plan.read_text(), final)
        require(all(message in report.read_text() for message in reviews), 'archived report omitted native output')
        for key in ('full_review_package', 'fix_review_package'):
            native = checker.field(receipt, key)
            if native != 'null':
                package = mapped(directory, manifest, role, native)
                checker.native_reads(sessions, entry['context'], {Path(native): package.read_text()})
                packages.append((role, package, checker.field(receipt, 'reviewed_head')))
        receipts.append({'role': role, 'path': str(receipt.relative_to(directory)), 'sha256': sha(receipt),
                         'context': entry['context']})
    for review in evidence['task_reviews']:
        package = mapped(directory, manifest, 'main-final', review['package'])
        require(sha(package) == review['package_sha256'], 'changed archived task package')
        packages.append(('main-final', package, evidence['first'] if review['stage'] == 'first-task' else evidence['head']))
    with tempfile.TemporaryDirectory(prefix='maxi-archive-inspection-') as temp:
        for role, snapshot in manifest['snapshots'].items():
            repository = Path(temp) / role
            run('git', 'clone', '--quiet', '--no-checkout', str(target / role / 'history.bundle'), str(repository))
            require(run('git', '-C', str(repository), 'rev-parse', 'HEAD') == snapshot['head'], 'bundle HEAD mismatch')
            for package_role, package, end in packages:
                if package_role != role: continue
                run('git', '-C', str(repository), 'checkout', '--quiet', '--detach', end)
                match = re.fullmatch(r'# Review package: (\S+)\.\.(\S+)', package.read_text().splitlines()[0])
                require(match is not None, 'missing archived package range')
                output = Path(temp) / 'regenerated.diff'
                run('bash', str(helper), str(package), *match.groups(), str(output), cwd=repository)
                require(output.read_bytes() == package.read_bytes(), 'archived package disagrees with Git objects')
    return {'result': 'archive_verified', 'source_head': manifest['source_head'],
            'receipts': receipts, 'packages_verified': len(packages), 'manifest_sha256': sha(target / 'manifest.json')}


def restore(directory, role, runtime):
    """Restore a missing controlled fixture at its recorded path for exact receipt inspection."""
    verify(directory)
    manifest = json.loads((directory / 'retained-proof/manifest.json').read_text())
    runtime = Path(runtime)
    require(runtime.resolve(strict=True) == runtime and str(runtime) == manifest['runtime_root'], 'restore outside controlled fixture')
    snapshot = manifest['snapshots'][role]
    destination = Path(snapshot['native_root'])
    require(destination.parent == runtime and destination.name in {'fixture', 'migration-fixture'} and
            not destination.exists() and not destination.is_symlink(), 'restore would overwrite or leave controlled fixture')
    run('git', 'clone', '--quiet', '--no-checkout', str(directory / 'retained-proof' / role / 'history.bundle'), str(destination))
    run('git', '-C', str(destination), 'remote', 'remove', 'origin')
    run('git', '-C', str(destination), 'checkout', '--quiet', '--detach', snapshot['head'])
    shutil.copytree(directory / 'retained-proof' / role / 'files', destination, dirs_exist_ok=True)
    return destination


if __name__ == '__main__':
    try:
        require(len(sys.argv) == 3 and sys.argv[1] in {'capture', 'verify'}, 'usage: retain-evidence.py capture|verify DIRECTORY')
        print(json.dumps((capture if sys.argv[1] == 'capture' else verify)(Path(sys.argv[2])), indent=2))
    except (ValueError, OSError, KeyError) as error:
        raise SystemExit(str(error))
