#!/usr/bin/env python3
"""Independent failure fixtures for corner-touching art and enclosed glints."""
import sys, unittest
from pathlib import Path
from PIL import Image, ImageDraw
sys.path.insert(0,str(Path(__file__).resolve().parents[1]/'ground_icons'))
from alpha import clear_white_border

class GroundAlphaTests(unittest.TestCase):
    def test_two_occupied_corners_do_not_disable_cleanup(self):
        im=Image.new('RGBA',(11,11),'white');draw=ImageDraw.Draw(im)
        draw.line((0,0,10,10),fill=(40,50,60,255),width=2)
        # Pillow's even-width diagonal cap need not include its endpoint pixel.
        # Set the fixture's two occupied corner pixels explicitly.
        im.putpixel((0,0),(40,50,60,255));im.putpixel((10,10),(40,50,60,255))
        out=clear_white_border(im)
        self.assertEqual(im.getpixel((0,0)),(40,50,60,255))
        self.assertEqual(out.getpixel((0,0)),im.getpixel((0,0)))
        self.assertEqual(out.getpixel((10,10)),im.getpixel((10,10)))
        self.assertEqual(out.getpixel((10,0))[3],0)
        self.assertEqual(out.getpixel((0,10))[3],0)
        self.assertEqual(im.getpixel((0,10))[3],255)
    def test_enclosed_white_highlight_is_not_erased(self):
        im=Image.new('RGBA',(15,15),'white');draw=ImageDraw.Draw(im)
        draw.rectangle((4,4,10,10),fill=(35,55,85,255));im.putpixel((7,7),(255,255,255,255))
        out=clear_white_border(im)
        self.assertEqual(out.getpixel((7,7)),(255,255,255,255))
        self.assertEqual(out.getpixel((4,4)),(35,55,85,255))
        self.assertEqual(out.getpixel((0,0))[3],0)
    def test_no_white_matte_does_not_modify_transparent_art(self):
        im=Image.new('RGBA',(13,13),(0,0,0,0));im.putpixel((6,6),(255,255,255,255))
        im.putpixel((7,6),(190,190,180,120));self.assertEqual(im.tobytes(),clear_white_border(im).tobytes())
    def test_only_background_alpha_can_change(self):
        im=Image.new('RGBA',(18,18),'white');draw=ImageDraw.Draw(im)
        draw.ellipse((3,2,15,16),fill=(160,180,220,255));draw.rectangle((7,5,10,9),fill='white')
        out=clear_white_border(im)
        for old,new in zip(im.getdata(),out.getdata()):
            self.assertEqual(old[:3],new[:3])
            if min(old[:3])<250:self.assertEqual(old,new)
    def test_near_white_exterior_but_not_light_metal(self):
        im=Image.new('RGBA',(12,12),(252,252,252,255));im.putpixel((6,6),(240,242,245,255))
        out=clear_white_border(im);self.assertEqual(out.getpixel((0,0))[3],0)
        self.assertEqual(out.getpixel((6,6)),im.getpixel((6,6)))
    def test_idempotent(self):
        im=Image.new('RGBA',(11,9),'white');ImageDraw.Draw(im).rectangle((2,2,8,6),fill=(20,30,45,255))
        out=clear_white_border(im);self.assertEqual(out.tobytes(),clear_white_border(out).tobytes())

if __name__=='__main__':unittest.main()
