"""Retain immutable original bytes without duplicating them per asset on disk."""
import errno,hashlib,os,shutil
from pathlib import Path

def retain_original(source,target):
 source,target=Path(source),Path(target);target.parent.mkdir(parents=True,exist_ok=True)
 if target.exists():
  if hashlib.sha256(source.read_bytes()).digest()!=hashlib.sha256(target.read_bytes()).digest():raise ValueError('Conflicting retained original; never overwrite: '+str(target))
  return
 try:os.link(source,target)
 except OSError as error:
  if error.errno!=errno.EXDEV:raise
  shutil.copyfile(source,target)
