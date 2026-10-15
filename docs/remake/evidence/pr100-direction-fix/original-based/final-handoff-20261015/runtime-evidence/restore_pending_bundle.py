#!/usr/bin/env python3
"""Restore archived HOLD evidence into a NEW empty directory, never the game."""
import argparse,hashlib,json,shutil,subprocess,tarfile,tempfile
from pathlib import Path
p=argparse.ArgumentParser(description=__doc__);p.add_argument('destination');a=p.parse_args();pkg=Path(__file__).resolve().parent;manifest=json.loads((pkg/'pending-runtime-manifest.json').read_text());destination=Path(a.destination).absolute()
if destination.is_symlink():raise SystemExit('Refusing a symlink destination')
destination=destination.resolve()
if destination.exists() and (not destination.is_dir() or any(destination.iterdir())):raise SystemExit('Use a new empty evidence directory; production files must not be overwritten')
if not shutil.which('zstd'):raise SystemExit('Install zstd before restoring this lossless container')
destination.parent.mkdir(parents=True,exist_ok=True);destination.mkdir(exist_ok=True);expected={e['path']:e for e in manifest['members']};seen=set();sha=lambda b:hashlib.sha256(b).hexdigest()
with tempfile.TemporaryDirectory(prefix='pr100-join-',dir=destination.parent)as temporary:
 joined=Path(temporary)/'bundle.tar.zst';whole=hashlib.sha256()
 with joined.open('wb')as out:
  for part in manifest['parts']:
   path=(pkg/part['path']).resolve()
   if path.parent!=pkg:raise SystemExit('Unsafe archive part path')
   data=path.read_bytes();assert len(data)==part['bytes'] and sha(data)==part['sha256'],'Part SHA mismatch';out.write(data);whole.update(data)
 assert whole.hexdigest()==manifest['archive_sha256'],'Joined archive SHA mismatch'
 decoder=subprocess.Popen(['zstd','-d','-c',str(joined)],stdout=subprocess.PIPE)
 try:
  with tarfile.open(fileobj=decoder.stdout,mode='r|')as archive:
   for member in archive:
    assert member.isfile() and member.name in expected and member.name not in seen,'Unexpected/repeated archive entry'
    path=(destination/member.name).resolve();assert path.is_relative_to(destination) and path!=destination and not path.exists(),'Unsafe/existing output'
    record=expected[member.name];data=archive.extractfile(member).read();assert len(data)==record['bytes'] and sha(data)==record['sha256'],'Member SHA mismatch'
    path.parent.mkdir(parents=True,exist_ok=True);path.write_bytes(data);seen.add(member.name)
 finally:
  decoder.stdout.close()
  if decoder.poll() is None and seen!=set(expected):decoder.terminate()
  result=decoder.wait()
 assert result==0 and seen==set(expected),'Incomplete restore'
proof={'status':'RESTORED_HOLD_EVIDENCE_ONLY','members':len(seen),'archive_sha256':manifest['archive_sha256'],'destination':str(destination),'production_imported':False,'completed_added':0}
(destination/'RESTORE_PROOF.json').write_text(json.dumps(proof,indent=2)+'\n');print(json.dumps(proof,indent=2))
