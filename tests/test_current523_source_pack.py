"""Authored generic-pack fixtures; none of these bytes are original M maps."""
import copy
import hashlib
import gzip
import importlib.util
import json
from pathlib import Path
import struct
import shutil
import sys
import tempfile
import unittest
from unittest.mock import patch

TOOLS = Path(__file__).parents[1] / "tools/map_restore"
sys.path.insert(0, str(TOOLS))
SPEC = importlib.util.spec_from_file_location("generic_source_pack", TOOLS / "build_current523_source_pack.py")
PACK = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(PACK)


def minimal(tail=b"\x00\xffauthored tail"):
    return bytes(32768) + struct.pack("<H",0) + bytes(16384) + struct.pack("<III",0,0,0) + tail


def fixture_inventory(members, assets=("0/", "13341")):
    return {"schema":1,"edition":"LineageM","cumulative_version":523,"asset_paths":list(assets),
            "land_policy":[{"land_id":row,"excluded_content":flags,"provenance":{"source":"AUTHORED_FIXTURE_POLICY_ONLY"}}
                           for row,flags in ((0,[]),(12156,["arena"]),(47443,[]))],
            "members":[{"member":member,"asset_path":asset,"bytes":len(raw),"sha256":PACK.sha(raw),
                        "availability":"present","provenance":{"snapshot_version":523,"container":"Client/Data/Fixture.dat",
                        "selection_version":508,"evidence_level":"AUTHORED_FIXTURE_ONLY","current_selection_verified":True,
                        "expected_member_sha256":PACK.sha(raw)}} for member,asset,raw in members]}


