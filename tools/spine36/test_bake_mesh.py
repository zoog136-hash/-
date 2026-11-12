#!/usr/bin/env python3
"""Pure sampler boundary fixtures; no original art or SDK execution is claimed."""
import copy
import importlib.util
from pathlib import Path
import unittest

spec=importlib.util.spec_from_file_location('bake_mesh',Path(__file__).with_name('bake_mesh.py'))
bake=importlib.util.module_from_spec(spec);spec.loader.exec_module(bake)

class SamplerContract(unittest.TestCase):
    def source(self):
        return {'slots':[{'name':'slot'}],'skins':{'default':{'slot':{'missing':{'type':'mesh'}}}},'animations':{'idle':{}}}
    def test_unreferenced_only(self):
        rows=bake.missing_attachment_audit(self.source(),set())
        self.assertEqual(len(rows),1);self.assertEqual(rows[0]['path'],'missing');self.assertEqual(rows[0]['references'],[])
        self.assertIn('not external',rows[0]['scope'])
    def test_setup_missing_refused(self):
        d=self.source();d['slots'][0]['attachment']='missing'
        with self.assertRaises(ValueError):bake.missing_attachment_audit(d,set())
    def test_animated_missing_refused(self):
        d=self.source();d['animations']['idle']['slots']={'slot':{'attachment':[{'time':0,'name':'missing'}]}}
        with self.assertRaises(ValueError):bake.missing_attachment_audit(d,set())
    def test_deform_missing_refused(self):
        for key in ['deform','ffd']:
            d=self.source();d['animations']['idle'][key]={'default':{'slot':{'missing':[]}}}
            with self.subTest(key=key),self.assertRaises(ValueError):bake.missing_attachment_audit(d,set())
    def test_linked_parent_missing_refused(self):
        d=self.source();d['skins']['default']['slot']['child']={'type':'linkedmesh','parent':'missing','path':'present'}
        with self.assertRaises(ValueError):bake.missing_attachment_audit(d,{'present'})
    def test_mesh_with_parent_missing_refused(self):
        d=self.source();d['skins']['default']['slot']['child']={'type':'mesh','parent':'missing','path':'present'}
        with self.assertRaises(ValueError):bake.missing_attachment_audit(d,{'present'})
    def test_duplicate_time_refused(self):
        d=self.mesh();d['clips']['idle']['frames'].append(copy.deepcopy(d['clips']['idle']['frames'][0]))
        with self.assertRaises(ValueError):bake.validate_mesh(d,{'idle'},{'UI/page.png':{}})
    def test_real_region_no_skip(self):
        self.assertEqual(bake.missing_attachment_audit(self.source(),{'missing'}),[])
    def test_external_call_not_assumed(self):
        d=self.source();d['animations']['idle']['events']=[{'name':'external_event','string':'missing'}]
        self.assertEqual(len(bake.missing_attachment_audit(d,set())),1)
    def test_only_default_skin(self):
        d=self.source();d['skins']['other']={}
        with self.assertRaises(ValueError):bake.missing_attachment_audit(d,set())
    def test_constraint_names(self):
        d={'path':[{'name':'p'}],'animations':{'idle':{'paths':{'p':{}}}}};bake.validate_source_constraints(d)
        d['animations']['idle']['paths']={'unknown':{}}
        with self.assertRaises(ValueError):bake.validate_source_constraints(d)
    def test_source_paths(self):
        for p in ['../x','/x','UI/../x','UI\\x','UI:x','UI//x']:
            with self.subTest(path=p),self.assertRaises(ValueError):bake.relative(p)
        self.assertEqual(str(bake.relative('UI/Spine/body.json')),'UI/Spine/body.json')
    def test_atlas_exact_case_and_pages(self):
        regions,pages=bake.atlas_names('\nBody.png\nsize: 16,16\nformat: RGBA8888\nfilter: Linear,Linear\nrepeat: none\nFace\n  rotate: false\n')
        self.assertEqual(regions,{'Face'});self.assertEqual(pages,['Body.png']);self.assertNotIn('face',regions)
    def mesh(self):
        batch={'page':'UI/page.png','blend':'normal','color':[1,1,1,1],'positions':[0,0,1,0,0,1],'uvs':[0,0,1,0,0,1],'indices':[0,1,2]}
        return {'schema':'twilight.spine36.mesh.v1','coordinate_space':'godot_y_down','premultiplied_alpha':False,'setup':{'batches':[batch]},'clips':{'idle':{'duration':0,'fps':60,'frames':[{'time':0,'batches':[copy.deepcopy(batch)]}]}}}
    def test_zero_duration(self):
        r=bake.validate_mesh(self.mesh(),{'idle'},{'UI/page.png':{}})
        self.assertEqual(r['frames'],1);self.assertEqual(r['clips']['idle']['distinct_geometry_hashes'],1)
    def test_negative_geometry_cases(self):
        for key,value in [('indices',[0,1,3]),('indices',[True,1,2]),('indices',[0,1]),('positions',[0,0,float('nan'),0,0,1]),('uvs',[0,0,2,0,0,1]),('color',[1,1,1]),('color',[1,1,1,1.01]),('dark_color',[0,0,0,-1]),('page','UI/not-declared.png'),('blend','unknown')]:
            d=self.mesh();d['clips']['idle']['frames'][0]['batches'][0][key]=value
            with self.subTest(key=key,value=value),self.assertRaises(ValueError):bake.validate_mesh(d,{'idle'},{'UI/page.png':{}})
    def test_source_clips_not_guessed(self):
        with self.assertRaises(ValueError):bake.validate_mesh(self.mesh(),{'other'},{'UI/page.png':{}})
    def test_last_frame_exact(self):
        d=self.mesh();d['clips']['idle']['duration']=1
        with self.assertRaises(ValueError):bake.validate_mesh(d,{'idle'},{'UI/page.png':{}})

if __name__=='__main__':unittest.main()
