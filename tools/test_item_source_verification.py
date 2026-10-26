"""Regression for exact structured identity, not keyword matches on related items."""
import html
import json
import unittest
from pathlib import Path
from tempfile import TemporaryDirectory
from unittest.mock import patch
import verify_item_source_images as verifier
from check_item_visuals import runtime_image_dimensions


class ExactSourceIdentity(unittest.TestCase):
    record = {"sourceId":"42", "name":"같은 이름", "sourceUrl":"https://lineagem.inven.co.kr/db/item/42",
              "sourceImageUrl":"https://static.inven.co.kr/exact.png"}

    def result(self, **overrides):
        item = {"code":42, "name":"같은 이름", "icon":self.record["sourceImageUrl"]} | overrides
        props = html.escape(json.dumps({"code":42,"item":item}), quote=True)
        page = f'<div id="lineagemDbItem" data-props="{props}"></div>'.encode()
        with patch.object(verifier, "fetch", return_value=page):
            return verifier.verify_record(self.record)[1]

    def test_nested_item_and_all_three_fields(self):
        result = self.result()
        self.assertTrue(all(result[k] for k in ["exact_id_found","exact_name_found","exact_image_found"]))

    def test_same_name_different_id(self):
        self.assertFalse(self.result(code=43)["exact_id_found"])

    def test_similar_name(self):
        self.assertFalse(self.result(name="같은 이름 (각인)")["exact_name_found"])

    def test_other_icon(self):
        self.assertFalse(self.result(icon="https://static.inven.co.kr/other.png")["exact_image_found"])

    def test_related_page_text_is_not_identity_evidence(self):
        page = f'<p>{self.record["name"]} {self.record["sourceImageUrl"]}</p>'.encode()
        with patch.object(verifier, "fetch", return_value=page):
            self.assertIn("error", verifier.verify_record(self.record)[1])

    def test_mismatching_detail_url_rejected_before_network(self):
        with patch.object(verifier, "fetch") as fetch:
            result = verifier.verify_record(self.record | {"sourceId":"43"})[1]
            self.assertIn("error", result)
            fetch.assert_not_called()


class RuntimeSvgArtwork(unittest.TestCase):
    def test_six_card_pack_icons_have_valid_viewports(self):
        paths = sorted(Path("assets/card_packs").glob("*.svg"))
        self.assertEqual(len(paths), 6)
        for path in paths:
            with self.subTest(path=path):
                self.assertEqual(runtime_image_dimensions(path), [144, 144])

    def test_scripted_and_external_svg_rejected(self):
        prefix = '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 144 144">'
        suffix = "</svg>"
        with TemporaryDirectory() as directory:
            local = Path(directory) / "untrusted.svg"
            for markup in ('<script/>', '<image href="https://example.org/not-local.png"/>'):
                with self.subTest(markup=markup):
                    local.write_text(prefix + '<rect width="10" height="10"/>' + markup + suffix)
                    with self.assertRaises(ValueError):
                        runtime_image_dimensions(local)


if __name__ == "__main__":
    unittest.main()