class GenericSourcePackTest(unittest.TestCase):
    def test_actual_generic_identity_and_lossless_unsigned_bytes(self):
        raw = bytearray(minimal())
        struct.pack_into("<II",raw,0,0xffffffff,0x800000ff)
        struct.pack_into("<HH",raw,32770,0xffff,0x8000)
        row = PACK.read_s32(bytes(raw),"Map/13341/80008000.s32")
        self.assertEqual(row["member"],"Map/13341/80008000.s32")
        self.assertEqual(row["raw_sections"]["floor"][:8],struct.pack("<II",0xffffffff,0x800000ff))
        self.assertEqual(PACK.write_s32(row),bytes(raw))
        self.assertEqual(list(row["sections"]),list(PACK.SECTION_NAMES))
        self.assertEqual(sum(section["bytes"] for section in row["sections"].values()),len(raw))
        self.assertFalse(any(key in row for key in ("land_id","origin","collision","movement")))
        corrupt = copy.deepcopy(row)
        corrupt["source_sha256"] = "0"*64
        with self.assertRaisesRegex(ValueError,"Lossless"):
            PACK.write_s32(corrupt)

    def test_unsafe_paths_seg_and_nonstandard_origin(self):
        for name in ("../x.s32","/Map/1/x.s32","Map/1/../x.s32","Map\\1\\x.s32","Map/1/x/y.s32","Map/1/x.s32\x00","Map/1/.s32"):
            with self.subTest(name=name),self.assertRaises(ValueError): PACK.member_name(name)
        self.assertEqual(PACK.asset_root("13341"),"Map/13341/")
        self.assertEqual(PACK.asset_root("13341/"),"Map/13341/")
        self.assertIsNone(PACK.candidate_origin("Map/0/800f7ff3e.s32"))
        self.assertEqual(PACK.candidate_origin("Map/0/80008000.s32"),[32768,32768])
        with self.assertRaisesRegex(ValueError,"SEG"):
            PACK.read_s32(minimal(),"Map/0/80008000.seg")

    def test_counts_tail_and_core_truncation_are_bounded(self):
        raw = minimal()
        for cut in (0,32767,32769,49153,49165):
            with self.subTest(cut=cut),self.assertRaises(ValueError): PACK.read_s32(raw[:cut],"Map/0/fixture.s32")
        for offset,fmt in ((32768,"H"),(49154,"I"),(49158,"I"),(49162,"I")):
            corrupt = bytearray(raw)
            struct.pack_into("<"+fmt,corrupt,offset,65535 if fmt=="H" else 0xffffffff)
            with self.subTest(offset=offset),self.assertRaises(ValueError): PACK.read_s32(bytes(corrupt),"Map/0/fixture.s32")
        with self.assertRaisesRegex(ValueError,"tail"):
            PACK.read_s32(minimal(bytes(1024*1024+1)),"Map/0/fixture.s32")

    def make_fixture(self, root):
        source = root/"source"
        files = [("Map/0/80008000.s32","0/",minimal()),
                 ("Map/13341/800f7ff3e.s32","13341",minimal(b"opaque"))]
        for member,_,raw in files:
            path=source/member;path.parent.mkdir(parents=True,exist_ok=True);path.write_bytes(raw)
        # Native table identity is replaced only for this explicitly authored
        # fixture; production still requires its literal independent SHA pin.
        lands=[{"ID":0,"Name":"fixture","AssetPath":"0/"},{"ID":12156,"Name":"fixture_shared","AssetPath":"0/"},
               {"ID":47443,"Name":"fixture_no_slash","AssetPath":"13341"}]
        lands += [{"ID":100000+i,"Name":"fixture_unused","AssetPath":"unused/"} for i in range(1062)]
        land_path=root/"Land.json";land_path.write_text(json.dumps({"rows":lands}))
        inventory=fixture_inventory(files);inventory_path=root/"inventory.json"
        inventory_path.write_text(json.dumps(inventory))
        return source,land_path,inventory_path,inventory

    def prepare(self, source, land, inventory):
        with patch.object(PACK,"LAND_SHA256",PACK.sha(land.read_bytes())):
            return PACK.prepare_manifest(source,land,inventory,PACK.sha(inventory.read_bytes()))

    def test_multiasset_shared_land_binding_policy_and_determinism(self):
        with tempfile.TemporaryDirectory() as temporary:
            source,land,path,_=self.make_fixture(Path(temporary))
            first=self.prepare(source,land,path)
            second=self.prepare(source,land,path)
            self.assertEqual(PACK.manifest_bytes(first),PACK.manifest_bytes(second))
            self.assertEqual(first["assets"][0]["land_ids"],[0,12156])
            self.assertEqual(first["assets"][1]["asset_path"],"13341")
            self.assertEqual(first["assets"][1]["source_root"],"Map/13341/")
            self.assertEqual(first["logical_lands"][1]["excluded_content"],["arena"])
            self.assertEqual(len(first["members"]),2)
            self.assertEqual(first["semantics"]["collision"],"UNKNOWN")
            with self.assertRaisesRegex(ValueError,"caller trust pin"):
                PACK.prepare_manifest(source,land,path,"0"*64)
            with self.assertRaisesRegex(ValueError,"independently pinned"):
                PACK.prepare_manifest(source,land,path,PACK.sha(path.read_bytes()))

    def test_malformed_asset_is_quarantined_without_losing_independent_asset(self):
        with tempfile.TemporaryDirectory() as temporary:
            source,land,path,inventory=self.make_fixture(Path(temporary))
            raw=b"authored malformed S32"
            (source/"Map/13341/800f7ff3e.s32").write_bytes(raw)
            row=inventory["members"][1];row.update(bytes=len(raw),sha256=PACK.sha(raw))
            row["provenance"]["expected_member_sha256"]=PACK.sha(raw)
            path.write_text(json.dumps(inventory))
            manifest=self.prepare(source,land,path)
            self.assertEqual(manifest["members"][1]["status"],"quarantined_malformed_s32")
            self.assertEqual(manifest["assets"][0]["status"],"ready")
            self.assertEqual(manifest["assets"][1]["status"],"unavailable_or_quarantined")

    def test_unknown_selection_seg_missing_extra_and_symlink_never_become_ready(self):
        with tempfile.TemporaryDirectory() as temporary:
            source,land,path,inventory=self.make_fixture(Path(temporary))
            inventory["members"][0]["provenance"]["current_selection_verified"]=False
            path.write_text(json.dumps(inventory))
            self.assertEqual(self.prepare(source,land,path)["members"][0]["status"],"unverified_current_selection")
            inventory["members"][0]["provenance"]["current_selection_verified"]=True
            seg=source/"Map/0/extra.seg";seg.write_bytes(b"SEG unsupported bytes")
            with self.assertRaisesRegex(ValueError,"extra"):
                self.prepare(source,land,path)
            inventory["members"] += fixture_inventory([("Map/0/extra.seg","0/",seg.read_bytes())])["members"]
            path.write_text(json.dumps(inventory))
            self.assertEqual(next(row for row in self.prepare(source,land,path)["members"] if row["format"]=="seg")["status"],"unsupported_format")
            seg.unlink();seg.symlink_to(source/"Map/0/80008000.s32")
            with self.assertRaisesRegex(ValueError,"Symlink"):
                self.prepare(source,land,path)

    def test_hardlink_publish_is_private_atomic_and_does_not_change_originals(self):
        with tempfile.TemporaryDirectory() as temporary:
            root=Path(temporary)
            source,land,path,_=self.make_fixture(root)
            manifest=self.prepare(source,land,path)
            originals=[source/row["member"] for row in manifest["members"]]
            for original in originals: original.chmod(0o600)
            before=[(p.read_bytes(),p.stat().st_mode) for p in originals]
            output=root/"private-linked-pack"
            PACK.publish(manifest,source,output,"hardlink")
            for row,original in zip(manifest["members"],originals):
                destination=output/row["path"]
                self.assertEqual(original.stat().st_ino,destination.stat().st_ino)
                self.assertEqual(PACK.sha(destination.read_bytes()),row["sha256"])
            with self.assertRaisesRegex(ValueError,"exists"):
                PACK.publish(manifest,source,output,"hardlink")
            shutil.rmtree(output)
            self.assertEqual(before,[(p.read_bytes(),p.stat().st_mode) for p in originals])
            originals[0].chmod(0o644)
            with self.assertRaisesRegex(ValueError,"private immutable"):
                PACK.publish(manifest,source,root/"unsafe-linked-pack","hardlink")
            self.assertFalse((root/"unsafe-linked-pack").exists())
            self.assertEqual(originals[0].stat().st_mode & 0o777,0o644)
            self.assertFalse(list(root.glob(".source523-*")))

    def test_gzip_strict_bounded_roundtrip_and_corruption(self):
        raw=minimal();stored=gzip.compress(raw,compresslevel=6,mtime=0)
        self.assertEqual(PACK.decode_gzip(stored,len(raw)),raw)
        for bad in (stored[:-1],stored+stored,stored+stored[-8:]):
            with self.subTest(case=len(bad)),self.assertRaises(ValueError): PACK.decode_gzip(bad,len(raw))
        bad=bytearray(stored);bad[-8]^=1
        with self.assertRaisesRegex(ValueError,"gzip"):
            PACK.decode_gzip(bytes(bad),len(raw))
        with self.assertRaisesRegex(ValueError,"ISIZE"):
            PACK.decode_gzip(stored,len(raw)+1)
        bomb=bytearray(gzip.compress(b"A"*(1024*1024),mtime=0));struct.pack_into("<I",bomb,len(bomb)-4,64)
        with self.assertRaises(ValueError): PACK.decode_gzip(bytes(bomb),64)
        bad=bytearray(stored);bad[3]=8
        with self.assertRaisesRegex(ValueError,"header"):
            PACK.decode_gzip(bytes(bad),len(raw))
        row={"member":"Map/0/80008000.s32","bytes":len(raw),"sha256":PACK.sha(raw)}
        info={"storage_format":"gzip","stored_bytes":len(stored),"stored_sha256":"0"*64}
        with self.assertRaisesRegex(ValueError,"Stored"):
            PACK.verify_payload(stored,row,info)
        info["stored_sha256"]=PACK.sha(stored);row["sha256"]="0"*64
        with self.assertRaisesRegex(ValueError,"Original"):
            PACK.verify_payload(stored,row,info)

    def test_gzip_canonical_resolution_pinning_and_unclaimed_paths(self):
        with tempfile.TemporaryDirectory() as temporary:
            root=Path(temporary);source,land,path,inventory=self.make_fixture(root)
            row=inventory["members"][0];original=source/row["member"];raw=original.read_bytes()
            gz=source/(row["member"]+".gz");gz.write_bytes(gzip.compress(raw,mtime=0));gz.chmod(0o600)
            decoded,info,physical,_=PACK.canonical_source(source,row)
            self.assertEqual(decoded,raw);self.assertEqual(info["storage_format"],"gzip");self.assertEqual(physical,gz)
            manifest=self.prepare(source,land,path);item=next(x for x in manifest["members"]if x["member"]==row["member"])
            self.assertEqual(item["path"],"originals/"+row["member"]+".gz")
            self.assertEqual(item["bytes"],len(raw));self.assertEqual(item["sha256"],PACK.sha(raw))
            pinned={**row,**info};pinned["stored_sha256"]="0"*64
            with self.assertRaisesRegex(ValueError,"pinned input"):
                PACK.canonical_source(source,pinned)
            original.write_bytes(b"X"+raw[1:])
            with self.assertRaisesRegex(ValueError,"Original"):
                PACK.canonical_source(source,row)
            original.write_bytes(raw)
            stray=source/"Map/0/unclaimed.s32.gz";stray.write_bytes(gz.read_bytes())
            with self.assertRaisesRegex(ValueError,"extra"):
                self.prepare(source,land,path)
            stray.unlink()
            output=root/"gzip-pack";PACK.publish(manifest,source,output,"hardlink")
            self.assertEqual((output/item["path"]).stat().st_ino,gz.stat().st_ino)
            malicious=copy.deepcopy(manifest);malicious["members"][0]["path"]="../escape.s32.gz"
            with self.assertRaisesRegex(ValueError,"Noncanonical"):
                PACK.publish(malicious,source,root/"bad-path","hardlink")
            self.assertFalse((root/"escape.s32.gz").exists())

    def test_explicit_gzip_input_retirement_preserves_old_pack_and_is_idempotent(self):
        with tempfile.TemporaryDirectory() as temporary:
            root=Path(temporary);source,land,path,_=self.make_fixture(root)
            manifest=self.prepare(source,land,path)
            for row in manifest["members"]:(source/row["member"]).chmod(0o600)
            old=root/"old-pack";PACK.publish(manifest,source,old,"hardlink")
            pin=PACK.sha(path.read_bytes())
            with patch.object(PACK,"LAND_SHA256",PACK.sha(land.read_bytes())):
                receipt=PACK.gzip_inputs(source,land,path,pin)
            self.assertEqual(len(receipt["members"]),2)
            for row in manifest["members"]:
                self.assertFalse((source/row["member"]).exists())
                gz=source/(row["member"]+".gz")
                self.assertEqual(PACK.sha(PACK.decode_gzip(gz.read_bytes(),row["bytes"])),row["sha256"])
                self.assertEqual(PACK.sha((old/row["path"]).read_bytes()),row["sha256"])
            with patch.object(PACK,"LAND_SHA256",PACK.sha(land.read_bytes())):
                resumed=PACK.gzip_inputs(source,land,path,pin)
            self.assertFalse(any(x["raw_canonical_retired"]for x in resumed["members"]))
            self.assertFalse(list(source.glob(".gzip-input-*")))

    def test_gzip_transaction_rolls_back_after_raw_unlink_failure(self):
        with tempfile.TemporaryDirectory() as temporary:
            root=Path(temporary);source,land,path,inventory=self.make_fixture(root)
            row=inventory["members"][0];original=source/row["member"];original.chmod(0o600);before=original.read_bytes()
            other=root/"old-immutable-original.s32";PACK.os.link(original,other)
            real=PACK._fsync_directory;calls=[]
            def fail_after_retirement(directory):
                calls.append(str(directory))
                if len(calls)==4:raise OSError("injected retirement fsync failure")
                return real(directory)
            with patch.object(PACK,"_fsync_directory",side_effect=fail_after_retirement):
                with self.assertRaisesRegex(OSError,"injected"):
                    PACK.gzip_input_member(source,row)
            self.assertEqual(original.read_bytes(),before)
            self.assertEqual(other.read_bytes(),before)
            self.assertEqual(original.stat().st_ino,other.stat().st_ino)
            self.assertFalse((source/(row["member"]+".gz")).exists())
            self.assertFalse(list(source.glob(".gzip-input-*")))


if __name__ == "__main__":
    unittest.main()
