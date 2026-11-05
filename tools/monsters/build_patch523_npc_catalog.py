"""Compile private, verified 523 NPC spell graphs; no source rows in Git."""
from __future__ import annotations
import argparse, hashlib, json, zipfile, zlib
from pathlib import Path

SOURCE_SHA = 'd5192c3c735ff95c6b181bf2d4d77448d8b562fdb28dbd43f897fa4eae1f4832'
BOSS_REPORT = 'BOSS_SKILL_DEEP_EVIDENCE.json'
NPC_REPORT = 'MAP_NPCBUFF_STAGE_EVIDENCE.json'
# Stage scheduling belongs to its separate feature. Keep only NPC environment evidence.
ENV_TABLES = {'Land','LandAttribute','LandAttributeType','Territories','BuffClass','BuffBonus','Bonus','BonusType','BonusApplicationType','Unit','InvokeOption','InvokeOptionType','AttackType'}

def sha(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()

def report(path: Path, member: str) -> dict:
    with zipfile.ZipFile(path) as archive:
        return json.loads(archive.read(member))

def compile_catalog(source: Path, boss_report: Path, npc_report: Path | None, host_npc_ids: tuple[int, ...] = ()) -> dict:
    if sha(source.read_bytes()) != SOURCE_SHA:
        raise ValueError('source ZIP SHA mismatch; expected the supplied validated523 archive')
    reports = [(report(boss_report,BOSS_REPORT),None)]
    if npc_report:
        reports.append((report(npc_report,NPC_REPORT),ENV_TABLES))
    tables, provenance, boss_ids = {}, {}, []
    with zipfile.ZipFile(source) as archive:
        if archive.testzip() is not None: raise ValueError('source ZIP CRC failed')
        for evidence, allowed in reports:
            for name, selected in evidence['source_rows'].items():
                if allowed is not None and name not in allowed: continue
                entry = evidence['source_table_provenance'][name]
                raw = archive.read(entry['path'])
                actual = entry['actual']
                if sha(raw) != actual['sha256'] or len(raw) != actual['bytes'] or format(zlib.crc32(raw)&0xffffffff, '08x') != actual['crc32']:
                    raise ValueError(f'{name}: report provenance mismatch')
                rows = json.loads(raw.decode('utf-8-sig'))['rows']
                if len(rows) != actual['row_count']: raise ValueError(f'{name}: row count mismatch')
                provenance[name] = {'path':entry['path'],**actual}
                target = tables.setdefault(name,{})
                for selected_row in selected:
                    position = selected_row['source_row_1based']
                    row = selected_row['row']
                    if position < 1 or position > len(rows) or rows[position-1] != row:
                        raise ValueError(f'{name}: row {position} differs from source')
                    key = str(row['ID']) if 'ID' in row else '@'+str(position)
                    old = target.get(key)
                    if old is not None and old != selected_row: raise ValueError(f'{name}: duplicate identity differs')
                    target[key] = selected_row
                    if allowed is None and name == 'NpcClass': boss_ids.append(row['ID'])
        report_boss_ids = sorted(boss_ids)
        report_attack_ids = sorted(int(key) for key in tables.get('NpcAttack',{}))
        report_spell_ids = sorted(int(key) for key in tables.get('SpellClass',{}))
        cache = {}
        def source_rows(name):
            if name not in cache:
                member = 'content/'+name+'.json'
                raw = archive.read(member)
                cache[name] = json.loads(raw.decode('utf-8-sig'))['rows']
                provenance[name] = {'path':member,'sha256':sha(raw),'bytes':len(raw),'crc32':format(zlib.crc32(raw)&0xffffffff,'08x'),'row_count':len(cache[name])}
            return cache[name]
        def include(name, predicate):
            found = []
            for i,row in enumerate(source_rows(name)):
                if not predicate(row): continue
                key = str(row['ID']) if 'ID' in row else '@'+str(i+1)
                tables.setdefault(name,{})[key] = {'source_row_1based':i+1,'row':row}
                found.append(row)
            return found
        def by_id(name, value):
            found = include(name,lambda row:row.get('ID')==value)
            if len(found)!=1: raise ValueError(f'{name} ID {value}: missing/ambiguous typed host dependency')
            return found[0]
        queue = []
        seen = set()
        for npc_id in host_npc_ids:
            by_id('NpcClass',npc_id)
            if npc_id not in boss_ids: boss_ids.append(npc_id)
            for attack in include('NpcAttack',lambda row:row['NpcClassID']==npc_id):
                if attack['IsSpell'] and attack['SpellID']: queue.append(('Spell',attack['SpellID']))
            include('NpcAttribute',lambda row:row['NpcClassID']==npc_id)
            include('NpcSpecialResistance',lambda row:row['NpcClassID']==npc_id)
        while queue:
            kind, identity = queue.pop()
            if (kind,identity) in seen: continue
            seen.add((kind,identity))
            table = {'Spell':'SpellClass','Buff':'BuffClass','Invoke':'InvokeOption'}[kind]
            record = by_id(table,identity)
            if kind=='Invoke':
                next_id = record.get('SuccessedInvokeOptionID',0)
                if next_id: queue.append(('Invoke',next_id))
                continue
            if kind=='Spell':
                for name,field in [('SpellCategory','SpellCategoryID'),('TargettingType','TargettingTypeID'),('TargetKind','TargetKindID')]:
                    if record.get(field): by_id(name,record[field])
            else:
                if record.get('BuffGroupID'): by_id('BuffGroup',record['BuffGroupID'])
            link_table = 'SpellBonus' if kind=='Spell' else 'BuffBonus'
            owner_field = 'SpellClassID' if kind=='Spell' else 'BuffClassID'
            for link in include(link_table,lambda row:row[owner_field]==identity):
                bonus = by_id('Bonus',link['BonusID'])
                bonus_type = by_id('BonusType',bonus['BonusTypeID'])
                unit = by_id('Unit',bonus_type['UnitID'])
                app = bonus.get('BonusApplicationTypeID',0)
                by_id('BonusApplicationType',app)
                target = {'SpellClassID':'Spell','BuffClassID':'Buff'}.get(unit['Name'])
                if target and bonus['Value']: queue.append((target,bonus['Value']))
                if bonus_type['Name']=='InvokeOption' and bonus.get('BonusApplicationTargetID'):
                    queue.append(('Invoke',bonus['BonusApplicationTargetID']))
                if bonus_type['Name']=='StatusEffectID':
                    include('StatusEffectAttr',lambda row:row['StatusEffectID']==bonus['Value'])
        # Small official enums and environmental group rules missing from the
        # scoped reports are read directly from the SHA-pinned full source.
        for name in ['BuffGroup', 'ElementalType']:
            member = 'content/'+name+'.json'
            if member not in archive.namelist(): continue
            raw = archive.read(member)
            rows = json.loads(raw.decode('utf-8-sig'))['rows']
            provenance[name] = {'path':member,'sha256':sha(raw),'bytes':len(raw),'crc32':format(zlib.crc32(raw)&0xffffffff,'08x'),'row_count':len(rows)}
            tables[name] = {str(row['ID']):{'source_row_1based':i+1,'row':row} for i,row in enumerate(rows)}
    return {'kind':'patch523_npc_spell_catalog','schema':1,'source_snapshot':'patch523',
            'source_archive_sha256':SOURCE_SHA,'boss_npc_ids':sorted(boss_ids),
            'report_boss_npc_ids':report_boss_ids,'report_attack_ids':report_attack_ids,'report_spell_ids':report_spell_ids,'host_extension_npc_ids':sorted(host_npc_ids),
            'provenance':provenance,'tables':tables,
            'execution_contract':'source typed graph; host attack clock/selection/hit/formula; unresolved semantics stay pending',
            'limits':['no summon-set members','no TargetClass geometry','no native AI clock/probability','no final reflection formula','no original sprite payload']}

def write_pack(catalog: dict, destination: Path) -> dict:
    destination.mkdir(parents=True,exist_ok=True)
    raw=json.dumps(catalog,ensure_ascii=False,sort_keys=True,separators=(',',':')).encode()
    (destination/'npc_spells.json').write_bytes(raw)
    manifest={'kind':'patch523_npc_spell_pack','schema':1,'source_snapshot':'patch523',
              'source_archive_sha256':SOURCE_SHA,'catalog_file':'npc_spells.json',
              'catalog_sha256':sha(raw),'catalog_bytes':len(raw),
              'table_counts':{name:len(rows) for name,rows in catalog['tables'].items()}}
    (destination/'manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
    return manifest

def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--source-zip',type=Path,required=True)
    parser.add_argument('--boss-report',type=Path,required=True)
    parser.add_argument('--npc-report',type=Path)
    parser.add_argument('--output',type=Path,required=True)
    parser.add_argument('--host-npc-id',type=int,action='append',default=[],help='Exact existing host binding identity; never a name join')
    args=parser.parse_args()
    result=write_pack(compile_catalog(args.source_zip,args.boss_report,args.npc_report,tuple(args.host_npc_id)),args.output)
    print(json.dumps(result,ensure_ascii=False,indent=2))
    print('manifest_sha256='+sha((args.output/'manifest.json').read_bytes()))
if __name__=='__main__': main()
