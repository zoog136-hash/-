#!/usr/bin/env python3
"""Build a private 523 Totem pack from source rows verified against the archive.

No source tables or generated private pack belong in the public code repository.
"""
import argparse
import hashlib
import json
from pathlib import Path
import tempfile
import zipfile


def digest(data):
    return hashlib.sha256(data).hexdigest()


def build(source, research, output):
    if output.exists():
        raise ValueError("Choose a new output directory; existing packs are preserved")
    with zipfile.ZipFile(source) as original, zipfile.ZipFile(research) as analysis:
        if original.testzip() or analysis.testzip():
            raise ValueError("ZIP CRC failure")
        evidence = json.loads(analysis.read("totem-progression-523/source_row_evidence.json"))
        tables, loaded, coordinates = {}, {}, set()
        for entry in evidence:
            table, pos = entry["table"], entry["source_row_1based"]
            if entry["version"] != 523 or (table, pos) in coordinates:
                raise ValueError("Wrong source version or duplicate row coordinate")
            coordinates.add((table, pos))
            if table not in loaded:
                loaded[table] = json.loads(original.read(f"content/{table}.json").decode("utf-8-sig"))["rows"]
            if pos < 1 or loaded[table][pos - 1] != entry["row"]:
                raise ValueError(f"Evidence mismatch: {table} row {pos}")
            tables.setdefault(table, []).append(entry["row"])
        expected = {"Totem": 3, "TotemLevel": 33, "TotemMaterial": 60,
                    "TotemBonus": 94, "TotemConstant": 8, "TotemResetCost": 2,
                    "TotemResonance": 4}
        for table, count in expected.items():
            if len(tables[table]) != count or tables[table] != loaded[table]:
                # Evidence is sorted by row coordinates, not opaque IDs.
                if len(tables[table]) != count or sorted(tables[table], key=lambda r: r['ID']) != sorted(loaded[table], key=lambda r: r['ID']):
                    raise ValueError(f"Incomplete core table: {table}")
        if len(evidence) != 1294 or len(tables) != 43:
            raise ValueError("Unexpected evidence coverage")
        def source_rows(name):
            return json.loads(original.read(f"content/{name}.json").decode("utf-8-sig"))["rows"]
        # Original activation groups -> spawn pack -> territory -> exact Land.
        # This is a documented local region binding, not an invented legacy map alias.
        spawns = source_rows("NpcSpawnPackNpcClassView")
        links = source_rows("NpcSpawnPackTerritory")
        territories = {r["ID"]: r for r in source_rows("Territories")}
        lands = {r["ID"]: r for r in source_rows("Land")}
        contexts = {}
        for totem in tables["Totem"]:
            ids = {r["NpcClassID"] for r in tables["NpcClassForNpcGroup"] if r["NpcGroupID"] == totem["NpcGroupID"]}
            packs = {r["NpcSpawnPackID"] for r in spawns if r["NpcClassID"] in ids}
            land_ids = {territories[r["TerritoriesID"]]["LandID"] for r in links if r["NpcSpawnPackID"] in packs}
            contexts[str(totem["ID"])] = [lands[id] for id in sorted(land_ids)]
        if sorted(len(v) for v in contexts.values()) != [2, 2, 3]:
            raise ValueError("Unexpected Totem region closure; review before changing bindings")
        body = json.dumps({"schema": 1, "source_version": 523, "tables": tables, "map_contexts": contexts},
                          ensure_ascii=False, separators=(",", ":")).encode()
        manifest = {"schema": 1, "source_version": 523, "sha256": digest(body),
                    "source_zip_sha256": digest(source.read_bytes()),
                    "research_zip_sha256": digest(research.read_bytes()),
                    "table_counts": {k: len(v) for k, v in tables.items()},
                    "evidence_rows": len(evidence), "delivery": "PRIVATE_LOCAL_ONLY"}
        output.parent.mkdir(parents=True, exist_ok=True)
        with tempfile.TemporaryDirectory(dir=output.parent) as temp:
            stage = Path(temp) / "pack"
            stage.mkdir()
            (stage / "totem_data.json").write_bytes(body)
            (stage / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n")
            stage.rename(output)
        return manifest


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source", type=Path, required=True)
    parser.add_argument("--research", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    print(json.dumps(build(args.source, args.research, args.output), indent=2))
