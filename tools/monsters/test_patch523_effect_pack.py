"""Boundaries discriminating commandwise M geometry from grouped-row guesses."""
import struct, unittest
import build_patch523_effect_pack as codec

def fixture(words=(1056,), values=b'\0', extent=(0,0,1,1), a=0):
 return (b'\xfe\x01'+struct.pack('<H',65535)+b'\x01\x01'+struct.pack('<4hH',*extent,1)
         +struct.pack('<bbBH',a,0,0,0)+struct.pack('<I',1)+bytes([0,0,len(words)])
         +struct.pack('<'+'H'*len(words),*words)+values)

class Boundaries(unittest.TestCase):
 def test_palette_zero_is_stored_coverage(self):
  palette,groups,_=codec.decode(fixture())
  image,offset,extent=codec.raster(palette,groups[0],0)
  self.assertEqual(image.getpixel((0,0)),(255,255,255,255))
  self.assertEqual(extent,[0,0,1,1])
 def test_zero_step_continues_same_row(self):
  raw=fixture(words=(65,2081),values=b'\0\0\0',extent=(1,0,5,1))
  palette,groups,_=codec.decode(raw);image,_,_=codec.raster(palette,groups[0],0)
  self.assertEqual([image.getpixel((x,0))[3] for x in range(4)],[255,255,0,255])
 def test_signed_floor_projection(self):
  palette,groups,_=codec.decode(fixture(extent=(0,12,1,13),a=-1))
  _,offset,_=codec.raster(palette,groups[0],0)
  self.assertEqual(offset,[0,12])
 def test_invalid_bound_and_trailing_bytes_rejected(self):
  with self.assertRaises(ValueError): codec.decode(fixture()+b'x')
  palette,groups,_=codec.decode(fixture(extent=(0,0,2,1)))
  with self.assertRaises(ValueError): codec.raster(palette,groups[0],0)

if __name__=='__main__': unittest.main()
