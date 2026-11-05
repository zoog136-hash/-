"""Small numeric/metadata fixtures only; no original asset, decode or build success.
Parallel process tests deliberately mock disk_usage, not production free space.
"""
import errno
import io
import json
import multiprocessing
import os
from pathlib import Path
import sys
import tempfile
import time
from types import SimpleNamespace
import unittest
from unittest import mock

sys.path.insert(0,str(Path(__file__).resolve().parent))
import base508_build_space as space

USAGE=SimpleNamespace(total=1000,used=0,free=1000)
def worker(directory, output, barrier, ready, release):
    with mock.patch.object(space.shutil,'disk_usage',return_value=USAGE):
        barrier.wait()
        try:
            with space.reserve_budget(output,600,0,100,state_dir=directory)as lease:
                ready.put(('acquired',os.getpid(),lease.details));release.wait(10)
        except space.BuildSpaceError as error:ready.put(('denied',os.getpid(),error.details))

def holding_worker(directory,output,ready):
    with mock.patch.object(space.shutil,'disk_usage',return_value=USAGE):
        with space.reserve_budget(output,600,100,100,state_dir=directory)as lease:
            ready.put(lease.as_dict());time.sleep(20)

class SpaceTests(unittest.TestCase):
    def setUp(self):
        self.temp=tempfile.TemporaryDirectory();self.addCleanup(self.temp.cleanup)
        self.root=Path(self.temp.name);self.state=self.root/'state';self.output=self.root/'output'
    def lease(self,expected=100,temporary=50,reserve=100):
        return space.reserve_budget(self.output,expected,temporary,reserve,state_dir=self.state)
    def rows(self):
        files=list(self.state.glob('*.json'))
        return json.loads(files[0].read_text())['reservations']if files else[]
    def test_measures_real_filesystem_without_creating_output(self):
        with self.lease(0,0,0)as lease:
            self.assertGreater(lease.details['actual_free'],0)
            self.assertFalse(self.output.exists());self.assertEqual(len(self.rows()),1)
        self.assertEqual(self.rows(),[])
    def test_normal_and_exception_release_preserve_payload(self):
        self.output.mkdir();sentinel=self.output/'uncommitted-source.txt';sentinel.write_text('keep')
        with mock.patch.object(space.shutil,'disk_usage',return_value=USAGE):
            with self.lease()as lease:self.assertEqual(lease.details['shortfall'],0)
            with self.assertRaisesRegex(ValueError,'fixture body error'):
                with self.lease():raise ValueError('fixture body error')
        self.assertEqual(self.rows(),[]);self.assertEqual(sentinel.read_text(),'keep')
    def test_release_uses_absolute_state_path_after_cwd_change(self):
        original=Path.cwd()
        try:
            os.chdir(self.root)
            with mock.patch.object(space.shutil,'disk_usage',return_value=USAGE):
                with space.reserve_budget(self.output,10,0,0,state_dir=Path('state'))as lease:
                    self.assertTrue(Path(lease.state_file).is_absolute())
                    os.chdir(original)
            self.assertEqual(self.rows(),[])
        finally:os.chdir(original)
    def test_shortfall_is_structured_without_output(self):
        with mock.patch.object(space.shutil,'disk_usage',return_value=SimpleNamespace(free=100)):
            with self.assertRaises(space.BuildSpaceError)as caught:
                with self.lease(80,30,20):self.fail('insufficient reservation admitted')
        result=caught.exception.details
        self.assertEqual((result['actual_free'],result['expected_new_bytes'],result['temporary_peak_bytes'],result['reserve_bytes'],result['other_reserved'],result['shortfall']),(100,80,30,20,0,30))
        self.assertEqual(caught.exception.exit_code,75);self.assertFalse(result['source_failure']);self.assertFalse(self.output.exists())
    def test_same_pid_independent_reservations_cannot_double_book(self):
        with mock.patch.object(space.shutil,'disk_usage',return_value=USAGE):
            with self.lease(600,0,100):
                with self.assertRaises(space.BuildSpaceError)as caught:
                    with self.lease(400,0,100):self.fail('double booking')
                self.assertEqual(caught.exception.details['other_reserved'],600)
                self.assertEqual(caught.exception.details['shortfall'],100)
                self.assertEqual(len(self.rows()),1)
        self.assertEqual(self.rows(),[])
    def test_strictest_live_reserve_floor_is_preserved(self):
        with mock.patch.object(space.shutil,'disk_usage',return_value=USAGE):
            with self.lease(200,0,500):
                with self.assertRaises(space.BuildSpaceError)as caught:
                    with self.lease(400,0,0):self.fail('live safety floor bypassed')
                self.assertEqual(caught.exception.details['effective_reserve_bytes'],500)
                self.assertEqual(caught.exception.details['shortfall'],100)
    def test_two_parallel_pids_different_output_dirs_only_one_starts(self):
        ctx=multiprocessing.get_context('fork');barrier=ctx.Barrier(2);ready=ctx.Queue();release=ctx.Event()
        processes=[ctx.Process(target=worker,args=(self.state,self.root/f'shard-{i}',barrier,ready,release))for i in range(2)]
        try:
            for process in processes:process.start()
            rows=[ready.get(timeout=10),ready.get(timeout=10)]
            self.assertEqual(sorted(r[0]for r in rows),['acquired','denied'])
            denied=next(r[2]for r in rows if r[0]=='denied')
            self.assertEqual(denied['other_reserved'],600);self.assertEqual(denied['shortfall'],300)
            self.assertEqual(len(self.rows()),1)
        finally:
            release.set()
            for process in processes:
                process.join(10)
                if process.is_alive():process.terminate();process.join()
        self.assertEqual([p.exitcode for p in processes],[0,0]);self.assertEqual(self.rows(),[])
    def test_dead_owner_only_is_pruned_without_payload_cleanup(self):
        ctx=multiprocessing.get_context('fork');ready=ctx.Queue()
        process=ctx.Process(target=holding_worker,args=(self.state,self.output,ready))
        sentinel=self.root/'finished-result.txt';sentinel.write_text('preserve')
        try:
            process.start();ready.get(timeout=10)
            self.assertEqual(len(self.rows()),1)
            with mock.patch.object(space.shutil,'disk_usage',return_value=USAGE):
                with self.assertRaises(space.BuildSpaceError):
                    with self.lease(400,0,100):self.fail('live PID ignored')
            self.assertEqual(len(self.rows()),1)
            process.terminate();process.join(10)
            with mock.patch.object(space.shutil,'disk_usage',return_value=USAGE):
                with self.lease(800,0,100)as lease:
                    self.assertEqual(lease.details['ignored_dead_reservations'],1)
                    self.assertEqual(lease.details['other_reserved'],0)
            self.assertEqual(self.rows(),[]);self.assertEqual(sentinel.read_text(),'preserve')
        finally:
            if process.is_alive():process.terminate();process.join()
    def test_permission_denied_liveness_check_does_not_prune(self):
        with mock.patch.object(space.os,'kill',side_effect=PermissionError):
            self.assertTrue(space._alive({'pid':123,'process_start':None}))
    def test_corrupt_ledger_fails_closed_and_is_not_reset(self):
        with self.lease(0,0,0)as lease:path=Path(lease.state_file)
        path.write_text('not a reservation JSON')
        with self.assertRaises(space.BuildSpaceError)as caught:
            with self.lease():self.fail('corrupt ledger reset')
        self.assertEqual(caught.exception.details['reason'],'reservation_state_unavailable')
        self.assertEqual(path.read_text(),'not a reservation JSON')
    def test_write_capacity_error_releases_lease_and_returns_storage_error(self):
        with mock.patch.object(space.shutil,'disk_usage',return_value=USAGE):
            with self.assertRaises(space.BuildSpaceError)as caught:
                with self.lease():raise OSError(errno.ENOSPC,'numeric fixture capacity failure')
        self.assertEqual(caught.exception.details['reason'],'write_capacity_error')
        self.assertEqual(caught.exception.details['actual_free'],1000)
        self.assertEqual(caught.exception.exit_code,75);self.assertEqual(self.rows(),[])
    def test_invalid_budget_does_not_create_state(self):
        for value in [-1,1.5,True]:
            with self.assertRaises(ValueError):
                with self.lease(value):self.fail('invalid budget')
        self.assertFalse(self.state.exists())

if __name__=='__main__':unittest.main()
