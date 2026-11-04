"""Verify the four virtual labels/constants without inferring a native predicate."""
from __future__ import annotations
import argparse, hashlib, json, zipfile
from pathlib import Path
from build_inventory_automation523 import SOURCE_SHA, SOURCE_SIZE

SELECTORS = {45011:('일반 장비','AutoSaleItemCommonTradable'),45021:('일반 장비 (각인)','AutoSaleItemCommon'),45031:('고급 장비','AutoSaleItemRareTradable'),45041:('고급 장비 (각인)','AutoSaleItemRare')}
def audit(path: Path) -> dict:
    assert path.stat().st_size == SOURCE_SIZE
    assert hashlib.sha256(path.read_bytes()).hexdigest() == SOURCE_SHA
    with zipfile.ZipFile(path) as z:
        assert z.testzip() is None
        names=('ItemClass','ConstantData','DescData_Korean','MerchantAutoSell')
        raw={n:z.read('content/'+n+'.json') for n in names}
        rows={n:json.loads(data.decode('utf-8-sig'))['rows'] for n,data in raw.items()}
    items={r['ID']:r for r in rows['ItemClass']}
    constants={r['Name']:r['Value'] for r in rows['ConstantData']}
    desc={r['ID']:r['Description'].strip() for r in rows['DescData_Korean']}
    sale={r['ItemClassID'] for r in rows['MerchantAutoSell']}
    found=[]
    for item_id,(label,constant) in SELECTORS.items():
        item=items[item_id]
        assert item['TestItem'] and item['SpriteID']==0 and item['Cost']==0
        assert not any(item[k] for k in ('IsTradable','IsStorable','IsDeletable','IsDroppable'))
        assert desc[item['IdentifiedDescID']]==label
        assert constants[constant]==str(item_id) and item_id in sale
        found.append({'item_class_id':item_id,'label':label,'constant':constant,'virtual':True,'actual_item_grant':False})
    return {'source_bytes':SOURCE_SIZE,'source_sha256':SOURCE_SHA,'zip_crc':'passed','table_sha256':{n:hashlib.sha256(data).hexdigest() for n,data in raw.items()},'selectors':found,'confirmed':'Four labels and ConstantData references, plus native select/cart/confirm help.','not_confirmed':['native equipment slot membership','native enhancement/attribute/identified filters','native NPC buyback eligibility of each equipment ID'],'host_policy':'Explicit configurable grade, one slot, marking view and enhancement ceiling, then exact currently held physical IDs. Existing trade/lock/equipment/quest restrictions are never relaxed.','public_scope_note':'Official2024-09-25 notes mention merchant auto-sale settings, but are not evidence of a complete equipment predicate.','public_url':'https://lineagem.plaync.com/board/update/view?articleId=66f31338a6acf62e167e4e3c'}
if __name__=='__main__':
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('source_zip',type=Path)
    print(json.dumps(audit(p.parse_args().source_zip),ensure_ascii=False,indent=2))
