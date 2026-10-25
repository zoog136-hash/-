"""Read-only guards shared by the reviewed scratch proposals; no authorization."""
from pathlib import Path
import hashlib
import json

GATE_SHA256 = '2d0305cf49b3d944a2994111855046d37675ba72efa8180862ad5b78291f7706'
SCRATCH = Path('/workspace/scratch')


def require(value, message):
    if not value:
        raise ValueError(message)


def no_links(path):
    path = Path(path)
    require(path.is_absolute() and '..' not in path.parts, 'Absolute non-traversing path required')
    require(not any(p.is_symlink() for p in (path, *path.parents)), 'Symlink paths are forbidden')
    return path


def repo_path(root, value, *, must_exist=True):
    root = no_links(root)
    value = str(value).removeprefix('res://')
    relative = Path(value)
    require(bool(value) and relative.parts and not relative.is_absolute() and '..' not in relative.parts,
            'Unsafe repository path')
    path = no_links(root / relative)
    require(path.resolve().is_relative_to(root), 'Repository path escapes root')
    if must_exist:
        require(path.is_file(), 'Missing regular repository file: ' + str(relative))
    return path


def log_path(root, value):
    value = Path(value)
    path = no_links(value if value.is_absolute() else root / value)
    require(any(path.resolve().is_relative_to(base) for base in (root, SCRATCH, Path('/tmp'))),
            'Actual log must be in repo, scratch, or /tmp')
    require(path.is_file() and 0 < path.stat().st_size <= 2 * 1024 * 1024,
            'Bounded actual default Main log required')
    return path


def scratch_path(value):
    path = no_links(Path(value).absolute())
    require(path.resolve().is_relative_to(SCRATCH) and not path.exists(), 'New scratch directory required')
    return path


def sha_file(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def strict_json(data):
    def unique(pairs):
        result = {}
        for key, value in pairs:
            require(key not in result, 'Duplicate JSON object key')
            result[key] = value
        return result
    def nonfinite(_):
        raise ValueError('Nonfinite JSON value')
    return json.loads(data, object_pairs_hook=unique, parse_constant=nonfinite)


def checked_gate(root):
    # Check the module before importing code from the repository.
    path = repo_path(root, 'tools/pr122_native_production_approvals.py')
    require(sha_file(path) == GATE_SHA256, 'Official production gate SHA changed; stop for review')


def input_marker(register, catalog, profiles, frames, native_profile):
    return ('PR122_GIRTAS_DEFAULT_MAIN_INPUT_PINS register=' + register + ' catalog=' + catalog
            + ' profiles=' + profiles + ' frames=' + frames + ' native_profile=' + native_profile)


def verify_log(text, *, marker, engine, test_sha, inputs):
    lines = text.splitlines()
    required = (marker, 'PR122_GIRTAS_DEFAULT_MAIN_ENGINE_PASS version=' + engine,
                'PR122_GIRTAS_DEFAULT_MAIN_TEST_PIN sha256=' + test_sha, inputs)
    require(all(lines.count(line) == 1 for line in required), 'Missing, repeated, or stale actual default Main proof')
    prefixes = ('PR122_NATIVE_DEFAULT_MAIN_PASS ', 'PR122_GIRTAS_DEFAULT_MAIN_INPUT_PINS ',
                'PR122_GIRTAS_DEFAULT_MAIN_TEST_PIN ', 'PR122_GIRTAS_DEFAULT_MAIN_ENGINE_PASS ')
    require(all(sum(line.startswith(prefix) for line in lines) == 1 for prefix in prefixes),
            'Conflicting actual default Main marker')
    require(not any(bad in text for bad in ('PR122_NATIVE_MAIN_PASS', 'ERROR:', 'SCRIPT ERROR',
                                           'PR122_DEFAULT_MAIN_CHECK_FAILED')),
            'Candidate or failed engine log cannot approve')
