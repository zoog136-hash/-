"""Independent edge oracle and lossless optional-layer regression fixtures."""
import struct
import unittest
import numpy as np
from formats import move_masks, origin, read_s32, write_s32

def oracle(g,x,y,h):
    height,width=g.shape
    dx,dy=((0,-1),(1,-1),(1,0),(1,1),(0,1),(-1,1),(-1,0),(-1,-1))[h]
    if not (0<=x+dx<width and 0<=y+dy<height): return False
    def at(a,b): return int(g[b,a]) if 0<=a<width and 0<=b<height else 0
    if h==0:return bool(at(x,y)&2)
    if h==1:return bool((at(x,y)&2 and at(x,y-1)&1) or (at(x,y)&1 and at(x+1,y)&2))
    if h==2:return bool(at(x,y)&1)
    if h==3:return bool(at(x,y+1)&3==3 or (at(x,y)&1 and at(x+1,y+1)&2))
    if h==4:return bool(at(x,y+1)&2)
    if h==5:return bool((at(x-1,y+1)&1 and at(x,y+1)&2) or (at(x-1,y+1)&2 and at(x-1,y)&1))
    if h==6:return bool(at(x-1,y)&1)
    return bool(at(x-1,y)&3==3 or (at(x,y)&2 and at(x-1,y-1)&1))

class Formats(unittest.TestCase):
    def test_edges_and_boundaries(self):
        rng=np.random.default_rng(8192)
        for shape in [(1,1),(1,9),(9,1),(31,37)]:
            grid=rng.integers(0,256,shape,dtype=np.uint8)
            masks=move_masks(grid)
            for y in range(shape[0]):
                for x in range(shape[1]):
                    for heading in range(8):
                        self.assertEqual(bool(masks[y,x]&(1<<heading)),oracle(grid,x,y,heading))
    def test_all_optional_layers_roundtrip(self):
        base=bytes(32768)+struct.pack('<HBBBHB',1,9,8,7,60000,6)+bytes(16384)
        base+=struct.pack('<ihHBBBBhB',1,-123,1,4,3,2,1,-30123,255)
        self.assertEqual(write_s32(read_s32(base,'80008000.s32')),base)
        tails=[struct.pack('<i5B',1,5,4,3,2,1),struct.pack('<ii',1,60000),
               struct.pack('<HB',1,2)+b'\x81\xff'+struct.pack('<BBHi',4,5,12862,-47),
               struct.pack('<HHHHi',0x8001,4,5,6,-123456)+b'opaque-tail']
        for tail in tails:
            base+=tail
            self.assertEqual(write_s32(read_s32(base,'80008000.s32')),base)
        for n in [0,32767,32769,49153]:
            with self.assertRaises(ValueError): read_s32(base[:n],'bad.s32')
    def test_chunk_name_is_not_guessed(self):
        self.assertEqual(origin('7fff7fff.s32'),[32704,32704])
        self.assertEqual(origin('80008000_1.s32'),[32768,32768])
        self.assertIsNone(origin('800F7FF3E.s32'))

if __name__=='__main__': unittest.main()
