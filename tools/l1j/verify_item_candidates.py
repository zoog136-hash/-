"""Validate A2 numeric icon candidates without equating numeric IDs with item identity."""
import argparse
import hashlib
import io
import json
from pathlib import Path
import re
import zipfile
from PIL import Image

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--a2', type=Path, required=True)
parser.add_argument('--items', type=Path, required=True)
parser.add_argument('--output', type=Path, required=True)
args = parser.parse_args()
icons, failures = {}, []
with zipfile.ZipFile(args.a2) as source:
    for info in source.infolist():
        match = re.fullmatch(r'appcenter/img/item/(\d+)\.png', info.filename)
        if not match:
            continue
        key = int(match[1])
        if key in icons:
            raise ValueError('Duplicate numeric icon ID')
        try:
            blob = source.read(info)
            with Image.open(io.BytesIO(blob)) as image:
                if image.format != 'PNG':
                    raise ValueError('PNG path contains a different format')
                image.load()
                size = list(image.size)
            icons[key] = {'source_member': info.filename, 'sha256': hashlib.sha256(blob).hexdigest(),
                          'size': size, 'identity_status': 'UNVERIFIED'}
        except Exception as exc:
            failures.append({'source_member': info.filename, 'icon_id': key, 'error': str(exc)})
items = json.loads(args.items.read_text(encoding='utf-8'))
links = []
for item in items:
    icon = int(item['inventory_graphic_id'])
    links.append({'source_candidate_id': item['canonical_candidate_id'], 'icon_id': icon,
                  'valid_png_candidate': icon in icons, 'identity_verified': False})
report = {'source_icons': len(icons) + len(failures), 'valid_pngs': len(icons),
          'numeric_item_matches': sum(r['valid_png_candidate'] for r in links), 'items': len(items),
          'identity_verified_by_this_tool': 0, 'failures': failures,
          'icons': {str(k): v for k, v in icons.items()}, 'item_candidates': links}
args.output.parent.mkdir(parents=True, exist_ok=True)
args.output.write_text(json.dumps(report, ensure_ascii=False, indent=2)+'\n', encoding='utf-8')
print(json.dumps({k: v for k, v in report.items() if k not in ('icons', 'item_candidates')}, ensure_ascii=False))
raise SystemExit(bool(failures))
