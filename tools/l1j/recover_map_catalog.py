"""Recover complete map data from immutable source archives, without executing them.

Cache headers establish absolute origins; a bare text grid does not. Every source
variant remains in the inventory rather than silently replacing another version.
Artwork and live world integration are separately blocked until verified.
"""
from __future__ import annotations

import argparse
import collections
import csv
import ctypes
import ctypes.util
import hashlib
import io
import json
from pathlib import Path, PurePosixPath
import re
import zipfile

import numpy as np
from convert_maps import read_cache
from extract_a3 import tables
from map_segment_reader import parse as parse_segment

LIMIT = 512 * 1024 * 1024


def sha(blob):
    return hashlib.sha256(blob).hexdigest()


def seven_entries(blob, label):
    """Use the installed libarchive; no external downloader or extraction paths."""
    lib = ctypes.CDLL(ctypes.util.find_library('archive') or 'libarchive.so.13')
    ptr = ctypes.c_void_p
    lib.archive_read_new.restype = ptr
    for name in ('archive_read_support_format_7zip', 'archive_read_support_filter_all', 'archive_read_free'):
        getattr(lib, name).argtypes = [ptr]
    lib.archive_read_open_memory.argtypes = [ptr, ptr, ctypes.c_size_t]
    lib.archive_read_next_header.argtypes = [ptr, ctypes.POINTER(ptr)]
    lib.archive_entry_pathname.argtypes = [ptr]
    lib.archive_entry_pathname.restype = ctypes.c_char_p
    lib.archive_entry_size.argtypes = [ptr]
    lib.archive_entry_size.restype = ctypes.c_longlong
    lib.archive_read_data.argtypes = [ptr, ptr, ctypes.c_size_t]
    lib.archive_read_data.restype = ctypes.c_longlong
    lib.archive_read_data_skip.argtypes = [ptr]
    lib.archive_error_string.argtypes = [ptr]
    lib.archive_error_string.restype = ctypes.c_char_p
    reader = lib.archive_read_new()
    memory = ctypes.create_string_buffer(blob)
    try:
        lib.archive_read_support_format_7zip(reader)
        lib.archive_read_support_filter_all(reader)
        if lib.archive_read_open_memory(reader, memory, len(blob)) != 0:
            raise ValueError(str(lib.archive_error_string(reader)))
        entry = ptr()
        while True:
            status = lib.archive_read_next_header(reader, ctypes.byref(entry))
            if status == 1:
                break
            if status != 0:
                raise ValueError(str(lib.archive_error_string(reader)))
            name = lib.archive_entry_pathname(entry).decode('utf-8', errors='replace')
            size = lib.archive_entry_size(entry)
            if wanted(name, label):
                if size < 0 or size > LIMIT:
                    raise ValueError('map archive entry exceeds bound: ' + name)
                buffer = ctypes.create_string_buffer(size or 1)
                used = 0
                while used < size:
                    count = lib.archive_read_data(reader, ctypes.byref(buffer, used), size-used)
                    if count <= 0:
                        raise ValueError('truncated archive entry: ' + name)
                    used += count
                yield name, size, buffer.raw[:size]
            else:
                if lib.archive_read_data_skip(reader) < 0:
                    raise ValueError('cannot skip archive entry: ' + name)
                yield name, size, None
    finally:
        lib.archive_read_free(reader)


def kind_of(name, context=''):
    path = PurePosixPath(name.replace('\\', '/'))
    suffix = path.suffix.lower()
    if suffix == '.map' and path.stem.isdigit(): return 'CACHE'
    if suffix == '.txt' and path.stem.isdigit() and (any('map' in p.lower() for p in path.parts[:-1]) or 'map' in context.lower()): return 'TEXT'
    if suffix == '.s32': return 'S32'
    if suffix == '.til' or (suffix in ('.pak', '.idx') and 'tile' in path.stem.lower()): return 'TILE_GRAPHICS'
    if suffix in ('.zip', '.7z'): return 'ARCHIVE'
    return ''


