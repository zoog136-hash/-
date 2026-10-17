#!/usr/bin/env python3
"""Plan identity-compatible open 2D outfits; apply only converted resources.

Recipes are conversion inputs, not a second delivery ledger. Unmatched bodies,
weapons and costumes retain their existing game visuals.
"""
import argparse
import json
import re
import subprocess
from collections import Counter
from pathlib import Path

GRADES = {"영웅", "전설", "신화", "유일"}
CORE = "mods/fantasycore/animations/"
CAMPAIGN = "mods/empyrean_campaign/animations/"
FEMALE_NAMES = {"벨라", "베리스", "가드리아", "백조의 로엔그린", "마리엘라", "얼음여왕",
    "저주받은 시녀", "저주받은 공작부인", "저주받은 남작부인", "키엘", "다이애나", "리타",
    "키아라", "레니아", "세라", "로즈마리", "케플리샤", "가문의 수호자 필리아", "리즈",
    "발키리 에이르", "암흑기사단 릴리", "판도라", "가시공주 아이비", "아스테어", "이실로테",
    "블루디카", "케레니스"}
WEAPON_GAPS = ("총", "창", "랜스", "랜서", "클로", "이도류", "체인소드", "사이드")
COSTUME_GAPS = ("낚시", "서커스", "토끼", "메이드", "벚꽃")
PALETTES = {"블루":"b4caff", "레드":"ffc1af", "골드":"ffdf9d", "금빛":"ffdf9d",
    "퍼플":"dabaff", "그린":"bdebb5", "화염":"ffc29b", "불타는":"ffc29b", "칠흑":"a8a8b5"}

def read(p): return json.loads(Path(p).read_text())
def save(p, value):
    Path(p).parent.mkdir(parents=True, exist_ok=True)
    Path(p).write_text(json.dumps(value, ensure_ascii=False, indent=2)+"\n")

def save_profiles(path, value):
    # Preserve this existing catalog's one-record-per-line format for review.
    prefix=json.dumps({k:v for k,v in value.items() if k!="profiles"},ensure_ascii=False,separators=(",",":"))[:-1]
    rows=[json.dumps(k,ensure_ascii=False)+":"+json.dumps(v,ensure_ascii=False,separators=(",",":")) for k,v in value["profiles"].items()]
    Path(path).write_text(prefix+',"profiles":{\n'+',\n'.join(rows)+'\n}}\n')

def monsters(root):
    raw=read(root/"data/game_db_v17.json")["몬스터"]
    patches=read(root/"data/monsters/monster_world_catalog.json")
    values={}
    for record in raw:
        value=record.copy();value.update(patches["overlays"].get(record["name"],{}));values[value["name"]]=value
    for record in patches["additions"]:
        if record["name"] in values: continue
        value=values.get(record.get("template","해골 근위병"),{}).copy();value.update(record);values[value["name"]]=value
    return list(values.values())

