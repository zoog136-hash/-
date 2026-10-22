"""Regression: unsupported 'reasoning' never reaches the images endpoint payload."""
from pathlib import Path
import importlib.util
import unittest

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location("image_compat", ROOT / "tools/pr122_image_generation_compat.py")
tool = importlib.util.module_from_spec(spec)
spec.loader.exec_module(tool)


class TestImageCompatibility(unittest.TestCase):
    def test_saved_requests_payload(self):
        source = ROOT / "docs/remake/pr122-hero-parallel/evidence/next-unique-20261022/image-tool-failure.json"
        for task in ("run", "attack", "support", "death"):
            with self.subTest(task=task):
                prompt = tool.load_prompt(source, task)
                payload = tool.make_payload(prompt, task)
                self.assertNotIn("reasoning", payload)
                self.assertEqual(payload["prompt"], prompt)
                self.assertEqual(payload["size"], tool.TASK_SIZES[task])
                self.assertEqual(set(payload), {"model", "prompt", "n", "size", "quality", "background", "output_format"})

    def test_invalid_fields_rejected(self):
        with self.assertRaises(ValueError):
            tool.make_payload("", "run")
        with self.assertRaises(ValueError):
            tool.make_payload("test", "unknown")
        with self.assertRaises(ValueError):
            tool.make_payload("test", "run", size="1537x2048")


if __name__ == "__main__":
    unittest.main()
