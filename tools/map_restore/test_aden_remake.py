"""Unit tests. Optional ADEN_PACK / ADEN_LAYOUTS enable actual private-map tests.
No absent private source is reported as an original-map runtime pass.
"""
from copy import deepcopy
import json
import os
from pathlib import Path
import tempfile
import unittest
import zlib
import numpy as np
from build_aden_remake import (DIMENSIONS, GRID_SHA, PlacementAdapter, file_sha,
                              grid_point, move_masks, pixel, reachable, sha, verify, write)


class CoordinateAndGraphTests(unittest.TestCase):
    def test_projection_roundtrip(self):
        points = np.array([(0,0),(2047,1535),(180,743),(981,750),(1808,1386)])
        np.testing.assert_array_equal(np.array([grid_point(p) for p in pixel(points)]),points)

    def test_blocked_edges_do_not_connect_adjacent_open_cells(self):
        masks=np.array([[4,64,4,64]],np.uint8)
        np.testing.assert_array_equal(reachable(masks,(0,0)),[[True,True,False,False]])

    def test_no_diagonal_only_connection(self):
        masks=np.array([[8,0],[0,128]],np.uint8)
        np.testing.assert_array_equal(reachable(masks,(0,0)),[[True,False],[False,False]])

    def test_no_horizontal_array_wrap(self):
        masks=np.array([[1,4],[64,16]],np.uint8)
        np.testing.assert_array_equal(reachable(masks,(1,0)),[[False,True],[False,False]])

    def test_blocked_start_rejected(self):
        with self.assertRaises(ValueError): reachable(np.zeros((3,3),np.uint8),(1,1))

    def test_original_cardinal_edges_reciprocal(self):
        rng=np.random.default_rng(119)
        grid=rng.integers(0,256,(128,128),dtype=np.uint8);m=move_masks(grid)
        np.testing.assert_array_equal((m[:-1]&16)!=0,(m[1:]&1)!=0)
        np.testing.assert_array_equal((m[:,:-1]&4)!=0,(m[:,1:]&64)!=0)

    def test_scalar_independent_edge_rules(self):
        grid=np.random.default_rng(4).integers(0,256,(65,129),dtype=np.uint8)
        masks=move_masks(grid)
        def at(x,y): return int(grid[y,x]) if 0<=x<grid.shape[1] and 0<=y<grid.shape[0] else 0
        for y in range(grid.shape[0]):
            for x in range(grid.shape[1]):
                a,n,e,s,w,sw,nw,se=[at(x+dx,y+dy) for dx,dy in [(0,0),(0,-1),(1,0),(0,1),(-1,0),(-1,1),(-1,-1),(1,1)]]
                rules=[bool(a&2),bool((a&2 and n&1) or (a&1 and e&2)),bool(a&1),
                       bool((s&3)==3 or (a&1 and se&2)),bool(s&2),
                       bool((sw&1 and s&2) or (sw&2 and w&1)),bool(w&1),
                       bool((w&3)==3 or (a&2 and nw&1))]
                expected=0
                for i,(dx,dy) in enumerate(((0,-1),(1,-1),(1,0),(1,1),(0,1),(-1,1),(-1,0),(-1,-1))):
                    if 0<=x+dx<grid.shape[1] and 0<=y+dy<grid.shape[0] and rules[i]: expected|=1<<i
                self.assertEqual(int(masks[y,x]),expected,(x,y))


@unittest.skipUnless(os.environ.get('ADEN_PACK') and os.environ.get('ADEN_LAYOUTS'),
                     'actual private Aden pack/layouts not supplied')
class ActualSourcePackTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.pack=Path(os.environ['ADEN_PACK']);cls.layouts=Path(os.environ['ADEN_LAYOUTS'])

    def clone_metadata(self, directory):
        root=Path(directory); (root/'definitions').mkdir()
        for name in ('index.json','definitions/aden_world.json'):
            (root/name).write_bytes((self.pack/name).read_bytes())
        (root/'navigation-00.bin').write_bytes((self.pack/'navigation-00.bin').read_bytes())
        return root

    def change_definition(self,root,callback):
        path=root/'definitions/aden_world.json';d=json.loads(path.read_text());callback(d);write(path,d)
        p=root/'index.json';index=json.loads(p.read_text());index['maps']['aden_world']['sha256']=file_sha(path);write(p,index)

    def test_all_3145728_cells_and_768_chunks(self):
        report=verify(self.pack,self.layouts)
        self.assertEqual(report['verified_cells'],3145728)
        self.assertEqual(report['verified_chunks'],768)
        self.assertEqual(report['grid_sha256'],GRID_SHA)
        self.assertEqual(report['status'],'PASS_DATA_ONLY')
        self.assertEqual(report['godot_runtime'],'NOT_RUN')

    def test_preserved_rosters_services_and_portal_links(self):
        old=json.loads(self.layouts.read_text())['aden_world']
        new=json.loads((self.pack/'definitions/aden_world.json').read_text())['remake_gameplay']
        for group in ('npc_spawn','monster_spawn','portal'):
            self.assertEqual([r['id'] for r in old[group]],[r['id'] for r in new[group]])
        for a,b in zip(old['monster_spawn'],new['monster_spawn']):
            for key in ('monster_types','weights','max_count','mode','boss_id','respawn_time','roaming_radius','level','spawn_radius'):
                self.assertEqual(a.get(key),b.get(key),(a['id'],key))
        for a,b in zip(old['npc_spawn'],new['npc_spawn']): self.assertEqual(a['role'],b['role'])
        for a,b in zip(old['portal'],new['portal']): self.assertEqual(a['target_map'],b['target_map'])

    def test_wrong_origin_rejected_even_with_new_definition_hash(self):
        with tempfile.TemporaryDirectory() as d:
            root=self.clone_metadata(d)
            self.change_definition(root,lambda v:v.update(origin=[0,0]))
            with self.assertRaises(ValueError): verify(root,self.layouts)

    def test_missing_chunk_rejected(self):
        with tempfile.TemporaryDirectory() as d:
            root=self.clone_metadata(d)
            self.change_definition(root,lambda v:v['navigation']['chunks'].pop())
            with self.assertRaises(ValueError): verify(root,self.layouts)

    def test_duplicate_chunk_rejected(self):
        with tempfile.TemporaryDirectory() as d:
            root=self.clone_metadata(d)
            self.change_definition(root,lambda v:v['navigation']['chunks'].append(v['navigation']['chunks'][0]))
            with self.assertRaises(ValueError): verify(root,self.layouts)

    def test_corrupt_navigation_rejected(self):
        with tempfile.TemporaryDirectory() as d:
            root=self.clone_metadata(d);p=root/'navigation-00.bin';data=bytearray(p.read_bytes());data[5]^=255;p.write_bytes(data)
            with self.assertRaises((ValueError,zlib.error)): verify(root,self.layouts)

    def test_changed_definition_without_hash_rejected(self):
        with tempfile.TemporaryDirectory() as d:
            root=self.clone_metadata(d);p=root/'definitions/aden_world.json';p.write_bytes(p.read_bytes()+b' ')
            with self.assertRaises(ValueError): verify(root,self.layouts)

    def test_changed_roster_rejected(self):
        with tempfile.TemporaryDirectory() as d:
            root=self.clone_metadata(d)
            self.change_definition(root,lambda v:v['remake_gameplay']['monster_spawn'][0].update(max_count=9999))
            with self.assertRaises(ValueError): verify(root,self.layouts)

    def test_wrong_layout_export_rejected(self):
        with tempfile.TemporaryDirectory() as d:
            path=Path(d)/'changed.json';path.write_bytes(self.layouts.read_bytes()+b' ')
            with self.assertRaises(ValueError): verify(self.pack,path)

if __name__=='__main__': unittest.main()
