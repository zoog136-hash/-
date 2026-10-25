from pathlib import Path
import json,hashlib
B=Path('/workspace/scratch/girtas-ne-final-source-cycle-independent-fresh-20261020')
BASECHECKS=['identity_equipment','compass8','anatomy_continuity','motion_specificity','loops_transitions','runtime_scale_footing']
ALLCHECKS=BASECHECKS+['attack_contact','hit_recovery','death_irreversibility']
def sha(p): return hashlib.sha256(Path(p).read_bytes()).hexdigest()
def jsha(o): return hashlib.sha256(json.dumps(o,sort_keys=True,separators=(',',':')).encode()).hexdigest()
def write(p,d):
    content=(json.dumps(d,ensure_ascii=False,indent=2)+'\n').encode();p=Path(p)
    if p.exists(): assert p.read_bytes()==content, 'Existing frozen quality file differs; preserve it'
    else:
        with p.open('xb') as f:f.write(content)
def snapshot_ledger():
    p=B/'private-image-ledger.json';d=json.loads(p.read_text());out=B/f'private-image-ledger-through-fresh-view{len(d["entries"]):02}.json'
    if out.exists(): assert out.read_bytes()==p.read_bytes()
    else:
        with out.open('xb') as f:f.write(p.read_bytes())
    return {'path':str(out),'sha256':sha(out),'viewed_encoded_bytes':d['viewed_encoded_bytes']}
