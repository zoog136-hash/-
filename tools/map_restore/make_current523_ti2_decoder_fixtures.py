#!/usr/bin/env python3
"""Make tiny synthetic runtime TI2 fixtures; never original-resource evidence.

The expected bytes come from the existing Python candidate-coverage helper.
No original archive, source record, manifest pin, or resource ledger is changed.
"""

import argparse
import copy
import json
from pathlib import Path

import current523_tile_review as review
from test_current523_tile_review import compress, decoded_fixture


def empty_blocks():
    return [{"flags": 0, "offset": (0, 0), "runs": (), "pixels": b""}
            for _ in range(256)]


def metadata(raw, parsed, compressed, rgba_digest):
    return {"source_bytes": len(compressed), "source_sha256": review.sha256(compressed),
            "decoded_bytes": len(raw), "decoded_sha256": review.sha256(raw),
            "blocks": len(parsed["blocks"]), "atlas_size": [384, 384],
            "atlas_rgba_sha256": rgba_digest,
            "stored_pixels": sum(block["pixel_count"] for block in parsed["blocks"]),
            "raw_header_u32": parsed["header"],
            "palette_colors": len(parsed["palette_u16le"]) // 2,
            "palette_u16le_sha256": review.sha256(parsed["palette_u16le"]),
            "raw_sections": copy.deepcopy(parsed["sections"]), "raw_decoded_roundtrip": True}


