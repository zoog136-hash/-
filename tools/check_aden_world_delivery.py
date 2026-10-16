#!/usr/bin/env python3
"""Verify real tracked regional art/data, independently of Godot fallback success."""
import argparse,hashlib,json,subprocess
from pathlib import Path

def verify(root,manifest):
 rows=json.loads(manifest.read_text())['files']
 tracked=set(subprocess.check_output(['git','ls-files','-z'],cwd=root).decode().split('\0'))
 failures=[];total=0
 for row in rows:
  relative=row['path'];path=root/relative
  if relative not in tracked:failures.append('NOT_TRACKED '+relative)
  if not path.is_file():failures.append('MISSING '+relative);continue
  blob=path.read_bytes();total+=len(blob)
  if len(blob)!=row['bytes'] or hashlib.sha256(blob).hexdigest()!=row['sha256']:failures.append('SHA_OR_SIZE '+relative)
 report={'status':'FAIL' if failures else 'PASS','files':len(rows),'bytes':total,'failures':failures,
  'original_third_party_art_integrated':False}
 print('ADEN_DELIVERY_RESULT '+json.dumps(report));return bool(failures)
if __name__=='__main__':
 p=argparse.ArgumentParser();p.add_argument('--root',type=Path,default=Path(__file__).resolve().parents[1]);p.add_argument('--manifest',type=Path);a=p.parse_args();raise SystemExit(verify(a.root,a.manifest or a.root/'docs/aden-world-expansion-20261016/ASSET_MANIFEST.json'))
