#!/usr/bin/env python3
"""Package/verify/install private shop data. Does not edit game code or saves."""
import argparse
import hashlib
import json
from pathlib import Path
import shutil
import tempfile
import zipfile

SCHEMA = "twilight.source523.shop-runtime.v1"
FILES = ("shop523.json", "npc523.json")


def sha(data):
    return hashlib.sha256(data).hexdigest()


def outside_repo(path):
    path = Path(path).resolve()
    if path.is_relative_to(Path(__file__).resolve().parents[2]):
        raise ValueError("private resource packs belong outside the Git working tree")
    return path


def package(shop_path, npc_path, destination):
    destination = outside_repo(destination)
    if destination in [Path(shop_path).resolve(), Path(npc_path).resolve()] or destination.exists():
        raise ValueError("preserve existing files; choose a new runtime ZIP path")
    payloads = {"shop523.json": Path(shop_path).read_bytes(), "npc523.json": Path(npc_path).read_bytes()}
    shop, npc = (json.loads(payloads[name]) for name in FILES)
    if shop.get("schema") != "twilight.source523.shop.v1" or npc.get("schema") != "twilight.source523.npc-definitions.v1" or npc.get("revision", 0) < 2 or npc.get("shop_pack_sha256") != sha(payloads["shop523.json"]) or npc.get("source_zip_sha256") != shop.get("source_zip_sha256"):
        raise ValueError("runtime shop/NPC source identities do not match")
    manifest = {"schema": SCHEMA, "runtime_revision": 2,
                "source_zip_sha256": shop["source_zip_sha256"],
                "files": [{"name": name, "bytes": len(payloads[name]), "sha256": sha(payloads[name])} for name in FILES],
                "consumption": "explicit CLI paths and SHA256; Drive storage does not auto-install"}
    payloads["manifest.json"] = (json.dumps(manifest, indent=2) + "\n").encode()
    destination.parent.mkdir(parents=True, exist_ok=True)
    with zipfile.ZipFile(destination, "x", compression=zipfile.ZIP_DEFLATED, compresslevel=9) as archive:
        for name, data in payloads.items():
            info = zipfile.ZipInfo(name, (2000, 1, 1, 0, 0, 0))
            info.compress_type = zipfile.ZIP_DEFLATED
            info.external_attr = 0o100600 << 16
            archive.writestr(info, data, compress_type=zipfile.ZIP_DEFLATED, compresslevel=9)
    data = destination.read_bytes()
    return {"path": str(destination), "bytes": len(data), "sha256": sha(data), "manifest": manifest}


def install(source, expected_sha256, destination):
    source, destination = Path(source).resolve(), outside_repo(destination)
    if sha(source.read_bytes()) != expected_sha256:
        raise ValueError("runtime ZIP SHA256 mismatch")
    if destination.exists():
        raise ValueError("choose a fresh consumer directory; existing installs are preserved")
    with zipfile.ZipFile(source) as archive:
        names = archive.namelist()
        if sorted(names) != sorted([*FILES, "manifest.json"]) or len(set(names)) != len(names):
            raise ValueError("unexpected runtime ZIP members")
        if sum(r.file_size for r in archive.infolist()) > 128 * 1024 * 1024 or archive.testzip() is not None:
            raise ValueError("runtime ZIP size/CRC failure")
        manifest = json.loads(archive.read("manifest.json"))
        if manifest.get("schema") != SCHEMA or manifest.get("runtime_revision") != 2 or {r["name"] for r in manifest.get("files", [])} != set(FILES):
            raise ValueError("runtime manifest mismatch")
        payloads = {}
        for row in manifest["files"]:
            data = archive.read(row["name"])
            if len(data) != row["bytes"] or sha(data) != row["sha256"]:
                raise ValueError("runtime member SHA256 mismatch: " + row["name"])
            payloads[row["name"]] = data
    destination.parent.mkdir(parents=True, exist_ok=True)
    staging = Path(tempfile.mkdtemp(prefix=".shop-install-", dir=destination.parent))
    try:
        for name, data in payloads.items():
            (staging / name).write_bytes(data)
        (staging / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n")
        staging.rename(destination)
    finally:
        if staging.exists():
            shutil.rmtree(staging)
    entries = {r["name"]: r for r in manifest["files"]}
    return {"directory": str(destination), "verified_crc": True,
            "arguments": ["--source523-shop-pack=" + str(destination / "shop523.json"),
                          "--source523-shop-sha256=" + entries["shop523.json"]["sha256"],
                          "--source523-npc-pack=" + str(destination / "npc523.json"),
                          "--source523-npc-sha256=" + entries["npc523.json"]["sha256"]]}


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest="action", required=True)
    build = sub.add_parser("package")
    build.add_argument("shop");build.add_argument("npc");build.add_argument("destination")
    deploy = sub.add_parser("install")
    deploy.add_argument("source");deploy.add_argument("sha256");deploy.add_argument("destination")
    args = parser.parse_args()
    print(json.dumps(package(args.shop, args.npc, args.destination) if args.action == "package" else install(args.source, args.sha256, args.destination)))
