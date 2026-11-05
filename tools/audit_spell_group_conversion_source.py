"""Read-only full-source/report audit. Outputs contain no raw source rows."""
import argparse
from collections import Counter, defaultdict
import hashlib
import json
from pathlib import Path
import zipfile
import zlib


def main():
    p=argparse.ArgumentParser()
    p.add_argument('--source',type=Path,required=True)
    p.add_argument('--report',type=Path,required=True)
    p.add_argument('--output',type=Path,required=True)
    a=p.parse_args()
    assert hashlib.sha256(a.source.read_bytes()).hexdigest()=='d5192c3c735ff95c6b181bf2d4d77448d8b562fdb28dbd43f897fa4eae1f4832'
    references=defaultdict(list)
    def walk(value):
        if isinstance(value,dict):
            if {'table','row_index_zero','raw'}<=value.keys():references[value['table']].append((value['row_index_zero'],value['raw']))
            for child in value.values():walk(child)
        elif isinstance(value,list):
            for child in value:walk(child)
    with zipfile.ZipFile(a.report) as report:
        assert report.testzip() is None
        prefix='TWILIGHT_latest523_spell_group_conversion/'
        manifest=json.loads(report.read(prefix+'source_manifest.json'))
        for name in report.namelist():
            if name.endswith('.json') and not name.endswith(('ARTIFACT_MANIFEST.json','evidence_verification.json')):walk(json.loads(report.read(name)))
    verified_tables=0;verified_rows=0;source_rows=0;selected={}
    with zipfile.ZipFile(a.source) as source:
        assert source.testzip() is None
        assert len([n for n in source.namelist() if n.startswith('content/') and n.endswith('.json')])==1065
        for item in manifest['tables']:
            raw=source.read('content/'+item['table']+'.json')
            assert len(raw)==item['bytes'] and hashlib.sha256(raw).hexdigest()==item['sha256']
            assert f'{zlib.crc32(raw)&0xffffffff:08x}'==item['crc32']
            rows=json.loads(raw.decode('utf-8-sig'))['rows'];assert len(rows)==item['rows']
            source_rows+=len(rows);verified_tables+=1
            for index,expected in references[item['table']]:
                assert 0<=index<len(rows) and rows[index]==expected,(item['table'],index)
                verified_rows+=1
            if item['table'] in ['GameClassSpellGroup','GameClassSpellGroupCostView','SpellClass','GameClassSpellGroupChangeSpell']:selected[item['table']]=rows
    settings=selected['GameClassSpellGroup'];costs=selected['GameClassSpellGroupCostView']
    assert len(settings)==16 and len(costs)==1200
    settings_groups={r['SpellGroupID'] for r in settings}
    members=[r for r in selected['SpellClass'] if r['SpellGroupID'] in settings_groups]
    assert len(members)==193
    keys={(r['SpellGroupID'],r['ChangeCount'],r['ItemClassID']) for r in costs};assert len(keys)==1200
    per_group=Counter(r['SpellGroupID'] for r in costs)
    assert len(per_group)==8 and set(per_group.values())=={150}
    for group in per_group:
        assert {r['ChangeCount'] for r in costs if r['SpellGroupID']==group}==set(range(1,51))
        for count in range(1,51):assert {r['ItemClassID'] for r in costs if r['SpellGroupID']==group and r['ChangeCount']==count}=={26,1122,32801}
    checks={r['CheckLearnSpellClassID'] for r in settings if r['CheckSpellLearned']}
    assert checks<={r['ID'] for r in selected['SpellClass']}
    for row in selected['GameClassSpellGroupChangeSpell']:
        assert row['GameClassSpellGroupID'] in {r['ID'] for r in settings}
        for key in ['SpellClassID','ChangedSpellClassID','LinkedSpellClassID']:assert row[key] in {r['ID'] for r in selected['SpellClass']}
    result=dict(source_tables=1065,related_tables_verified=verified_tables,related_source_rows_read=source_rows,report_raw_references_verified=verified_rows,
        settings=len(settings),cost_rows=len(costs),cost_groups=len(per_group),group_members=len(members),mastery_required=sum(r['IsRequireSpellGroupMastery'] for r in members),
        replacement_rows=len(selected['GameClassSpellGroupChangeSpell']),status='SOURCE_AUDIT_PASS_NOT_EXECUTION_APPROVAL')
    a.output.write_text(json.dumps(result,indent=2));print(json.dumps(result))


if __name__=='__main__':main()
