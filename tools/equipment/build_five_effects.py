#!/usr/bin/env python3
"""Build a private, additive effects graph for the already installed 523 cache.

The canonical ZIP and original base bytes are pinned. No base cache is rebuilt,
patched, or uploaded. Missing original relationships stay explicit in audit.
"""
import argparse
import configparser
from collections import defaultdict, deque
from copy import deepcopy
import hashlib
import json
from pathlib import Path
import tempfile
import zipfile

from build_five_systems import effect

SCHEMA = "patch523-equipment-effects-v1"
BASE_SCHEMA = "patch523-five-systems-v1"
BASE_SHA = "e2a51dce910799ee31c7943b84a6b44d3c84dfb964b25fe8962f39522cafd700"
BASE_BYTES = 9_894_720
SOURCE_SHA = "d5192c3c735ff95c6b181bf2d4d77448d8b562fdb28dbd43f897fa4eae1f4832"


def sha256(data):
    return hashlib.sha256(data).hexdigest()


class Source:
    """Read only canonical ZIP members; optional extraction must match bytewise."""
    def __init__(self, archive, content=None):
        self.archive, self.content = archive, content
        self.cache, self.indexes, self.hashes = {}, {}, {}

    def rows(self, name):
        if name not in self.cache:
            member = "content/" + name + ".json"
            if self.archive.namelist().count(member) != 1:
                raise ValueError("missing or ambiguous canonical table: " + name)
            data = self.archive.read(member)
            if self.content is not None and (self.content / (name + ".json")).read_bytes() != data:
                raise ValueError("extracted table differs from canonical ZIP: " + name)
            value = json.loads(data.decode("utf-8-sig"))
            if not isinstance(value, dict) or not isinstance(value.get("rows"), list):
                raise ValueError("invalid original table: " + name)
            self.cache[name] = value["rows"]
            self.hashes[name] = sha256(data)
        return self.cache[name]

    def one(self, name, identity):
        if name not in self.indexes:
            index = {}
            for row in self.rows(name):
                if "ID" not in row:
                    raise ValueError("ID-less definition table: " + name)
                if row["ID"] in index and index[row["ID"]] != row:
                    raise ValueError("conflicting original ID in " + name)
                index[row["ID"]] = row
            self.indexes[name] = index
        return self.indexes[name].get(identity)


