#!/usr/bin/env python3
"""Compare locally fetched official NC probability responses with a private pack.

Read-only, offline verification. Neither source tables nor public response bodies
are copied into the repository. Fetch snapshots through the public page's normal
API and keep them beside private evidence, then pass their paths explicitly.
"""
import argparse
from collections import Counter
from decimal import Decimal
import hashlib
import json
from pathlib import Path


TOTEMS = {"테베라스 토템": 4, "티칼 토템": 14, "아틀란티스 토템": 24}
TYPES = {
    "물리 방어력(AC)": "ArmorClass", "마법 방어력(MR)": "MagicResist",
    "PVE 대미지 리덕션": "PVEDamageReduction", "대미지 리덕션": "DamageReduction",
    "근거리 대미지 감소": "MeleeDamageReductionPercent",
    "원거리 대미지 감소": "RangeDamageReductionPercent",
    "마법 대미지 감소": "MagicDamageReductionPercent",
    "경험치 획득량 증가": "ExperienceAdditionPercent",
    "근거리 대미지": "MeleeDamage", "원거리 대미지": "RangeDamage", "마법 대미지": "MagicDamage",
    "근거리 명중": "MeleeHit", "원거리 명중": "RangeHit", "마법 명중": "MagicHit",
    "발동: 오시리스 저지먼트": "InvokeOption",
    "발동: 제브레퀴 베놈": "InvokeOption", "발동: 포세이돈 배리어": "InvokeOption",
}


def leaves(records, inherited=None):
    for record in records:
        values = dict(inherited or {})
        values.update({k: v for k, v in record.items() if k != "@entries"})
        if "@entries" in record:
            yield from leaves(record["@entries"], values)
        else:
            yield values


def raw_percent(value):
    number = Decimal(str(value).removesuffix("%")) * 10000
    if number != number.to_integral_value():
        raise ValueError("Official percentage is not exactly representable in source units")
    return int(number)


def verify(pack_path, success_path, options_path):
    body_path = pack_path / "totem_data.json"
    manifest = json.loads((pack_path / "manifest.json").read_bytes())
    if hashlib.sha256(body_path.read_bytes()).hexdigest() != manifest["sha256"]:
        raise ValueError("Private pack SHA mismatch")
    body = json.loads(body_path.read_bytes())
    if body["source_version"] != 523:
        raise ValueError("Expected source 523")
    tables = body["tables"]
    success = json.loads(success_path.read_bytes())
    options = json.loads(options_path.read_bytes())
    for response, count in [(success, 33), (options, 94)]:
        paging = response["pageNavigation"]
        if paging["totalCount"] != count or paging["endPage"] != 1:
            raise ValueError("Incomplete official snapshot")
    source_success = Counter((r["TotemID"], r["Level"], r["Probability"]) for r in tables["TotemLevel"])
    public_success = Counter((TOTEMS[r["토템명"]], int(r["토템 레벨"]), raw_percent(r["토템 강화 확률[%]"]))
                             for r in leaves(success["records"]))
    if public_success != source_success:
        raise ValueError("Official success rows differ from source 523")
    levels = {r["ID"]: r for r in tables["TotemLevel"]}
    bonuses = {r["ID"]: r for r in tables["Bonus"]}
    types = {r["ID"]: r for r in tables["BonusType"]}
    source_options = Counter()
    for row in tables["TotemBonus"]:
        level, bonus = levels[row["TotemLevelID"]], bonuses[row["BonusID"]]
        source_options[(level["TotemID"], level["Level"], types[bonus["BonusTypeID"]]["Name"], bonus["Value"], row["Probability"])] += 1
    public_options = Counter()
    for row in leaves(options["records"]):
        kind = TYPES[row["옵션 종류"]]
        text = str(row["옵션 수치"])
        value = raw_percent(text) if text.endswith("%") else int(text)
        if kind == "ArmorClass":
            value = -value  # Source stores positive armour benefit, UI displays AC -1.
        public_options[(TOTEMS[row["토템명"]], int(row["토템 레벨"]), kind, value, raw_percent(row["옵션별 등장 확률[%]"]))] += 1
    if public_options != source_options:
        raise ValueError("Official option values/selection weights differ from source 523")
    return {"source_version": 523, "success_rows": sum(source_success.values()),
            "option_rows": sum(source_options.values()), "match": True,
            "scope": "Published numeric rates and option values only; not server transition/RNG semantics",
            "snapshot_sha256": {p.name: hashlib.sha256(p.read_bytes()).hexdigest() for p in [success_path, options_path]}}


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--pack", type=Path, required=True)
    parser.add_argument("--success", type=Path, required=True)
    parser.add_argument("--options", type=Path, required=True)
    args = parser.parse_args()
    print(json.dumps(verify(args.pack, args.success, args.options), ensure_ascii=False, indent=2))
