"""Pure fixtures: CI results, observer failures and art findings stay separate."""
import copy
import unittest
from unittest import mock

import reconcile_remaining_findings_v03 as runner


SHA = 'a' * 64
OLD_RUN = 40009886980
CURRENT_RUN = 40014699342


class FakeEvidence:
    def __init__(self, reports):
        self.reports = reports

    def artifact(self, reference):
        return copy.deepcopy(self.reports[reference['path']]), reference['sha256']


class ReceiptSeparationTests(unittest.TestCase):
    def fixtures(self, connected_status='in_progress', connected_conclusion=''):
        reports = {
            'ci1.json': {'schema': 'legendary-final-github-ci-v01', 'status': 'completed',
                         'conclusion': 'failure', 'run_id': OLD_RUN, 'commit': '1' * 40,
                         'error': 'Original900second import timeout'},
            'ci2-observer.json': {'schema': 'legendary-final-github-ci-v01', 'status': 'OBSERVATION_BLOCKED',
                                  'conclusion': '', 'run_id': CURRENT_RUN, 'commit': '2' * 40,
                                  'error': 'HTTP401: observer credential expired'},
            'ci2-connected.json': {'schema': 'legendary-final-github-ci-connected-followup-v01',
                                   'status': connected_status, 'conclusion': connected_conclusion,
                                   'run_id': CURRENT_RUN, 'commit': '2' * 40},
        }
        gate = {'integration_receipts': [{'path': path, 'sha256': SHA} for path in reports],
                'active_staging': {'sha256': SHA}, 'active_manifest': {'sha256': SHA}}
        return reports, gate

    def test_ci1_failure_and_observer401_are_not_the_latest_ci_result(self):
        reports, gate = self.fixtures()
        result = runner.integration_artifacts(FakeEvidence(reports), gate)
        self.assertEqual([x['reported_result']['status'] for x in result],
                         ['completed', 'OBSERVATION_BLOCKED', 'in_progress'])
        self.assertEqual([x['reported_result']['conclusion'] for x in result], ['failure', '', ''])
        self.assertEqual(result[0]['reported_result']['run_id'], OLD_RUN)
        self.assertEqual(result[1]['reported_result']['run_id'], result[2]['reported_result']['run_id'])
        self.assertEqual(result[2]['reported_result']['run_id'], CURRENT_RUN)

    def test_completed_followup_keeps_actual_result_and_preserves_ci1_history(self):
        reports, gate = self.fixtures('completed', 'success')
        result = runner.integration_artifacts(FakeEvidence(reports), gate)
        self.assertEqual(result[-1]['reported_result']['conclusion'], 'success')
        self.assertEqual(result[0]['reported_result']['conclusion'], 'failure')
        self.assertEqual(result[1]['reported_result']['status'], 'OBSERVATION_BLOCKED')

    def test_integration_metadata_cannot_add_or_resolve_art_findings(self):
        reports, gate = self.fixtures()
        art = {'visual_findings': [{'issue_id': 'original', 'resolution_status': 'HOLD'}],
               'active_residual_units': {'unique_active_or_missing_clips': 1}}
        original = copy.deepcopy(art)
        art['integration_evidence'] = runner.integration_artifacts(FakeEvidence(reports), gate)
        self.assertEqual(art['visual_findings'], original['visual_findings'])
        self.assertEqual(art['active_residual_units'], original['active_residual_units'])
        self.assertNotIn('camera', repr(art['integration_evidence']))

    def test_incomplete_root_gate_cannot_start_corpus_even_with_ci1_completed(self):
        _, gate = self.fixtures()
        gate.update(all_possible_corrections_complete=False, local_integration_checks_complete=False)
        with mock.patch.object(runner, 'assert_core'), mock.patch.object(runner.core, 'safe_json', return_value=(gate, SHA)), mock.patch.object(runner, 'Evidence') as evidence:
            with self.assertRaisesRegex(ValueError, 'no reconciliation executed'):
                runner.finalize('fixture-only.json')
            evidence.assert_not_called()


if __name__ == '__main__':
    unittest.main()
