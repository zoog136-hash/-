import base64,struct,unittest,zlib
from base508_seg import read_seg,write_seg
from base508_til import read_til,write_raw,render_til

class LegacyTests(unittest.TestCase):
 def seg(self):
  return struct.pack('<8192H',*([0x1234]*8192))+struct.pack('<HBBBB',1,7,8,3,4)+bytes(range(256))*32+struct.pack('<IHHBBBBB',1,0xffff,1,9,10,11,12,13)+b'\x00\xffuninterpreted tail'
 def test_seg_lossless_bytes_and_distinct_attribute_encoding(self):
  source=self.seg();row=read_seg(source,'Map/15/7fff8000.seg');self.assertEqual(write_seg(row),source)
  self.assertEqual(row['source_format'],'SEG');self.assertEqual(base64.b64decode(row['seg_attribute_u8']),bytes(range(256))*32)
  self.assertEqual(struct.unpack('<8192H',base64.b64decode(row['attribute_u16le'])),tuple(range(256))*32)
  self.assertEqual(row['covers'],[[7,8,0x403]]);self.assertEqual(row['objects'][0]['parts'],[[9,10,11,0xd0c]])
  self.assertEqual(row['terrain_collision'],'UNKNOWN');self.assertIn('INDEPENDENT_LEGACY_VARIANT',row['visual_semantics'])
 def test_seg_truncation_never_pads_unknown_cells(self):
  source=self.seg()
  for length in [0,16384,24581,24585]:
   with self.assertRaises(ValueError):read_seg(source[:length],'7fff8000.seg')
 def til(self,block):return struct.pack('<IIII',2,0,0,len(block))+block+b'preserved tail'
 def test_til_offsets_aliases_rgb555_and_zlib(self):
  block=bytes([2,0,0,1,1,1,0,1])+struct.pack('<H',0x7c00);source=self.til(block);tile=read_til(source)
  self.assertEqual(write_raw(tile),source);self.assertEqual(tile['blocks'][0],tile['blocks'][1])
  self.assertEqual(render_til(tile['blocks'][0]).getpixel((0,0)),(255,0,0,255))
  zipped=read_til(zlib.compress(source));self.assertEqual(zipped['container_encoding'],'ZLIB');self.assertEqual(write_raw(zipped),source)
 def test_til_rejects_offset_overflow_and_remaster(self):
  with self.assertRaises(ValueError):read_til(struct.pack('<III',1,100,100))
  with self.assertRaises(ValueError):render_til(bytes([0])+bytes(2304))
  with self.assertRaises(ValueError):render_til(bytes([2,0,0,48,48]))
 def test_til_classic_diamond_coverage_and_half_alpha(self):
  diamond=bytes([1])+struct.pack('<288H',*([0x3e0]*288));image=render_til(diamond)
  self.assertEqual(sum(value>0 for value in image.getchannel('A').tobytes()),288)
  self.assertEqual(image.getpixel((0,0)),(0,255,0,255))
  half=render_til(bytes([5])+diamond[1:]);self.assertEqual(half.getpixel((0,0)),(0,255,0,128))

if __name__=='__main__':unittest.main()
