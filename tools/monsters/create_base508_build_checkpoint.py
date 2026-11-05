"""Create an immutable cumulative delta relative to the preserved source671 pack."""
import argparse,hashlib,json,os,shutil,zipfile
from pathlib import Path

def sha(path):
 h=hashlib.sha256()
 with path.open('rb')as f:
  for b in iter(lambda:f.read(4*1024**2),b''):h.update(b)
 return h.hexdigest()
def run(a):
 b=json.loads((a.baseline/'manifest.json').read_text());m=json.loads((a.current/'manifest.json').read_text());assert all(m['records'][k]==v for k,v in b['records'].items());assert all(m['models'][k]==v for k,v in b['models'].items());root=a.output;root.mkdir(parents=True,exist_ok=False);(root/'delta').mkdir();(root/'tools').mkdir()
 delta={**m,'records':{k:v for k,v in m['records'].items()if k not in b['records']},'models':{k:v for k,v in m['models'].items()if k not in b['models']},'source_files':{}};used=set();paths=set()
 for ref in delta['models'].values():
  relative=ref['tracks_ref'];paths.add(relative);model=json.loads((a.current/relative).read_text())
  for track in model['tracks'].values():
   for frames in track['directions']:
    for frame in frames:used.update(layer['path']for layer in frame['layers'])
 delta['source_files']={k:v for k,v in m['source_files'].items()if v['path']in used};inherited={v['path']:v['sha256']for v in b['source_files'].values()}
 for file in delta['source_files'].values():
  if inherited.get(file['path'])!=file['sha256']:paths.add(file['path'])
 for relative in sorted(paths):
  target=root/'delta'/relative;target.parent.mkdir(parents=True,exist_ok=True);os.link(a.current/relative,target)
 delta['counts']={'npc_records':len(delta['records']),'unique_sprite_models':len(delta['models']),'original_sp2_files_used':len(delta['source_files']),'native_geographic_spawns':0};(root/'delta/manifest.json').write_text(json.dumps(delta,ensure_ascii=False,separators=(',',':'))+'\n')
 for name in('restore_base508_source_delta.py','merge_base508_source_packs.py','package_base508_monster_install.py'):shutil.copy2(Path(__file__).with_name(name),root/'tools'/name)
 recipe={'schema':1,'source_snapshot':'base508','base_manifest_sha256':sha(a.baseline/'manifest.json'),'base_install_zip_bytes':1339066288,'base_install_zip_sha256':'88b3f4470664571f1f6b2894602fa7a6895cc0443a9ac2f5c914f206ba2b876e','release_id':a.release,'expected_npc_classes':len(m['records']),'expected_source_models':len(m['models']),'baseline_npc_classes':len(b['records']),'additional_npc_classes':len(delta['records']),'additional_source_models':len(delta['models']),'inherited_pixel_files':len(used-set(paths)),'native_geographic_spawns':0,'contract':'Cumulative build delta. Restore against the preserved671 baseline; earlier small deltas are not additionally required. Old671/34/4 records and models are preserved.'};(root/'RESTORE.json').write_text(json.dumps(recipe,indent=2)+'\n')
 (root/'README.txt').write_text('누적 빌드 증분입니다. 기존671 설치ZIP에서 전체 최신 설치ZIP을 자동 생성하며 이전 작은 증분을 별도로 적용할 필요가 없습니다.\npython tools/restore_base508_source_delta.py --base-install-zip <기존671설치ZIP> --work <새작업폴더> --output <최신설치ZIP>\n검증된 평탄한671팩 폴더가 있으면 --base-root를 사용할 수 있습니다.\n이 증분 ZIP 자체를 게임에 직접 설치하지 마세요. 원본 픽셀 공개 업로드 금지. 원본 지리 배치는0입니다.\n',encoding='utf-8');print(json.dumps(recipe))
if __name__=='__main__':
 p=argparse.ArgumentParser(description=__doc__)
 for n in('baseline','current','output'):p.add_argument('--'+n,type=Path,required=True)
 p.add_argument('--release',required=True);run(p.parse_args())
