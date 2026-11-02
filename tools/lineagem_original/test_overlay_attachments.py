"""Synthetic source-format regression: overlay clothes/alias handling, not visual proof."""
import gzip,json,pathlib,tempfile,unittest
import attach_native_layers
from test_original_sp2 import Sp2LayoutTests

class OverlayAttachments(unittest.TestCase):
 def test_overlay_declared_clothes_are_attached_with_alias_and_raw_attr(self):
  with tempfile.TemporaryDirectory() as temp:
   root=pathlib.Path(temp);inputs=root/'inputs';pack=root/'pack'
   spr=inputs/'lineagem-category-source-metadata/original-spr';spr.mkdir(parents=True)
   (spr/'list_0.spr').write_text('#1 1 effect\n0.animation(0 1,0.0:1)\n105.clothes(1 120)\n#120 1=100 layer alias\n#100 1 effect mu\n104.attr(128)\n')
   inv=inputs/'full_resource_inventory/inventory';inv.mkdir(parents=True)
   with gzip.open(inv/'id_to_archive.json.gz','wt') as f:json.dump({'100':{'assets':[{'name':'Sprite/100-0.sp2'}]}},f)
   pixels=inputs/'transformation-001/Sprite';pixels.mkdir(parents=True)
   (pixels/'100-0.sp2').write_bytes(Sp2LayoutTests().sample())
   (pack/'overlays').mkdir(parents=True);(pack/'actors').mkdir();(pack/'pixels').mkdir()
   (pack/'registered_effect_layers.json').write_text('{}')
   frame={'physical_group':0,'stored_direction_bit':0,'source_frame':0,'source_ticks':1,'duration':None,'layers':[]}
   actor={'source_sprite_id':1,'tracks':{'idle':{'source_sprite_id':1,'source_raw_body':'0 1,0.0:1','directions':[[frame.copy()] for _ in range(8)]}}}
   path=pack/'overlays/1.json';path.write_text(json.dumps(actor))
   attach_native_layers.build(inputs,pack,{1})
   result=json.loads(path.read_text());track=result['tracks']['idle']
   self.assertEqual(track['source_effect_layers'][0]['sprite_id'],120)
   self.assertEqual(track['source_effect_layers'][0]['physical_sprite_id'],100)
   for direction in track['directions']:
    layer=direction[0]['effect_layers'][0]
    self.assertEqual(layer['source_attributes'],['128'])
    self.assertEqual(layer['physical_layer_id'],100)
    self.assertTrue((pack/layer['path']).is_file())
   registry=json.loads((pack/'registered_effect_layers.json').read_text())
   self.assertIn('120',registry)

if __name__=='__main__':unittest.main()
