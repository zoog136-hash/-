#!/usr/bin/env python3
"""Build data/ui/item_icon_identity.json: original 523 icons for bag entries
whose name is not an original Korean item name.

Only ItemClass IDs and icon file names are written (no image bytes).

* exact: legacy name-catalog rows (catalog_v19.json, source "inven") whose
  publisher sourceId is the original ItemClass.ID. Accepted only when that
  row's original icon file name equals the catalog's own image file name
  (case-insensitive), i.e. the same original picture. Many of these rows are
  TestItem (retired in 523) or renamed (빙령의 장갑 -> 수령의 장갑); the
  picture is still the item's own original icon.
* approx ("TWILIGHT 근사"): TWILIGHT-local items (game_db_v17.json without any
  original row: local crafting materials, local-expansion gear, local potions)
  get the original icon of an original item of the same original kind
  (same EquipSlot / WeaponType, nearest original grade; materials and potions
  from a fixed reviewed table). The picture is original; the pairing is an
  approximation and is marked as such.

usage: build_item_icon_identity.py --tables <DIR with ItemClass.json ...>
       --images-manifest <pack>/images/manifest.json [--repo .] [--check]
"""
import argparse, collections, hashlib, json, os, sys

GRADES = {"일반": 1, "고급": 2, "희귀": 3, "영웅": 4, "전설": 5, "신화": 32, "유일": 52}
GRADE_ORDER = [1, 2, 3, 4, 5, 32, 52]
WEAPON_TYPES = {"한손검": 1, "도끼": 2, "활": 3, "창": 4, "지팡이": 5, "단검": 6, "양손검": 7,
                "그레이트소드": 7, "이도류": 8, "크로우": 9, "체인소드": 11, "라이플": 34,
                "핸드캐넌": 54, "사이드": 84, "마검": 102}
EQUIP_SLOTS = {"helmet": 1, "body": 2, "armor": 2, "tshirt": 3, "cloak": 4, "gaiters": 5, "pants": 5,
               "boots": 6, "gloves": 7, "ring": 9, "necklace": 10, "belt": 11, "earring": 12,
               "offhand": 19, "rune": 20, "badge": 32, "seal": 121,
               "bracelet": 152, "catalyst": 222}  # crystal: see below
# Reviewed approximations for TWILIGHT-local materials and potions: the
# original item of the same original kind (NormalMaterial 10491 / Potion 3 ...).
FIXED = {
    "철 광석": 379, "동 광석": 3672, "미스릴 원석": 3662, "가죽 조각": 366, "천 조각": 739,
    "정제된 목재": 227361, "마력 결정": 254, "연마석": 845, "약초": 137714, "정령의 가루": 3732,
    "축복의 성수": 117284,
    "HP 물약": 233, "강력 HP 물약": 236, "축복받은 HP 물약": 237,
    "초급 회복 물약": 233, "중급 회복 물약": 237, "상급 회복 물약": 236, "특급 회복 물약": 236,
    "왕실 회복 물약": 236, "신성 회복 물약": 236, "엘릭서 회복 물약": 236,
}


