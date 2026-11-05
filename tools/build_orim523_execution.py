#!/usr/bin/env python3
"""Private typed actor/group sidecar; source bytes verified, never published."""
import hashlib,json,sys,zipfile,zlib
from pathlib import Path
from build_dungeon523_pack import SOURCE_SHA256,encoded,require

def build(source):
    require(hashlib.sha256(source.read_bytes()).hexdigest()==SOURCE_SHA256)
    with zipfile.ZipFile(source) as z:
        require(z.testzip() is None)
        index={r['path']:r for r in json.loads(z.read('index.json'))}
        out={'source_sha256':SOURCE_SHA256,'schema':1,'tables':{}}
        for name in ['OrimsTrailNpc','OrimsTrailNpcType','NpcClassForNpcGroup','ItemBonus','Bonus','BonusType','NpcClass','NpcAttack','DescData_Korean','OrimsTrailSpawn']:
            path='content/'+name+'.json';raw=z.read(path);entry=index[path]
            require(len(raw)==entry['bytes'] and hashlib.sha256(raw).hexdigest()==entry['sha256'] and f'{zlib.crc32(raw):08x}'==entry['crc32'])
            out['tables'][name]=json.loads(raw.decode('utf-8-sig'))['rows']
            require(len(out['tables'][name])==entry['row_count'])
        links=[r for r in out['tables']['ItemBonus'] if r['ItemClassID'] in [231162,232352]]
        bonuses={r['BonusID'] for r in links}
        out['tables']['ItemBonus']=links
        out['tables']['Bonus']=[r for r in out['tables']['Bonus'] if r['ID'] in bonuses]
        types={r['BonusTypeID'] for r in out['tables']['Bonus']}
        out['tables']['BonusType']=[r for r in out['tables']['BonusType'] if r['ID'] in types]
        groups={r['NpcGroupID'] for r in out['tables']['OrimsTrailSpawn'] if r['NpcGroupID']}
        actor_ids={r['NpcClassID'] for r in out['tables']['OrimsTrailNpc']}
        actor_ids|={r['NpcClassID'] for r in out['tables']['NpcClassForNpcGroup'] if r['NpcGroupID'] in groups}
        out['tables']['NpcClass']=[r for r in out['tables']['NpcClass'] if r['ID'] in actor_ids]
        out['tables']['NpcAttack']=[r for r in out['tables']['NpcAttack'] if r['NpcClassID'] in actor_ids]
        desc_ids={r['DescId'] for r in out['tables']['NpcClass']}
        out['tables']['DescData_Korean']=[r for r in out['tables']['DescData_Korean'] if r['ID'] in desc_ids]
        del out['tables']['OrimsTrailSpawn'] # consumed only to scope members; base pack retains these rows.
        return encoded(out)

if __name__=='__main__':
    data=build(Path(sys.argv[1]));target=Path(sys.argv[2]);require(not target.exists())
    require(not target.resolve().is_relative_to(Path(__file__).resolve().parents[1]))
    target.write_bytes(data)
    print(json.dumps({'path':str(target),'bytes':len(data),'sha256':hashlib.sha256(data).hexdigest()}))
