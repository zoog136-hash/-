"""Generate CI-only visual fixtures; never redistribute third-party bitmap resources."""
import argparse, hashlib, json, pathlib, sys
sys.path.insert(0,str(pathlib.Path(__file__).resolve().parents[1]))
from l1j_ci_make_fixture import png_bytes

def main():
    parser=argparse.ArgumentParser();parser.add_argument('--root',type=pathlib.Path,default=pathlib.Path('.'));a=parser.parse_args()
    root=a.root.resolve();path=root/'data/l1j/live_visual_bindings.json';manifest=json.loads(path.read_text())
    for section, fields in [('items',[('inventory_texture','inventory_sha256'),('ground_texture','ground_sha256')]),('monsters',[('texture','sha256')])]:
        for record in manifest[section]:
            for key,digest in fields:
                destination=root/record[key].removeprefix('res://')
                if destination.exists(): raise ValueError('refusing to overwrite original art '+str(destination))
                destination.parent.mkdir(parents=True,exist_ok=True)
                blob=png_bytes((180,120,30,255));destination.write_bytes(blob);record[digest]=hashlib.sha256(blob).hexdigest()
                raw=root/'data/l1j/verified_bytes'/(record[digest]+'.l1jpng')
                raw.parent.mkdir(parents=True,exist_ok=True);raw.write_bytes(blob)
    manifest['synthetic_fixture_only']=True
    path.write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n')
    print('Synthetic live-binding fixture: 5 items, 4 monsters, no original art')
if __name__=='__main__':main()