def rows(tables, name):
    with open(os.path.join(tables, name + ".json"), encoding="utf-8-sig") as f:
        return json.load(f)["rows"]


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--tables", required=True)
    ap.add_argument("--images-manifest", required=True)
    ap.add_argument("--repo", default=".")
    ap.add_argument("--check", action="store_true", help="fail if the committed file differs")
    a = ap.parse_args()
    desc = {r["ID"]: (r["Description"] or "").strip() for r in rows(a.tables, "DescData_Korean")}
    items = {r["ID"]: r for r in rows(a.tables, "ItemClass")}
    with open(a.images_manifest, encoding="utf-8") as f:
        manifest = json.load(f)
    icon_asset = {r["id"]: r["asset_id"] for r in manifest["icons"]}
    assets = {x["asset_id"]: x for x in manifest["assets"]}

    def name(it):
        return desc.get(it.get("IdentifiedDescID") or 0) or desc.get(it.get("DescID") or 0, "")

    def icon(it):
        asset = assets.get(icon_asset.get(it["IconID"], -1), {})
        path = str(asset.get("path", ""))
        return path, asset.get("status", "")

    # Runtime identity rule (source523_item_identity.by_name): one icon per name.
    by_name = collections.defaultdict(set)
    for it in items.values():
        if not it.get("TestItem") and name(it):
            by_name[name(it)].add(it["IconID"])
    resolved = {n for n, icons in by_name.items() if len(icons) == 1}

    repo = a.repo
    catalog = json.load(open(os.path.join(repo, "data/catalog_v19.json"), encoding="utf-8"))
    exact = {}
    for rec in catalog.get("아이템", []):
        n = rec.get("name", "")
        if not n or n in resolved or n in exact or rec.get("source") != "inven":
            continue
        try:
            sid = int(rec.get("sourceId") or 0)
        except ValueError:
            continue
        it = items.get(sid)
        if it is None:
            continue
        path, status = icon(it)
        want = str(rec.get("sourceImageUrl", "")).rsplit("/", 1)[-1].lower()
        got = path.rsplit("/", 1)[-1].lower()
        if status == "unsupported_csb":
            # Animated original icon (AssetType 101): the catalog image is its frame 00.
            ok = want.replace("_00.png", "") in got.replace("fx_", "").replace(".csb", "")
        else:
            ok = status == "verified_original" and got == want
        if ok:
            exact[n] = {"item_class_id": sid, "icon_file": path.rsplit("/", 1)[-1], "basis": "catalog_inven_source_id_same_icon_file"}
            if it.get("TestItem"):
                # The floor selector admits no TestItem row: an original row
                # with the same floor sprite (SpriteID) supplies the floor body.
                same = sorted(i for i, other in items.items() if not other.get("TestItem") and other.get("SpriteID") == it.get("SpriteID") and int(it.get("SpriteID") or 0) > 0)
                if same:
                    exact[n]["ground_item_class_id"] = same[0]

    db = json.load(open(os.path.join(repo, "data/game_db_v17.json"), encoding="utf-8"))
    equip = collections.defaultdict(set)
    for r in rows(a.tables, "ItemEquipSlot"):
        equip[r["EquipSlotID"]].add(r["ItemClassID"])
    weapon = {}
    for r in rows(a.tables, "ItemCraftView"):
        if r.get("ItemCategoryID") == 1 and r.get("WeaponType"):
            weapon[r["ItemClassID"]] = r["WeaponType"]
    usable = {i for i, it in items.items() if not it.get("TestItem") and icon(it)[1] == "verified_original"}

    def pick(pool, grade, local):
        by_grade = collections.defaultdict(list)
        for i in sorted(pool & usable):
            by_grade[items[i]["GradeID"]].append(i)
        if not by_grade:
            return None, None
        at = GRADE_ORDER.index(grade) if grade in GRADE_ORDER else 0
        order = sorted(by_grade, key=lambda g: (abs((GRADE_ORDER.index(g) if g in GRADE_ORDER else 99) - at), -(GRADE_ORDER.index(g) if g in GRADE_ORDER else 0)))
        choices = by_grade[order[0]]
        # Stable spread so items of one kind and grade do not all share one picture.
        k = int(hashlib.sha256(local.encode("utf-8")).hexdigest(), 16) % len(choices)
        return choices[k], order[0]

    approx = {}
    for rec in db.get("아이템", []):
        n = rec.get("name", "")
        if not n or n in resolved or n in exact or n in approx:
            continue
        grade = GRADES.get(rec.get("grade", ""), 1)
        chosen, basis = None, ""
        if n in FIXED:
            chosen, basis = FIXED[n], "twilight_approx_reviewed_same_kind"
        elif rec.get("slot") == "weapon" and rec.get("type") in WEAPON_TYPES:
            wt = WEAPON_TYPES[rec["type"]]
            chosen, g = pick({i for i, w in weapon.items() if w == wt}, grade, n)
            basis = "twilight_approx_weapon_type_%d_grade_%s" % (wt, g)
        elif rec.get("slot") == "crystal":
            # No original SpellRune row has a picture: original 정령의 수정 items.
            chosen, g = pick({i for i, it in items.items() if name(it).startswith(("정령의 수정", "흑정령의 수정"))}, grade, n)
            basis = "twilight_approx_spirit_crystal_grade_%s" % g
        elif rec.get("slot") in EQUIP_SLOTS:
            slot = EQUIP_SLOTS[rec["slot"]]
            chosen, g = pick(equip.get(slot, set()), grade, n)
            basis = "twilight_approx_equip_slot_%d_grade_%s" % (slot, g)
        if chosen is None or chosen not in items:
            continue
        path, status = icon(items[chosen])
        if status != "verified_original":
            continue
        approx[n] = {"item_class_id": chosen, "icon_file": path.rsplit("/", 1)[-1], "basis": basis}

    out = {"schema": "twilight-item-icon-identity-v1", "source_version": 523,
           "note": "Original 523 icons for bag names without an original Korean item name. exact = the item's own original picture; approx = TWILIGHT 근사 (original picture of an original item of the same kind). IDs and file names only.",
           "exact": dict(sorted(exact.items())), "approx": dict(sorted(approx.items()))}
    text = json.dumps(out, ensure_ascii=False, indent=1, sort_keys=False) + "\n"
    target = os.path.join(repo, "data/ui/item_icon_identity.json")
    if a.check:
        same = os.path.exists(target) and open(target, encoding="utf-8").read() == text
        print("ITEM_ICON_IDENTITY_CHECK", "ok" if same else "differs")
        return 0 if same else 1
    os.makedirs(os.path.dirname(target), exist_ok=True)
    open(target, "w", encoding="utf-8").write(text)
    print("ITEM_ICON_IDENTITY exact=%d approx=%d" % (len(exact), len(approx)))
    return 0


if __name__ == "__main__":
    sys.exit(main())
