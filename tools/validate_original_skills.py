"""Offline catalogue invariants; errors fail CI. Unknown history does not pass as complete."""
import json
import sys
from collections import Counter
from pathlib import Path

ROOT=Path(__file__).resolve().parents[1]
DATA=ROOT/'data/skills'
def read(name):return json.loads((DATA/name).read_text())
def main():
    master=read('master.json');records=master['records'];balance=read('balance.json');relations=read('relations.json');presets=read('vfx.json');sources=read('sources.json');inventory=read('research_inventory.json')['records']
    problems=[]
    def check(ok,message):
        if not ok:problems.append(message)
    ids={r['id'] for r in records}
    check(len(ids)==len(records),'duplicate runtime ID')
    check(len(master['classes'])==13 and len(set(master['classes']))==13,'13 unique classes')
    classes=Counter(r['class'] for r in records)
    for job in master['classes']:check(classes[job]>0,'missing class '+job)
    known={'VERIFIED','INFERRED','CUSTOM_BALANCE','UNKNOWN','NOT_APPLICABLE'}
    for r in records:
        id=r['id']
        check(r['class'] in master['classes']+['공용'],'bad class '+id)
        check(r['origin']=='LINEAGEM_20250617','legacy in runtime '+id)
        check(r['pve'] not in ['NOT_APPLICABLE','PVP_ONLY'],'PvP-only active '+id)
        check(r['historical_effective']<='2025-06-17','future skill '+id)
        check(r['implementation']!='COMPLETE','unreviewed completeness claim '+id)
        check((ROOT/r['icon'].removeprefix('res://')).exists(),'missing icon '+id)
        for group in r['fields'].values():
            for f in group.values():check(f['status'] in known,'invalid provenance '+id)
        check(id in balance['skills'] and id in relations and id in presets,'missing linked resource '+id)
        for s in r['source_ids']:
            check(s in sources,'missing source '+id)
            check(sources[s]['effective']<='2025-06-17','future source '+id)
            check(sources[s].get('page_modified','')[:10]<='2025-06-17','post-cutoff secondary modification '+id)
        for field in ['requires_skill','inherits_effects']:
            for dep in relations[id].get(field,[]):check(dep in ids,'dangling '+dep)
        parent=relations[id].get('upgrades_from')
        if parent:check(parent in ids,'dangling upgrade '+str(parent))
        check(relations[id]['requires_status']=='UNKNOWN' or r['fields']['learning']['requires_skill']['status']=='VERIFIED','absence must be distinguished from unknown '+id)
    visited=set();active=set()
    def visit(id):
        if id in active:problems.append('cycle '+id);return
        if id in visited:return
        active.add(id)
        deps=relations[id].get('requires_skill',[])+relations[id].get('inherits_effects',[])
        for dep in deps:
            if dep in ids:visit(dep)
        active.remove(id);visited.add(id)
    for id in ids:visit(id)
    check(balance['counter_fallback']=={'일반':.1,'고급':.1,'희귀':.1,'영웅':.15,'전설':.2,'신화':.25,'유일':.3},'counter fallback changed')
    for e in inventory:
        if e.get('implementation')=='PVP_EXCLUDED':check(e.get('runtime_id') not in ids,'excluded runtime skill '+e['id'])
    result={'runtime_effects_connected':len(records),'class_counts':dict(classes),'audit_assignments':len(inventory),'audit_states':dict(Counter(e['implementation'] for e in inventory)),'historical_completeness':master['completeness'],'vfx_reference_validation':'UNKNOWN','errors':problems}
    print(json.dumps(result,ensure_ascii=False,indent=2))
    if '--report' in sys.argv:
        dest=Path(sys.argv[sys.argv.index('--report')+1]);dest.parent.mkdir(parents=True,exist_ok=True);dest.write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n')
    return bool(problems)
if __name__=='__main__':raise SystemExit(main())