class Graph:
    def __init__(self, base, source):
        self.base, self.source = base, source
        self.selected = defaultdict(dict)
        self.queue, self.visited = deque(), set()
        self.missing, self.empty, self.terminals = [], [], []
        self.edges = []
        self.missing_keys, self.empty_keys = set(), set()

    def missing_ref(self, table, identity, via):
        key = (table, identity, via)
        if key not in self.missing_keys:
            self.missing_keys.add(key)
            self.missing.append({"table": table, "identity": identity, "via": via})

    def add(self, table, identity, via):
        if type(identity) is not int or identity < 0:
            raise ValueError(f"invalid typed identity {table}:{identity!r}")
        self.edges.append({"table": table, "id": identity, "via": via})
        key = (table, identity)
        if key in self.visited:
            return
        self.visited.add(key)
        row = self.source.one(table, identity)
        if row is None:
            self.missing_ref(table, identity, via)
            return
        self.selected[table][identity] = deepcopy(row)
        self.queue.append((table, identity, row))

    def children(self, table, field, identity, via):
        rows = [row for row in self.source.rows(table) if row.get(field) == identity]
        if not rows:
            key = (table, field, identity)
            if key not in self.empty_keys:
                self.empty_keys.add(key)
                self.empty.append({"table": table, "field": field, "identity": identity,
                                   "source_row_count": 0, "via": via})
        for row in rows:
            self.add(table, row["ID"], via)
        return rows

    def scalar_definition(self, table, row, field, include_zero=False):
        value = row.get(field, 0)
        if value or include_zero:
            self.add(table, value, f"{field} of source row {row['ID']}")

    def walk(self):
        while self.queue:
            table, identity, row = self.queue.popleft()
            via = f"{table}:{identity}"
            if table == "Bonus":
                self._bonus(row, via)
            elif table == "BonusType":
                self.add("Unit", row["UnitID"], via + ".UnitID")
            elif table == "SpellClass":
                self.children("SpellBonus", "SpellClassID", identity, via)
                for name, field, zero in [
                    ("TargettingType", "TargettingTypeID", True),
                    ("TargetKind", "TargetKindID", True),
                    ("TargetKind", "SiegeTargetKindID", True),
                    ("ElementalType", "ElementalTypeID", True),
                    ("SpellCastGroup", "CastGroupID", False),
                    ("SpellGroup", "SpellGroupID", False),
                    ("Unit", "MPCostUnit", True),
                    ("SpellClass", "CopySpellClassID", False),
                ]:
                    self.scalar_definition(name, row, field, zero)
            elif table in ("SpellBonus", "BuffBonus", "BuffStackBonus", "IntervalBonus"):
                self.add("Bonus", row["BonusID"], via + ".BonusID")
            elif table == "BuffClass":
                self.children("BuffBonus", "BuffClassID", identity, via)
                self.children("BuffStack", "BuffClassID", identity, via)
                self.scalar_definition("BuffGroup", row, "BuffGroupID", True)
            elif table == "BuffStack":
                self.children("BuffStackBonus", "BuffStackID", identity, via)
            elif table == "InvokeOption":
                self.add("InvokeOptionType", row["InvokeOptionTypeID"], via + ".InvokeOptionTypeID")
                kind = self.source.one("InvokeOptionType", row["InvokeOptionTypeID"])
                if kind:
                    for number in range(1, 7):
                        unit_id = kind.get(f"Param{number}Unit", 0)
                        value = row.get(f"Param{number}", 0)
                        if not unit_id or not value:
                            continue
                        unit = self.source.one("Unit", unit_id)
                        self.add("Unit", unit_id, via + f".Param{number}Unit")
                        if unit and unit["Name"] in ("SpellClassID", "BuffClassID"):
                            self.add(unit["Name"].removesuffix("ID"), value, via + f".Param{number}")
                self.scalar_definition("InvokeOption", row, "SuccessedInvokeOptionID")
                self.scalar_definition("AttackType", row, "AttackTypeID", True)
                self.scalar_definition("TargetKind", row, "TargetKind", True)
                self.scalar_definition("TargetKind", row, "SiegeTargetKind", True)
            elif table == "InvokeOptionType":
                for number in range(1, 7):
                    self.scalar_definition("Unit", row, f"Param{number}Unit")
            elif table == "IntervalBonusCategory":
                self.children("IntervalBonus", "IntervalBonusCategory", identity, via)
            elif table == "UniversalGroupSet":
                self.add("Unit", row["UnitID"], via + ".UnitID")
                unit = self.source.one("Unit", row["UnitID"])
                if unit and unit["Name"] == "AttackTypeID":
                    self.add("AttackType", row["Value"], via + ".Value")

    def _bonus(self, row, via):
        self.add("BonusType", row["BonusTypeID"], via + ".BonusTypeID")
        kind = self.source.one("BonusType", row["BonusTypeID"])
        self.add("BonusApplicationType", row["BonusApplicationTypeID"], via + ".BonusApplicationTypeID")
        if not kind:
            return
        unit = self.source.one("Unit", kind["UnitID"])
        name, value = kind["Name"], row["Value"]
        app, target = row["BonusApplicationTypeID"], row["BonusApplicationTargetID"]
        if name == "InvokeOption" and unit and unit["Name"] == "Percentage" and app == 10:
            self.add("InvokeOption", target, via + ".BonusApplicationTargetID")
        elif app == 0 and target == 0 and unit and unit["Name"] in ("BuffClassID", "SpellClassID", "IntervalBonusCategoryID"):
            destination = unit["Name"].removesuffix("ID")
            self.add(destination, value, via + ".Value")
        elif app == 0 and target == 0 and unit and unit["Name"] == "SpecialResistanceTypeID":
            self.add("SpecialResistanceType", value, via + ".Value")
        elif app == 0 and target == 0 and unit and unit["Name"] == "StatusEffectID":
            self.children("StatusEffectAttr", "StatusEffectID", value, via + ".Value")
            self.children("StatusEffectGroupLink", "StatusEffectID", value, via + ".Value")
            self.terminals.append({"namespace":"StatusEffectAttrType", "via":via,
                                   "reason":"original enum definition table is absent; attribute values are preserved without invented labels"})
        if app == 2:
            self.add("SpecialResistanceType", target, via + ".BonusApplicationTargetID")
        elif app == 3:
            self.add("ElementalType", target, via + ".BonusApplicationTargetID")
        elif app == 381:
            self.children("UniversalGroupSet", "GroupID", target, via + ".BonusApplicationTargetID")
        elif app == 72:
            exists = self.source.one("DescData_Korean", target) is not None
            if exists:
                self.add("DescData_Korean",target,via+".BonusApplicationTargetID")
            self.terminals.append({"namespace":"DescID", "id":target,"via":via,
                                   "source_row_exists":exists,"execution":"caption only; no invented proc"})
            if not exists:
                self.missing_ref("DescData_Korean", target, via)


