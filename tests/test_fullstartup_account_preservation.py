"""Strict fullstartup account preservation must reject unknown-state drift."""
import copy
import sys
import unittest
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'tools/boot'))
from benchmark_full_startup import compare_selected_account

class AccountPreservationTests(unittest.TestCase):
    def setUp(self):
        self.before = {'schema':'v2','revision':3,'selected':'one',
                       'shared':{'warehouse':{'gold':41}},
                       'characters':[{'id':'one','state':{'level':7,'inventory':{'x':2}}}],
                       'future_owner':{'source':42,'claims':[1,2]}}
        self.after = copy.deepcopy(self.before)
        self.after['revision'] = 4
    def check_rejected(self, field):
        self.assertFalse(compare_selected_account(self.before, self.after)[field])
    def test_only_selection_revision_changes(self):
        self.assertEqual(compare_selected_account(self.before,self.after),
                         {'account_envelope_exact':True,'revision_increment_exact':True})
        self.assertEqual(self.before['revision'],3)
    def test_unknown_nested_field_cannot_change(self):
        self.after['future_owner']['claims'].append(3)
        self.check_rejected('account_envelope_exact')
    def test_unknown_account_field_cannot_appear_or_disappear(self):
        for candidate in [dict(self.after,seal='guessed'),
                          {k:v for k,v in self.after.items() if k!='future_owner'}]:
            self.assertFalse(compare_selected_account(self.before,candidate)['account_envelope_exact'])
    def test_character_progress_and_shared_assets_cannot_change(self):
        self.after['characters'][0]['state']['inventory']['x']=1
        self.check_rejected('account_envelope_exact')
        self.after=copy.deepcopy(self.before);self.after['revision']=4
        self.after['shared']['warehouse']['gold']=40
        self.check_rejected('account_envelope_exact')
    def test_boolean_numeric_type_drift_is_rejected(self):
        self.before["future_owner"]["enabled"]=True
        self.after["future_owner"]["enabled"]=1
        self.check_rejected("account_envelope_exact")
    def test_revision_must_increment_once(self):
        for value in [3,5,True,4.5,None,float('inf')]:
            self.after['revision']=value
            self.check_rejected('revision_increment_exact')
    def test_missing_account_is_not_preserved(self):
        self.assertFalse(all(compare_selected_account(self.before,None).values()))
    def test_godot_whole_numeric_reload_is_same_value(self):
        self.after["characters"][0]["state"]["level"]=7.0
        self.after["future_owner"]["source"]=42.0
        self.assertTrue(all(compare_selected_account(self.before,self.after).values()))
    def test_json_whole_float_revision_is_accepted(self):
        self.before['revision']=3.0;self.after['revision']=4.0
        self.assertTrue(all(compare_selected_account(self.before,self.after).values()))

if __name__=='__main__':unittest.main()
