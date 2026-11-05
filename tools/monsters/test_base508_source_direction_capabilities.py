"""Source direction metadata only; this never synthesizes or decodes an image."""
import collections,unittest
from base508_actor_capabilities import profile
class DirectionCapabilitiesTests(unittest.TestCase):
 def result(self,partial=False):
  tracks={role:{'source_action_id':code,'directions':[[{}]if not partial or i==0 else []for i in range(8)]}for role,code in [('walk',0),('attack',1),('idle',3)]}
  row={'source_category':{'Name':'Npc','IsAttackable':True},'source_kind':'source_attackable_monster_actor'}
  npc={'ID':123,'AI':4,'MonsterClassID':1,'WeaponTypeID':0}
  return profile(row,npc,{'tracks':tracks},collections.defaultdict(list),collections.defaultdict(list))
 def test_complete_actor_retains_existing_combat_readiness(self):
  p=self.result();self.assertTrue(p['host_combat_ready']);self.assertEqual(p['source_common_direction_slots'],list(range(8)))
 def test_single_real_slot_never_becomes_eight_direction_combat(self):
  p=self.result(True);self.assertFalse(p['host_combat_ready']);self.assertEqual(p['source_common_direction_slots'],[0]);self.assertEqual(p['source_direction_slots_by_action']['1'],[0])
if __name__=='__main__':unittest.main()
