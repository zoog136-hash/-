"""Pure gate/receipt fixtures: fail before any production corpus evidence read."""
import unittest,tempfile,json
from pathlib import Path
from unittest.mock import patch
import reconcile_remaining_findings_v05 as runner
class FinalGateTests(unittest.TestCase):
 def test_false_gate_blocks_before_evidence_access(self):
  with tempfile.TemporaryDirectory() as t:
   p=Path(t)/'gate.json';p.write_text(json.dumps({'all_possible_corrections_complete':False,'local_integration_checks_complete':False}))
   with patch.object(runner,'assert_core'),patch.object(runner,'Evidence',side_effect=AssertionError('No corpus allowed')):
    with self.assertRaisesRegex(ValueError,'not final'):runner.finalize(p)
 def test_missing_delta_receipt_blocks_before_evidence_access(self):
  with tempfile.TemporaryDirectory() as t:
   p=Path(t)/'gate.json';p.write_text(json.dumps({'all_possible_corrections_complete':True,'local_integration_checks_complete':True,'integration_receipts':[{'path':'final-github-ci-receipt-v02-completed-v01.json'}]}))
   with patch.object(runner,'assert_core'),patch.object(runner,'Evidence',side_effect=AssertionError('No corpus allowed')):
    with self.assertRaisesRegex(ValueError,'current changed-delta'):runner.finalize(p)
 def test_historical_1319_receipt_not_current_SHA_approval(self):
  class E:
   def artifact(self,ref):return {'staging_sha256':'old','PASS':1319},ref['sha256']
  gate={'integration_receipts':[{'path':'final-runtime-integration-reconciled-v01.json','sha256':'a'*64}],'active_staging':{'sha256':'new'},'active_manifest':{'sha256':'new'}}
  row=runner.integration_artifacts(E(),gate)[0]
  self.assertEqual(row['scope'],'HISTORICAL_INPUT_COMMIT_ORIGINAL_CHECKS');self.assertEqual(row['reported_result']['PASS'],1319)
 def test_current_delta_wrong_SHA_rejected(self):
  class E:
   def artifact(self,ref):return {'staging_sha256':'old'},ref['sha256']
  gate={'integration_receipts':[{'path':'final-correction-render-integration-v01.json','sha256':'a'*64}],'active_staging':{'sha256':'new'},'active_manifest':{'sha256':'new'}}
  with self.assertRaises(ValueError):runner.integration_artifacts(E(),gate)
 def test_completed_CI_failure_is_not_observer_or_image_fault(self):
  class E:
   def artifact(self,ref):return {'status':'completed','conclusion':'failure','run_id':40014699342,'summary':{'PASS':216,'FAIL':12,'SKIP':5}},ref['sha256']
  gate={'integration_receipts':[{'path':'final-github-ci-receipt-v02-completed-v01.json','sha256':'a'*64}],'active_staging':{'sha256':'new'},'active_manifest':{'sha256':'new'}}
  report=runner.integration_artifacts(E(),gate)[0]['reported_result']
  self.assertEqual(report['conclusion'],'failure');self.assertEqual(report['summary']['FAIL'],12)
if __name__=='__main__':unittest.main()
