import json,sys,tempfile,unittest
from pathlib import Path
from PIL import Image
sys.path.insert(0,str(Path(__file__).resolve().parents[1]/'tools'))
from analyze_pr122_approval_audit import analyze

class AnalysisClassificationTest(unittest.TestCase):
    def setUp(self):
        self.temp=tempfile.TemporaryDirectory();self.addCleanup(self.temp.cleanup);self.root=Path(self.temp.name)
        Image.new('RGBA',(8,8),(255,255,255,255)).save(self.root/'pose.png')
        self.plan={'head':'fixture','resources':[]}
        self.report={'resources':[dict(frames='fixture.tres',failures=[],entries=[],clips={'idle_0':dict(count=1,speed=6,loop=True,frames=[dict(index=0,duration=1,failures=[],source_path='res://pose.png',atlas_levels=[])])})]}
    def test_region_edge_is_review_signal_not_automatic_defect(self):
        summary,details=analyze(self.root,self.plan,self.report)
        self.assertEqual(summary['technical_failures'],[])
        self.assertEqual(summary['visual_review_flagged_clips'],1)
        self.assertEqual(summary['new_quality_approvals'],0)
    def test_transparent_frame_cannot_pass(self):
        Image.new('RGBA',(8,8),(0,0,0,0)).save(self.root/'pose.png')
        summary,_=analyze(self.root,self.plan,self.report)
        self.assertTrue(any('TRANSPARENT_FRAME' in r['error'] for r in summary['technical_failures']))
    def test_selected_pin_mismatch_is_preserved(self):
        self.plan['resources']=[dict(sha256='new',entries=[dict(id='actor',register='ledger',frames='frame.tres',recorded_frames='frame.tres',recorded_frames_sha256='old')])]
        summary,_=analyze(self.root,self.plan,self.report)
        self.assertEqual(len(summary['staging_pin_mismatches']),1)
        self.assertEqual(summary['new_quality_approvals'],0)

    def test_missing_profile_remains_in_denominator_and_failures(self):
        self.report['resources'][0]['entries']=[dict(entry_id='actor',category='mythic',scope='staging',failures=['PROFILE_LOAD_FAILED'],resolved=[dict(required=True,role_available=False,existing_runtime_walk_fallback=False) for _ in range(33)])]
        summary,_=analyze(self.root,self.plan,self.report)
        self.assertEqual(summary['counts']['mythic:staging']['required_requests'],33)
        self.assertEqual(summary['counts']['mythic:staging']['missing_requests'],33)
        self.assertEqual(summary['entry_failures'][0]['error'],'PROFILE_LOAD_FAILED')
        self.assertEqual(summary['new_quality_approvals'],0)

if __name__=='__main__':unittest.main()