def wanted(name, context=''):
    return kind_of(name, context) in ('CACHE', 'TEXT', 'S32', 'ARCHIVE')


def zip_entries(archive, label):
    for info in archive.infolist():
        if info.is_dir(): continue
        if wanted(info.filename, label) and info.file_size > LIMIT:
            raise ValueError('map archive entry exceeds bound: ' + info.filename)
        yield info.filename, info.file_size, archive.read(info) if wanted(info.filename, label) else None


def read_text(blob):
    text = blob.decode('utf-8-sig')
    if not re.fullmatch(r'[0-9,\s]+', text): raise ValueError('non-numeric text grid')
    lines = [line.strip().rstrip(',') for line in text.splitlines() if line.strip()]
    if not lines or len(lines) > 4096: raise ValueError('invalid row count')
    width = len(lines[0].split(','))
    if width < 1 or width > 4096 or any(len(line.split(',')) != width for line in lines):
        raise ValueError('inconsistent text grid width')
    values = np.fromstring(','.join(lines), sep=',', dtype=np.int64)
    if len(values) != width*len(lines) or np.any(values < 0) or np.any(values > 255):
        raise ValueError('text attributes outside exact byte range')
    return {'dimensions': [width, len(lines)], 'source_origin': None}, values.astype(np.uint8).reshape(len(lines),width)


def write_exact(path, blob):
    path.parent.mkdir(parents=True, exist_ok=True)
    if path.exists() and path.read_bytes() != blob:
        raise ValueError('preserved existing output differs: ' + str(path))
    if not path.exists(): path.write_bytes(blob)


