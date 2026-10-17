#!/usr/bin/env python3
from pathlib import Path
import argparse,json,hashlib,zipfile
ap=argparse.ArgumentParser(description="Restore final STOP source delta after base CAS; archive integrity only, no production import or QA")
ap.add_argument("destination");ap.add_argument("--proof-output");a=ap.parse_args();pkg=Path(__file__).resolve().parent;dst=Path(a.destination).resolve();H=lambda d:hashlib.sha256(d).hexdigest();idx=json.loads((pkg/"index.json").read_text());mb=(pkg/"contents-manifest.json").read_bytes();assert H(mb)==idx["manifest_sha256"],"manifest SHA mismatch";m=json.loads(mb)
# Preserve base selected source files exactly before restoring new HOLD candidates.
for s in m["base_selected51"]:assert H((dst/s["path"]).read_bytes())==s["sha256"],"Base selected51 mismatch: "+s["path"]
cache={};handles={}
for part in idx["parts"]:
 p=pkg/part["path"];assert p.stat().st_size==part["bytes"] and H(p.read_bytes())==part["sha256"],"part SHA mismatch";handles[part["path"]]=zipfile.ZipFile(p)
for h,v in m["objects"].items():
 data=handles[v["part"]].read(v["member"]);assert len(data)==v["bytes"] and H(data)==h,"member SHA mismatch";cache[h]=data
for f in m["files"]:
 p=(dst/f["path"]).resolve();assert p.is_relative_to(dst) and p!=dst,"unsafe path";p.parent.mkdir(parents=True,exist_ok=True)
 if p.exists():
  old=H(p.read_bytes());assert old==f["sha256"] or (f["prior_sha256"] and old==f["prior_sha256"]),"Refusing unknown existing file: "+str(p)
 if not p.exists() or H(p.read_bytes())!=f["sha256"]:p.write_bytes(cache[f["sha256"]])
 assert p.stat().st_size==f["bytes"] and H(p.read_bytes())==f["sha256"],"restored member SHA mismatch"
selected=[]
for s in m["base_selected51"]:
 h=H((dst/s["path"]).read_bytes());assert h==s["sha256"],"Base original changed";selected.append(dict(s,restored_sha256=h,status="PASS"))
pr={"scope":"Archive restoration byte integrity only; no Godot, geometry, visual QA, gameplay or tests were run after user STOP","delta_members":len(m["files"]),"all_delta_member_sha256":"PASS","base_selected51_exact_sha_preserved":selected,"running_generations":0,"review_flags":"ALL FALSE","Main":"UNVERIFIED","completed_added":0}
if a.proof_output:Path(a.proof_output).write_text(json.dumps(pr,indent=2))
print(json.dumps({k:v for k,v in pr.items() if k!="base_selected51_exact_sha_preserved"},indent=2))
