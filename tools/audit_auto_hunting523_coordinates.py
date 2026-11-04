#!/usr/bin/env python3
"""Read-only cross-check of approved Drive coordinate evidence and AUTO arrivals.

Consumes local, authorized copies only. Performs no network request, changes no
original, and does not certify collision or choose any gameplay landing cell.
"""
import argparse
import json
from pathlib import Path
import zipfile

from build_auto_hunting523 import SOURCE_SHA256, TABLE_SHA256, digest, project

COORDINATE_ZIP_SHA = 'b406f8265b4710d3d75b937f716eab6aece16f3bbfbd5f3e8308d70174530f91'
CORRECTION_ZIP_SHA = '7e957580c404247b8b959306f74bceb96d4731fe3421af35e4ed1dd9de45df15'
PORTAL_TABLE_SHA = 'af434065337cfd2b8c3fab9887ce5d3569ce6651d122a05288769d487df78a45'


def open_checked(path, expected):
    if digest(path.read_bytes()) != expected:
        raise ValueError('Unexpected local input SHA256: ' + path.name)
    archive = zipfile.ZipFile(path)
    if archive.testzip() is not None:
        archive.close()
        raise ValueError('Invalid ZIP CRC: ' + path.name)
    return archive


def read_json(archive, name):
    return json.loads(archive.read(name).decode('utf-8-sig'))


def inclusive_hint(territory, x, y):
    # Diagnostic comparison only. This is deliberately NOT an arrival policy.
    return territory['StartX'] <= x <= territory['EndX'] and territory['StartY'] <= y <= territory['EndY']


