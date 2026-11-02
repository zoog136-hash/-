import struct,unittest
import original_sp2 as sp2

class Sp2LayoutTests(unittest.TestCase):
    def sample(self,entries=1,wrap=False):
        p=lambda f,*v:struct.pack('<'+f,*v)
        palette=b''.join(p('H',c) for c in ([65535] if entries==1 else [65535,0,31]))
        refs=2 if wrap else 1
        frame=p('4hH',0,0,1,1,refs)+bytes(refs)*3+(p('2h',-1,0) if wrap else p('h',0))
        blocks=p('i',65536 if wrap else 1)+(bytes(3)*65536 if wrap else bytes([0,0,1])+p('H',32))
        return bytes([254,1])+palette+bytes([1,1])+frame+blocks+(b'' if wrap else bytes([0]))
    def test_literal_one_and_three_palette_layouts_are_distinguished(self):
        for n in [1,3]:
            raw=self.sample(n);pal,mask,dirs,size=sp2.parse(raw)
            self.assertEqual(len(pal),n);self.assertEqual(mask,1)
            image,offset=sp2.render(pal,*dirs[0],0)
            self.assertEqual(image.getpixel((0,0)),(255,255,255,255));self.assertEqual(offset,(0,0))
    def test_unsigned_cumulative_reference_wrap(self):
        pal,mask,dirs,size=sp2.parse(self.sample(wrap=True))
        self.assertEqual([r[3] for r in dirs[0][0][0][1]],[65535,0])
    def test_truncated_and_trailing_streams_are_rejected(self):
        raw=self.sample()
        for altered in [raw[:-1],raw+b'\0']:
            with self.assertRaises(ValueError):sp2.parse(altered)

if __name__=='__main__':unittest.main()
