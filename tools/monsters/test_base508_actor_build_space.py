"""Budget refusal protects completed outputs; no original image is synthesized or decoded."""
import gzip
import json
from pathlib import Path
import tempfile
from types import SimpleNamespace
import unittest
from unittest import mock
import build_base508_full_model_pack as builder
import base508_build_space as space

class ActorBuildSpaceTests(unittest.TestCase):
 def test_budget_refusal_preserves_checkpoint_and_never_enters_build(self):
  with tempfile.TemporaryDirectory() as directory:
   root=Path(directory);out=root/'output';out.mkdir();checkpoint=out/'manifest.json';checkpoint.write_bytes(b'previous-verified-checkpoint')
   args=SimpleNamespace(output=out,shards=1,shard=0,space_packet_factor=4.0,space_temporary_mib=128,space_reserve_mib=512)
   with mock.patch.dict('os.environ',{'BASE508_SPACE_STATE_DIR':str(root/'leases')}),mock.patch.object(builder,'estimate_build_budget',return_value=(1000,{})),mock.patch.object(space.shutil,'disk_usage',return_value=SimpleNamespace(free=500)),mock.patch.object(builder,'build') as compile:
    with self.assertRaises(space.BuildSpaceError) as caught:builder.main(args)
    self.assertEqual(caught.exception.exit_code,75);self.assertFalse(caught.exception.details['source_failure']);compile.assert_not_called()
   self.assertEqual(checkpoint.read_bytes(),b'previous-verified-checkpoint')
 def test_estimate_counts_only_requested_shard_and_unique_inputs(self):
  with tempfile.TemporaryDirectory() as directory:
   root=Path(directory);(root/'input.zip').touch()
   models={str(i):{'original_members':['Sprite/1-0.sp2']} for i in range(4)}
   catalog=root/'catalog.gz';requests=root/'requests.gz'
   with gzip.open(catalog,'wt') as f:json.dump({'models':models},f)
   with gzip.open(requests,'wt') as f:json.dump({'files':[{'name':'Sprite/1-0.sp2','size':100,'available_library_package':{'file_name':'input.zip'}}]},f)
   args=SimpleNamespace(catalog=catalog,requests=requests,model_ids=None,shards=2,shard=1,source_capabilities=True,packages=root,spr_root=root,space_packet_factor=4)
   with mock.patch.object(builder.original_spr,'read',return_value={}),mock.patch.object(builder.original_spr,'resolve',return_value=(1,{0:{'tokens':[(0,0,1)]}})),mock.patch.object(builder.original_spr,'resolve_references',return_value={}):
    expected,plan=builder.estimate_build_budget(args)
   self.assertEqual(plan['selected_models'],2);self.assertEqual(plan['unique_original_members'],1)
   self.assertEqual(expected,400+16*1024+2*65536)
if __name__=='__main__':unittest.main()