def roots_from_base(base, source):
    groups = defaultdict(list)
    for row in base["tables"]["ItemInvokeReplacementEntityView"]:
        groups[(row["ItemInvokeReplacementID"], row["SlotNumber"])].append(row)
    variable_groups = {row["ItemInvokeReplacementBonusGroupID"] for values in groups.values()
                       if len(values) > 1 for row in values}
    spell_ids = set()
    for link in base["tables"]["ItemInvokeReplacementBonus"]:
        if link["ItemInvokeReplacementBonusGroupID"] not in variable_groups:
            continue
        bonus = source.one("Bonus", link["BonusID"])
        kind = source.one("BonusType", bonus["BonusTypeID"]) if bonus else None
        if not kind or kind["Name"] != "InvokeOption" or bonus["BonusApplicationTypeID"] != 10:
            continue
        option = source.one("InvokeOption", bonus["BonusApplicationTargetID"])
        if not option or option["InvokeOptionTypeID"] != 1:
            continue
        links = [r for r in source.rows("SpellBonus") if r["SpellClassID"] == option["Param1"]]
        names = {source.one("BonusType", source.one("Bonus", r["BonusID"])["BonusTypeID"])["Name"] for r in links}
        if {"BuffClassID", "SpellDebuffMinDuration", "SpellDebuffMaxDuration"}.issubset(names):
            spell_ids.add(option["Param1"])
    set_bonus_ids = sorted({row["BonusID"] for row in base["tables"]["ItemSetBonus"]
                            if not base["bonuses"][str(row["BonusID"])]["supported"]})
    set_buff_ids = sorted({row["BuffClassID"] for row in base["tables"]["ItemSet"] if row.get("BuffClassID")})
    return {"variable_debuff_spell_ids":sorted(spell_ids),"unsupported_set_bonus_ids":set_bonus_ids,
            "set_buff_class_ids":set_buff_ids}


