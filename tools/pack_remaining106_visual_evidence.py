"""Preserve actual Main framebuffer evidence losslessly, with bounded ZIP parts.

Only known QA outputs are read. Source PNGs, game files and saves are untouched.
All temporal native captures, dynamic AI/lifecycle captures, wide AI views and
final side-by-side comparisons are retained. Redundant static pose screenshots
are inventoried separately; they do not replace continuous native evidence.
"""
import argparse
import hashlib
import json
from pathlib import Path
import zipfile


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--review-root', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    root, output = args.review_root.resolve(), args.output.resolve()
    if output.exists():
        raise SystemExit('Refuse existing evidence output; preserve prior packages')
    selected = set()
    static_inventory = []
    for area in ['headless', 'opengl', 'visual-actual', 'temporal-opengl', 'style-compare-clear']:
        for path in (root / area).rglob('*'):
            if not path.is_file():
                continue
            if path.suffix in {'.json', '.log'}:
                selected.add(path)
            elif path.suffix == '.png':
                keep = (area in {'temporal-opengl', 'style-compare-clear'}
                        or area == 'visual-actual' and path.name.startswith(('ai-', 'lifecycle-', 'monster-')))
                if keep:
                    selected.add(path)
                else:
                    static_inventory.append({'path': str(path.relative_to(root)), 'sha256': digest(path)})
    for area in ['review-boards']:
        selected.update(p for p in (root / area).glob('*.png'))
    selected.update(p for p in [root / 'staging-preservation-proof.json', root / 'import.log',
                               root / 'visual-runner-parse.log', root / 'visual-runner-parse-fixed.log'] if p.is_file())
    if not selected:
        raise SystemExit('No actual evidence found')
    output.mkdir(parents=True)
    limit, archives, members = 32 * 1024 * 1024, [], []
    archive, size = None, 0
    try:
        for path in sorted(selected):
            if path.is_symlink() or not path.is_relative_to(root):
                raise ValueError('Unsafe evidence source: ' + str(path))
            if path.stat().st_size > limit:
                raise ValueError('Evidence member exceeds bounded part size: ' + str(path))
            if archive is None or size + path.stat().st_size > limit:
                if archive is not None:
                    archive.close()
                name = f'actual-Main-evidence-{len(archives)+1:02d}.zip'
                archives.append(name)
                archive = zipfile.ZipFile(output / name, 'w', zipfile.ZIP_DEFLATED, compresslevel=6)
                size = 0
            relative = str(path.relative_to(root))
            before = digest(path)
            archive.write(path, relative)
            if digest(path) != before:
                raise ValueError('Evidence changed while archiving: ' + relative)
            members.append({'path': relative, 'sha256': before, 'bytes': path.stat().st_size,
                            'archive': archives[-1]})
            size += path.stat().st_size
    finally:
        if archive is not None:
            archive.close()
    for name in archives:
        with zipfile.ZipFile(output / name) as source:
            if source.testzip() is not None:
                raise ValueError('Archive CRC failed: ' + name)
            expected = {row['path']: row for row in members if row['archive'] == name}
            for member in source.infolist():
                if hashlib.sha256(source.read(member)).hexdigest() != expected[member.filename]['sha256']:
                    raise ValueError('Archive member SHA failed: ' + member.filename)
    document = {'archives': [{'path': name, 'sha256': digest(output / name),
                              'bytes': (output / name).stat().st_size} for name in archives],
                'members': members, 'source_root_at_capture': str(root),
                'all_native_temporal_and_dynamic_AI_lifecycle_bodies_delivered': True,
                'redundant_static_capture_bodies_delivered': False,
                'redundant_static_inventory': static_inventory,
                'restore': 'Verify part SHA; extract each independent ZIP into one NEW empty folder. Relative paths reproduce capture layout; recorded absolute paths resolve by source_root_at_capture suffix.'}
    (output / 'manifest.json').write_text(json.dumps(document, ensure_ascii=False, indent=2) + '\n')
    print(json.dumps({'parts': len(archives), 'members': len(members),
                      'bytes': sum((output / name).stat().st_size for name in archives)}, ensure_ascii=False))


if __name__ == '__main__':
    main()
