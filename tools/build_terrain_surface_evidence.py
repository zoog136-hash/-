"""Package actual paired Godot viewports; never synthesize game imagery."""
import argparse
import hashlib
import html
import json
import statistics
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont


def union_area(rectangles):
    xs = sorted({x for r in rectangles for x in (r[0], r[2])})
    area = 0.0
    for left, right in zip(xs, xs[1:]):
        intervals = sorted((r[1], r[3]) for r in rectangles if r[0] < right and r[2] > left)
        bottom = -float('inf')
        height = 0.0
        for start, end in intervals:
            height += max(0.0, end-max(bottom, start))
            bottom = max(bottom, end)
        area += (right-left)*height
    return area


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--root', type=Path, default=Path('docs/playable-maps-20261011/terrain-surface-evidence'))
    parser.add_argument('--baseline', required=True)
    parser.add_argument('--commit', required=True)
    args = parser.parse_args()
    reports = {phase: json.loads((args.root/phase/'result.json').read_text()) for phase in ('before', 'after')}
    before, after = reports['before'], reports['after']
    assert not before['failures'] and not after['failures']
    assert before['captures'] == after['captures'], 'camera mismatch'
    assert len(after['captures']) == 75
    maps = list(dict.fromkeys(c['map'] for c in after['captures']))
    assert len(maps) == 25
    comparisons = []
    for view in after['captures']:
        row = dict(view)
        for phase in reports:
            data = (args.root/phase/view['file']).read_bytes()
            row[phase+'_sha256'] = hashlib.sha256(data).hexdigest()
        comparisons.append(row)
    font = ImageFont.load_default(size=16)
    for phase in reports:
        sheet = Image.new('RGB', (1600, 1060), '#171c20')
        draw = ImageDraw.Draw(sheet)
        for i, map_id in enumerate(maps):
            x, y = (i % 5)*320, (i // 5)*212
            with Image.open(args.root/phase/(map_id+'-middle.jpg')) as image:
                image.thumbnail((320, 180))
                sheet.paste(image, (x, y+28))
            draw.text((x+7, y+5), map_id, fill='#eee8d8', font=font)
        sheet.save(args.root/(phase+'-contact-sheet.jpg'), quality=94)
    scope = []
    for map_id in maps:
        path = Path('data/maps')/('aden_field.json' if map_id == 'aden_world' else map_id+'.json')
        data = json.loads(path.read_text())
        x, y, w, h = data['bounds']
        rectangles = []
        for view in comparisons:
            if view['map'] != map_id:
                continue
            px, py = view['camera_center']
            vw, vh = (v/view['zoom'] for v in view['viewport'])
            rectangles.append((max(x, px-vw/2), max(y, py-vh/2), min(x+w, px+vw/2), min(y+h, py+vh/2)))
        scope.append({'map': map_id, 'name': data['map_name'], 'family': data.get('family', 'aden'),
                      'sampled_camera_area_ratio': union_area(rectangles)/(w*h),
                      'rendered_views': 3, 'fidelity_score': None,
                      'fidelity_status': 'not_verified_against_exact_original_layout',
                      'quality_score': None, 'quality_status': 'requires_visual_review'})
    summary = {'baseline': args.baseline, 'commit': args.commit, 'comparisons': comparisons,
               'scope': scope, 'performance': {},
               'limitations': ['three sampled terrain views per map', 'camera area is not completion percentage',
                              'HUD and dynamic actors hidden', 'water/shader time may differ',
                              'software OpenGL measurements are not device performance']}
    for phase, report in reports.items():
        summary['performance'][phase] = {
            'median_load_ms': statistics.median(p['load_ms'] for p in report['performance']),
            'median_frame_interval_ms': statistics.median(p['frame_interval_ms_median'] for p in report['performance']),
            'max_static_memory_bytes': max(p['static_memory_bytes'] for p in report['performance'])}
    (args.root/'comparison.json').write_text(json.dumps(summary, ensure_ascii=False, indent=2)+'\n')
    choices = ''.join(f'<option value="{html.escape(c["file"])}">{html.escape(c["map"])} / {html.escape(c["file"].split("-")[-1][:-4])}</option>' for c in comparisons)
    document = '''<!doctype html><meta charset="utf-8"><title>TWILIGHT terrain comparison</title>
<style>body{margin:24px;background:#171c20;color:#eee8d8;font:16px system-ui}select,input{margin:12px}#view{position:relative;max-width:1280px;aspect-ratio:16/9}img{width:100%;display:block}#after{position:absolute;inset:0;clip-path:inset(0 0 0 50%)}small{display:block;margin-top:16px;color:#bec7ce}</style>
<h1>TWILIGHT — 25 maps / 75 matched terrain views</h1><p>Before: BASELINE<br>After: COMMIT</p>
<label>View <select id="choice">CHOICES</select></label><label>Before / After <input id="split" type="range" value="50"></label>
<div id="view"><img id="before"><img id="after"></div>
<p><a href="before-contact-sheet.jpg">Before contact sheet</a> · <a href="after-contact-sheet.jpg">After contact sheet</a> · <a href="comparison.json">Coordinates, hashes, scope and timings</a></p>
<small>Real Godot viewports. HUD and dynamic actors are hidden for terrain comparison. Water animation may differ. These samples do not establish full-world or original-layout completion.</small>
<script>const choice=document.querySelector('#choice'),split=document.querySelector('#split');function show(){document.querySelector('#before').src='before/'+choice.value;document.querySelector('#after').src='after/'+choice.value;}choice.onchange=show;split.oninput=()=>document.querySelector('#after').style.clipPath='inset(0 0 0 '+split.value+'%)';show();</script>'''
    document = document.replace('BASELINE', html.escape(args.baseline)).replace('COMMIT', html.escape(args.commit)).replace('CHOICES', choices)
    (args.root/'index.html').write_text(document)
    print('SURFACE_EVIDENCE_OK', len(maps), 'maps', len(comparisons), 'camera pairs')


if __name__ == '__main__':
    main()
