"""Regression checks for lost review state and false rejection of approved clips."""
import contextlib
import copy
import importlib.util
import io
import json
from pathlib import Path
import tempfile
import unittest

HERE=Path(__file__).resolve().parent
ROOT=HERE.parents[2]


def module(name):
    spec=importlib.util.spec_from_file_location(name,HERE/(name+'.py'))
    result=importlib.util.module_from_spec(spec)
    spec.loader.exec_module(result)
    return result


class HeroAuditRegressions(unittest.TestCase):
    def test_real_five_six_phase_cycles_are_not_rejected_or_padded(self):
        qa=module('check_artifacts')
        for counts in [[6]*8,[5]*8,[5,6,6,6,5,5,5,5]]:
            frames=[dict(direction=d,phase=p) for d,c in enumerate(counts) for p in range(c)]
            self.assertEqual([len(row) for row in qa.run_rows(frames)],counts)

    def test_missing_heading_or_repeated_phase_stays_rejected(self):
        qa=module('check_artifacts')
        frames=[dict(direction=d,phase=p) for d in range(8) for p in range(6)]
        with self.assertRaises(AssertionError):qa.run_rows(frames[:-6])
        frames[5]['phase']=0
        with self.assertRaises(AssertionError):qa.run_rows(frames)

    def pixel_case(self):
        row=dict(direction=5,phase=4,rgba_sha256='exact-reviewed-pixels',components_8=[2535,20])
        accepted=dict(status='APPROVED_ISOLATED_PIXEL_ARTIFACTS',atlas_sha256_by_actor={'transform:359':'exact-atlas'},findings=[dict(row,id='transform:359',visually_reviewed=True,accepted_by_latest_user_policy=True)])
        return row,accepted

    def test_reviewed_tiny_fragment_passes_only_for_its_exact_art(self):
        qa=module('check_artifacts');row,accepted=self.pixel_case()
        qa.require_reviewed_isolated_artifacts([row],accepted,'transform:359','exact-atlas')
        with self.assertRaises(AssertionError):qa.require_reviewed_isolated_artifacts([row],accepted,'transform:359','different-atlas')
        row['rgba_sha256']='unreviewed'
        with self.assertRaises(AssertionError):qa.require_reviewed_isolated_artifacts([row],accepted,'transform:359','exact-atlas')

    def test_larger_part_or_unreviewed_exception_stays_rejected(self):
        qa=module('check_artifacts');row,accepted=self.pixel_case()
        row['components_8']=[2535,25];accepted['findings'][0]['components_8']=[2535,25]
        with self.assertRaises(AssertionError):qa.require_reviewed_isolated_artifacts([row],accepted,'transform:359','exact-atlas')
        row,accepted=self.pixel_case();accepted['findings'][0]['visually_reviewed']=False
        with self.assertRaises(AssertionError):qa.require_reviewed_isolated_artifacts([row],accepted,'transform:359','exact-atlas')

    def test_roster_refresh_preserves_entire_repair_scope_and_future_annotations(self):
        roster=module('build_roster')
        data=json.loads((ROOT/'data/pr122_hero_parallel_staging.json').read_text())
        data['future_review_schema']={'must_survive':['all','fields']}
        data['actors']['transform:16']['future_visual_note']={'source':'reviewed'}
        with tempfile.TemporaryDirectory(prefix='hero-roster-test-') as directory:
            roster.OUT=Path(directory)/'staging.json'
            before=json.dumps(data,ensure_ascii=False,indent=2)+'\n'
            roster.OUT.write_text(before)
            with contextlib.redirect_stdout(io.StringIO()):roster.build()
            self.assertEqual(roster.OUT.read_text(),before)


if __name__=='__main__':unittest.main()
