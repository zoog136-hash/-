"""Verify every emitted pixel against the original PNG and all retained hashes."""
import argparse
import hashlib
import json
from pathlib import Path
from PIL import Image


def verify(root, source_png):
    pack = json.loads((root / "map.json").read_text())
    if hashlib.sha256((root / pack["portals_file"]).read_bytes()).hexdigest() != pack["portals_sha256"]:
        raise ValueError("Portal table SHA mismatch")
    if pack.get('npc_occupancy_file') and hashlib.sha256((root/pack['npc_occupancy_file']).read_bytes()).hexdigest() != pack['npc_occupancy_sha256']:
        raise ValueError('NPC occupancy source SHA mismatch')
    source = None
    if source_png:
        if hashlib.sha256(source_png.read_bytes()).hexdigest() != pack["art"]["source_sha256"]:
            raise ValueError("Original PNG SHA mismatch")
        Image.MAX_IMAGE_PIXELS = 160_000_000
        source = Image.open(source_png)
        source.load()
    rows = pack["geometry"]+pack["art"]["chunks"]+pack["preserved_navigation"]
    for row in rows:
        relative = Path(row["file"])
        if relative.is_absolute() or ".." in relative.parts:
            raise ValueError("Unsafe member path")
        path = root / relative
        if hashlib.sha256(path.read_bytes()).hexdigest() != row["sha256"]:
            raise ValueError("Pack SHA mismatch: "+str(relative))
        if row.get('source_file') and hashlib.sha256((root/row['source_file']).read_bytes()).hexdigest() != row['source_sha256']:
            raise ValueError('Original S32 source SHA mismatch')
        if source is not None and "position" in row:
            x, y = row["position"]
            w, h = row["size"]
            with Image.open(path) as piece:
                if piece.mode != source.mode or piece.size != (w, h) or piece.tobytes() != source.crop((x, y, x+w, y+h)).tobytes():
                    raise ValueError("Original pixel mismatch: "+str(relative))
    composition = None
    if pack['art']['status'] == 'S32_TI2_RENDERABLE':
        path = root / pack['art']['composition_file']
        if hashlib.sha256(path.read_bytes()).hexdigest() != pack['art']['composition_sha256']:
            raise ValueError('Composition metadata SHA mismatch')
        composition = json.loads(path.read_text())
        for row in composition['tile_provenance']:
            if hashlib.sha256((root / row['source']).read_bytes()).hexdigest() != row['sha256']:
                raise ValueError('Original TI2 source SHA mismatch')
        canvas = Image.new('RGBA', tuple(pack['art']['size']))
        for row in pack['art']['chunks']:
            with Image.open(root / row['file']) as piece:
                canvas.paste(piece, tuple(row['position']))
        if hashlib.sha256(canvas.tobytes()).hexdigest() != pack['art']['pixel_sha256']:
            raise ValueError('Composed map pixel SHA mismatch')
    overview = root / pack["art"]["overview"]
    if hashlib.sha256(overview.read_bytes()).hexdigest() != pack["art"]["overview_sha256"]:
        raise ValueError("Overview SHA mismatch")
    verified = len(rows)+2+int(bool(pack.get('npc_occupancy_file')))+sum(bool(row.get('source_file')) for row in pack['geometry'])
    if composition: verified += 1+len(composition['tile_provenance'])
    return {"verified_files": verified, "original_png_pixels_compared": bool(source), "composed_pixels_reassembled": bool(composition), "art_chunks": len(pack["art"]["chunks"]), "report": pack["report"]}


if __name__ == "__main__":
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("pack", type=Path)
    p.add_argument("--source-png", type=Path)
    args = p.parse_args()
    print(json.dumps(verify(args.pack, args.source_png)))
