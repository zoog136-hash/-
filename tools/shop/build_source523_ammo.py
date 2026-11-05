#!/usr/bin/env python3
"""Compile exact ordinary NPC ammo; host combat adaptations remain explicit."""
import argparse
import hashlib
import json
from pathlib import Path
import zipfile

SOURCE="d5192c3c735ff95c6b181bf2d4d77448d8b562fdb28dbd43f897fa4eae1f4832"
FAMILIES={337:"화살",389:"화살",477:"화살",478:"화살",236381:"화살",369:"스팅",30633:"스팅",75174:"총알",110724:"총알",110734:"총알",179693:"총알"}


def build(archive):
    if hashlib.sha256(archive.read_bytes()).hexdigest()!=SOURCE:raise ValueError("source identity mismatch")
    with zipfile.ZipFile(archive) as pack:
        if pack.testzip() is not None:raise ValueError("source CRC failure")
        def rows(name):return json.loads(pack.read("content/"+name+".json"))["rows"]
        items={r["ID"]:r for r in rows("ItemClass")};labels={r["ID"]:r["Description"] for r in rows("DescData_Korean")}
        bonuses={r["ID"]:r for r in rows("Bonus")};types={r["ID"]:r["Name"] for r in rows("BonusType")}
        values={id:{} for id in FAMILIES}
        for row in rows("ItemBonus"):
            if row["ItemClassID"] not in FAMILIES:continue
            bonus=bonuses[row["BonusID"]];kind=types[bonus["BonusTypeID"]]
            if kind not in ["WeaponSmallDamage","WeaponLargeDamage","AmmoEffectSpriteID","AmmoExplosionSpriteID"] or row["IsPossession"] or bonus["BonusApplicationTypeID"] or bonus["BonusApplicationTargetID"] or kind in values[row["ItemClassID"]]:raise ValueError("new conditional or unsupported ammo effect")
            values[row["ItemClassID"]][kind]=bonus["Value"]
        output={}
        for id,family in FAMILIES.items():
            if items[id]["TestItem"]:raise ValueError("test ammunition")
            output[str(id)]={"name":labels[items[id]["DescID"]],"family":family,"small":values[id]["WeaponSmallDamage"],"large":values[id]["WeaponLargeDamage"],"material":items[id]["MaterialID"]}
    return {"schema":"twilight.source523.ammo.v1","source_sha256":SOURCE,"damage_policy":"uniform_size_die","estimated_undead_bonus":2,"estimated_undead_materials":[14,17,22],"origin":"원본 크기별 탄약 수치 · TWILIGHT 1~최댓값 주사위/별도 합산 · 은/미스릴/오리하루콘 언데드 +2 자체값","items":output}


def main():
    p=argparse.ArgumentParser(description=__doc__);p.add_argument("archive",type=Path);p.add_argument("output",type=Path);a=p.parse_args()
    if a.output.resolve()==a.archive.resolve():raise ValueError("preserve source archive")
    a.output.write_text(json.dumps(build(a.archive),ensure_ascii=False,indent=2)+"\n");print("EXACT_AMMO",len(FAMILIES))


if __name__=="__main__":main()
