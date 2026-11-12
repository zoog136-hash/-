#!/usr/bin/env python3
"""Pure exact-dedup contract fixtures; no GPU or original render acceptance."""
import copy
import importlib.util
from pathlib import Path
import sys
import unittest
sys.path.insert(0,str(Path(__file__).parent))
import compact_mesh as compact

class CompactContract(unittest.TestCase):
    def mesh(self):
        batch={'page':'UI/원본.png','positions':[0.123456789123,0,1,0,0,1],'uvs':[0,0,1,0,0,1],'indices':[0,1,2],'color':[1,0.1,0.2,0.5],'dark_color':[0,0,0,1],'blend':'multiply','slot':'원본'}
        second=copy.deepcopy(batch);second['positions'][1]=0.5
        return {'schema':'twilight.spine36.mesh.v1','coordinate_space':'godot_y_down','premultiplied_alpha':False,'source':{'runtime_git':'pin'},'setup':{'batches':[batch]},'clips':{'실제 clip':{'duration':0,'fps':60,'frames':[{'time':0,'batches':[second]}]}}}
    def test_exact_binary64_equivalence(self):
        data=self.mesh();before=compact.expanded_digest(data);r=compact.compact(data)
        self.assertEqual(before,compact.expanded_digest(data));self.assertTrue(r['semantic_values_unchanged']);self.assertEqual(r['templates'],1);self.assertEqual(r['batch_references'],2)
        self.assertEqual(data['setup']['batches'][0]['geometry'],'g000000');self.assertEqual(data['clips']['실제 clip']['frames'][0]['batches'][0]['geometry'],'g000000')
    def test_no_position_quantization(self):
        data=self.mesh();before=data['setup']['batches'][0]['positions'][:];compact.compact(data)
        self.assertEqual(before,data['setup']['batches'][0]['positions'])
        h=compact.expanded_digest(data);data['setup']['batches'][0]['positions'][0]+=1e-14
        self.assertNotEqual(h,compact.expanded_digest(data))
    def test_page_exact_identity(self):
        data=self.mesh();data['clips']['실제 clip']['frames'][0]['batches'][0]['page']='UI/다른.png'
        self.assertEqual(compact.compact(data)['templates'],2)
    def test_uv_exact_identity(self):
        data=self.mesh();data['clips']['실제 clip']['frames'][0]['batches'][0]['uvs'][0]=1e-14
        self.assertEqual(compact.compact(data)['templates'],2)
    def test_indices_exact_identity(self):
        data=self.mesh();data['clips']['실제 clip']['frames'][0]['batches'][0]['indices']=[0,2,1]
        self.assertEqual(compact.compact(data)['templates'],2)
    def test_mixed_inline_ref_refused(self):
        data=self.mesh();compact.compact(data);data['setup']['batches'][0]['page']='UI/원본.png'
        with self.assertRaises(ValueError):compact.expanded_digest(data)
    def test_unknown_ref_refused(self):
        data=self.mesh();compact.compact(data);data['setup']['batches'][0]['geometry']='unknown'
        with self.assertRaises(ValueError):compact.expanded_digest(data)
    def test_recompact_refused(self):
        data=self.mesh();compact.compact(data)
        with self.assertRaises(ValueError):compact.compact(data)
    def test_empty_pose(self):
        data=self.mesh();data['setup']['batches']=[];data['clips']['실제 clip']['frames'][0]['batches']=[]
        r=compact.compact(data);self.assertEqual(r['templates'],0);self.assertEqual(r['batch_references'],0)
    def test_ascii_roundtrip(self):
        import json
        data=self.mesh();compact.compact(data);encoded=json.dumps(data,ensure_ascii=True,allow_nan=False)
        self.assertTrue(encoded.isascii());self.assertEqual(compact.expanded_digest(data),compact.expanded_digest(json.loads(encoded)))

if __name__=='__main__':unittest.main()
