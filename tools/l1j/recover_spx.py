"""Recover the original 1,700 SPX resources and atomically publish four verified packs.

The prior decoder is preserved in spx_decode.py. Source frame types are opaque;
no attack/move/death meaning is inferred from a filename or block type.
"""
from __future__ import annotations
import argparse, hashlib, io, json, os, pathlib, re, tempfile, time, zipfile
from PIL import Image
from spx_decode import decode_spx, spriteframes_tres

PREFIX = "assets/l1j/candidates/spx_converted/"
PATCH = "appcenter/connector/patch/patch_1.zip"

def sha(data):
    return hashlib.sha256(data).hexdigest()

def recover(source: pathlib.Path, staging: pathlib.Path, output: pathlib.Path):
    staging.mkdir(parents=True, exist_ok=True)
    output.mkdir(parents=True, exist_ok=True)
    records, failures = [], []
    with zipfile.ZipFile(source) as outer:
        patch = outer.read(PATCH)  # validates original ZIP CRC before decoding
    with zipfile.ZipFile(io.BytesIO(patch)) as original:
        names = sorted(n for n in original.namelist() if n.endswith('.spx'))
        if len(names) != 1700 or len(names) != len(set(names)):
            raise ValueError('source must contain exactly 1,700 unique SPX members')
        stems = [pathlib.PurePosixPath(n).stem for n in names]
        if len(set(stems)) != len(stems) or any(not re.fullmatch(r'\d+-\d+', n) for n in stems):
            raise ValueError('ambiguous/unsafe sprite identifiers')
        for index, name in enumerate(names):
            blob = original.read(name)
            try:
                decoded = decode_spx(blob, max_pixels_per_frame=4_000_000)
                visible = [(m, image) for m, image in decoded if image is not None]
                if not visible:
                    raise ValueError('all frames empty; retained as explicit failure')
                lo = [min(m['xy_offset'][axis] for m, image in visible) for axis in range(2)]
                hi = [max(m['xy_offset'][axis] + image.size[axis] for m, image in visible) for axis in range(2)]
                size = [hi[axis] - lo[axis] for axis in range(2)]
                if size[0] * size[1] > 4_000_000:
                    raise ValueError('common canvas exceeds pixel bound')
                stem = pathlib.PurePosixPath(name).stem
                folder = staging / PREFIX / stem
                folder.mkdir(parents=True, exist_ok=True)
                paths, meta = [], []
                for fi, (m, image) in enumerate(decoded):
                    # Empty source frames retain timing as transparent frames.
                    canvas = Image.new('RGBA', size, (0, 0, 0, 0))
                    placement = [m['xy_offset'][axis] - lo[axis] for axis in range(2)]
                    if image is not None:
                        canvas.paste(image, tuple(placement))
                    filename = f'frame_{fi:03}.png'
                    canvas.save(folder / filename)
                    path = f'res://{PREFIX}{stem}/{filename}'
                    paths.append(path)
                    with Image.open(folder / filename) as check:
                        check.load()
                        if check.size != tuple(size) or check.mode != 'RGBA':
                            raise ValueError('PNG verification mismatch')
                    meta.append({**m, 'path':path, 'pad_before':placement, 'canvas_size':size,
                                 'alpha_bbox':canvas.getbbox(), 'pixel_sha256':sha(canvas.tobytes())})
                (folder / 'SpriteFrames.tres').write_text(spriteframes_tres(paths), encoding='utf-8')
                metadata = {'source':name, 'source_sha256':sha(blob), 'frame_count':len(decoded),
                            'canvas_size':size, 'source_origin':lo,
                            'godot_center_offset':[lo[axis] + size[axis] / 2 for axis in range(2)],
                            'action_classification':'UNKNOWN', 'frames':meta}
                (folder / 'frame_metadata.json').write_text(json.dumps(metadata, ensure_ascii=False, indent=2)+'\n')
                records.append({k:v for k,v in metadata.items() if k != 'frames'} | {'sprite_id':stem})
            except Exception as exc:
                failures.append({'source':name, 'source_sha256':sha(blob), 'error':str(exc)})
            if (index+1) % 100 == 0:
                print(f'SPX {index+1}/1700, failed={len(failures)}', flush=True)
    manifest = {'source_archive_sha256':sha(source.read_bytes()), 'patch_sha256':sha(patch),
                'total_sources':len(names), 'converted':len(records),
                'frames':sum(r['frame_count'] for r in records), 'failures':failures, 'sprites':records}
    (output / 'SPX_VERIFICATION.json').write_text(json.dumps(manifest, ensure_ascii=False, indent=2)+'\n')
    if failures:
        raise ValueError(f'{len(failures)} SPX failed; no final packs published')
    packs = []
    for part in range(4):
        final = output / f'TWILIGHT_L1J_SPX_VERIFIED_PART{part+1}_20261010.zip'
        temp = final.with_suffix('.zip.tmp')
        subset = records[part*425:(part+1)*425]
        with zipfile.ZipFile(temp, 'w', zipfile.ZIP_DEFLATED, compresslevel=6) as archive:
            for record in subset:
                for file in sorted((staging/PREFIX/record['sprite_id']).iterdir()):
                    archive.write(file, file.relative_to(staging).as_posix())
            archive.writestr(f'data/l1j/spx/part{part+1}.json', json.dumps({'sprites':subset},ensure_ascii=False))
        with zipfile.ZipFile(temp) as archive:
            if archive.testzip() is not None:
                raise ValueError('final ZIP CRC failure')
            entries = set(archive.namelist())
            png_count = 0
            for name in entries:
                if name.endswith('.png'):
                    with Image.open(io.BytesIO(archive.read(name))) as image:
                        image.load()
                    png_count += 1
                if name.endswith('SpriteFrames.tres'):
                    text = archive.read(name).decode('utf-8')
                    refs = re.findall(r'path="res://([^"]+)"', text)
                    if len(refs) != next(r['frame_count'] for r in subset if '/'+r['sprite_id']+'/' in name):
                        raise ValueError('frame count mismatch')
                    if any(ref not in entries for ref in refs):
                        raise ValueError('broken SpriteFrames reference')
            info = {'part':part+1,'sprites':len(subset),'png_frames':png_count,'crc_checked':len(entries),
                    'sha256':sha(temp.read_bytes()),'bytes':temp.stat().st_size,'filename':final.name}
        os.replace(temp, final)
        packs.append(info)
    (output/'SPX_PACKS.json').write_text(json.dumps({'packs':packs,'frames':manifest['frames'],'failures':[]},indent=2)+'\n')
    print(json.dumps({'sprites':len(records),'frames':manifest['frames'],'packs':len(packs),'failures':0}),flush=True)

if __name__ == '__main__':
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--source',type=pathlib.Path,required=True)
    parser.add_argument('--staging',type=pathlib.Path,required=True)
    parser.add_argument('--output',type=pathlib.Path,required=True)
    args=parser.parse_args()
    recover(args.source,args.staging,args.output)
