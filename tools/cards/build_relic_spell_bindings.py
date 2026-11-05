#!/usr/bin/env python3
"""Reproduce small ID/hash joins; keep native rule values in the authorized ZIP."""
import argparse
import hashlib
import json
from pathlib import Path
import zipfile

SOURCE_SHA = 'd5192c3c735ff95c6b181bf2d4d77448d8b562fdb28dbd43f897fa4eae1f4832'
IDENTITY_FIELDS = ('id', 'name', 'class', 'origin', 'activation')

def canonical(value):
    return json.dumps(value, ensure_ascii=False, sort_keys=True, separators=(',', ':'))

def build(source, bindings, root):
    assert hashlib.sha256(source.read_bytes()).hexdigest() == SOURCE_SHA
    reviewed = json.loads(bindings.read_text())
    assert reviewed['source_zip_sha256'] == SOURCE_SHA
    with zipfile.ZipFile(source) as archive:
        assert archive.testzip() is None
        def table(name):
            return json.loads(archive.read('content/' + name + '.json').decode('utf-8-sig'))['rows']
        spells = {r['ID']:r for r in table('SpellClass')}
        cards = table('BuffCard')
        bonuses = {r['ID']:r for r in table('Bonus')}
        types = {r['ID']:r['Name'] for r in table('BonusType')}
        spell_links = table('SpellBonus')
        level_buffs = {r['BuffClassID'] for r in table('BuffBonus') if r['MinSpellLevel'] == 1}
        assert next(r for r in table('BuffCardDeck') if r['ID'] == 41)['Name'] == 'Spell'
        result = {}
        for host in json.loads((root / 'data/skills/master.json').read_text())['records']:
            if host['id'] not in reviewed['skills']:
                continue
            binding = reviewed['skills'][host['id']]
            spell_id = binding['spell_id']
            assert hashlib.sha256(canonical(spells[spell_id]).encode()).hexdigest() == binding['row_sha256']
            matches = [r for r in cards if r['BuffCardDeckID'] == 41 and r['SpellClassID'] == spell_id]
            assert len(matches) == 1
            identity = {k:host[k] for k in IDENTITY_FIELDS}
            main_buffs = {bonuses[r['BonusID']]['Value'] for r in spell_links
                if r['SpellClassID'] == spell_id and r['MinSpellLevel'] == 0
                and types[bonuses[r['BonusID']]['BonusTypeID']] == 'BuffClassID'
                and bonuses[r['BonusID']]['BonusApplicationTypeID'] == 0
                and bonuses[r['BonusID']]['BonusApplicationTargetID'] == 0}
            result[host['id']] = {**binding, 'spell_card_id':matches[0]['ID'],
                'grade_id':matches[0]['GradeID'], 'has_level_buff':len(main_buffs) == 1 and bool(main_buffs & level_buffs), 'host_identity_sha256':hashlib.sha256(canonical(identity).encode()).hexdigest()}
        assert len(result) == 119
    return {'schema_version':1, 'source_zip_sha256':SOURCE_SHA,
        'reviewed_bindings_commit':'e1c8c9de73b92e91686d9474f162881c4c19bd90',
        'reviewed_bindings_sha256':hashlib.sha256(bindings.read_bytes()).hexdigest(),
        'identity_fields':list(IDENTITY_FIELDS), 'skills':result}

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--source', type=Path, required=True)
    parser.add_argument('--bindings', type=Path, required=True)
    parser.add_argument('--root', type=Path, default=Path('.'))
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    args.output.write_text(json.dumps(build(args.source, args.bindings, args.root), ensure_ascii=False, indent=2) + '\n')

if __name__ == '__main__':
    main()
