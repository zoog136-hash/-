#!/usr/bin/env python3
"""Build a private, deterministic auto-hunting definition pack from cumulative523.

No source content is checked into Git. This does not create a navigation graph,
choose arrival tiles, infer server activation, or install anything into a save.
"""
from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
import tempfile
import zipfile

SOURCE_SHA256 = 'd5192c3c735ff95c6b181bf2d4d77448d8b562fdb28dbd43f897fa4eae1f4832'
TABLE_SHA256 = {
    'AutoScheduleLandTeleport': '58640704fa95e98fc2c858d3c048eac8b50002d57b1abd1ab38f3ec614bad237',
    'AutoScheduleCategory': '163a8c3eda56b99a18f934dcc406b3f0c0e4902ab965fe0100aa8f5e2cbe51c6',
    'LandTeleport': '7d944107259b90c3d1c02f23d8025dedbcc80c38f6273b1c552ad091217ca19a',
    'LandTeleportTerritories': '44b4fea4b8607f92a72c0fa2a4d502eee27dd4eee43b1b53a9ecbe7f0522690c',
    'Territories': '2ef6e702e46204f8fd233ede612890ec20eadbbd16189bc02b04df3a58f4cc3b',
    'Land': '8778d18d8c23a0ccb0a555f495e056987796232c616dec805dfb4c4d633b0ef9',
    'LandTeleportPrerequisite': '91206e9b114591bc1fa91aa25630bddedc0e47ce2d58a52622162068ea84038d',
    'Prerequisite': 'b3beababa954708c0a38e394e5f3a177245df2c396136a7dc66fb2761be3fb65',
    'PrerequisiteType': '5a9ccbaea69f12e0a23942bb50fb1548c0aaaa2edcb1e2fa712ecf81802a50d0',
    'Currency': '9569dfe7a443af5f828a486265ce289762a1493e2b4554d359c0f2ad939f916a',
}
PACK_NAME = 'auto_hunting523.json'


def digest(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def encode(value) -> bytes:
    return (json.dumps(value, ensure_ascii=False, sort_keys=True, separators=(',', ':')) + '\n').encode()


def project(tables: dict) -> dict:
    """Join typed source FKs, retaining multiplicity, raw flags and all row fields."""
    def index(name):
        result = {r['ID']: r for r in tables[name]}
        if len(result) != len(tables[name]):
            raise ValueError('duplicate identity in ' + name)
        return result

    categories, teleports = index('AutoScheduleCategory'), index('LandTeleport')
    territories, lands = index('Territories'), index('Land')
    prerequisites, types, currencies = index('Prerequisite'), index('PrerequisiteType'), index('Currency')
    index('AutoScheduleLandTeleport')
    index('LandTeleportTerritories')
    entries = []
    sentinel = territories[0]
    if sentinel['Name'] != 'None':
        raise ValueError('unexpected Territory 0')
    for row in tables['AutoScheduleLandTeleport']:
        tid = row['TerritoryID']
        hunting = territories[tid] if tid != 0 else None
        teleport = teleports[row['LandTeleportID']]
        destinations = []
        for link in tables['LandTeleportTerritories']:
            if link['LandTeleportID'] != teleport['ID']:
                continue
            if link['TerritoryID'] == 0:
                raise ValueError('sentinel is not a landing region')
            territory = territories[link['TerritoryID']]
            if territory['StartX'] > territory['EndX'] or territory['StartY'] > territory['EndY']:
                raise ValueError('inverted landing region')
            destinations.append({'link': link, 'territory': territory, 'land': lands[territory['LandID']]})
        if not destinations:
            raise ValueError('missing landing relation')
        conditions = []
        for link in tables['LandTeleportPrerequisite']:
            if link['LandTeleportID'] == teleport['ID']:
                definition = prerequisites[link['PrerequisiteID']]
                conditions.append({'link': link, 'definition': definition, 'type': types[definition['PrerequisiteTypeID']]})
        entries.append({
            'schedule': row, 'category': categories[row['AutoScheduleCategoryID']],
            'hunting_territory': hunting,
            'hunting_land': lands[hunting['LandID']] if hunting else None,
            'teleport': teleport, 'currency': currencies[teleport['CurrencyID']],
            'destinations': destinations, 'prerequisites': conditions,
        })
    return {'schema': 'twilight-auto-hunting523-v1', 'source_zip_sha256': SOURCE_SHA256,
            'territory_zero_sentinel': sentinel, 'categories': tables['AutoScheduleCategory'],
            'entries': entries}


def build(source: Path, output: Path) -> dict:
    # Verify the complete archive and exact selected table bytes before projection.
    if digest(source.read_bytes()) != SOURCE_SHA256:
        raise ValueError('expected the exact validated cumulative523 ZIP')
    tables = {}
    with zipfile.ZipFile(source) as archive:
        if archive.testzip() is not None:
            raise ValueError('source ZIP CRC mismatch')
        for name, expected in TABLE_SHA256.items():
            member = 'content/' + name + '.json'
            if archive.namelist().count(member) != 1:
                raise ValueError('missing or duplicated source member: ' + member)
            raw = archive.read(member)
            if digest(raw) != expected:
                raise ValueError('source table SHA mismatch: ' + name)
            tables[name] = json.loads(raw.decode('utf-8-sig'))['rows']
    projection = project(tables)
    payload = encode(projection)
    counts = {'menus': len(tables['AutoScheduleLandTeleport']),
              'landings': sum(len(r['destinations']) for r in projection['entries']),
              'unspecified_hunting_regions': sum(r['TerritoryID'] == 0 for r in tables['AutoScheduleLandTeleport'])}
    receipt = {'schema': 1, 'source_zip_sha256': SOURCE_SHA256, 'table_sha256': TABLE_SHA256,
               'file': PACK_NAME, 'bytes': len(payload), 'sha256': digest(payload), 'counts': counts,
               'delivery': 'PRIVATE_LOCAL_ONLY', 'runtime_movement': 'BLOCKED_UNVERIFIED_ARRIVAL_AND_MAP_RULES'}
    output.mkdir(parents=True, exist_ok=True)
    # Refuse to replace an installed pack silently. A repeat of the same build is safe.
    for name, raw in [(PACK_NAME, payload), ('receipt.json', encode(receipt))]:
        target = output / name
        if target.exists() and target.read_bytes() != raw:
            raise ValueError('refusing to overwrite a different pack: ' + str(target))
    for name, raw in [(PACK_NAME, payload), ('receipt.json', encode(receipt))]:
        with tempfile.NamedTemporaryFile(dir=output, delete=False) as stream:
            temp = Path(stream.name)
            stream.write(raw)
        temp.replace(output / name)
    return receipt


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--source-zip', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True, help='private directory outside the Git checkout')
    args = parser.parse_args()
    if args.output.resolve().is_relative_to(Path(__file__).resolve().parents[1]):
        parser.error('resource packs must stay outside the public code checkout')
    print(json.dumps(build(args.source_zip, args.output), ensure_ascii=False, sort_keys=True))
