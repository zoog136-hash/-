"""Reproduce Git checkout conversion of the three authenticated PNG plans."""
import argparse
import hashlib
import json
from pathlib import Path
import subprocess
import tempfile

p = argparse.ArgumentParser()
p.add_argument('--root', type=Path, required=True)
p.add_argument('--output', type=Path, required=True)
a = p.parse_args()
a.output.mkdir(parents=True, exist_ok=True)
corrections = json.loads((a.root / 'data/maps/native_png_navigation_corrections.json').read_bytes())
review = json.loads((a.root / 'data/maps/aden_png_display_review.json').read_bytes())
expected = {
    'data/maps/native_png_plan.json': corrections['base_plan_sha256'],
    'data/maps/aden_faith_png_plan.json': review['base_plan_sha256'],
    'data/maps/domination_png_plan.json': corrections['domination_plan_sha256'],
}
rows = []
with tempfile.TemporaryDirectory(prefix='pr154-autocrlf-') as scratch:
    checkout = Path(scratch)
    def git(*args):
        return subprocess.run(['git', '-C', scratch, *args], check=True,
                              stdout=subprocess.PIPE, stderr=subprocess.PIPE).stdout
    git('init', '-q')
    git('config', 'core.autocrlf', 'false')
    (checkout / '.gitattributes').write_bytes((a.root / '.gitattributes').read_bytes())
    for name in expected:
        path = checkout / name
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes((a.root / name).read_bytes())
    git('add', '.')
    git('config', 'core.autocrlf', 'true')
    for name in expected:
        (checkout / name).unlink()
    git('checkout-index', '--all', '--force')
    for name, sha in expected.items():
        data = (checkout / name).read_bytes()
        actual = hashlib.sha256(data).hexdigest()
        row = dict(path=name, bytes=len(data), lf=data.count(b'\n'),
                   crlf=data.count(b'\r\n'), expected=sha, actual=actual,
                   sha_matches=actual == sha)
        rows.append(row)
        (a.output / Path(name).name).write_bytes(data)
        print(json.dumps(row), flush=True)
report = dict(core_autocrlf=True, plans=rows,
              all_authenticated_bytes_preserved=all(r['sha_matches'] for r in rows))
(a.output / 'checkout.json').write_text(json.dumps(report, indent=2) + '\n')
raise SystemExit(0 if report['all_authenticated_bytes_preserved'] else 1)
