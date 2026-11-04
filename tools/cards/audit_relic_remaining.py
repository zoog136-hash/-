#!/usr/bin/env python3
"""Trace remaining exact IDs without distributing native rule tables."""
import argparse
import hashlib
import json
from pathlib import Path
import zipfile

SOURCE_SHA = 'd5192c3c735ff95c6b181bf2d4d77448d8b562fdb28dbd43f897fa4eae1f4832'
ROOTS = [48471, 70271, 95152, 35443, 69601, 95662, 33162, 69711]
OFFICIAL = [
 'https://lineagem.plaync.com/guidebook/view?title=광전사+마법',
 'https://lineagem.plaync.com/guidebook/view?title=뇌신+마법',
 'https://lineagem.plaync.com/guidebook/view?title=마검사+마법',
 'https://lineagem.plaync.com/guidebook/view?title=투사+마법',
 'https://lineagem.plaync.com/board/update/view?articleId=619d433980a0270dff23432e']

def audit(source):
    assert hashlib.sha256(source.read_bytes()).hexdigest() == SOURCE_SHA
    with zipfile.ZipFile(source) as archive:
        assert archive.testzip() is None
        names = set(archive.namelist())
        def table(name):
            return json.loads(archive.read('content/' + name + '.json').decode('utf-8-sig'))['rows']
        bonuses = {r['ID']:r for r in table('Bonus')}
        types = {r['ID']:r['Name'] for r in table('BonusType')}
        spell_links = table('SpellBonus')
        buffs = table('BuffBonus')
        options = {r['ID']:r for r in table('InvokeOption')}
        option_types = {r['ID']:r['Name'] for r in table('InvokeOptionType')}
        report = []
        for root in ROOTS:
            links = [r for r in spell_links if r['SpellClassID'] == root]
            children = {bonuses[r['BonusID']]['Value'] for r in links if types[bonuses[r['BonusID']]['BonusTypeID']] == 'SpellClassID'}
            direct_buffs = {bonuses[r['BonusID']]['Value'] for r in links if types[bonuses[r['BonusID']]['BonusTypeID']] == 'BuffClassID'}
            row = {'root_spell_id':root, 'root_link_ids':[r['ID'] for r in links], 'direct_children':sorted(children), 'direct_buffs':sorted(direct_buffs)}
            row['level1_buff_links'] = [r['ID'] for r in buffs if r['BuffClassID'] in direct_buffs and r['MinSpellLevel'] == 1]
            invoked = {bonuses[r['BonusID']]['BonusApplicationTargetID'] for r in buffs if r['BuffClassID'] in direct_buffs and types[bonuses[r['BonusID']]['BonusTypeID']] == 'InvokeOption'}
            row['local_resolution'] = 'exact native invoke delta + validated attack scope; host payload policy' if root in [48471,70271,95152] else 'verified child maxHP recovery delta' if root == 35443 else 'configured recovery estimate; native definition remains absent' if root in [69601,95662] else 'native PvP delta + explicitly local training consumer'
            row['invokes'] = [{'option_id':oid, 'type':option_types[options[oid]['InvokeOptionTypeID']], 'weapon_member_ids':[r['WeaponTypeID'] for r in table('WeaponTypeForWeaponGroup') if r['WeaponGroupID'] == options[oid]['WeaponGroupID']], 'native_attack_on_miss':options[oid]['Param5'], 'by_spell_attack':options[oid]['BySpellAttack']} for oid in sorted(invoked) if oid in [5811,10861,17002]]
            row['child_level1_links'] = [{'child_spell_id':r['SpellClassID'], 'link_id':r['ID'], 'bonus_id':r['BonusID'], 'type':types[bonuses[r['BonusID']]['BonusTypeID']]} for r in spell_links if r['SpellClassID'] in children and r['MinSpellLevel'] == 1]
            if root in [69601,95662]:
                child = 69631 if root == 69601 else 95692
                restoration = [r for r in spell_links if r['SpellClassID'] == child and r['MinSpellLevel'] <= 1 and types[bonuses[r['BonusID']]['BonusTypeID']] == 'RestorationID']
                row.update(blocker='Restoration definition absent', child_spell_id=child, restoration_ids=sorted({bonuses[r['BonusID']]['Value'] for r in restoration}), missing_fields=['recovery basis','amount/expression','unit','threshold inputs'], required_api='typed Restoration resolver before existing heal/cap API')
            if root in [33162,69711]:
                row.update(blocker='No opponent-player damage consumer', required_api='opponent player identity + player-versus-player incoming damage; current consumer requires TwilightMonster')
            report.append(row)
    return {'source_sha256':SOURCE_SHA, 'content_tables':sum(n.startswith('content/') and n.endswith('.json') for n in names), 'restoration_table_present':'content/Restoration.json' in names, 'weapon_membership_table_present':'content/WeaponTypeForWeaponGroup.json' in names, 'official_sources':OFFICIAL, 'skills':report}

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--source', required=True, type=Path)
    args = parser.parse_args()
    print(json.dumps(audit(args.source), ensure_ascii=False, indent=2))

if __name__ == '__main__':
    main()
