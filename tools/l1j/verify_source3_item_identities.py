#!/usr/bin/env python3
"""Read-only source3 identity preflight. Never runs SQL, callbacks or game code."""
import argparse
import hashlib
import json
import re
from pathlib import Path


class IdentityError(ValueError):
    pass


def require(condition, reason):
    if not condition:
        raise IdentityError(reason)


def digest(data):
    return hashlib.sha256(data).hexdigest()


def record_digest(record):
    return digest(json.dumps(record, ensure_ascii=False, sort_keys=True,
                             separators=(",", ":")).encode())


def identify_display(source, tables, language, field='identified_name_id'):
    raw = source['raw_fields']
    bless = raw.get('bless')
    require(bless in ('0', '1', '2') and
            source['source_variant'].get('bless_raw') == bless, 'inconsistent blessing variant')
    match = re.fullmatch(r'\$(\d+)', raw.get(field, ''))
    require(match is not None, 'unsupported name token; separate review required')
    token = int(match[1])
    table = tables[language]
    require(token + 1 < len(table), 'DESC token missing')
    prefix = {'0': 227, '1': None, '2': 228}[bless]
    return (table[prefix + 1] + ' ' if prefix is not None else '') + table[token + 1]


def validate_identity(binding, source_items, catalog, visuals, tables):
    """Require a unique typed source and game identity; never fall back by name/ID."""
    key = binding['source_item_key']
    require(key == 'source3:tw380:Taiwan:' + binding['source_table'] + ':' + binding['source_item_id'],
            'source namespace/table mismatch')
    matches = [r for r in source_items if r.get('source_item_key') == key]
    require(len(matches) == 1, 'source identity missing or duplicated')
    source = matches[0]
    require(source.get('table') == binding['source_table'] and
            source.get('source_item_id') == binding['source_item_id'], 'source typed ID mismatch')
    require(source.get('eligible_for_identity_mapping') is True and
            source.get('excluded_feature_reasons') == [], 'source feature excluded or not eligible')
    require(source.get('name_source') == binding['source_name'] and
            source.get('source_type') == binding['source_type'], 'source name/subtype mismatch')
    require({'dagger': '단검', 'sword': '한손검', 'bow': '활'}.get(binding['source_type']) ==
            binding['game_type'] and binding['game_slot'] == 'weapon', 'unreviewed source/game type pair')
    require(source.get('source_variant') == binding['source_variant'], 'source variant mismatch')
    require(source['raw_fields'].get('bless') == '1' and
            source['source_variant'].get('bless_raw') == '1', 'only plain templates reviewed')
    for field, expected in binding['source_identity_fields'].items():
        require(source['raw_fields'].get(field) == expected, 'source field mismatch: ' + field)
    require(source['source_row']['provenance'] == binding['source_provenance'], 'source provenance mismatch')
    require(digest(source['source_row']['raw_sql_row'].encode()) ==
            binding['source_provenance']['tuple_sha256'], 'source tuple mismatch')
    name = binding['game_name']
    aliases = [r for r in source_items if any(a.get('name_ko') == name
               for a in r.get('supported_korean_aliases', []))]
    displayed = [r for r in aliases if identify_display(r, tables, 'k') == name]
    require(len(displayed) == 1 and displayed[0]['source_item_key'] == key,
            'actual Korean display missing or ambiguous across source variants')
    for field in ('identified_name_id', 'unidentified_name_id'):
        evidence = source['local_desc_translation_evidence'][field]
        entry = evidence['entries'][binding['translation_token']]
        require(evidence['template'] == '$' + binding['translation_token'] and
                evidence['resolved']['c'] == binding['source_name'] and
                evidence['resolved']['k'] == name and
                entry['c']['state'] == entry['k']['state'] == 'present' and
                entry['c']['value'] == binding['source_name'] and entry['k']['value'] == name,
                'strict C-to-K translation mismatch')
        require(identify_display(source, tables, 'c', field) == binding['source_name'] and
                identify_display(source, tables, 'k', field) == name,
                'original DESC display mismatch')
    games = [r for r in catalog['아이템'] if r.get('source') == binding['game_source'] and
             r.get('sourceId') == binding['game_source_id']]
    require(len(games) == 1, 'game source identity missing or duplicated')
    game = games[0]
    require((game.get('name'), game.get('type'), game.get('slot')) ==
            (name, binding['game_type'], binding['game_slot']), 'game name/type/slot mismatch')
    require(record_digest(game) == binding['game_record_sha256'], 'game record changed; review required')
    reviews = [r for r in visuals['items'] if r.get('game_source_id') == binding['game_source_id'] and
               r.get('game_name') == name and r.get('source_candidate_id') ==
               binding['prior_reviewed_source_candidate_id']]
    require(len(reviews) == 1, 'prior corroborating review missing or duplicated')
    require(Path(reviews[0]['inventory_source_member']).stem == source['raw_fields']['invgfx'] and
            Path(reviews[0]['ground_source_member']).stem == source['raw_fields']['grdgfx'],
            'reviewed icon/ground references differ from source')
    return {'source_item_key': key, 'game_source': binding['game_source'],
            'game_source_id': binding['game_source_id'], 'identity_only': True}


