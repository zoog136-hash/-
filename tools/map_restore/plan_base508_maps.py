"""Plan additional restorations using actual files; never count inventory as art.

All required S32 and TI2 bytes must exist and match their original CRC/size.
Partial maps are reported, not silently rendered. No network or mutations.
"""
import argparse
import gzip
import json
from pathlib import Path
import zlib
from base508 import read_s32, write_s32


def plan(analysis, structure, source_roots, land_ids):
    lands = {r['ID']:r for r in json.loads((analysis/'land_catalog.json').read_text())}
    maps = json.loads((structure/'inventory/map_id_to_archive.json').read_text())
    tiles = json.loads((structure/'inventory/tile_id_to_archive.json').read_text())
    audited = {}
    with gzip.open(structure/'maps/chunks.jsonl.gz','rt') as handle:
        for line in handle:
            row = json.loads(line)
            group = row['member'].split('/')[1]
            audited.setdefault(group,set()).update(row.get('floor_tile_ids',[]))
            audited[group].update(row.get('foreground_tile_ids',[]))
    cache = {}
    def locate(spec):
        if spec['member'] not in cache:
            candidates = [root/spec['member'] for root in source_roots]
            valid, rejected = [], []
            for path in candidates:
                if not path.is_file(): continue
                payload = path.read_bytes()
                if len(payload)==spec['bytes'] and f'{zlib.crc32(payload):08x}'==spec['crc32']:
                    valid.append(str(path))
                else: rejected.append(str(path))
            cache[spec['member']] = {'valid_paths':valid,'rejected_paths':rejected}
        return cache[spec['member']]
    result = []
    for land_id in land_ids:
        land = lands[land_id]
        group = land['AssetPath'].strip('/')
        specs = maps[group]
        missing_s32, unsupported, bad, tile_ids = [], [], [], set()
        for spec in specs:
            if not spec['member'].endswith('.s32'):
                unsupported.append(spec)
                continue
            found = locate(spec)
            bad.extend(found['rejected_paths'])
            if not found['valid_paths']:
                missing_s32.append(spec)
                continue
            payload = Path(found['valid_paths'][0]).read_bytes()
            chunk = read_s32(payload,spec['member'])
            if write_s32(chunk)!=payload: raise ValueError('Source roundtrip mismatch')
            tile_ids.update(pair[0] for pair in chunk['tile_pairs'])
        exact = not missing_s32 and not unsupported
        if missing_s32: tile_ids.update(audited.get(group,set()))
        tile_specs = [next(r for r in tiles[str(tile)] if r['member'].endswith('.ti2')) for tile in sorted(tile_ids)]
        missing_ti2 = []
        for spec in tile_specs:
            found = locate(spec)
            bad.extend(found['rejected_paths'])
            if not found['valid_paths']: missing_ti2.append(spec)
        result.append({'land_id':land_id,'asset_path':land['AssetPath'],'map_key':f'base508_land_{land_id}',
                       'source_s32_expected':len(specs),'source_s32_ready':len(specs)-len(missing_s32)-len(unsupported),
                       'tile_ids_required':len(tile_ids),'tile_requirements_exact':exact,
                       'source_ti2_ready':len(tile_specs)-len(missing_ti2),
                       'source_ready_for_builder':exact and not missing_ti2,
                       'visual_restoration_status':'NOT_RENDERED_BY_PREFLIGHT',
                       'terrain_collision':'UNKNOWN','rejected_source_paths':sorted(set(bad)),
                       'unsupported_formats':unsupported,'missing_s32':missing_s32,'missing_ti2':missing_ti2})
    return result


if __name__ == '__main__':
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--analysis',type=Path,required=True)
    p.add_argument('--structure',type=Path,required=True)
    p.add_argument('--source-root',type=Path,action='append',required=True)
    p.add_argument('--land',type=int,action='append',required=True)
    p.add_argument('--out',type=Path,required=True)
    args = p.parse_args()
    result = plan(args.analysis,args.structure,args.source_root,args.land)
    args.out.write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n')
    print(json.dumps([{k:v for k,v in row.items() if k not in ['missing_s32','missing_ti2','rejected_source_paths']} for row in result]))