def compile_extension(base, source, base_sha=BASE_SHA):
    if base.get("schema") != BASE_SCHEMA or base.get("source_sha256") != SOURCE_SHA:
        raise ValueError("base cache schema/source SHA does not match the pinned 523 source")
    roots = roots_from_base(base, source)
    graph = Graph(base, source)
    for key, table in [("variable_debuff_spell_ids","SpellClass"),
                       ("unsupported_set_bonus_ids","Bonus"),("set_buff_class_ids","BuffClass")]:
        for identity in roots[key]: graph.add(table, identity, "root:" + key)
    graph.walk()
    tables, equal_counts = {}, {}
    for name, selected in sorted(graph.selected.items()):
        existing = {row["ID"]:row for row in base.get("tables",{}).get(name,[]) if "ID" in row}
        additions = []
        equal_counts[name] = 0
        for identity, row in sorted(selected.items()):
            if identity in existing:
                if existing[identity] != row:
                    raise ValueError(f"source/base row conflict: {name}:{identity}")
                equal_counts[name] += 1
            else:
                additions.append(row)
        if additions: tables[name] = additions
    descriptions = {r["ID"]:r["Description"].strip() for r in source.rows("DescData_Korean")}
    bonuses = {}
    for identity, row in sorted(graph.selected.get("Bonus",{}).items()):
        kind = source.one("BonusType", row["BonusTypeID"])
        if not kind:
            continue
        classified = effect(row, kind, descriptions)
        existing = base.get("bonuses",{}).get(str(identity))
        if existing is not None and existing != classified:
            raise ValueError(f"source/base classified bonus conflict: {identity}")
        if existing is None: bonuses[str(identity)] = classified
    return {"schema":SCHEMA,"base_sha256":base_sha,"source_sha256":SOURCE_SHA,
            "tables":tables,"bonuses":bonuses,
            "audit":{"roots":roots,"selected_counts":{k:len(v) for k,v in sorted(graph.selected.items())},
                     "added_counts":{k:len(v) for k,v in tables.items()},"equal_base_rows_omitted":equal_counts,
                     "missing_references":graph.missing,"empty_relationships":graph.empty,
                     "terminal_references":graph.terminals,"typed_edges":graph.edges,
                     "source_table_sha256":dict(sorted(source.hashes.items())),
                     "source_execution_equivalent":False,"normal_acquisition_verified":False,
                     "buff_shells_preserved":True,"base_cache_rebuilt":False}}


def require_private_output(path, base_path, source_zip):
    path = path.resolve()
    if path in (base_path.resolve(), source_zip.resolve()):
        raise ValueError("output must not overwrite the base cache or canonical ZIP")
    code_root = Path(__file__).resolve().parents[2]
    connected_repository = False
    for parent in path.parents:
        config_path = parent / ".git" / "config"
        if not config_path.is_file():
            continue
        config = configparser.ConfigParser()
        config.read(config_path)
        if any(section.startswith("remote ") for section in config.sections()):
            connected_repository = True
    if path.is_relative_to(code_root) or connected_repository:
        raise ValueError("effects extension must be outside the public repository")


def build_extension(base_path, source_zip, output, content=None):
    require_private_output(output, base_path, source_zip)
    base_bytes = base_path.read_bytes()
    if len(base_bytes) != BASE_BYTES or sha256(base_bytes) != BASE_SHA:
        raise ValueError("original installed base cache bytes/SHA mismatch; do not rebuild it")
    source_bytes = source_zip.read_bytes()
    if sha256(source_bytes) != SOURCE_SHA:
        raise ValueError("canonical source ZIP SHA mismatch")
    base = json.loads(base_bytes)
    with zipfile.ZipFile(source_zip) as archive:
        if archive.testzip() is not None:
            raise ValueError("canonical source ZIP CRC mismatch")
        result = compile_extension(base, Source(archive, content), BASE_SHA)
    data = (json.dumps(result, ensure_ascii=False, separators=(",",":"))+"\n").encode()
    output.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.NamedTemporaryFile(prefix=output.name+".", suffix=".tmp", dir=output.parent, delete=False) as temporary:
        temporary_path = Path(temporary.name)
        temporary.write(data)
    try:
        if base_path.read_bytes() != base_bytes:
            raise ValueError("base cache changed during conversion; extension not activated")
        temporary_path.replace(output)
    finally:
        temporary_path.unlink(missing_ok=True)
    return {"path":str(output),"bytes":len(data),"sha256":sha256(data),"base_sha256":BASE_SHA,
            "source_sha256":SOURCE_SHA,"added_counts":result["audit"]["added_counts"],
            "missing_references":result["audit"]["missing_references"],"source_execution_equivalent":False}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--base-cache",type=Path,required=True)
    parser.add_argument("--source-zip",type=Path,required=True)
    parser.add_argument("--content",type=Path)
    parser.add_argument("--output",type=Path,required=True)
    args = parser.parse_args()
    print(json.dumps(build_extension(args.base_cache,args.source_zip,args.output,args.content),ensure_ascii=False))


if __name__ == "__main__":
    main()
