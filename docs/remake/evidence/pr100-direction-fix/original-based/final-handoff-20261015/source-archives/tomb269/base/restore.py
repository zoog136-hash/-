#!/usr/bin/env python3
from pathlib import Path
import argparse,json,hashlib,zipfile
ap=argparse.ArgumentParser(description="Restore immutable HOLD source WIP from CAS archives; no production import")
ap.add_argument("destination");ap.add_argument("--proof-output");a=ap.parse_args();pkg=Path(__file__).resolve().parent;dst=Path(a.destination).resolve();idx=json.loads((pkg/"index.json").read_text());sha=lambda b:hashlib.sha256(b).hexdigest();manifestbytes=(pkg/idx["manifest"]["path"]).read_bytes()
assert sha(manifestbytes)==idx["manifest"]["sha256"],"manifest SHA mismatch";m=json.loads(manifestbytes);cache={};handles={}
for part in idx["parts"]:
 p=pkg/part["path"];assert p.stat().st_size==part["bytes"] and sha(p.read_bytes())==part["sha256"],"part SHA mismatch: "+str(p);handles[part["path"]]=zipfile.ZipFile(p)
for h,o in m["objects"].items():
 data=handles[o["part"]].read(o["member"]);assert len(data)==o["bytes"] and sha(data)==h,"object SHA mismatch: "+h;cache[h]=data
for f in m["files"]:
 p=(dst/f["path"]).resolve();assert p.is_relative_to(dst) and p!=dst,"unsafe member path";p.parent.mkdir(parents=True,exist_ok=True);data=cache[f["sha256"]]
 if p.exists():assert p.is_file() and sha(p.read_bytes())==f["sha256"],"Refusing to replace different existing file: "+str(p)
 else:p.write_bytes(data)
 assert p.stat().st_size==f["bytes"] and sha(p.read_bytes())==f["sha256"],"restored member SHA mismatch"
sel=[]
for s in m["selected51"]:
 h=sha((dst/s["path"]).read_bytes());assert h==s["sha256"],"selected source mismatch";sel.append(dict(s,restored_sha256=h,status="PASS"))
proof={"format":m["format"],"restored_to":str(dst),"all_member_sha256":"PASS","restored_files":len(m["files"]),"unique_objects":len(m["objects"]),"selected51_exact_sha_restored":sel,"review_flags":"ALL FALSE; source only HOLD","Main":"UNVERIFIED","completed_added":0}
if a.proof_output:Path(a.proof_output).write_text(json.dumps(proof,ensure_ascii=False,indent=2))
print(json.dumps({k:v for k,v in proof.items() if k!="selected51_exact_sha_restored"},indent=2))
