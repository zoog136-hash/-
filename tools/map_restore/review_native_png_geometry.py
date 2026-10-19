"""Draw native-pixel manual geometry over the REAL private PNGs for review.

Green areas are authored walking candidates, red areas are exclusions, yellow
numbers are runtime route probes. This is a review image, not proof that every
source wall or gameplay coordinate has been established. Never publish the art.
"""
import argparse
import json
from pathlib import Path

from PIL import Image, ImageDraw

from build_native_png_maps import ROOT, digest

Image.MAX_IMAGE_PIXELS = 180_000_000


def review(sources, plan_path, pack, output):
    output = output.resolve()
    if output.is_relative_to(ROOT):
        raise ValueError('Source-bearing review images belong outside public Git')
    output.mkdir(parents=True, exist_ok=True)
    plan = json.loads(plan_path.read_text())
    report = {}
    for mid, spec in plan['maps'].items():
        source = sources/spec['file']
        if digest(source) != plan['sources'][spec['file']]['sha256']:
            raise ValueError('Wrong source bytes: '+spec['file'])
        manifest = json.loads((pack/mid/'manifest.json').read_text())
        x, y, w, h = manifest['bounds']
        with Image.open(source) as original:
            image = original.crop((x, y, x+w, y+h))
        image.thumbnail((2400, 1400))
        sx, sy = image.width/w, image.height/h
        layer = Image.new('RGBA', image.size)
        draw = ImageDraw.Draw(layer)

        def points(values):
            return [((a-x)*sx, (b-y)*sy) for a, b in values]

        for polygon in spec['walk_polygons']:
            draw.polygon(points(polygon), fill=(30, 220, 140, 65), outline=(40, 255, 180, 255), width=2)
        for shape in spec.get('collision', []):
            if shape['shape'] == 'polygon':
                draw.polygon(points(shape['points']), fill=(250, 30, 30, 130), outline='red', width=2)
            elif shape['shape'] == 'circle':
                px, py = points([shape['center']])[0]
                radius = shape['radius']*sx
                draw.ellipse((px-radius, py-radius, px+radius, py+radius), fill=(250, 30, 30, 160))
        for i, point in enumerate(spec['route_checks']):
            px, py = points([point])[0]
            draw.ellipse((px-4, py-4, px+4, py+4), fill='yellow')
            draw.text((px+5, py), str(i), fill='yellow', stroke_width=1, stroke_fill='black')
        path = output/(mid+'.png')
        Image.alpha_composite(image, layer).save(path)
        report[mid] = dict(image_sha256=digest(path), route_checks=len(spec['route_checks']),
                           collision_shapes=len(spec.get('collision', [])),
                           full_terrain_verified=spec['full_terrain_collision_verified'])
    (output/'review.json').write_text(json.dumps(report, indent=2)+'\n')
    return report


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--sources', type=Path, required=True)
    parser.add_argument('--pack', type=Path, required=True)
    parser.add_argument('--plan', type=Path, default=ROOT/'data/maps/native_png_plan.json')
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    print(json.dumps(review(args.sources, args.plan, args.pack, args.output)))
