"""Generate offsets only, no original row content, for pinned cold-start inputs."""
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

def generate(path):
    assert hashlib.sha256(path.read_bytes()).hexdigest() == PIN
    result = ['extends RefCounted', '## Byte spans only; no row contents. Regenerate from the pinned ZIP with',
              '## tools/build_current523_boot_row_spans.py. [start, end, row count] per batch.',
              '## Includes the four original boot tables and the large first-encounter NPC tables.',
              'const TABLES = {']
    with zipfile.ZipFile(path) as archive:
        for table in TABLES:
            raw = archive.read('content/' + table + '.json')
            rows = json.loads(raw)['rows']
            starts = [m.start() + 4 for m in re.finditer(rb'(?m)^    \{\r?$', raw)]
            ends = [m.start() + 5 for m in re.finditer(rb'(?m)^    \},?\r?$', raw)]
            assert len(starts) == len(ends) == len(rows)
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
            result.append(f'"{table}": {{"sha":"{hashlib.sha256(raw).hexdigest()}", "bytes":{len(raw)}, "rows":{len(rows)}, "spans":[')
            for i in range(0, len(spans), 24):
                result.append(','.join(str(n) for n in spans[i:i+24])+',')
            result.append(']},')
    return '\n'.join(result + ['}', ''])

if __name__ == '__main__':
    print(generate(Path(sys.argv[1])), end='')