def plan(root):
    catalog=read(root/"data/catalog_v19.json")["변신"]
    reviewed=read(root/"data/animation_presentation.json")["transforms"]
    manifest=read(root/"data/visuals/runtime_manifest.json")["catalog"]
    loot_source=(root/"scripts/loot_drop.gd").read_text()
    named_bosses=set(re.findall(r'"([^"\n]+)"',loot_source.split("const NAMED_BOSSES",1)[1].split("]",1)[0]))
    result={"schema":1,"source_revision":"af6eee6d339ac98011864bfe89da837fe7769c28", "actors":{},"bindings":{},"unmatched":{}}
    def enemy_actor(name):
        key="expanded/"+name
        mod=CAMPAIGN if name in {"skeleton_knight_boss","skeleton_mage_boss","skeleton_mage_high_boss","hobgoblin","hobgoblin_archer","zombie_dark","antlion_armored","wyvern_air_boss"} else CORE
        roles={"idle":"stance","walk":"run","attack":"swing","hit":"hit","death":"die","cast":"cast"}
        if name=="skeleton_archer" or name=="hobgoblin_archer":roles["attack"]="shoot";roles["ranged_attack"]="shoot"
        if name.startswith("wyvern"):roles["special"]="cast";roles["ranged_attack"]="shoot"
        elif "mage" in name:roles["attack"]="cast";roles["special"]="cast"
        elif name=="skeleton_knight_boss":roles["special"]="cast"
        result["actors"].setdefault(key,{"layers":{"body":mod+"enemies/"+name+".txt"},"roles":roles,"equipment":False})
        return key
    def outfit(sex,armor,head,weapon):
        key="expanded/"+"_".join((sex,armor,head,weapon))
        prefix="avatar/"+sex+"/"
        parts={"plate":("plate_boots","plate_greaves","plate_cuirass","plate_gauntlets"),
            "chain":("chain_boots","chain_greaves","chain_cuirass","chain_gloves"),
            "leather":("leather_boots","leather_pants","leather_chest","leather_gloves"),
            "mage":("mage_boots","mage_skirt","mage_vest","mage_sleeves")}[armor]
        layers=dict(zip(("feet","legs","chest","hands"),(prefix+p for p in parts)))
        layers["head"]=prefix+head;layers["main"]=prefix+weapon
        if weapon=="longsword":layers["off"]=prefix+"shield"
        roles={"idle":"stance","walk":"run","attack":"shoot" if weapon=="longbow" else "swing","hit":"hit","death":"die","cast":"cast"}
        if weapon=="longbow":roles["ranged_attack"]="shoot"
        result["actors"].setdefault(key,{"layers":layers,"roles":roles,"equipment":True})
        return key
    for record in catalog:
        if record["grade"] not in GRADES:continue
        key="transform:"+record["sourceId"];name=record["name"]
        options=" ".join(record.get("sourceOptions",[]));body=reviewed[record["sourceId"]]["body"]
        primary=next((w for text in record.get("sourceOptions",[]) for w in ("한손검","양손검","활","지팡이","총","도끼","창","클로","이도류","체인소드","사이드") if w+" 추가" in text),"")
        weapon_gap="사이드" if "신화-사신" in name else next((s for s in WEAPON_GAPS if s in name or s==primary),None)
        if weapon_gap:
            result["unmatched"][key]={"name":name,"reason":"No compatible published sequential weapon frames: "+weapon_gap};continue
        if any(s in name for s in COSTUME_GAPS):
            result["unmatched"][key]={"name":name,"reason":"Distinctive costume is not supplied by the licensed equipment layers"};continue
        if record["sourceId"] in {"267","242","7","11","16"}:
            result["unmatched"][key]={"name":name,"reason":"Distinctive horned or demonic body is not supplied by human equipment layers"};continue
        if "데스나이트" in name:
            actor=enemy_actor("skeleton_knight_boss");body="armored"
        elif body in {"humanoid","armored","caster","archer"} or "신화-광전사" in name:
            sex="female" if "(여)" in name or name in FEMALE_NAMES else "male"
            style=manifest.get(key,{}).get("motion_style","slash")
            primary_frames={"한손검":"longsword","양손검":"greatsword","활":"longbow","지팡이":"staff","도끼":"battle_axe"}
            weapon=primary_frames.get(primary) or ("longbow" if "활" in name or body=="archer" or style=="bow" else "staff" if body=="caster" else "battle_axe" if "광전사" in name else "greatsword" if "슬레이어" in name else "dagger" if "어쌔신" in name or "암살" in name or "단검" in options else "longsword")
            armor="mage" if weapon=="staff" else "leather" if weapon in {"longbow","dagger"} else "plate" if body=="armored" or "기사" in name or "군주" in name else "chain"
            head={"plate":"plate_helm","chain":"chain_coif","leather":"head_long" if sex=="female" else "head_short","mage":"mage_hood"}[armor]
            actor=outfit(sex,armor,head,weapon)
            body="caster" if weapon=="staff" else "archer" if weapon=="longbow" else "armored" if armor=="plate" else "humanoid"
        else:
            result["unmatched"][key]={"name":name,"reason":"No matching licensed eight-view body: "+body};continue
        tint=next((v for k,v in PALETTES.items() if k in name),"ffffff")
        result["bindings"][key]={"name":name,"actor":actor,"body_kind":body,"pixel_scale":1.05,"color_tint":tint,"identity_basis":"body, gender, equipment and named colour; TWILIGHT adaptation, not original illustration restoration"}
    families={"skeleton":"skeleton","skeleton_archer":"skeleton_archer","lich":"skeleton_mage",
        "zombie":"zombie","zombie_lord":"zombie_dark","goblin":"goblin","orc":"hobgoblin",
        "orc_archer":"hobgoblin_archer","minotaur":"minotaur","ant":"antlion_small","soldier_ant":"antlion_armored",
        "drake":"wyvern","dragon":"wyvern","bandit":"human","bandit_archer":"human_archer",
        "elf_archer":"human_archer","mage":"human_mage","dark_knight":"human_knight","commander":"human_knight"}
    exclusions=("다이어울프","셸로브","레비아탄","플레임 팽","아크모","제로스","호루스","아누비스","오시리스","천사궁수","데스 라이더","나이트메어","심연수인","좀비 나이트","좀비 메이드","창병")
    for record in monsters(root):
        name=record["name"];key="monster:"+name;family=record.get("visual",{}).get("body","")
        boss=bool(record["is_boss"]) if "is_boss" in record else bool(record["boss"]) if "boss" in record else "보스" in record.get("desc","") or name.endswith("의 지배자") or name in named_bosses
        source=families.get(family)
        if source is None or any(s in name for s in exclusions):
            result["unmatched"][key]={"name":name,"reason":"No identity-compatible licensed source for "+family,"boss":boss};continue
        if key=="monster:해골 근위병":continue # retain the already verified resource and its pixel references
        if name=="데스나이트":
            source="skeleton_knight_boss";actor=enemy_actor(source)
        elif source.startswith("human"):
            signature=str(record.get("visual",{}).get("weapon","sword"))
            if signature in {"spear","claw","gun","dual"}:
                result["unmatched"][key]={"name":name,"reason":"Compatible body exists but its signature weapon frames are missing: "+signature,"boss":boss};continue
            weapon="longbow" if source=="human_archer" or signature=="bow" else "staff" if source=="human_mage" or signature=="staff" else "battle_axe" if signature=="axe" else "dagger" if signature=="dagger" else "longsword"
            armor="leather" if source in {"human","human_archer"} else "mage" if source=="human_mage" else "plate"
            sex="female" if "마녀" in name else "male"
            actor=outfit(sex,armor,{"leather":"leather_hood","mage":"mage_hood","plate":"plate_helm"}[armor],weapon)
        else:
            if source.startswith("wyvern"):
                source="wyvern_fire" if "화염" in name or "화룡" in name or "발라카스" in name else "wyvern_water" if "수룡" in name or "파푸리온" in name else "wyvern_air_boss" if boss else "wyvern_air" if "풍룡" in name or "바람" in name else "wyvern"
            if family=="lich" and boss:source="skeleton_mage_high_boss" if "불멸" in name else "skeleton_mage_boss"
            actor=enemy_actor(source)
        accent=str(record.get("visual",{}).get("accent","ffffff"))
        result["bindings"][key]={"name":name,"actor":actor,"boss":boss,"body_kind":"flying" if family in {"drake","dragon"} else "armored" if family in {"dark_knight","commander"} else "caster" if family in {"mage","lich"} else "large" if family in {"minotaur","zombie_lord"} else "humanoid","pixel_scale":1.4 if boss or family in {"drake","dragon","minotaur"} else .85,"color_tint":accent if source.startswith("human") else "ffffff","identity_basis":"existing DB body and weapon; explicitly shared family source, not dedicated per-monster motion"}
    return result

