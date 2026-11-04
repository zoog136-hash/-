import hashlib
import json
from pathlib import Path
import sys
import tempfile
import unittest
import zipfile

ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/"tools/shop"))
import source523_runtime_pack as runtime


class RuntimeInstallTest(unittest.TestCase):
    def fixture(self,directory):
        root=Path(directory)
        shop=root/"shop.json";shop.write_text(json.dumps({"schema":"twilight.source523.shop.v1","source_zip_sha256":"a"*64}))
        npc=root/"npc.json";npc.write_text(json.dumps({"schema":"twilight.source523.npc-definitions.v1","revision":2,"source_zip_sha256":"a"*64,"shop_pack_sha256":hashlib.sha256(shop.read_bytes()).hexdigest()}))
        pack=root/"runtime.zip";receipt=runtime.package(shop,npc,pack)
        return shop,npc,pack,receipt

    def test_fresh_install_checks_members_and_preserves_inputs(self):
        with tempfile.TemporaryDirectory() as directory:
            shop,npc,pack,receipt=self.fixture(directory)
            before=(shop.read_bytes(),npc.read_bytes())
            installed=runtime.install(pack,receipt["sha256"],Path(directory)/"applied")
            self.assertEqual((shop.read_bytes(),npc.read_bytes()),before)
            self.assertEqual((Path(installed["directory"])/"shop523.json").read_bytes(),before[0])
            self.assertEqual(len(installed["arguments"]),4)

    def test_wrong_archive_hash_creates_no_install(self):
        with tempfile.TemporaryDirectory() as directory:
            _,_,pack,_=self.fixture(directory);target=Path(directory)/"applied"
            with self.assertRaisesRegex(ValueError,"SHA256 mismatch"):runtime.install(pack,"0"*64,target)
            self.assertFalse(target.exists())

    def test_existing_consumer_data_is_never_overwritten(self):
        with tempfile.TemporaryDirectory() as directory:
            _,_,pack,receipt=self.fixture(directory);target=Path(directory)/"applied";target.mkdir()
            (target/"user-save.json").write_bytes(b"preserve")
            with self.assertRaisesRegex(ValueError,"fresh consumer"):runtime.install(pack,receipt["sha256"],target)
            self.assertEqual((target/"user-save.json").read_bytes(),b"preserve")

    def test_path_traversal_zip_is_rejected(self):
        with tempfile.TemporaryDirectory() as directory:
            pack=Path(directory)/"bad.zip"
            with zipfile.ZipFile(pack,"w") as archive:archive.writestr("../escape.json",b"bad")
            with self.assertRaisesRegex(ValueError,"unexpected"):runtime.install(pack,hashlib.sha256(pack.read_bytes()).hexdigest(),Path(directory)/"applied")
            self.assertFalse((Path(directory)/"escape.json").exists())

    def test_private_pack_cannot_install_inside_public_repo(self):
        with self.assertRaisesRegex(ValueError,"outside the Git"):runtime.install("missing.zip","0"*64,ROOT/"private-install")


if __name__=="__main__":unittest.main()
