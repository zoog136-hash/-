"""Offline stdlib tests for bounded public API evidence probes."""
import importlib.util
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import Mock, patch
from urllib.error import HTTPError
from io import BytesIO

spec = importlib.util.spec_from_file_location("exchange_probe", Path(__file__).parents[1] / "tools/exchange/probe_official.py")
probe = importlib.util.module_from_spec(spec)
spec.loader.exec_module(probe)


class Response(BytesIO):
    code = 200
    headers = {"Date": "Thu, 12 Nov 2026 12:00:00 GMT"}


class ProbeTests(unittest.TestCase):
    def test_capture_reuse_and_tamper(self):
        with tempfile.TemporaryDirectory() as directory:
            output = Path(directory)
            opener = Mock()
            opener.open.return_value = Response(b'{"quantity":7,"salePrice":10}')
            url = probe.BASE + "/game/server"
            self.assertEqual(probe.probe(url, output, opener), "captured")
            self.assertEqual(probe.probe(url, output, opener), "reused")
            self.assertEqual(opener.open.call_count, 1)
            receipt = json.loads(next(output.glob("*.receipt.json")).read_text())
            self.assertEqual(receipt["http_date"], Response.headers["Date"])
            (output / receipt["body_file"]).write_text("{}")
            with self.assertRaises(probe.ProbeError):
                probe.probe(url, output, opener)
            self.assertEqual(opener.open.call_count, 1)

    def test_429_saved_not_retried_or_reused(self):
        with tempfile.TemporaryDirectory() as directory:
            opener = Mock()
            opener.open.side_effect = HTTPError(probe.BASE, 429, "rate limited", {}, BytesIO(b'{"error":"limit"}'))
            for _ in range(2):
                with self.assertRaises(probe.ProbeError):
                    probe.probe(probe.BASE, Path(directory), opener)
            self.assertEqual(opener.open.call_count, 1)
            receipt = json.loads(next(Path(directory).glob("*.receipt.json")).read_text())
            self.assertEqual(receipt["http_status"], 429)

    def test_cli_bounds_and_filters_do_not_request(self):
        with tempfile.TemporaryDirectory() as directory, patch.object(probe, "build_opener") as factory:
            for extra in (("--pages", "11"), ("--delay", "0"), ("--delay", "nan"), ("--item-id", "1")):
                self.assertEqual(probe.main(["--kind", "catalog", "--output", directory, *extra]), 1)
            factory.assert_not_called()

    def test_stock_urls_and_delay(self):
        with tempfile.TemporaryDirectory() as directory, patch.object(probe, "build_opener"), patch.object(probe, "probe", return_value="captured") as call, patch.object(probe.time, "sleep") as sleep:
            self.assertEqual(probe.main(["--kind", "stock", "--server-id", "1", "--item-id", "2", "--enchant-level", "0", "--pages", "2", "--output", directory]), 0)
            self.assertEqual(call.call_count, 2)
            self.assertIn("/item/2/stock?serverId=1&enchantLevel=0&blessedType=0&size=10&page=2", call.call_args.args[0])
            sleep.assert_called_once_with(1.0)

    def test_redirect_denied(self):
        with self.assertRaises(probe.ProbeError):
            probe.NoRedirect().redirect_request(None, None, 302, "", {}, "https://example.com")


if __name__ == "__main__":
    unittest.main()
