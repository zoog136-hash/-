"""Read-only MySQL dump extraction. SQL is never executed; skill tables are excluded."""
from __future__ import annotations
import argparse, collections, hashlib, json, pathlib, re, zipfile

TABLES = {'weapon','armor','etcitem','npc','droplist','shop','spawnlist','spawnlist_npc',
          'mapids','npcaction','npcaction_teleport','teleport','spr_action',
          'craft_info','craft_npcs','craft_block','hunting_quest','hunting_quest_teleport',
          'beginner_quest','beginner_quest_drop','beginner_teleport','beginner_addteleport','magicdoll_info'}

def values(text):
    result, index = [], 0
    while index < len(text):
        while index < len(text) and text[index] in ' ,\t\r\n': index += 1
        if index >= len(text): break
        quoted = text[index] == "'"
        token = []
        if quoted:
            index += 1
            while index < len(text):
                ch=text[index]; index += 1
                if ch == '\\':
                    if index >= len(text): raise ValueError('truncated escape')
                    ch=text[index]; index += 1
                    token.append({'n':'\n','r':'\r','t':'\t','0':'\0','b':'\b','Z':'\x1a'}.get(ch,ch))
                elif ch == "'":
                    if index < len(text) and text[index] == "'":
                        token.append("'");index += 1
                    else: break
                else: token.append(ch)
            else: raise ValueError('unterminated quoted SQL value')
        else:
            while index < len(text) and text[index] != ',':
                token.append(text[index]);index += 1
        value=''.join(token).strip() if not quoted else ''.join(token)
        if not quoted and value.upper() == 'NULL': value=None
        elif value is not None and re.fullmatch(r'-?\d+',value): value=int(value)
        elif value is not None and re.fullmatch(r'-?\d+\.\d+',value): value=float(value)
        elif value in ('true','false'): value=value == 'true'
        result.append(value)
    return result

def tables(text, requested=TABLES):
    schemas, records = {}, collections.defaultdict(list)
    current=None
    for line in text.splitlines():
        match=re.match(r'CREATE TABLE `([^`]+)`',line)
        if match:
            current=match[1] if match[1] in requested else None
            if current: schemas[current]=[]
            continue
        if current:
            column=re.match(r'\s+`([^`]+)` ',line)
            if column: schemas[current].append(column[1])
            if line.startswith(')'): current=None
        match=re.match(r'INSERT INTO `([^`]+)` VALUES \((.*)\);$',line)
        inserted_table=re.match(r'INSERT INTO `([^`]+)`',line)
        if inserted_table and inserted_table[1] in requested and not match:
            raise ValueError('Unsupported INSERT syntax in requested table: '+inserted_table[1])
        if match and match[1] in requested:
            table=match[1]
            row=values(match[2])
            if len(row) != len(schemas.get(table,[])):
                raise ValueError(f'{table} row width mismatch: {len(row)} vs {len(schemas.get(table,[]))}')
            records[table].append(dict(zip(schemas[table],row)))
    return dict(records), schemas

def extract(source,output):
    with zipfile.ZipFile(source) as z: raw=z.read('db/l1remaster.sql')
    decoded=raw.decode('utf-8-sig')
    result, schemas=tables(decoded)
    output.mkdir(parents=True,exist_ok=True)
    for table, rows in result.items():
        (output/(table+'.json')).write_text(json.dumps(rows,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    report={'source':'a3.zip!db/l1remaster.sql','sha256':hashlib.sha256(raw).hexdigest(),
            'counts':{k:len(v) for k,v in result.items()},'schemas':schemas,'errors':[]}
    (output/'extraction.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    print(json.dumps(report['counts']))

if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--source',type=pathlib.Path,required=True)
    parser.add_argument('--output',type=pathlib.Path,required=True)
    a=parser.parse_args();extract(a.source,a.output)
