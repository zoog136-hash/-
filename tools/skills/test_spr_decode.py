#!/usr/bin/env python3
"""Small synthetic tests; no original assets or network required."""
import struct
import unittest
from spr_decode import DecodeError, Sprite, grid_xy, ref_client_xy


def fixture(*, palette=False, wrapper=False, refs=None, gap=0, color=0x7c00,
            palette_index=0, trailer=b""):
    refs = refs if refs is not None else [[(0,0,255,0)], [(2,0,7,0)]]
    block = struct.pack("<4B", 1,2,1,1) + bytes([1,gap,1])
    prefix = bytes([len(refs)])
    if palette:
        prefix = bytes([255,1]) + struct.pack("<H",color) + prefix
        block += bytes([palette_index])
    else:
        block += struct.pack("<H",color)
    frames = b""
    for rr in refs:
        frames += struct.pack("<4h3H", -20,-30,40,50,0xabcd,0xffee,len(rr))
        frames += b"".join(struct.pack("<bbBH",*r) for r in rr)
    return (b"SPR_0" if wrapper else b"")+prefix+frames+struct.pack("<III",1,0,12345)+block+trailer


class DecoderTests(unittest.TestCase):
    def test_rgb555_exact_transparency(self):
        s = Sprite(fixture())
        im, meta = s.render(0)
        self.assertEqual(im.getpixel((1,2)), (255,0,0,255))
        self.assertEqual(im.getpixel((0,0)), (0,0,0,0))
        self.assertEqual(meta["nonzero_alpha_pixels"],1)

    def test_palette_and_wrapper(self):
        plain = Sprite(fixture())
        palette = Sprite(fixture(palette=True,wrapper=True))
        self.assertEqual(plain.render(0)[0].tobytes(),palette.render(0)[0].tobytes())
        self.assertEqual(palette.metadata()["wrapper"],"SPR_0")
        self.assertEqual(palette.metadata()["palette_rgb555_uint16"],[0x7c00])

    def test_palette_256_count_zero(self):
        data = fixture(palette=True)
        data = bytes([255,0])+struct.pack("<256H",*([0x7c00]*256))+data[4:]
        s = Sprite(data)
        self.assertEqual(len(s.palette),256)
        self.assertEqual(s.render(0)[0].getpixel((1,2)),(255,0,0,255))

    def test_raw_metadata_preserved(self):
        s = Sprite(fixture())
        f = s.metadata()["frames"][0]
        self.assertEqual(f["raw_header_values"],[-20,-30,40,50,0xabcd,0xffee,1])
        self.assertEqual(bytes.fromhex(f["raw_header_hex"]),struct.pack("<4h3H",-20,-30,40,50,0xabcd,0xffee,1))
        self.assertEqual(f["references"][0]["t_opaque_uint8"],255)
        self.assertEqual(f["references"][0]["raw_hex"],struct.pack("<bbBH",0,0,255,0).hex())
        self.assertEqual(s.opaque_after_offsets_uint32,12345)

    def test_fixed_canvas_keeps_origins_across_frames(self):
        s = Sprite(fixture())
        a, am = s.render(0,fixed_canvas=True)
        b, bm = s.render(1,fixed_canvas=True)
        self.assertEqual(a.size,b.size)
        self.assertEqual(am["canvas_bounds"],[0,-12,48,24])
        self.assertEqual(am["original_grid_origin_in_canvas"],bm["original_grid_origin_in_canvas"])
        self.assertNotEqual(am["alpha_bbox_in_canvas"],bm["alpha_bbox_in_canvas"])

    def test_explicit_canvas_rejects_clipping(self):
        s = Sprite(fixture())
        with self.assertRaises(DecodeError):s.render(0,canvas_bounds=[0,0,1,1])
        with self.assertRaises(DecodeError):s.render(0,canvas_bounds=[0,0,100000,100000])
        im,_ = s.render(0,canvas_bounds=[-24,-24,48,48])
        self.assertEqual(im.size,(72,72))

    def test_reference_client_c_integer_math_all_signed_x(self):
        # Independent transcription of sprite_motion.cpp 306-320.
        for x in range(-128,128):
            for y in (-128,-3,0,1,127):
                a,b=x-4,y+1
                q=int(a/2)  # C++ truncates division toward zero.
                rem=a-2*q
                px,py=24*(q+b),12*(b-q)
                if rem==1:px+=24
                elif rem==-1:py+=12
                self.assertEqual(ref_client_xy(x,y),(px,py))
                gx,gy=grid_xy(x,y)
                self.assertEqual((px-gx,py-gy),(-24,36))

    def test_reference_client_pixels_equivalent_origin_different(self):
        s = Sprite(fixture())
        a,am=s.render(0,fixed_canvas=True)
        b,bm=s.render(0,fixed_canvas=True,coordinate_system="reference-client")
        self.assertEqual(a.tobytes(),b.tobytes())
        self.assertEqual(am["original_grid_origin_in_canvas"],bm["original_grid_origin_in_canvas"])
        self.assertEqual(am["reference_client_origin_in_canvas"],bm["reference_client_origin_in_canvas"])
        self.assertIsNone(am["foot_anchor"])

    def test_invalid_frame_never_clamps(self):
        s=Sprite(fixture())
        for frame in (-1,2,100):
            with self.assertRaises(DecodeError):s.render(frame)

    def test_invalid_refs_palette_and_wrapper(self):
        with self.assertRaises(DecodeError):Sprite(fixture(refs=[[(0,0,0,1)]]))
        with self.assertRaises(DecodeError):Sprite(fixture(palette=True,palette_index=1))
        with self.assertRaises(DecodeError):Sprite(b"SPR_1"+fixture())

    def test_truncations_and_bad_rle(self):
        data=fixture()
        for stop in range(len(data)):
            with self.assertRaises(DecodeError):Sprite(data[:stop])
        with self.assertRaises(DecodeError):Sprite(fixture(gap=48))

    def test_odd_gap_trailer_reported(self):
        s=Sprite(fixture(gap=1,trailer=b"TAIL"))
        self.assertEqual(s.trailing_bytes,4)
        self.assertEqual(len(s.warnings),2)

    def test_empty_frames_and_zero_frames(self):
        s=Sprite(fixture(refs=[[]]))
        im,m=s.render(0)
        self.assertEqual(im.size,(1,1))
        self.assertIsNone(m["alpha_bbox_in_canvas"])
        zero=Sprite(bytes([0])+struct.pack("<II",0,0))
        self.assertEqual(zero.metadata()["frame_count"],0)
        with self.assertRaises(DecodeError):zero.render(0)

    def test_no_white_yellow_colorkey_guess(self):
        for color, rgb in [(0x7fff,(255,255,255)),(0x7fe0,(255,255,0)),(0,(0,0,0))]:
            im,_=Sprite(fixture(color=color)).render(0)
            self.assertEqual(im.getpixel((1,2)),rgb+(255,))


if __name__=="__main__":
    unittest.main(verbosity=2)
