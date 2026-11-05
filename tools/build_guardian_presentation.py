#!/usr/bin/env python3
"""Project exact UI551 card property tracks onto existing TWILIGHT art, without copying art."""
import argparse,gzip,hashlib,json
from pathlib import Path

def build(source):
    raw=Path(source).read_bytes();trees=json.loads(gzip.decompress(raw))
    definitions=[('open','UI/SkillTree/SkillTree_Card_Enchant_Default.csb','Fx_Start',1875673952),('success','UI/SkillTree/SkillTree_Card_Enchant_Result.csb','Fx_Success_Start',1382326551),('failure','UI/SkillTree/SkillTree_Card_Enchant_Result.csb','Fx_Fail_Start',1831005125)]
    result={'schema':1,'authority':'UI551 property timelines, existing TWILIGHT card art; no original atlas/audio claim','source_library_file':'libfile_0ba507ea27888191b60532f6aa6b6ff0','decoded_trees_sha256':hashlib.sha256(raw).hexdigest(),'fps':60,'fps_evidence':'https://github.com/cocos2d/cocos2d-x/blob/v3/cocos/editor-support/cocostudio/ActionTimeline/CCActionTimeline.cpp','clips':{}}
    for name,member,clip,tag in definitions:
        tree=trees[member];definition=next(x for x in tree['animation_list'] if x['name']==clip)
        result['clips'][name]={'member':member,'action_tag':tag,'source_clip':definition,'speed':tree['action']['speed'],'tracks':[x for x in tree['timelines'] if x['action_tag']==tag and x['property'] in ('Scale','Alpha')]}
    return json.dumps(result,ensure_ascii=False,indent=2)+'\n'
if __name__=='__main__':
    parser=argparse.ArgumentParser();parser.add_argument('--source',required=True);parser.add_argument('--check',action='store_true');args=parser.parse_args()
    target=Path(__file__).resolve().parents[1]/'data/growth/guardian_presentation.json';text=build(args.source)
    if args.check:assert target.read_text()==text,'presentation drift'
    else:target.write_text(text)
