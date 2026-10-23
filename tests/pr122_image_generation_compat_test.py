"""Regression: unsupported 'reasoning' never reaches the images endpoint payload."""
from pathlib import Path
import importlib.util
import unittest
from unittest.mock import patch
import base64
import io
import json
import tempfile
from urllib.error import HTTPError

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

    def test_actual_http_boundary_removes_text_model_options(self):
        payload = tool.make_payload("unchanged saved prompt", "run")
        payload.update({"reasoning": {"effort": "high"}, "temperature": 0.5,
                        "text": {"format": "json"}, "max_output_tokens": 3000})
        response = json.dumps({"data": [{"b64_json": base64.b64encode(tool.PNG_SIGNATURE).decode()}]})
        with patch.object(tool, "urlopen", return_value=io.StringIO(response)) as transport:
            tool.generate(payload, "test-key-never-printed")
        sent = json.loads(transport.call_args.args[0].data)
        self.assertEqual(set(sent), tool.IMAGE_FIELDS)
        self.assertEqual(sent["prompt"], "unchanged saved prompt")
        self.assertEqual(transport.call_count, 1)

    def test_current_retry_prompt_is_preserved(self):
        source = ROOT / "docs/remake/pr122-hero-parallel/evidence/visual-review-20261023/image-generation-retry.json"
        expected = json.loads(source.read_text())["request"]["prompt"]
        self.assertEqual(tool.load_prompt(source, "run"), expected)
        with self.assertRaises(ValueError):
            tool.load_prompt(source, "attack")

    def test_http_400_is_not_retried(self):
        error = HTTPError(tool.ENDPOINT, 400, "Bad request", {},
                          io.BytesIO(b'{"error":{"message":"Unknown parameter: reasoning"}}'))
        with patch.object(tool, "urlopen", side_effect=error) as transport:
            with self.assertRaisesRegex(RuntimeError, "HTTP 400"):
                tool.generate(tool.make_payload("saved prompt", "run"), "test-key-never-printed")
        self.assertEqual(transport.call_count, 1)

    def test_successful_response_is_decoded_and_saved_without_claiming_approval(self):
        from PIL import Image
        png = io.BytesIO()
        Image.new("RGBA", (16, 16), (200, 100, 20, 255)).save(png, format="PNG")
        response = json.dumps({"data": [{"b64_json": base64.b64encode(png.getvalue()).decode()}]})
        with tempfile.TemporaryDirectory() as tmp, patch.dict(tool.os.environ, {"OPENAI_API_KEY": "fake-fixture-key"}):
            output, receipt = Path(tmp) / "source.png", Path(tmp) / "result.json"
            with patch.object(tool, "urlopen", return_value=io.StringIO(response)), patch("sys.stdout", new_callable=io.StringIO):
                code = tool.main(["--task", "run", "--source", str(ROOT / tool.SOURCE), "--size", "16x16",
                                  "--execute", "--confirm-billing", "--output", str(output), "--receipt", str(receipt)])
            self.assertEqual(code, 0)
            self.assertEqual(output.read_bytes(), png.getvalue())
            result = json.loads(receipt.read_text())
            self.assertEqual(result["result"], "SAVED_UNAPPROVED_SOURCE")
            self.assertEqual(result["dimensions"], [16, 16])

    def test_missing_credential_sends_no_request_and_writes_receipt(self):
        with tempfile.TemporaryDirectory() as tmp, patch.dict(tool.os.environ, {}, clear=True):
            receipt = Path(tmp) / "result.json"
            with patch.object(tool, "urlopen") as transport:
                code = tool.main(["--task", "run", "--source", str(ROOT / tool.SOURCE),
                                  "--execute", "--confirm-billing", "--output", str(Path(tmp) / "source.png"),
                                  "--receipt", str(receipt)])
            self.assertEqual(code, 2)
            transport.assert_not_called()
            result = json.loads(receipt.read_text())
            self.assertEqual(result["result"], "BLOCKED_CREDENTIAL_NOT_CONFIGURED")
            self.assertEqual(result["http_requests"], 0)
            self.assertFalse((Path(tmp) / "source.png").exists())


if __name__ == "__main__":
    unittest.main()