def recover(sources, out, reports, root):
    records, candidates, errors, segments, texture_files = [], collections.defaultdict(list), [], [], []
    required_tiles = set()
    nested_count = 0
    archive_metadata = []
    metadata = {}
    primary = next((p for p in sources if p.name.endswith('-a3.zip') or p.name == 'a3.zip'), None)
    if primary is None: raise ValueError('A3 archive is missing; source rules and origins cannot be confirmed')
    if primary:
        with zipfile.ZipFile(primary) as z:
            rows, _ = tables(z.read('db/l1remaster.sql').decode('utf-8-sig'), {'mapids'})
        metadata = {int(r['mapid']): r for r in rows['mapids']}

    def inspect(entries, label, archive_name, depth=0):
        nonlocal nested_count
        for name, size, blob in entries:
            kind = kind_of(name, label)
            if not kind: continue
            source = label + '!' + name
            if kind == 'ARCHIVE':
                nested_count += 1
                if depth >= 8:
                    errors.append({'source': source, 'error': 'nested depth exceeds bound'})
                    continue
                try:
                    if name.lower().endswith('.zip'):
                        with zipfile.ZipFile(io.BytesIO(blob)) as z:
                            inspect(zip_entries(z, source), source, archive_name, depth+1)
                    else:
                        inspect(seven_entries(blob, source), source, archive_name, depth+1)
                except (ValueError, OSError, zipfile.BadZipFile) as exc:
                    errors.append({'source': source, 'error': str(exc)})
                continue
            record = {'source': source, 'archive': archive_name, 'kind': kind, 'bytes': size, 'status': 'INDEXED'}
            if kind == 'TILE_GRAPHICS':
                texture_files.append(source)
                records.append(record)
                continue
            record['source_sha256'] = sha(blob)
            try:
                if kind in ('CACHE', 'TEXT'):
                    map_id = int(PurePosixPath(name).stem)
                    meta, grid = read_cache(blob, map_id) if kind == 'CACHE' else read_text(blob)
                    raw = grid.tobytes()
                    record.update(meta, map_id=map_id, row_major_sha256=sha(raw), status='VALIDATED')
                    record['nonzero_edge_bytes'] = int(np.count_nonzero(grid & 3))
                    priority = (0 if archive_name == primary.name else 1 if 'L1J-JP_3.63c' in archive_name else 2, 0 if kind == 'CACHE' else 1, source)
                    candidates[map_id].append((priority, record, raw))
                else:
                    parsed = parse_segment(blob)
                    record.update(status='VALIDATED', tile_count=len(parsed['tile_ids']), unknown_tail_bytes=parsed['unknown_tail_bytes'])
                    required_tiles.update(parsed['tile_ids'])
                    segments.append({'source': source, 'sha256': record['source_sha256'], **parsed})
            except (ValueError, KeyError, OverflowError) as exc:
                record.update(status='BLOCKED', reason=str(exc))
            # Retain every source entry, including invalid and duplicate variants.
            records.append(record)

    for path in sources:
        digest = hashlib.sha256()
        with path.open('rb') as stream:
            for block in iter(lambda: stream.read(1024*1024), b''): digest.update(block)
        archive_metadata.append({'filename': path.name, 'bytes': path.stat().st_size, 'sha256': digest.hexdigest()})
        with zipfile.ZipFile(path) as z: inspect(zip_entries(z, path.name), path.name, path.name)
        print('MAP_RECOVERY_ARCHIVE', path.name, 'map_entries', len(records), flush=True)

    selected = []
    for map_id, variants in sorted(candidates.items()):
        # Prefer a self-describing cache over text for the same source priority.
        _, record, raw = min(variants, key=lambda item:item[0])
        result = {k:v for k,v in record.items() if k not in ('kind','status','archive','bytes')}
        result['variants'] = len(variants)
        result['distinct_grids'] = len({v[1]['row_major_sha256'] for v in variants})
        row = metadata.get(map_id, {})
        result['source_name'] = str(row.get('locationname', 'UNKNOWN')) if record['archive'] == primary.name else 'UNKNOWN_OTHER_REVISION'
        # A cache header from another revision must not silently override a bare
        # text grid. A3's own SQL is accepted only for an exact dimensions match.
        if result['source_origin'] is None and record['archive'] == primary.name and row:
            declared = [int(row['endX'])-int(row['startX'])+1, int(row['endY'])-int(row['startY'])+1]
            if declared == result['dimensions']:
                result['source_origin'] = [int(row['startX']), int(row['startY'])]
                result['origin_basis'] = 'same A3 SQL and exact text dimensions'
        elif result['source_origin'] is not None:
            result['origin_basis'] = 'original cache header'
        result['navigation_rules'] = 'A3_STATIC_EDGES' if record['archive'] == primary.name else 'UNVERIFIED_OTHER_REVISION'
        result['gameplay_applied'] = False
        result['artwork_restored'] = False
        result['raw_file'] = f'raw/{map_id}.bin'
        write_exact(out/result['raw_file'], raw)
        selected.append(result)

    counts = collections.Counter(r['kind'] for r in records)
    blocked = [r for r in records if r['status'] == 'BLOCKED']
    fields = json.loads((root/'data/maps/field_index.json').read_text())
    fields.append({'map_id':'aden_world', 'map_name':'아덴 월드', 'family':'aden'})
    mappings = []
    for field in fields:
        map_id = field['map_id']
        source_id = 4 if map_id == 'aden_world' else 100+int(map_id[-2:]) if map_id.startswith('oman_') else None
        candidate = next((r for r in selected if r['map_id'] == source_id), None)
        mappings.append({'game_map_id':map_id, 'game_map_name':field['map_name'],
            'candidate_source_map_id':source_id, 'source_name':candidate['source_name'] if candidate else 'UNKNOWN',
            'mapping_status':'CANDIDATE_PC_LINEAGE_NOT_CONFIRMED_LINEAGEM' if candidate else 'UNRESOLVED',
            'source_origin':candidate['source_origin'] if candidate else None,
            'required': ['visual tile textures', 'verified client edition', 'pixel calibration', 'NPC/portal placements'],
            'gameplay_applied':False, 'artwork_restored':False})
    summary = {'archives':len(sources), 'nested_archives':nested_count, 'entries':dict(counts),
        'validated_grid_entries':sum(r['status']=='VALIDATED' and r['kind'] in ('CACHE','TEXT') for r in records),
        'selected_maps':len(selected), 'a3_navigation_maps':sum(r['navigation_rules']=='A3_STATIC_EDGES' and r['source_origin'] is not None for r in selected),
        'empty_edge_maps':[r['map_id'] for r in selected if r['nonzero_edge_bytes']==0],
        'parsed_s32':len(segments), 'blocked_entries':len(blocked), 'required_tile_ids':len(required_tiles),
        'tile_graphic_files':len(texture_files), 'archive_errors':errors, 'game_maps':len(mappings), 'restored_game_maps':0}
    out.mkdir(parents=True, exist_ok=True)
    (out/'source_maps.json').write_text(json.dumps({'schema':1, 'maps':selected},ensure_ascii=False,indent=2)+'\n')
    (out/'s32_placements.json').write_text(json.dumps({'segments':segments,'required_tile_ids':sorted(required_tiles),'blocked':blocked},ensure_ascii=False,separators=(',',':'))+'\n')
    reports.mkdir(parents=True, exist_ok=True)
    (reports/'MAP_SOURCE_MAPPING.json').write_text(json.dumps({'schema':1,'summary':summary,'game_maps':mappings,'source_maps':selected,'archives':archive_metadata,'blocked_entries':blocked},ensure_ascii=False,indent=2)+'\n')
    keys = ['source','kind','bytes','map_id','dimensions','source_origin','source_sha256','row_major_sha256','status','reason']
    with (reports/'MAP_SOURCE_INVENTORY.csv').open('w',newline='',encoding='utf-8-sig') as f:
        writer=csv.DictWriter(f,fieldnames=keys,extrasaction='ignore');writer.writeheader();writer.writerows(records)
    lines=['# 맵 자료 누락 및 적용 제한', '', '원본 지형의 실제 게임 적용: **0/25, 미완료**.', '',
        '`a2(1).zip`은 이번 환경에 전달되지 않았다. 나머지 16개 첨부를 검사했다.', '',
        f'S32가 참조하는 타일 ID: {len(required_tiles):,}개. 발견한 .til / tile.pak / tile.idx: {len(texture_files)}개.',
        '타일 ID와 통행 바이트는 배경 이미지가 아니다. 원본 배경을 생성했다고 집계하지 않는다.', '',
        '다른 판본의 통행 바이트는 출처별로 보존하며 A3 규칙으로 자동 실행하지 않는다.', '',
        '| 게임 맵 | 대응 후보 | 상태 |', '| --- | --- | --- |']
    lines += [f"| {r['game_map_id']} | {r['candidate_source_map_id'] if r['candidate_source_map_id'] is not None else '미확인'} | 배경·판본·좌표·NPC/포털 미검증 |" for r in mappings]
    lines += ['', '## 파싱 보류 원본', ''] + [f"- `{r['source']}`: {r['reason']} (SHA-256 `{r['source_sha256']}`)" for r in blocked]
    (reports/'MAP_ASSET_MISSING_REPORT.md').write_text('\n'.join(lines)+'\n',encoding='utf-8')
    print('MAP_RECOVERY_DATA_OK', json.dumps(summary,ensure_ascii=False), flush=True)
    if errors: raise ValueError('archive errors are preserved; do not claim complete inventory')
    return summary


if __name__ == '__main__':
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--sources',type=Path,required=True)
    parser.add_argument('--output',type=Path,required=True)
    parser.add_argument('--reports',type=Path,required=True)
    parser.add_argument('--root',type=Path,default=Path(__file__).resolve().parents[2])
    args=parser.parse_args()
    sources=sorted(args.sources.glob('*.zip'))
    if not sources: raise SystemExit('no source archives; no recovery claimed')
    recover(sources,args.output,args.reports,args.root)
