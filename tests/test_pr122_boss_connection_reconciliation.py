import copy, hashlib, json, sys, tempfile, unittest
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parents[1]/'tools'))
from reconcile_pr122_boss_connections import reconcile, STAGING, CONNECTIONS, CATALOG

class ReconciliationTest(unittest.TestCase):
    def setUp(self):
        self.temp=tempfile.TemporaryDirectory();self.addCleanup(self.temp.cleanup);self.root=Path(self.temp.name)
        self.key='monster:fixture';self.resource='assets/published/SpriteFrames.tres'
        tracks=[f'{role}_{d}' for role in ['idle','run','attack','hit'] for d in range(8)]+['death_2']
        text='\n'.join('"name": &"'+x+'"' for x in tracks)+'\nmetadata/twilight_production_connected = true\nmetadata/twilight_detailed_completed = false\n'
        p=self.root/self.resource;p.parent.mkdir(parents=True);p.write_text(text)
        self.actor=dict(frames='res://assets/staging/old.tres',frames_sha256='preserve-source-pin',production_connected=False,detailed_completed=False,quality_review='HOLD')
        self.put(STAGING,dict(actors={self.key:self.actor},new_approvals=0,default_catalog_switches=0))
        self.put(CONNECTIONS,dict(connections=[dict(id=self.key,frames='res://'+self.resource,frames_sha256=hashlib.sha256(p.read_bytes()).hexdigest(),required_clips=33)]))
        self.put(CATALOG,dict(profiles={self.key:dict(frames_path='res://'+self.resource,attack_hit_frame=1)}))
    def put(self,path,value):
        p=self.root/path;p.parent.mkdir(parents=True,exist_ok=True);p.write_text(json.dumps(value))
    def test_reconcile_is_metadata_only_and_idempotent(self):
        before,after,report=reconcile(self.root)
        expected=copy.deepcopy(before);expected['actors'][self.key].update(production_connected=True,connected_frames='res://'+self.resource)
        self.assertEqual(after,expected);self.assertEqual(report['new_art_approvals'],0)
        self.assertEqual(json.loads((self.root/STAGING).read_text()),before)
        self.put(STAGING,after);self.assertEqual(reconcile(self.root)[2]['changes'],[])
    def test_stale_catalog_rejected(self):
        self.put(CATALOG,dict(profiles={self.key:dict(frames_path='res://other.tres')}))
        with self.assertRaisesRegex(AssertionError,'Catalog binding mismatch'):reconcile(self.root)
    def test_changed_published_bytes_rejected(self):
        with (self.root/self.resource).open('a') as f:f.write('changed')
        with self.assertRaisesRegex(AssertionError,'Published SHA mismatch'):reconcile(self.root)
    def test_missing_track_rejected_even_with_matching_pin(self):
        p=self.root/self.resource;p.write_text(p.read_text().replace('"name": &"run_7"',''))
        j=json.loads((self.root/CONNECTIONS).read_text());j['connections'][0]['frames_sha256']=hashlib.sha256(p.read_bytes()).hexdigest();self.put(CONNECTIONS,j)
        with self.assertRaisesRegex(AssertionError,'Missing published tracks'):reconcile(self.root)

if __name__=='__main__':unittest.main()