def audit(source_path, coordinate_path, correction_path):
    with open_checked(source_path, SOURCE_SHA256) as source, \
            open_checked(coordinate_path, COORDINATE_ZIP_SHA) as coordinate, \
            open_checked(correction_path, CORRECTION_ZIP_SHA) as correction:
        tables = {}
        for name, expected in TABLE_SHA256.items():
            raw = source.read('content/' + name + '.json')
            if digest(raw) != expected:
                raise ValueError('Original table SHA mismatch: ' + name)
            tables[name] = json.loads(raw.decode('utf-8-sig'))['rows']
        for name in ['Land', 'Territories', 'Portal']:
            original = source.read('content/' + name + '.json')
            if coordinate.read('inputs/' + name + '.json') != original:
                raise ValueError('Drive evidence table differs from current523: ' + name)
        if digest(source.read('content/Portal.json')) != PORTAL_TABLE_SHA:
            raise ValueError('Portal table SHA mismatch')
        portals = read_json(coordinate, 'inputs/Portal.json')['rows']
        portal_index = {row['ID']: row for row in portals}
        territories = {row['ID']: row for row in tables['Territories']}
        lands = {row['ID']: row for row in tables['Land']}
        records = read_json(coordinate, 'results/all236_root_pair_eligible_named_records_and_M_declarations.json')
        summary = read_json(coordinate, 'results/SUMMARY.json')
        correction_record = read_json(correction, 'evidence_reclassification.json')
        exact_source_count = 0
        nonmatch_count = 0
        for record in records:
            # Recompute the claim against the separate actual M declarations.
            # Candidate XY remains a tool hypothesis, not an actor/world mapping.
            xy = record['tool_source_xy_candidates']['half']
            matches = []
            for candidate in record['source_target_root_only_join_candidates']:
                portal = candidate['Portal']
                if portal != portal_index[portal['ID']] or candidate['TargetTerritory'] != territories[portal['TargetTerritoryID']]:
                    raise ValueError('Research candidate differs from original M declaration')
                if candidate['SourceLand'] != lands[portal['SourceLandID']] or candidate['TargetLand'] != lands[candidate['TargetTerritory']['LandID']]:
                    raise ValueError('Research candidate has a mismatched Land namespace')
                if [portal['SourceX'], portal['SourceY']] == xy:
                    matches.append(portal['ID'])
            if matches != record['source_coordinate_exact_Portal_matches']['half']:
                raise ValueError('Source-coordinate claim differs from direct declaration comparison')
            exact_source_count += bool(matches)
            nonmatch_count += not matches

        entries = project(tables)['entries']
        landings = [(entry, landing) for entry in entries for landing in entry['destinations']]
        landing_ids = {landing['territory']['ID'] for _, landing in landings}
        typed_links = [row['ID'] for row in portals if row['TargetTerritoryID'] in landing_ids]
        hints = []
        for portal in portals:
            point = territories[portal['TargetTerritoryID']]
            if point['StartX'] != point['EndX'] or point['StartY'] != point['EndY']:
                continue
            for entry, landing in landings:
                area = landing['territory']
                if area['LandID'] != point['LandID'] or not inclusive_hint(area, point['StartX'], point['StartY']):
                    continue
                hints.append({
                    'schedule_id': entry['schedule']['ID'],
                    'landing_link_id': landing['link']['ID'],
                    'landing_territory_id': area['ID'],
                    'land_id': landing['land']['ID'],
                    'asset_path': landing['land']['AssetPath'],
                    'portal_id': portal['ID'],
                    'declared_point_territory_id': point['ID'],
                    'declared_point': [point['StartX'], point['StartY']],
                    'on_end_boundary': point['StartX'] == area['EndX'] or point['StartY'] == area['EndY'],
                    'typed_auto_portal_link': False,
                    'safe_cell_certified': False,
                    'reason': 'GEOMETRIC_HINT_ONLY; ENDPOINT_AND_NAVIGATION_CONTRACT_UNVERIFIED',
                })
        if len(records) != 236 or exact_source_count != 224 or nonmatch_count != 12:
            raise ValueError('Unexpected coordinate evidence counts')
        if len(landings) != 87 or typed_links or len(hints) != 2 or not all(h['on_end_boundary'] for h in hints):
            raise ValueError('Unexpected AUTO arrival join results')
        if summary['M_actual_movement_or_collision_steps_observed'] != 0:
            raise ValueError('New movement evidence requires an independent review')
        return {
            'schema': 1,
            'inputs': {
                'source_zip_sha256': SOURCE_SHA256,
                'coordinate_zip': {'bytes': coordinate_path.stat().st_size, 'sha256': COORDINATE_ZIP_SHA},
                'correction_zip': {'bytes': correction_path.stat().st_size, 'sha256': CORRECTION_ZIP_SHA},
                'original_Portal_table_sha256': PORTAL_TABLE_SHA,
                'all_three_M_input_tables_match_current523_bytes': True,
                'all_three_input_ZIP_CRC': 'PASS',
            },
            'recomputed_source_declaration_comparison': {'eligible': len(records), 'exact': exact_source_count, 'unmatched': nonmatch_count},
            'upstream_reported_M_runtime_collision_steps': summary['M_actual_movement_or_collision_steps_observed'],
            'raw_S32_offset_recheck_this_audit': 'NOT_PERFORMED; ORIGINAL125_S32_FILES_NOT_IN_COORDINATE_PACKAGE',
            'arrival_region_count': len(landings),
            'typed_Portal_target_to_auto_landing_ID_matches': typed_links,
            'geometric_hints_only': hints,
            'pixel_decoder_evidence_qualified_as_M_navigation': False,
            'old_pixel_QA_not_independent_M_format_specification': correction_record['old_pixel_QA_not_independent_M_format_specification'],
            'qualified_arrival_cells': 0,
            'runtime_transitions_activated': 0,
            'scope': 'ACTUAL_DRIVE_INPUT_BYTES_AND_M_DECLARATION_CROSSCHECK; NO_COORDINATE_OR_COLLISION_INFERENCE',
        }


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--source-zip', type=Path, required=True)
    parser.add_argument('--coordinate-zip', type=Path, required=True)
    parser.add_argument('--correction-zip', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    result = json.dumps(audit(args.source_zip, args.coordinate_zip, args.correction_zip), ensure_ascii=False, indent=2) + '\n'
    if args.output.resolve() in {p.resolve() for p in [args.source_zip, args.coordinate_zip, args.correction_zip]}:
        parser.error('output cannot replace an original input')
    if args.output.exists() and args.output.read_text() != result:
        parser.error('refusing to replace different existing audit evidence')
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(result)
    print('AUTO_HUNT523_COORDINATE_AUDIT_PASS:236 candidates/224 exact/12 unmatched;87 regions/0 typed links/2 boundary hints/0 certified arrival cells')
