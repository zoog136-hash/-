#!/usr/bin/env python3
"""Pure client-bound/duplicate/quota fixtures; no claims or image calls."""
import datetime,importlib.util,unittest
from pathlib import Path
s=importlib.util.spec_from_file_location('v08',Path(__file__).with_name('prepare_quota_recovery_v08.py'));m=importlib.util.module_from_spec(s);s.loader.exec_module(m)
class Limits(unittest.TestCase):
 def setUp(self):
  self.plan={'quota_not_before_utc':'2026-10-23T20:55:39+00:00'};self.job={'correction_candidate_id':'qc025','state':'READY'};self.now=datetime.datetime(2026,10,23,21,0,tzinfo=datetime.timezone.utc)
 def gate(self,**over):
  a=dict(plan=self.plan,job=self.job,now=self.now,authorized=True,primary_settled=True,prior_success=False,recovery_reserved=False,stop429=False);a.update(over);return m.pure_claim_gate(**a)
 def test_exact_quota_exception_can_make_only_one_new_attempt(self):self.assertIsNone(self.gate())
 def test_original_success_and_visual_hold_outside_allowlist(self):self.assertEqual(self.gate(job={'correction_candidate_id':'qc009','state':'READY'}),'WAIT_NOT_EXACT_SEVEN_QUOTA_EXCEPTIONS')
 def test_existing_successful_png_never_regenerated(self):self.assertEqual(self.gate(prior_success=True),'WAIT_SUCCESSFUL_PNG_ALREADY_EXISTS_NO_REGENERATION')
 def test_failed_recovery_reserved_still_no_retry(self):self.assertEqual(self.gate(recovery_reserved=True),'WAIT_RECOVERY_ALREADY_RESERVED_OR_ATTEMPTED_NO_RETRY')
 def test_second_client_attempt_already_used_blocks_third(self):self.assertEqual(self.gate(original_client_attempts=2),'WAIT_TOTAL_CLIENT_ATTEMPT_BOUND_EXCEEDED')
 def test_429_stops_new_recovery_sources(self):self.assertEqual(self.gate(stop429=True),'WAIT_QUOTA_REOCCURRED_STOP_ALL_ADDITIONAL_CALLS')
 def test_wait_for_all_primary71_receipts(self):self.assertEqual(self.gate(primary_settled=False),'WAIT_PRIMARY71_TOOL_REQUESTS_SETTLED')
 def test_quota_reset_not_elapsed_blocks(self):self.assertEqual(self.gate(now=self.now.replace(hour=20,minute=54)),'WAIT_QUOTA_RESET')
 def test_transport_moderation_or_png_not_quota_exception(self):
  a={'status':'BLOCKED_QUOTA_NO_RETRY','generation_attempts':1,'generated':None,'correction_candidate_id':'qc025','id':'245','direction':'NW','role':'idle','previous_source_sha256':'a'*64};r={k:a[k] for k in ['correction_candidate_id','id','direction','role','previous_source_sha256']};r.update(blocked=True,error='HTTP429 usage_limit_reached');self.assertTrue(m.quota_only_no_png(a,r));r['generated']='/fake/already.png';self.assertFalse(m.quota_only_no_png(a,r));r.pop('generated');r['error']='moderation_blocked';self.assertFalse(m.quota_only_no_png(a,r))
if __name__=='__main__':unittest.main()
