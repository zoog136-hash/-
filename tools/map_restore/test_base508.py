"""Version-specific safeguards: high TileID bits, lossless tails, truncation."""
import base64
import struct
import unittest
from base508 import read_s32, write_s32, origin


def fixture():
    # Includes TileID > 65535, unsigned object group and opaque tail.
    floor = struct.pack("<I", (0xabcdef << 8) | 254)*8192
    return (floor + struct.pack("<HBBI", 1, 12, 34, 0x12345678)
            + struct.pack("<H", 0x8041)*8192
            + struct.pack("<IHHBBBI", 1, 65535, 1, 4, 5, 200, 0xfedcba98)
            + struct.pack("<I", 1) + b"abcde"
            + struct.pack("<II", 1, 0xabcdef) + b"opaque\x00\xfftail")


class Base508Tests(unittest.TestCase):
    def test_roundtrip_and_high_bits(self):
        data = fixture()
        row = read_s32(data, "Map/13474/7ffd8001.s32")
        self.assertEqual(write_s32(row), data)
        self.assertIn([0xabcdef, 254], row["tile_pairs"])
        self.assertIn([0xfedcba, 152], row["tile_pairs"])
        self.assertEqual(row["objects"][0]["group"], 65535)
        self.assertEqual(row["terrain_collision"], "UNKNOWN")
        self.assertEqual(base64.b64decode(row["uninterpreted_tail"]), b"opaque\x00\xfftail")

    def test_original_origin(self):
        self.assertEqual(origin("Map/13474/7ffd8001.s32"), [32576, 32832])

    def test_truncated_core(self):
        data = fixture()
        for end in (0, 32767, 49158, 49170, len(data)-20):
            with self.assertRaises(ValueError):
                read_s32(data[:end], "Map/0/7ffd8001.s32")

    def test_malicious_count(self):
        data = bytearray(fixture())
        # Cover count cannot point outside the bounded payload.
        struct.pack_into("<H", data, 32768, 65535)
        with self.assertRaises(ValueError):
            read_s32(bytes(data), "7ffd8001.s32")


if __name__ == "__main__":
    unittest.main()