def generate(output):
    output.mkdir(parents=True, exist_ok=True)
    cases = []

    def store(name, raw, valid=True, parsed=None, row=None):
        compressed = compress(raw)
        rgba_path = ""
        if not valid:
            try:
                review.render_atlas(review.parse_ti2(raw))
            except ValueError:
                pass
            else:
                raise AssertionError("Malformed fixture unexpectedly accepted by Python: " + name)
        if parsed is None and row is None:
            parsed = review.parse_ti2(raw)
        if row is None:
            rgba = review.render_atlas(parsed).tobytes() if valid else b""
            row = metadata(raw, parsed, compressed, review.sha256(rgba))
        else:
            row = copy.deepcopy(row)
            row.update(source_bytes=len(compressed), source_sha256=review.sha256(compressed),
                       decoded_bytes=len(raw), decoded_sha256=review.sha256(raw))
        if valid:
            rgba_path = "expected-" + row["atlas_rgba_sha256"] + ".rgba"
            (output / rgba_path).write_bytes(rgba)
        raw_path, compressed_path = name + ".raw", name + ".br"
        (output / raw_path).write_bytes(raw)
        (output / compressed_path).write_bytes(compressed)
        cases.append({"name": name, "valid": valid, "raw_path": raw_path,
                      "compressed_path": compressed_path, "rgba_path": rgba_path, "row": row})
        return row

    # Each command advances x immediately; a nonzero row step applies after its
    # write, resets x to the descriptor origin, and can occur without a write.
    blocks = empty_blocks()
    blocks[0] = {"flags": 0xb4, "offset": (1, 2),
                 "runs": (0x0040, 0x0821, 0x0003, 0x0020, 0x0400, 0x8022),
                 "pixels": bytes([0, 1, 2, 3, 0])}
    blocks[1] = {"flags": 0xc0, "offset": (0, 0), "runs": (), "pixels": bytes([3]) * 288}
    blocks[2] = {"flags": 0xc1, "offset": (0, 0), "runs": (), "pixels": bytes([2]) * 288}
    blocks[255] = {"flags": 0x80, "offset": (23, 23), "runs": (1 << 5,), "pixels": b"\x00"}
    raw = decoded_fixture(blocks, extra_header=0x80000000)
    base = store("commandwise_unknown_bits_and_triangles", raw)

    blocks = empty_blocks()
    blocks[0] = {"flags": 0, "offset": (0, 0), "runs": (2 << 5,), "pixels": bytes([0, 255])}
    store("palette_zero_count_means_256", decoded_fixture(blocks, palette=tuple(range(256))))
    store("empty_stored_pixels", decoded_fixture(empty_blocks(), palette=(0,)))
    blocks = empty_blocks()
    blocks[0] = {"flags": 0x80, "offset": (250, 250), "runs": (31 | (31 << 10),), "pixels": b""}
    store("nonwriting_cursor_outside_is_ignored", decoded_fixture(blocks, palette=(0,)))

    # Hash-consistent malformed indices reach the grammar without a SHA failure.
    bad = bytearray(raw)
    index_start = base["raw_sections"]["indices"]["offset"]
    bad[index_start] = 4
    changed = copy.deepcopy(base)
    changed["raw_sections"]["indices"]["sha256"] = review.sha256(bytes(bad[index_start:]))
    store("palette_index_out_of_range", bytes(bad), False, row=changed)

    # The Python parser preserves raw unsigned coordinates; the candidate
    # renderer rejects only actual writes outside the 24x24 block canvas.
    for name, origin, runs in (("canvas_x_overflow", (23, 0), (2 << 5,)),
                               ("canvas_y_outside", (0, 24), (1 << 5,)),
                               ("canvas_row_step_overflow", (0, 0), ((1 << 5) | (31 << 10), 1 << 5))):
        blocks = empty_blocks()
        blocks[0] = {"flags": 0, "offset": origin, "runs": runs,
                     "pixels": bytes(sum((word >> 5) & 31 for word in runs))}
        store(name, decoded_fixture(blocks), False)

    sections = base["raw_sections"]
    cuts = (0, 3, 4, sections["flags"]["offset"] - 1,
            sections["descriptors"]["offset"] - 1,
            sections["descriptors"]["offset"] + 2,
            sections["indices"]["offset"] - 1, len(raw) - 1)
    for cut in cuts:
        store("truncated_at_" + str(cut), raw[:cut], False, row=base)

    changed = copy.deepcopy(base)
    changed["stored_pixels"] += 1
    changed["raw_sections"]["indices"]["bytes"] += 1
    changed["raw_sections"]["indices"]["sha256"] = review.sha256(raw[index_start:] + b"\x00")
    store("unconsumed_decoded_tail", raw + b"\x00", False, row=changed)

    # Keep structural section metadata coherent while disagreeing with the
    # actual physical header/palette; the decoder must inspect the raw bytes.
    for name, changed_raw in (("raw_header_block_count_255", bytes([255]) + raw[1:]),
                               ("raw_header_no_palette", bytes([0, 1, 0, 128]) + raw[4:]),
                               ("raw_palette_count_disagrees", raw[:4] + b"\x03" + raw[5:])):
        changed = copy.deepcopy(base)
        section_name = "palette" if "palette_count" in name else "header"
        section = changed["raw_sections"][section_name]
        start, length = section["offset"], section["bytes"]
        section["sha256"] = review.sha256(changed_raw[start:start + length])
        store(name, changed_raw, False, row=changed)

    document = {"schema": 1, "kind": "SYNTHETIC_NOT_ORIGINAL_EVIDENCE",
                "semantics": dict(review.SEMANTICS), "cases": cases}
    encoded = (json.dumps(document, indent=2, sort_keys=True) + "\n").encode()
    (output / "fixtures.json").write_bytes(encoded)
    result = {"fixture_root": str(output.resolve()), "fixture_manifest_sha256": review.sha256(encoded),
              "valid_cases": sum(case["valid"] for case in cases),
              "invalid_cases": sum(not case["valid"] for case in cases),
              "original_source_members": 0,
              "fixture_bytes": sum(path.stat().st_size for path in output.iterdir() if path.is_file())}
    print("CURRENT523_TI2_DECODER_FIXTURES " + json.dumps(result, sort_keys=True))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    generate(args.output)


if __name__ == "__main__":
    main()
