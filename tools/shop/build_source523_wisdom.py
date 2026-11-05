#!/usr/bin/env python3
"""Verify plain wisdom buff: no source territory/class/target restrictions skipped."""
import argparse
import hashlib
import json
from pathlib import Path
import zipfile
from build_source523_restoration import SOURCE


def build(archive):
    if hashlib.sha256(archive.read_bytes()).hexdigest()!=SOURCE:raise ValueError("source identity mismatch")
    with zipfile.ZipFile(archive) as pack:
        if pack.testzip() is not None:raise ValueError("source CRC failure")
        def rows(name):return json.loads(pack.read("content/"+name+".json"))["rows"]
        bonuses={r["ID"]:r for r in rows("Bonus")};types={r["ID"]:r["Name"] for r in rows("BonusType")}
        item=next(r for r in rows("ItemClass") if r["ID"]==376)
        labels={r["ID"]:r["Description"] for r in rows("DescData_Korean")}
        values={};buff_values={}
        for table,field,selected,output in [("ItemBonus","ItemClassID",376,values),("BuffBonus","BuffClassID",39,buff_values)]:
            for r in rows(table):
                if r[field]!=selected:continue
                b=bonuses[r["BonusID"]];kind=types[b["BonusTypeID"]]
                if kind in output or b["BonusApplicationTypeID"] or b["BonusApplicationTargetID"] or r.get("IsPossession",False) or any(r.get(k,0) for k in ["CharacterLevel","CharacterClass","MinSpellLevel"]):raise ValueError("new conditional/duplicate wisdom effect")
                output[kind]=b["Value"]
        if set(values)!={"BuffClassID","BuffDuration","ItemConsumeDelay","ItemConsumeEffectSpriteID"} or set(buff_values)!={"SpellPower","RegenMP"} or values["BuffClassID"]!=39 or item["TestItem"] or item["GradeID"]!=1:raise ValueError("unsupported new item effect")
        buff=next(r for r in rows("BuffClass") if r["ID"]==39)
        erase=["IsEraseOnAttack","IsEraseOnAttacked","IsEraseOnMove","IsEraseOnSpellCastAndShieldIt","IsEraseOnSkillCastAndShieldIt","IsEraseOnItemUse","IsEraseOnSpellAttacked","IsEraseOnSkillAttacked","IsEraseOnCast","IsEraseOnHealed","IsAbsoluteTimeBuff"]
        if any(buff[k] for k in erase) or buff["IsImmuneToDead"] or not buff["IsEraseOnTimeEnd"]:raise ValueError("new unsupported buff lifecycle")
        return {"schema":"twilight.source523.wisdom.v1","item_id":376,"name":labels[item["DescID"]],"buff_id":39,"group":buff["BuffGroupID"],"duration":values["BuffDuration"],"sp":buff_values["SpellPower"],"mp_regen":buff_values["RegenMP"],"source_consume_delay_raw":values["ItemConsumeDelay"],"host_cooldown_seconds":0.5,"host_regen_interval":30.0,"origin":"원본 SP+2·MP회복+2·300초 · TWILIGHT 기존 30초 회복 틱/0.5초 사용 대기"}


def main():
    p=argparse.ArgumentParser(description=__doc__);p.add_argument("archive",type=Path);p.add_argument("output",type=Path);a=p.parse_args()
    if a.output.resolve()==a.archive.resolve():raise ValueError("preserve source archive")
    a.output.write_text(json.dumps(build(a.archive),ensure_ascii=False,indent=2)+"\n");print("PLAIN_WISDOM_VERIFIED")


if __name__=="__main__":main()
