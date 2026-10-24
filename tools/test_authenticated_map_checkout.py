"""Check authenticated PNG plans survive a real Git autocrlf checkout."""
import hashlib
import json
from pathlib import Path
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]


def run():
    correction = json.loads((ROOT / 'data/maps/native_png_navigation_corrections.json').read_text())
    review = json.loads((ROOT / 'data/maps/aden_png_display_review.json').read_text())
    expected = {
        'data/maps/native_png_plan.json': correction['base_plan_sha256'],
        'data/maps/domination_png_plan.json': correction['domination_plan_sha256'],
        'data/maps/aden_faith_png_plan.json': review['base_plan_sha256'],
    }
    with tempfile.TemporaryDirectory(prefix='twilight-checkout-') as directory:
        target = Path(directory)
        def git(*args):
            return subprocess.check_output(['git', '-C', directory, *args], stderr=subprocess.STDOUT)
        git('init', '-q')
        git('config', 'core.autocrlf', 'false')
        (target / '.gitattributes').write_bytes((ROOT / '.gitattributes').read_bytes())
        for name in expected:
            path = target / name
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_bytes((ROOT / name).read_bytes())
        git('add', '.')
        git('config', 'core.autocrlf', 'true')
        for name in expected:
            (target / name).unlink()
        git('checkout-index', '-a', '-f')
        failures = []
        for name, sha in expected.items():
            actual = hashlib.sha256((target / name).read_bytes()).hexdigest()
            ok = actual == sha
            print(json.dumps({'path': name, 'sha_matches': ok, 'actual': actual, 'expected': sha}))
            if not ok:
                failures.append(name)
        if failures:
            raise AssertionError('autocrlf changed authenticated plan bytes: ' + ', '.join(failures))
    print('AUTHENTICATED_MAP_CHECKOUT_OK 3 plans')


if __name__ == '__main__':
    run()
