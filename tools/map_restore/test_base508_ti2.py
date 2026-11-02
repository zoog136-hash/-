"""Pixel coverage, palette precision and source seam regression tests."""
import struct
import unittest
from base508_ti2 import parse, render
from compose_base508 import project


class Ti2Tests(unittest.TestCase):
    def test_default_black_is_opaque_and_outside_is_transparent(self):
        data = struct.pack('<IBH', 4097, 1, 0)+bytes([64])+bytes(288)
        tile = parse(data)
        image = render(tile['blocks'][0], tile['palette'])
        self.assertEqual(image.getpixel((22, 0)), (0, 0, 0, 255))
        self.assertEqual(image.getpixel((0, 0)), (0, 0, 0, 0))
        self.assertEqual(image.getchannel('A').histogram()[255], 288)

    def test_normal_rle_continuation_and_rgb565(self):
        palette = [0, 0xf800, 0x07e0, 0x001f]
        runs = [1 | (2 << 5), 2 | (1 << 5) | (2 << 10), (1 << 5) | (1 << 10)]
        data = struct.pack('<IB4H', 4097, 4, *palette)+bytes([2, 2, 3, 3])+struct.pack('<3H', *runs)+bytes([0, 1, 2, 3])
        tile = parse(data)
        image = render(tile['blocks'][0], tile['palette'])
        self.assertEqual(image.getpixel((3, 3)), (0, 0, 0, 255))
        self.assertEqual(image.getpixel((4, 3)), (255, 0, 0, 255))
        self.assertEqual(image.getpixel((7, 3)), (0, 255, 0, 255))
        self.assertEqual(image.getpixel((2, 5)), (0, 0, 255, 255))
        with self.assertRaises(ValueError): parse(data[:-1])
        with self.assertRaises(ValueError): parse(data+b'unknown')

    def test_invalid_palette_index_is_not_replaced(self):
        data = struct.pack('<IBH', 4097, 1, 0)+bytes([64])+bytes([1])*288
        with self.assertRaises(ValueError): parse(data)

    def test_adjacent_source_chunks_have_exact_seams(self):
        self.assertEqual(project([32576, 32832], 128, 0, [32576, 32832]), project([32640, 32832], 0, 0, [32576, 32832]))
        self.assertEqual(project([32576, 32832], 0, 64, [32576, 32832]), project([32576, 32896], 0, 0, [32576, 32832]))

    def test_display_alpha_does_not_change_raw_palette(self):
        for flags, color, alpha in [(80, 0, 0), (96, 0xffff, 0), (68, 0, 128), (80, 0x8410, 131), (96, 0x8410, 123)]:
            data = struct.pack('<IBH', 4097, 1, color)+bytes([flags])+bytes(288)
            tile = parse(data)
            raw = render(tile['blocks'][0], tile['palette'])
            display = render(tile['blocks'][0], tile['palette'], display_alpha=True)
            self.assertEqual(raw.getpixel((22,0))[3], 255)
            self.assertEqual(display.getpixel((22,0))[:3], raw.getpixel((22,0))[:3])
            self.assertEqual(display.getpixel((22,0))[3], alpha)


if __name__ == '__main__':
    unittest.main()
