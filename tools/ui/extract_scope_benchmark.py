"""Extract a hash-checked UI44 benchmark fixture from the private installed pack."""
import argparse
import hashlib
import json
from pathlib import Path

MANIFEST = "5263d92594e8f44248ad799d6b56ba7816fc5f30bdc4ead0bafaf0bf2dd0b94c"
CLOSURE = "8956873f1506303e1a2551a448ce139b55889bcaf24f460286cef51fa44111d0"
ROOTS = ["UI/BMShop/BM_Gacha.csb", "UI/CommonUi/Common_Slot.csb",
         "UI/Map/Map_All.csb", "UI/Main/Set_R_Top_MiniMapLayout.csb"]


def digest(data):
    return hashlib.sha256(data).hexdigest()


def walk(node):
    yield node
    for child in node.get("children", []):
        yield from walk(child)


def extract(root):
    data = (root / "original_ui.json").read_bytes()
    if digest(data) != MANIFEST:
        raise ValueError("expected ui44 release manifest")
    manifest = json.loads(data)
    pending, selected = ROOTS.copy(), {}
    while pending:
        key = pending.pop()
        if key in selected:
            continue
        scene = manifest["scenes"][key]
        if digest((root / "originals" / key).read_bytes()) != scene["_source_sha256"]:
            raise ValueError("source mismatch: " + key)
        selected[key] = scene
        for node in walk(scene["nodeTree"]):
            if node.get("classname") == "ProjectNode":
                member = node.get("options", {}).get("fileName", "")
                if member:
                    pending.append(member if member.startswith("UI/") else "UI/" + member)
    fixture = {"scenes": selected, "externally_bound_texture_nodes":
               {k: v for k, v in manifest["externally_bound_texture_nodes"].items() if k in selected}}
    result = json.dumps(fixture, ensure_ascii=False, separators=(",", ":")).encode()
    if digest(result) != CLOSURE or len(selected) != 33:
        raise ValueError("unexpected projection closure")
    return result


if __name__ == "__main__":
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("pack", type=Path)
    p.add_argument("destination", type=Path, help="new private temporary file, never add to git")
    args = p.parse_args()
    fixture = extract(args.pack)
    with args.destination.open("xb") as output:
        output.write(fixture)
    print(CLOSURE, args.destination)
