import pathlib, tempfile, unittest
import original_spr as spr

class SourceSemantics(unittest.TestCase):
    def read_text(self,text):
        with tempfile.TemporaryDirectory() as t:
            p=pathlib.Path(t)/'list_0.spr';p.write_bytes(text.encode('cp949'));return spr.read([p])
    def test_alias_override_retains_body_and_native_timing(self):
        ds=self.read_text('#1 80 body\n110.framerate(36)\n0.Walk(1 2,72.0:2 72.1:2)\n110.framerate(24)\n3.Breath(1 3,0.2:4 0.0:4 0.1:4)\n#2 80=1 run\n110.framerate(36)\n0.RunL(1 2,56.0:2 56.1:2)\n')
        body,a=spr.resolve(ds,2)
        self.assertEqual(body,1);self.assertEqual(a[0]['tokens'][0],(56,0,2))
        self.assertEqual(ds[1][0].actions[0]['tokens'][0],(72,0,2))
        self.assertEqual(a[3]['fps'],24);self.assertEqual(a[3]['tokens'][0],(0,2,4))
        self.assertEqual(spr.frame_at(a[0],1/36,True),(56,0))
        self.assertEqual(spr.frame_at(a[0],2/36,True),(56,1))
        self.assertEqual(spr.frame_at(a[0],4/36,True),(56,0))
        self.assertEqual(spr.frame_at(a[0],4/36,False),(56,1))
    def test_frame_rate_whitespace_and_section_switches(self):
        ds=self.read_text('#1 80 body\n110.frame rate(36)\n0.walk(1 2,0.0:2 0.1:2)\n110.Frame   Rate(24)\n1.attack(1 1,8.0:17)\n3.breath(1 1,16.0:48)\n#2 80=1 run\n110.frame\trate(36)\n0.RunL(1 1,24.0:16)\n')
        self.assertEqual([ds[1][0].actions[k]['fps'] for k in [0,1,3]],[36,24,24])
        body,actions=spr.resolve(ds,2)
        self.assertEqual(body,1);self.assertEqual(actions[0]['fps'],36)
        self.assertEqual(actions[1]['fps'],24)
        self.assertEqual(ds[1][0].directives[0]['name'],'frame rate')
    def test_only_110_sets_rate_and_missing_rate_stays_unknown(self):
        ds=self.read_text('#1 80 x\n111.frame rate(36)\n0.walk(1 1,0.0:2)\n#2 80 x\n110.framerate(24)\n3.breath(1 1,0.0:4)\n110.frame rate(36)\n0.walk(1 1,8.0:2)\n')
        self.assertIsNone(ds[1][0].actions[0]['fps'])
        self.assertEqual(ds[2][0].actions[3]['fps'],24)
        self.assertEqual(ds[2][0].actions[0]['fps'],36)
    def test_inline_shadow_stops_at_its_own_closing_parenthesis(self):
        ds=self.read_text('#2284 1 body 101.shadow(1126) 102.type(10)\n')
        self.assertEqual(ds[2284][0].references[0]['targets'],[1126])
    def test_declared_clothes_count_is_not_silently_repaired(self):
        ds=self.read_text('#19339 1 body\n105.clothes(1 19340 19341)\n')
        r=ds[19339][0].references[0]
        self.assertFalse(r['count_valid']);self.assertEqual(r['targets'],[19340,19341])
    def test_cycles_and_duplicate_ids_fail_resolution(self):
        ds=self.read_text('#1 1=2 a\n#2 1=1 b\n')
        with self.assertRaises(ValueError):spr.resolve(ds,1)
        ds=self.read_text('#1 1 a\n#1 1 b\n')
        with self.assertRaises(ValueError):spr.resolve(ds,1)
    def test_unknown_fps_and_zero_duration_cannot_be_played(self):
        ds=self.read_text('#1 1 a\n0.Walk(1 1,0.0:2)\n#2 1 b\n110.framerate(36)\n0.Walk(1 1,0.0:0)\n')
        for sid in [1,2]:
            with self.assertRaises(ValueError):spr.frame_at(ds[sid][0].actions[0],0,True)

if __name__=='__main__':unittest.main()