def apply(root, recipes, baseline_ref=None):
    profiles=read(root/"data/combat_animation_profiles.json")
    baseline=json.loads(subprocess.check_output(["git","show",baseline_ref+":data/combat_animation_profiles.json"],cwd=root,text=True))["profiles"] if baseline_ref else None
    # Rejected candidates must recover the pre-expansion visual configuration,
    # including the absence of a profile for locally added database records.
    for key,profile in list(profiles["profiles"].items()):
        if key not in recipes["unmatched"] or not str(profile.get("frames_path","")).startswith("res://assets/actors/eight_direction/expanded/"):continue
        if baseline is None and "prior_visual_profile" not in profile:raise ValueError("Recovery requires --baseline-ref for "+key)
        prior=baseline.get(key) if baseline is not None else profile["prior_visual_profile"]
        if prior is None:del profiles["profiles"][key]
        else:profiles["profiles"][key]=prior
    for key,binding in recipes["bindings"].items():
        folder=root/"assets/actors/eight_direction"/binding["actor"]
        proof=read(folder/"provenance.json")
        profile=profiles["profiles"].get(key,{}).copy()
        if "prior_visual_profile" not in profile:
            profile["prior_visual_profile"]=baseline.get(key) if baseline is not None else (profile.copy() or None)
        profile.update({k:v for k,v in binding.items() if k in {"name","pixel_scale","color_tint","body_kind"}})
        contacts={role:min(int(track.get("source_frames_per_direction",track["unique_frames_per_direction"]))-1,max(1,int(track.get("source_frames_per_direction",track["unique_frames_per_direction"]))//2)) for role,track in proof["tracks"].items() if role in {"attack","cast","ranged_attack","special"}}
        profile.update({"frames_path":"res://"+str(folder.relative_to(root))+"/SpriteFrames.tres","layout":"directional8","sprite_offset":[0,-32*profile["pixel_scale"]],"embedded_shadow":True,"authored_motion_weight":0,"hit_recoil":0,"action_hit_frames":contacts,"attack_hit_frame":contacts["attack"],"death_duration":proof["tracks"]["death"]["source_duration_seconds"],"movement_fps":proof["tracks"]["walk"].get("source_frames_per_direction",proof["tracks"]["walk"]["unique_frames_per_direction"])/proof["tracks"]["walk"]["source_duration_seconds"]})
        profiles["profiles"][key]=profile
    save_profiles(root/"data/combat_animation_profiles.json",profiles)

def main():
    p=argparse.ArgumentParser();p.add_argument("--root",type=Path,default=Path('.'));p.add_argument("--recipes",type=Path,required=True);p.add_argument("--apply",action="store_true");p.add_argument("--baseline-ref",help="Git revision of the pre-expansion visual profiles, used only to recover rejected owned overrides");args=p.parse_args();root=args.root.resolve()
    recipes=read(args.recipes) if args.apply else plan(root)
    if args.apply:apply(root,recipes,args.baseline_ref)
    else:save(args.recipes,recipes)
    print(json.dumps({"outfits":len(recipes["actors"]),"bindings":dict(Counter(k.split(':')[0] for k in recipes["bindings"])),"unmatched":dict(Counter(k.split(':')[0] for k in recipes["unmatched"]))},ensure_ascii=False))

if __name__=="__main__":main()
