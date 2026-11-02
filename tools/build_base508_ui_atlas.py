#!/usr/bin/env python3
"""Build metadata only from exact original CSB -> plist -> PNG references."""
import argparse, hashlib, json, plistlib, re, zipfile
from pathlib import Path


def numbers(value):
    return [int(v) for v in re.findall(r'-?\d+', value)]


def main():
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('--root',type=Path,required=True)
    p.add_argument('--layout',type=Path,action='append',required=True)
    p.add_argument('--output',type=Path,required=True)
    p.add_argument('--tables',type=Path,required=True)
    a=p.parse_args(); layout={"screens":{}};refs={}
    for source in a.layout:
        for key,nodes in json.loads(source.read_text())["screens"].items():
            if key in layout["screens"] and layout["screens"][key]!=nodes:raise ValueError("Conflicting CSB inspection "+key)
            layout["screens"][key]=nodes
    for nodes in layout['screens'].values():
        for node in nodes:
            for ref in node['resources']:
                if ref['plistFile']:refs.setdefault('UI/'+ref['plistFile'],set()).add(ref['path'])
    out={'schema':1,'source':'lineagem_base508','atlases':{},'missing':[],'grade_bindings':{},'unbound_grades':{}}
    families={'GradeCommon':'Common','GradeRare':'Rare','GradeUnique':'Unique',
              'GradeLegend':'Legend','GradeEpic':'Epic','Grade6':'Myth','Grade7':'Sole'}
    with zipfile.ZipFile(a.tables) as tables:
        grade_raw=tables.read('content/Grade.json');color_raw=tables.read('content/ColorTable.json')
        grades=json.loads(grade_raw.decode('utf-8-sig'))['rows']
        colors={row['ID']:row for row in json.loads(color_raw.decode('utf-8-sig'))['rows']}
        out['table_evidence']={'Grade':hashlib.sha256(grade_raw).hexdigest(),
                               'ColorTable':hashlib.sha256(color_raw).hexdigest()}
        for grade in grades:
            color=colors.get(grade['ColorID'],{});family=families.get(color.get('Name'))
            if family is None:
                out['unbound_grades'][str(grade['ID'])]={'grade':grade,'color':color,'status':'source_grade_prefab_undeclared'}
                continue
            prefab='UI/Change/Change_Card_A_'+family+'.csb'
            if prefab not in layout['screens']:raise ValueError('Missing declared grade prefab '+prefab)
            out['grade_bindings'][str(grade['ID'])]={'grade':grade,'color':color,
                'prefab':prefab,'sprite_node':'Sp_Card_'+family,
                'binding':'Explicit grade family presentation binding; no integer-to-asset inference'}
    for name,keys in sorted(refs.items()):
        path=a.root/name
        if not path.is_file():out['missing'].append(name);continue
        raw=path.read_bytes(); data=plistlib.loads(raw); meta=data['metadata']
        if meta.get('format')!=2:raise ValueError('Unsupported plist format: '+name)
        page=Path(name).parent/meta['textureFileName']
        if '..' in page.parts or page.is_absolute():raise ValueError('Unsafe texture reference')
        pixels=a.root/page
        if not pixels.is_file():out['missing'].append(str(page));continue
        frames={}
        for key in sorted(keys):
            if key not in data['frames']:raise ValueError('Missing exact frame '+name+':'+key)
            f=data['frames'][key]
            frames[key]={'rect':numbers(f['frame']),'rotated':f['rotated'],
                         'source_rect':numbers(f['sourceColorRect']),
                         'source_size':numbers(f['sourceSize'])}
        out['atlases'][name]={'page':str(page),'page_sha256':hashlib.sha256(pixels.read_bytes()).hexdigest(),
                             'plist_sha256':hashlib.sha256(raw).hexdigest(),'frames':frames}
    a.output.write_text(json.dumps(out,ensure_ascii=False,indent=2)+'\n')
    print('Verified',len(out['atlases']),'atlas pages;',sum(len(v['frames']) for v in out['atlases'].values()),'exact frame keys')

if __name__=='__main__':main()
