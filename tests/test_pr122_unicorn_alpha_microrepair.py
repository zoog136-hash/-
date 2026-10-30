"""Synthetic contract tests only; fixtures do not approve game animation."""
import hashlib
import io
import sys
import tempfile
import unittest
from argparse import Namespace
from pathlib import Path
from zipfile import ZipFile

import numpy as np
from PIL import Image

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "tools"))
import pr122_unicorn_alpha_microrepair as repair


def source(island=1, edge=False):
    rgba = np.zeros((80, 80, 4), dtype=np.uint8)
    rgba[20:55, 20:55] = [57, 76, 113, 255]
    rgba[8:8 + island, 7:7 + island] = [180, 200, 229, 230]
    if edge:
        rgba[0, 43] = [255, 255, 255, 255]
    b = io.BytesIO()
    Image.fromarray(rgba, "RGBA").save(b, format="PNG")
    return b.getvalue(), rgba


class AlphaContract(unittest.TestCase):
    def test_microedit_changes_only_detached_pixels(self):
        original, rgba = source()
        report, output = repair.propose(original)
        self.assertEqual(report["status"], "UNAPPROVED_ALPHA_MICROCANDIDATE")
        self.assertEqual((report["visible_components_before"], report["visible_components_after"]), (2, 1))
        self.assertEqual(report["changed_pixels"], 1)
        self.assertEqual(report["original_sha256"], hashlib.sha256(original).hexdigest())
        with Image.open(io.BytesIO(output)) as im:
            patched = np.asarray(im)
        delta = np.any(patched != rgba, axis=2)
        self.assertEqual(int(delta.sum()), 1)
        self.assertTrue(delta[8, 7])
        self.assertTrue(np.array_equal(patched[20:55, 20:55], rgba[20:55, 20:55]))
        self.assertEqual(patched[8, 7].tolist(), [0, 0, 0, 0])
        self.assertFalse(report["approved"] or report["production_applied"])
        self.assertEqual(report["completed_added"], 0)

    def test_rejects_large_islands_boundary_and_clean_source(self):
        for island, edge in [(4, False), (1, True)]:
            report, output = repair.propose(source(island, edge)[0])
            self.assertEqual(report["status"], "REFUSED")
            self.assertIsNone(output)
        rgba = np.zeros((80, 80, 4), dtype=np.uint8)
        rgba[20:55, 20:55] = [57, 76, 113, 255]
        b = io.BytesIO(); Image.fromarray(rgba, "RGBA").save(b, format="PNG")
        report, output = repair.propose(b.getvalue())
        self.assertEqual(report["status"], "REFUSED")
        self.assertIsNone(output)

    def test_pinned_archive_and_source_sha(self):
        original, _ = source()
        with tempfile.TemporaryDirectory() as td:
            archive = Path(td) / "archive.zip"
            with ZipFile(archive, "w") as package:
                package.writestr("unicorn/source.png", original)
            args = Namespace(input=None, archive=archive, member="unicorn/source.png",
                             archive_sha256=repair.sha(archive.read_bytes()), source_sha256=repair.sha(original))
            name, data = repair.pinned_source(args)
            self.assertEqual((name, data), ("source.png", original))
            args.archive_sha256 = "0" * 64
            with self.assertRaises(ValueError): repair.pinned_source(args)
            args.archive_sha256 = repair.sha(archive.read_bytes()); args.member = "../bad.png"
            with self.assertRaises(ValueError): repair.pinned_source(args)
            args.member = "unicorn/source.png"; args.source_sha256 = "0" * 64
            with self.assertRaises(ValueError): repair.pinned_source(args)


if __name__ == "__main__":
    unittest.main()
