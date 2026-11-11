#!/usr/bin/env python3
"""Link original 523 town NPCs (EarthObjectClass) to their DialogData_Korean rows.

The 523 client tables carry no column that joins an EarthObjectClass to a
DialogData row (the live server chose the paragraph). This tool writes only
row identities (class ID -> DialogData ID + Name), never text: the game reads
the text from the installed original archive and checks each Name again.

Join, in order:
  1. a DialogData "NPC_<KEY>_DIALOG_NPC" row names the NPC: its "_PA1.._PAn"
     rows are the pages;
  2. a DialogData name row "NPC_[ADEN_|OREN_]<KEY>" / "NPCNAME_<KEY>" whose text
     is the NPC's name (the part after "^" of its DescData name): the text row
     "DIALOG_<KEY>", "<TOWN>_<KEY>", "TALKING_<KEY>", "NPCTALK_<KEY>",
     "NPC_<KEY>_DIALOG" or a long "NPC_<KEY>" row;
  3. REVIEWED: original rows whose romanized key is spelled differently from
     the name row, or that have no name row (checked against the archive).
Usage: build_source523_npc_dialog_links.py <tables source.zip> <output.json>
"""
import hashlib
import json
import re
import sys
import zipfile
from collections import defaultdict

SOURCE_SHA256 = "d5192c3c735ff95c6b181bf2d4d77448d8b562fdb28dbd43f897fa4eae1f4832"
NAME_RE = re.compile(r'^(?:NPC|NPCNAME)_(?:ADEN_|OREN_)?([A-Z0-9]+)$')
PAGES_RE = re.compile(r'^(NPC_[A-Z0-9_]+_DIALOG)_NPC$')
TEXT_PATTERNS = ('DIALOG_%s', 'GLUDIN_%s', 'SILVER_%s', 'ELF_%s', 'GIRAN_%s', 'CHOBO_%s',
                 'TALKING_%s', 'NPCTALK_%s', 'NPC_%s_DIALOG', 'NPC_%s')
# NPC name (after "^" in DescData) -> original DialogData row Name.
REVIEWED = {
    '꽃다발 상인^샤론': 'GLUDIN_SHARON',
    '마법사^이베카': 'GLUDIN_EBECA',
    '마법연구원^나비': 'GLUDIN_NAVI',
    '장로 마법사^세이룬': 'GLUDIN_SEIROON',
    '마법수련생^그레그': 'GLUDIN_GREG',
    '장교^마리': 'GLUDIN_MARY',
    '붉은 기사단^글로우': 'GLUDIN_GLOW',
    '백조의 기사^이실로테': 'GLUDIN_ECILOTE',
    '경비병^조': 'GLUDIN_JOE',
    '철의 기사^아툰': 'DIALOG_ATUN',
    '엘프전사^루멘': 'DIALOG_RUMEN',
    '용 사냥꾼^드루가 베일': 'DIALOG_VAIL',
    '장난꾸러기^제이프': 'DIALOG_JAPE',
    '미치광이^라반': 'DIALOG_LABAN',
    '달의 기사^질리언': 'DIALOG_ZILIAN',
    '동물 애호가^휴즈': 'DIALOG_HUSE',
    '수호자^페어리 프린세스': 'ELF_FAIRY',
}


def bare(text):
    return re.sub(r'^\[[^\]]*\]\s*', '', text).strip()


def main(source, output):
    digest = hashlib.sha256(open(source, 'rb').read()).hexdigest()
    if digest != SOURCE_SHA256:
        raise SystemExit('unexpected tables archive ' + digest)
    archive = zipfile.ZipFile(source)

    def rows(table):
        return json.loads(archive.read('content/%s.json' % table).decode('utf-8-sig'))['rows']

    dialog = rows('DialogData_Korean')
    by_name = {row['Name']: row for row in dialog}
    desc = {row['ID']: row['Description'] for row in rows('DescData_Korean')}
    keys = defaultdict(set)
    for row in dialog:
        match = NAME_RE.match(row['Name'])
        if match and '\n' not in row['Description'] and len(row['Description']) < 40:
            keys[bare(row['Description'])].add((match.group(1), row['Name']))
    page_sets = defaultdict(list)
    for row in dialog:
        match = PAGES_RE.match(row['Name'])
        if match:
            page_sets[bare(row['Description'])].append(match.group(1))

    def pages_for(full_name):
        name = full_name.split('^')[-1].strip()
        if full_name in REVIEWED:
            row = by_name[REVIEWED[full_name]]
            return [row], 'reviewed_romanized_key'
        for prefix in sorted(page_sets.get(name, [])):
            pages, index = [], 1
            while '%s_PA%d' % (prefix, index) in by_name:
                pages.append(by_name['%s_PA%d' % (prefix, index)]); index += 1
            if pages:
                return pages, 'dialog_npc_row:' + prefix + '_NPC'
        for key, name_row in sorted(keys.get(name, [])):
            for pattern in TEXT_PATTERNS:
                candidate = pattern % key
                row = by_name.get(candidate)
                if row is None or candidate == name_row or NAME_RE.match(candidate) and len(row['Description']) < 12:
                    continue
                return [row], 'name_row:' + name_row
        return [], ''

    links = []
    for cls in sorted(rows('EarthObjectClass'), key=lambda row: row['ID']):
        full_name = desc.get(cls['DescID'], '')
        if not full_name:
            continue
        pages, basis = pages_for(full_name)
        if pages:
            links.append({'earth_object_class_id': cls['ID'], 'basis': basis,
                          'pages': [{'id': row['ID'], 'name': row['Name']} for row in pages]})
    payload = {'schema': 'twilight.source523.npc-dialog-links.v1', 'source_zip_sha256': SOURCE_SHA256,
               'table': 'DialogData_Korean', 'text_in_file': False, 'links': links}
    with open(output, 'w', encoding='utf-8') as handle:
        json.dump(payload, handle, ensure_ascii=False, indent=1)
        handle.write('\n')
    print('links', len(links))


if __name__ == '__main__':
    main(sys.argv[1], sys.argv[2])