def load_desc_evidence(manifest, desc_input, source_input, source_items):
    """Verify private evidence bytes and parse the Java excerpt; never execute it."""
    from cryptography.hazmat.primitives.ciphers import Cipher, modes
    from cryptography.hazmat.decrepit.ciphers.algorithms import TripleDES
    for relative, expected in manifest['desc_evidence']['file_guards'].items():
        require(digest(guarded_path(desc_input, relative).read_bytes()) == expected,
                'DESC evidence changed; review required: ' + relative)
    code = json.loads((desc_input / 'code_provenance.json').read_text())
    excerpt_bytes = (desc_input / 'S_IdentifyDesc_lines29_47.java.txt').read_bytes()
    require(digest(excerpt_bytes) == code['excerpt_sha256'], 'identify excerpt SHA mismatch')
    excerpt = excerpt_bytes.decode()
    for bless, token in ((0, 227), (2, 228)):
        pattern = r'getBless\(\)\s*==\s*' + str(bless) + r'\)\s*\{\s*name.append\("\$' + str(token) + r' "\)'
        require(re.search(pattern, excerpt) is not None, 'identify prefix source mismatch')
    require('name.append(item.getItem().getIdentifiedNameId())' in excerpt,
            'identify name composition missing')
    evidence = json.loads((desc_input / 'variant_identity_evidence.json').read_text())
    tables = {}
    for table in evidence['table_ranges']:
        raw = (desc_input / table['encrypted_range_path']).read_bytes()
        decoded = (desc_input / table['decoded_original_path']).read_bytes()
        require(len(raw) == table['source_bytes'] and digest(raw) == table['encrypted_range_sha256'] and
                digest(decoded) == table['decoded_original_sha256'], 'DESC table SHA/size mismatch')
        blocks = len(raw) // 8 * 8
        decryptor = Cipher(TripleDES(bytes.fromhex('7e214023255e243c') * 3), modes.ECB()).decryptor()
        require(decryptor.update(raw[:blocks]) + decryptor.finalize() + raw[blocks:] == decoded,
                'DESC ciphertext/plaintext mismatch')
        lines = decoded.decode(table['encoding']).splitlines()
        require(len(lines) == table['actual_splitlines'], 'DESC table length mismatch')
        require(table['lang'] not in tables, 'duplicate DESC language')
        tables[table['lang']] = lines
    require(set(tables) == {'c', 'e', 'k'}, 'three DESC languages required')
    require(len(evidence['items']) == 9, 'nine reviewed SQL variant rows required')
    for row in evidence['items']:
        matches = [r for r in source_items if r['source_item_key'] == row['source_item_key']]
        require(len(matches) == 1, 'variant source ID missing or duplicated')
        source = matches[0]
        require(source['raw_fields'] == row['raw_SQL_fields'] and
                source['source_row']['provenance'] == row['SQL_provenance'] and
                source['source_row']['raw_sql_row'] == row['raw_SQL_tuple'], 'variant SQL projection mismatch')
        provenance = row['SQL_provenance']
        raw = guarded_path(source_input, 'source_snapshots/' + provenance['path']).read_bytes()
        chunk = raw[provenance['byte_offset']:provenance['byte_offset'] + provenance['byte_length']]
        require(digest(chunk) == provenance['tuple_sha256'] and chunk.decode() == row['raw_SQL_tuple'],
                'variant SQL tuple byte range mismatch')
        for language in tables:
            require(identify_display(source, tables, language) ==
                    row['resolved_actual_identify_display_by_language'][language], 'variant display mismatch')
    return tables


def guarded_path(root, relative):
    path = (root / relative).resolve()
    require(path.is_relative_to(root.resolve()), 'guard path outside root')
    require(path.is_file(), 'missing evidence file: ' + relative)
    return path


def verify(root, source_input, desc_input):
    manifest = json.loads((root / 'data/l1j/source3_item_identities.json').read_text())
    require(manifest.get('schema') == 2 and manifest.get('gameplay_enabled') is False,
            'identity-only manifest required')
    for base, guards in ((root, manifest['game_file_guards']),
                         (source_input, manifest['input_file_guards'])):
        for relative, expected in guards.items():
            require(digest(guarded_path(base, relative).read_bytes()) == expected,
                    'file changed; review required: ' + relative)
    items = [json.loads(line) for line in (source_input / 'source_items.jsonl').read_text().splitlines()]
    tables = load_desc_evidence(manifest, desc_input, source_input, items)
    catalog = json.loads((root / 'data/catalog_v19.json').read_text())
    visuals = json.loads((root / 'data/l1j/live_visual_bindings.json').read_text())
    require(len({b['source_item_key'] for b in manifest['bindings']}) == len(manifest['bindings']),
            'duplicate binding')
    result = []
    for binding in manifest['bindings']:
        provenance = binding['source_provenance']
        raw = guarded_path(source_input, 'source_snapshots/' + provenance['path']).read_bytes()
        require(digest(raw) == provenance['file_sha256'], 'source SQL changed')
        chunk = raw[provenance['byte_offset']:provenance['byte_offset'] + provenance['byte_length']]
        require(digest(chunk) == provenance['tuple_sha256'], 'SQL tuple byte range changed')
        result.append(validate_identity(binding, items, catalog, visuals, tables))
    return {'identity_bindings_verified': result, 'gameplay_enabled': False,
            'drops_enabled': 0, 'recipes_enabled': 0, 'npc_actions_enabled': 0}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--root', type=Path, default=Path(__file__).resolve().parents[2])
    parser.add_argument('--source-input', required=True, type=Path)
    parser.add_argument('--desc-input', required=True, type=Path)
    args = parser.parse_args()
    try:
        print(json.dumps(verify(args.root, args.source_input, args.desc_input), ensure_ascii=False))
    except (IdentityError, KeyError, TypeError, OSError, ValueError, ImportError) as exc:
        parser.exit(1, 'SOURCE3_IDENTITY_HOLD: ' + str(exc) + '\n')


if __name__ == '__main__':
    main()
