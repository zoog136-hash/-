"""Read-only audit of the private patch523 ZIP; never copies original rows to Git."""
from __future__ import annotations
import argparse
import hashlib
import json
from pathlib import Path
import zipfile

SOURCE_SHA = 'd5192c3c735ff95c6b181bf2d4d77448d8b562fdb28dbd43f897fa4eae1f4832'
SOURCE_BYTES = 25031173
MEMBERS = {
    'StorageAutoStore': ('8c6c4a1276a782b4f4692fe48fa34c25db5b5d659992b20e2d1804c2151f27ce', 84),
    'MerchantAutoSell': ('9efc9455b8e8cf12dbd88c93902d054520e3da1a6e6a819fd94183c07fe4c76a', 25),
}

def audit(path: Path) -> dict:
    assert path.stat().st_size == SOURCE_BYTES, 'wrong source size'
    assert hashlib.file_digest(path.open('rb'), 'sha256').hexdigest() == SOURCE_SHA, 'wrong source SHA256'
    result = {'source_bytes': SOURCE_BYTES, 'source_sha256': SOURCE_SHA, 'crc': 'all_members_ok', 'tables': {}}
    with zipfile.ZipFile(path) as archive:
        assert archive.testzip() is None, 'corrupt ZIP member'
        items = {row['ID']: row for row in json.loads(archive.read('content/ItemClass.json').decode('utf-8-sig'))['rows']}
        for name, (sha, count) in MEMBERS.items():
            raw = archive.read('content/'+name+'.json')
            assert hashlib.sha256(raw).hexdigest() == sha, 'wrong table SHA256'
            rows = json.loads(raw.decode('utf-8-sig'))['rows']
            assert len(rows) == count
            assert len({row['ID'] for row in rows}) == count
            assert all(row['ItemClassID'] in items for row in rows), 'unresolved item class'
            summary = {'rows': count, 'unique_item_classes': len({row['ItemClassID'] for row in rows}), 'sha256': sha, 'bytes': len(raw), 'missing_item_classes': 0}
            summary['not_player_tradable_rows'] = sum(not items[row['ItemClassID']]['IsTradable'] for row in rows)
            if name == 'StorageAutoStore':
                assert all(items[row['ItemClassID']]['IsStorable'] for row in rows)
                summary['bless_counts'] = {str(code): sum(row['ItemBlessCodeID'] == code for row in rows) for code in sorted({row['ItemBlessCodeID'] for row in rows})}
            result['tables'][name] = summary
        text_rows = json.loads(archive.read('content/UIStaticTextData_Korean.json').decode('utf-8-sig'))['rows']
        texts = {row['TextDesc']: row['Text'] for row in text_rows}
        # Evidence of the actual native sequence, distinct from on-pickup automation.
        for prefix, checks in {
            'STORAGE_POPUP_HELP': [('ND_KEEPAUTO', 'ND_STEP_2', '자동 보관할 아이템을 선택'), ('ND_KEEPAUTO', 'ND_STEP_4', '가지고 있는 모든 수량'), ('ND_KEEPAUTO', 'ND_STEP_5', '모두 맡기기')],
            'STORE_POPUP_HELP': [('ND_SALEAUTO', 'ND_STEP_2', '자동 판매할 아이템을 선택'), ('ND_SALEAUTO', 'ND_STEP_4', '가지고 있는 모든 수량'), ('ND_SALEAUTO', 'ND_STEP_5', '모두 팔기')],
        }.items():
            for section, step, expected in checks:
                assert any(key.startswith(prefix) and section in key and step in key and expected in text for key, text in texts.items()), expected
        result['help_sequence'] = 'explicit_selection_then_cart_then_confirm_all'
        result['native_price_in_auto_sell_table'] = False
        assert all(set(row) == {'ID', 'ItemClassID'} for row in json.loads(archive.read('content/MerchantAutoSell.json').decode('utf-8-sig'))['rows'])
    return result

if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('source_zip', type=Path)
    args = parser.parse_args()
    print(json.dumps(audit(args.source_zip), ensure_ascii=False, indent=2))
