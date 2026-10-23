#!/usr/bin/env python3
"""Durably retain one draft; do not promote generation to actor approval."""
import argparse
import hashlib
import json
from pathlib import Path
from PIL import Image

HERE=Path(__file__).resolve().parent
ROOT=HERE.parents[4]

def main():
    p=argparse.ArgumentParser()
    p.add_argument('slug')
    p.add_argument('clip')
    p.add_argument('image',type=Path)
    a=p.parse_args()
    assert a.slug.replace('_','').isalnum() and a.clip.replace('-','').replace('_','').isalnum()
    raw=HERE/a.slug/'raw'/f'{a.clip}.png'
    data=a.image.read_bytes()
    raw.parent.mkdir(parents=True,exist_ok=True)
    if raw.exists():assert raw.read_bytes()==data,'Never replace an existing draft'
    else:
        temporary=raw.with_suffix('.png.tmp')
        temporary.write_bytes(data)
        temporary.replace(raw)
    with Image.open(raw) as im:
        assert im.format=='PNG' and im.mode=='RGBA'
        assert min(im.size)>0
        alpha=im.getchannel('A')
        assert alpha.getextrema()[1]>0
        record=dict(source=raw.relative_to(ROOT).as_posix(),source_imagegen_path=str(a.image),sha256=hashlib.sha256(data).hexdigest(),bytes=len(data),dimensions=list(im.size),RGBA=True,transparent_pixels=alpha.histogram()[0],status='DRAFT_SOURCE_SAVED',full_review='DEFERRED_UNTIL_ALL_DRAFTS',new_approval=False)
    receipt=HERE/a.slug/f'{a.clip}-receipt.json'
    temporary=receipt.with_suffix('.json.tmp')
    temporary.write_text(json.dumps(record,ensure_ascii=False,indent=2)+'\n')
    temporary.replace(receipt)
    print(json.dumps(dict(slug=a.slug,clip=a.clip,status=record['status'],bytes=len(data))))

if __name__=='__main__':main()
