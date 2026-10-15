"""Synthetic algorithm regression. This is never source-map delivery evidence."""
import unittest
import numpy as np
from formats import move_masks
from build_remake import strict_masks, distances, select_entry, placements


class Remake(unittest.TestCase):
    def test_no_corner_cut_without_losing_cardinal_passages(self):
        rng=np.random.default_rng(108)
        for shape in [(1,9),(17,31),(32,13)]:
            grid=rng.integers(0,4,shape,dtype=np.uint8)
            raw=move_masks(grid); strict=strict_masks(raw)
            self.assertTrue(np.array_equal(raw&85,strict&85))
            self.assertTrue(np.all((strict|raw)==raw))
            for y,x in np.argwhere(raw!=0)[:10]:
                self.assertTrue(np.array_equal(distances(raw,(int(x),int(y))),distances(strict,(int(x),int(y)))))
            for y in range(shape[0]):
                for x in range(shape[1]):
                    for heading,dx,dy in [(1,1,-1),(3,1,1),(5,-1,1),(7,-1,-1)]:
                        if not strict[y,x]&(1<<heading): continue
                        hx=2 if dx>0 else 6;hy=4 if dy>0 else 0
                        self.assertTrue(raw[y,x]&(1<<hx) and raw[y,x]&(1<<hy))
                        self.assertTrue(raw[y,x+dx]&(1<<hy) and raw[y+dy,x]&(1<<hx))

    def test_missing_source_entrance_is_not_fabricated_as_an_observation(self):
        grid=np.full((40,70),3,np.uint8);masks=move_masks(grid)
        start,reach,observations=select_entry(grid,masks,[32576,32768],[])
        self.assertEqual(observations,[])
        self.assertEqual(reach[start[1],start[0]],0)
        _,_,observations=select_entry(grid,masks,[32576,32768],[{'src_x':32580,'src_y':32773}])
        self.assertEqual(observations,[(4,5)])

    def test_preserve_live_gameplay_and_deterministic_spawns(self):
        grid=np.full((40,70),3,np.uint8);masks=strict_masks(move_masks(grid))
        entry=(6,6);reach=distances(masks,entry)
        old={'map_id':'oman_01','npc_spawn':[{'id':'guide','role':'shop','position':[5,9]}],
            'portal':[{'id':'home','position':[0,0],'target_map':'aden_world','target_position':[99,99]}],
            'monster_spawn':[{'id':'normal','monster_types':['existing'],'max_count':7,'respawn_time':25,'mode':'normal'},
                {'id':'boss','boss_id':'existing_id','monster_types':['existing_boss'],'max_count':1,'respawn_time':86400,'mode':'boss'},
                {'id':'dense','monster_types':['existing'],'max_count':24,'respawn_time':7,'spawn_radius':240,'mode':'dense'}]}
        a=placements(old,grid,masks,[32704,32704],entry,reach)
        self.assertEqual(a,placements(old,grid,masks,[32704,32704],entry,reach))
        self.assertEqual(a['monster_spawn'][1]['respawn_time'],86400)
        self.assertEqual(a['monster_spawn'][1]['boss_id'],'existing_id')
        self.assertTrue(set(a['monster_spawn'][0]['source_cells']).isdisjoint(a['monster_spawn'][1]['source_cells']))
        self.assertEqual(a['npc_spawn'][0]['role'],'shop')
        region=a['monster_spawn'][2];r=region['rect'];cx,cy=r[0]+r[2]/2,r[1]+r[3]/2
        from build_remake import pixel
        for flat in region['source_cells']:
            px,py=pixel((flat%70,flat//70),70)
            self.assertLessEqual((px-cx)**2+(py-cy)**2,240**2)


if __name__=='__main__': unittest.main()
