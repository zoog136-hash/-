"""Generate byte spans and column kinds, without any original cell values."""
import hashlib
import json
import re
import sys
import zipfile
from pathlib import Path

PIN = "d5192c3c735ff95c6b181bf2d4d77448d8b562fdb28dbd43f897fa4eae1f4832"
TABLES = (
    "ItemClass", "Bonus", "SpellClass", "NpcClass",
    # Large members read together on first admission of a spell-using NPC.
    "NpcAttack", "NpcAttribute", "NpcSpecialResistance",
    "SpellBonus", "BuffClass", "BuffBonus",
)
MAX_ROWS, MAX_BYTES = 512, 1048576

def row_spans(raw):
    rows = json.loads(raw)['rows']
    starts = [m.start() + 4 for m in re.finditer(rb'(?m)^    \{\r?$', raw)]
    ends = [m.start() + 5 for m in re.finditer(rb'(?m)^    \},?\r?$', raw)]
    assert len(starts) == len(ends) == len(rows)
    return rows, starts, ends

def column_kinds(rows):
    keys = list(rows[0])
    # The pinned runtime reads Dictionary.values() in insertion order.
    assert all(list(row) == keys for row in rows)
    kinds = []
    for key in keys:
        types = {type(row[key]) for row in rows}
        if types <= {int, float}:
            kinds.append("TYPE_FLOAT")
        elif types == {str}:
            kinds.append("TYPE_STRING")
        else:
            kinds.append("TYPE_NIL")
    return ", ".join(kinds)

def table_spans(raw):
    rows, starts, ends = row_spans(raw)
    spans = []
    i = 0
    while i < len(rows):
        j = i+1
        while j < len(rows) and j-i < MAX_ROWS and ends[j]-starts[i] <= MAX_BYTES:
            j += 1
        a, b = starts[i], ends[j-1]
        assert b-a <= MAX_BYTES
        assert json.loads(b'[' + raw[a:b] + b']') == rows[i:j]
        spans.extend((a, b, j-i))
        i = j
    return rows, spans

def generate(path):
    assert hashlib.sha256(path.read_bytes()).hexdigest() == PIN
    result = ['extends RefCounted', '## Byte spans and column kinds only. Regenerate from the pinned ZIP with',
              '## tools/build_current523_boot_row_spans.py. [start, end, row count] per batch.',
              '## Includes the four original boot tables and the large first-encounter NPC tables.',
              'const TABLES = {']
    with zipfile.ZipFile(path) as archive:
        for table in TABLES:
            raw = archive.read('content/' + table + '.json')
            rows, spans = table_spans(raw)
            result.append(f'"{table}": {{"sha":"{hashlib.sha256(raw).hexdigest()}", "bytes":{len(raw)}, "rows":{len(rows)},')
            result.append(f'"kinds":[{column_kinds(rows)}], "spans":[')
            for i in range(0, len(spans), 24):
                result.append(','.join(str(n) for n in spans[i:i+24])+',')
            result.append(']},')
        raw = archive.read('content/Territories.json')
        ids = {row['TerritoryId'] for row in json.loads(archive.read('content/ConsumeTerritories.json'))['rows']}
        rows, starts, ends = row_spans(raw)
        result.extend(['}', '',
                       '## Territories rows referenced by ConsumeTerritories, in source order.',
                       '## [start, end] only. IDs and rectangles are read from the installed archive.',
                       f'const CONSUME_TERRITORIES = {{"sha":"{hashlib.sha256(raw).hexdigest()}", "bytes":{len(raw)}, "spans":['])
        spans = []
        seen = set()
        for row, start, end in zip(rows, starts, ends):
            if row['ID'] in ids:
                assert row['ID'] not in seen
                assert json.loads(raw[start:end]) == row
                spans.extend((start, end))
                seen.add(row['ID'])
        assert seen == ids
        for i in range(0, len(spans), 24):
            result.append(','.join(str(n) for n in spans[i:i+24])+',')
    return '\n'.join(result + [']}', ''])

def generate_craft_inputs(path):
    assert hashlib.sha256(path.read_bytes()).hexdigest() == PIN
    with zipfile.ZipFile(path) as archive:
        raw = archive.read('content/ItemCraftInput.json')
    count, spans = table_spans(raw)
    lines = ['extends RefCounted',
             '## Byte spans only. Regenerate with tools/build_current523_boot_row_spans.py <ZIP> --craft-inputs.',
             f'const LAYOUT = {{"sha":"{hashlib.sha256(raw).hexdigest()}", "bytes":{len(raw)}, "rows":{count}, "spans":[']
    lines.extend(','.join(str(n) for n in spans[i:i+24])+',' for i in range(0, len(spans), 24))
    return '\n'.join(lines + [']}', ''])

if __name__ == '__main__':
    generator = generate_craft_inputs if sys.argv[2:] == ['--craft-inputs'] else generate
    print(generator(Path(sys.argv[1])), end='')
