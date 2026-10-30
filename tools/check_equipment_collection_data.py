#!/usr/bin/env python3
"""Data/source-ID capability audit, independent of Godot runtime validation."""
from pathlib import Path
import argparse,collections,json,re,hashlib,sys
ROOT=Path(__file__).resolve().parents[1]
def normal(n):
    return re.sub(r'\s+',' ',re.sub(r'\(\s*각인\s*\)|\[\s*각인\s*\]|（\s*각인\s*）|(?<!\S)각인(?!\S)','',n)).strip()
def audit(root):
    d=json.loads((root/'data/collections/equipment_collections.json').read_text())
    source=json.loads((root/'data/catalog_v19.json').read_text())['아이템']
    # These are the actual base world's equipment source slots, not materials.
    slots={'weapon','offhand','helmet','tshirt','body','pants','cloak','shoulder','gaiters','boots','gloves','ring','earring','belt','necklace','bracelet','badge','crystal','catalyst','rune','seal'}
    equipment=[v for v in source if v.get('sourceId') and v.get('slot') in slots]
    names={normal(v['name']) for v in equipment}
    codes=set(re.findall(r'"([a-z_]+:(?:flat|percent))"',(root/'scripts/collections/equipment_collection_stats.gd').read_text().split('static func record')[0]))
    definitions=d['collections'];ids={v['id'] for v in definitions}
    assert len(definitions)==447 and len(ids)==447
    assert sum(len(v['requirements']) for v in definitions)==1659
    assert sum(bool(v['data_ready']) for v in definitions)==390
    assert len(d['item_names'])==432
    assert all(not c.startswith('pvp_') for c in codes)
    reasons=collections.Counter(); rows=[]
    for c in definitions:
        assert c['name']==normal(c['name'])
        seen=set()
        for q in c['requirements']:
            assert q['kind']=='equipment' and q['name']==normal(q['name'])
            assert q['slot_id'] not in seen;seen.add(q['slot_id'])
            assert isinstance(q['quantity'],int) and q['quantity']>0
            if c['data_ready']: assert isinstance(q['enchant'],int) and q['enchant']>=0
        missing=sorted({q['name'] for q in c['requirements'] if q['name'] not in names})
        unsupported=sorted({e['key']+':'+e['unit'] for e in c['effects']}-codes)
        code='review' if not c['data_ready'] else 'unbound_item' if missing else 'unsupported_effect' if unsupported else 'available'
        reasons[code]+=1
        rows.append({'id':c['id'],'name':c['name'],'status':code,'missing_items':missing,'unsupported_effects':unsupported,'review_reasons':c['review_reasons']})
    # Detect serializer drift, rather than silently dropping a future save field.
    world=(root/'scripts/world.gd').read_text();runtime=(root/'scripts/collections/equipment_collection_runtime.gd').read_text()
    save=re.search(r'(?ms)^func _save_game\(.*?(?=^func )',world).group()
    keys=set(re.findall(r'^\t\t"([^"\n]+)":',save,re.M))|{'native_png_plan_sha256','native_png_review_sha256'}
    known=set(json.loads(re.search(r'^const KNOWN_SAVE_KEYS: Array = (.+)$',runtime,re.M).group(1)))
    assert keys==known,{'missing_known_keys':list(keys-known),'stale_keys':list(known-keys)}
    assert '_save_game(true,override)' in runtime
    assert runtime.index('var error: Error = world._save_game(true,override)') < runtime.index('world.inventory = next_inventory')
    assert 'data.merge(collection_override, true)' in save
    assert 'equipment_collections.write_save(save_path(), data)' in save
    assert 'equipment_collections.accept_load(data)' in world
    assert 'equipment_collections.next_safe_id()' in world
    assert 'equipment_collections.configure(self)' in world
    assert 'equipment_collections.stat_record()' in world
    hud=(root/'scripts/ui/renewal_hud.gd').read_text()
    assert '"equipment_collections": open_equipment_collections()' in hud
    assert '["equipment_collections","장비 컬렉션"]' in hud
    # PR183 makes the equipment-collection route available from every catalog
    # category, including compact card views. Enforce its real control binding,
    # its visible label, and its always-enabled state instead of the old
    # item-only rule, which would invalidate the improved touch navigation.
    assert 'equipment_collection_button = UI.button("장비 컬렉션",open_equipment_collections' in hud
    assert 'equipment_collection_button.disabled = false' in hud
    assert 'equipment_collection_button.text = "장비 컬렉션"' in hud
    assert 'equipment_collection_button.disabled = category != "아이템"' not in hud
    report={'scope':'STATIC_DATA_AND_BINDING_ONLY_NOT_GODOT_EXECUTION','collection_count':447,'data_ready':390,'slots':1659,'item_names':432,'exact_bound_names':len({x['name'] for x in d['item_names']}&names),'binding_status':dict(reasons),'unmatched_names':sorted({x['name'] for x in d['item_names']}-names),'supported_effect_codes':sorted(codes),'save_keys_checked':len(keys),'rows':rows,'data_sha256':hashlib.sha256((root/'data/collections/equipment_collections.json').read_bytes()).hexdigest()}
    return report
if __name__=='__main__':
    ap=argparse.ArgumentParser();ap.add_argument('--root',type=Path,default=ROOT);ap.add_argument('--report',type=Path);args=ap.parse_args()
    report=audit(args.root)
    if args.report: args.report.parent.mkdir(parents=True,exist_ok=True);args.report.write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n')
    print('EQUIPMENT_COLLECTION_DATA_OK '+json.dumps({k:v for k,v in report.items() if k not in ['rows','unmatched_names','supported_effect_codes']},ensure_ascii=False))
