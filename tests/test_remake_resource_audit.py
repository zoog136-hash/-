import importlib.util
from pathlib import Path
import unittest

from PIL import Image


SPEC = importlib.util.spec_from_file_location("audit", Path(__file__).resolve().parents[1] / "tools/remake_resource_audit.py")
AUDIT = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(AUDIT)


class FrameEvidenceTests(unittest.TestCase):
    def test_translation_and_repeated_cells_are_not_unique_poses(self):
        sheet = Image.new("RGBA", (24, 8))
        for x in (1, 10, 18):
            sheet.paste((255, 0, 0, 255), (x, 2, x + 2, 5))
        result = AUDIT.frame_stats(sheet, {"cell": [8, 8], "tracks": [{"name": "walk_down", "row": 0, "count": 3, "fps": 8}]})
        track = result["tracks"]["walk_down"]
        self.assertEqual(track["cells"], 3)
        self.assertEqual(track["unique_rgba_frames"], 2)
        self.assertEqual(track["unique_alpha_cropped_frames"], 1)

    def test_hidden_rgb_and_empty_pixels_cannot_inflate_pose_count(self):
        first = Image.new("RGBA", (8, 8), (255, 0, 0, 0))
        second = Image.new("RGBA", (8, 8), (0, 0, 255, 0))
        self.assertEqual(AUDIT.pixel_hash(first), AUDIT.pixel_hash(second))
        self.assertEqual(AUDIT.pixel_hash(first, True), "empty")

    def test_out_of_bounds_frame_layout_is_rejected(self):
        with self.assertRaises(ValueError):
            AUDIT.frame_stats(Image.new("RGBA", (8, 8)), {"cell": [8, 8], "tracks": [{"name": "walk", "row": 0, "count": 2}]})

    def test_duplicate_item_bytes_do_not_require_same_file_path(self):
        rows = {"item:1": {"source": {"path": "a.png", "sha256": "same"}},
                "item:2": {"source": {"path": "b.png", "sha256": "same"}},
                "item:3": {"source": {"path": "", "sha256": None}}}
        self.assertEqual(AUDIT.duplicate_groups(rows, "path"), [])
        self.assertEqual(AUDIT.duplicate_groups(rows, "sha256"), [{"sha256": "same", "ids": ["item:1", "item:2"]}])


if __name__ == "__main__":
    unittest.main()
