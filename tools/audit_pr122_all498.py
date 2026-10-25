#!/usr/bin/env python3
"""Reconcile the fixed 498-species scope without granting new art approvals.

Historical coverage is preserved separately from the user's stricter current
approval gates. Shared bodies, loaded resources and passing CI cannot confer
per-species visual approval. This program never writes production resources.
"""
import argparse
from collections import Counter
from datetime import datetime, timezone
import hashlib
import json
from pathlib import Path
import re
import subprocess


SCOPE = {'hero_plus', 'normal_monster', 'boss'}
FOLLOWUP14 = ['258', '412', '288', '401', '176', '351', '349', '328',
              '249', '218', '173', '167', '110', '2']
PAIR = {'monster:알비노 이구아나', 'monster:공포의 아그니'}


def build(root, ci_file):
    def read(relative):
        return json.loads((root / relative).read_text())

    def sha(path):
        return hashlib.sha256(path.read_bytes()).hexdigest()

    head = subprocess.check_output(['git', '-C', str(root), 'rev-parse', 'HEAD'], text=True).strip()
    coverage = read('docs/remake/evidence/pr100-direction-fix/original-based/coverage/coverage.json')
    pending_path = 'docs/remake/evidence/pr100-direction-fix/original-based/final-handoff-20261015/remaining106.json'
    pending = {x['id']: x for x in read(pending_path)['identities']}
    sources = {x['key']: x for x in read('data/animation_authoring_sources.json')['targets']}
    profiles = read('data/combat_animation_profiles.json')['profiles']
    identities = [x for x in coverage['identities'] if x['group'] in SCOPE]
    assert len(identities) == len({x['key'] for x in identities}) == 498
    assert sum(x['native_connected'] for x in identities) == 392
    tracked = set(subprocess.check_output(['git', '-C', str(root), 'ls-files', '-z']).decode().split('\0'))
    ci = json.loads(ci_file.read_text()) if ci_file else {'workflow_runs': []}
    runs = ci['workflow_runs']
    assert not ci_file or (runs and all(x['head_sha'] == head for x in runs)), 'CI snapshot must match audited HEAD exactly'
    required = {x['workflow_id']: x['name'] for x in read(
        'docs/remake/evidence/pr122-remaining106/batch10/ci-846b71d.json')['workflow_runs']}
    latest = {}
    for run in runs:
        latest.setdefault(run['workflow_id'], run)
    missing_ci = [{'workflow_id': i, 'name': name} for i, name in required.items() if i not in latest]
    full_ci_pass = not missing_ci and all(latest[i]['conclusion'] == 'success' for i in required)
    checkpoint = read('docs/remake/TWILIGHT_REMAINING106_CHECKPOINT.json')
    active_path = (root / checkpoint.get('active_batch_checkpoint',
        'docs/remake/evidence/pr122-remaining106/batch10/continuation-state.json')).resolve()
    assert active_path.is_relative_to(root), 'Active checkpoint must stay inside checkout'
    active = json.loads(active_path.read_text()).get('active_authoring', {}) if active_path.is_file() else {}
    # Explicit species decisions are separate from the final integration CI.
    # Never create an approval from a count, a resource binding or a CI result.
    approvals = {}
    registry_path = checkpoint.get('individual_approval_registry')
    if registry_path:
        registry = read(registry_path)
        for decision in registry['decisions']:
            key = decision['id']
            assert key not in approvals and decision['status'] == 'APPROVED'
            assert key in {x['key'] for x in identities if not x['native_connected']}
            assert all(value == 'PASS' for value in decision['species_gates'].values())
            for pin in decision['evidence_pins']:
                relative = pin['path']
                path = (root / relative).resolve()
                assert path.is_relative_to(root) and path.is_file()
                assert sha(path) == pin['sha256'], f'Approval evidence changed: {relative}'
            preservation = read(decision['source_preservation_manifest'])
            for pin in preservation['checked_files']:
                path = root / pin['path']
                assert pin['path'] in tracked and sha(path) == pin['sha256'], f'Approved source changed: {path}'
            profile_sha = hashlib.sha256(json.dumps(profiles[key], ensure_ascii=False,
                sort_keys=True, separators=(',', ':')).encode()).hexdigest()
            assert profile_sha == decision['reviewed_profile_sha256'], f'Approved profile changed: {key}'
            approvals[key] = decision
    files = {}

    def resource(relative):
        relative = relative.removeprefix('res://')
        path = (root / relative).resolve()
        assert path.is_relative_to(root) and path != root
        if relative not in files:
            files[relative] = {'path': relative, 'present': path.is_file(), 'tracked': relative in tracked}
            if path.is_file():
                files[relative].update(bytes=path.stat().st_size, sha256=sha(path))
        return files[relative]

    rows = []
    animation_pattern = re.compile(r'\{"frames"\s*:\s*\[(.*?)\],\s*"loop"\s*:\s*(?:true|false),\s*"name"\s*:\s*&"([^"]+)"', re.S)
    for old in identities:
        key = old['key']
        profile = profiles.get(key, {})
        binding = profile.get('frames_path', '') if profile.get('layout') == 'directional8' else ''
        previous = pending.get(key)
        followup = key in {'transform:' + n for n in FOLLOWUP14}
        row = {'id': key, 'name': old['name'], 'group': old['group'],
               'legacy_completed': old['native_connected'],
               'runtime_connected': bool(binding), 'frames_path': binding,
               'recorded_main_eight_direction_claim': old['actual_gameplay'],
               'Android_real_device': 'NOT_RUN', 'current_contract_APPROVED': False,
               'newly_approved': False, 'locomotion14_quality_followup': followup}
        # APPROVED is deliberately never inferred from old coverage or CI.
        if key in approvals:
            row.update(status='APPROVED', queue='COMPLETED',
                       current_contract_APPROVED=True, newly_approved=True,
                       approval_decision=approvals[key],
                       reason='Explicit per-species source/Main/independent visual decision, with unchanged pinned source and profile. Final integration CI/APK remain separate.')
        elif key in PAIR:
            row.update(status='CI_PASS' if full_ci_pass else 'MAIN_VISUAL_PASS',
                       queue='FINAL_REVIEW_CONFIRMATION' if full_ci_pass else 'CI_PENDING',
                       reason='Existing post-authoring Main review passed; verify all required exact-HEAD workflows and final approval evidence separately.')
        elif old['native_connected']:
            row.update(status='APPROVED', queue='PRESERVE_LEGACY_COMPLETION',
                       approval_basis='PRESERVED_LEGACY_392',
                       reason='Existing approved completion retained; this audit grants no new review for legacy art. Track any locomotion repair separately without recounting the species.')
        elif previous and previous['status'].startswith('HOLD'):
            row.update(status='HOLD', queue='EXISTING_HOLD', reason=previous['reason'])
        elif key in active or binding:
            blocked = key in active and active[key].get('status') == 'HOLD'
            row.update(status='HOLD' if blocked else 'AUTHORING',
                       queue='SOURCE_HOLD' if blocked else 'AUTHORING_UNAPPROVED',
                       reason=active.get(key, {}).get('blocker',
                           'Source work or a runtime binding exists; full required motion and visual/CI approval are not established.'))
            if key in active:
                row['active_authoring'] = active[key]
        else:
            row.update(status='NOT_STARTED', queue='NOT_AUTHORED_OR_CONNECTED',
                       reason=(previous or {}).get('reason', old['missing_source']))
        if key in sources:
            row['source_reference'] = sources[key]['reference']
            resource(row['source_reference']['path'])
        if previous:
            row['legacy_pending_record'] = previous
        if binding:
            row['binding_resource'] = resource(binding)
            path = root / binding.removeprefix('res://')
            if path.is_file():
                text = path.read_text()
                row['animation_track_counts'] = {
                    name: len(re.findall(r'"duration"\s*:', frames))
                    for frames, name in animation_pattern.findall(text)}
                row['required_existing_roles'] = sorted({name.rsplit('_', 1)[0]
                                                        for name in row['animation_track_counts']})
                row['linked_resource_paths'] = sorted(set(re.findall(r'path="(res://[^"]+)"', text)))
                for source in row['linked_resource_paths']:
                    resource(source)
                provenance = path.parent / 'provenance.json'
                if provenance.is_file():
                    row['production_provenance'] = resource(provenance.relative_to(root).as_posix())
        if followup:
            row['quality_work'] = 'Existing Android walking/running complaint; genuine 6-8 pose walk and distinct run, all eight directions and transitions. Count as quality repair, not a new species.'
        rows.append(row)
    counts = Counter(x['status'] for x in rows)
    outside_classes = [{'id': x['key'], 'name': x['name'],
                        'frames_path': profiles.get(x['key'], {}).get('frames_path', ''),
                        'inside498': False}
                       for x in coverage['identities'] if x['group'] == 'class'
                       and profiles.get(x['key'], {}).get('layout') == 'directional8'
                       and profiles.get(x['key'], {}).get('frames_path')]
    return {'schema': 1, 'observed_UTC': datetime.now(timezone.utc).isoformat(),
            'repository': 'zoog136-hash/-', 'PR': 122, 'audited_commit': head,
            'scope': '180 hero-plus transforms + 258 normal monsters + 60 bosses; fixed 498 unique identities',
            'approval_policy': 'Latest user directive: preserve legacy392; explicit complete per-species source/Main/independent visual decisions may be approved while full integration CI/APK are deferred to the final stage. This audit never grants approvals.',
            'summary': {'target': 498, 'user_confirmed_baseline': 392,
                        'historical_unverified_report': 398,
                        'Git_recorded_completed_preserved': 392, 'unsubstantiated_difference': 6,
                        'runtime_connected': sum(x['runtime_connected'] for x in rows),
                        'legacy_remaining': 106, 'legacy_HOLD': 16,
                        'CI_pending': counts['MAIN_VISUAL_PASS'],
                        'legacy_not_authored_or_connected': 88,
                        'new_approved': len(approvals),
                        'completed': 392 + len(approvals), 'remaining': 106 - len(approvals),
                        'HOLD': counts['HOLD'], 'AUTHORING': counts['AUTHORING'],
                        'NOT_STARTED': counts['NOT_STARTED'],
                        'current_contract_approvals_granted_by_audit': 0,
                        'current_evidence_states': dict(counts)},
            'CI': {'head_sha': head, 'snapshot_sha256': sha(ci_file) if ci_file else None,
                   'status': 'EXACT_HEAD_SNAPSHOT' if ci_file else 'DEFERRED_TO_FINAL_INTEGRATION',
                   'all_returned_runs_success': bool(runs) and all(x['conclusion'] == 'success' for x in runs),
                   'required_workflows': required, 'missing_required_workflows': missing_ci,
                   'all_required_workflows_success': full_ci_pass,
                   'runs': [{'id': x['id'], 'name': x['name'], 'status': x['status'],
                             'conclusion': x['conclusion'], 'head_sha': x['head_sha'],
                             'url': x['html_url']} for x in runs]},
            'quality_followup14': [{'id': 'transform:' + n,
                                   'inside498': 'transform:' + n in {x['id'] for x in rows},
                                   'new_species_count': 0, 'Android_retest': 'NOT_RUN'} for n in FOLLOWUP14],
            'reported398_scope_crosscheck': {
                'target_runtime_bindings': sum(x['runtime_connected'] for x in rows),
                'additional_base_class_bindings_outside498': outside_classes,
                'arithmetic_total': sum(x['runtime_connected'] for x in rows) + len(outside_classes),
                'interpretation': f'{sum(x["runtime_connected"] for x in rows)} target bindings plus {len(outside_classes)} base-class bindings are connections, not approved target species. Historical398 is not adopted as a completion baseline; base classes remain outside180+258+60.'},
            'identities': rows, 'resources': list(files.values()),
            'audit_context': {'input_snapshot':'current working tree; audited_commit is the parent HEAD when changes are uncommitted',
                              'production_mutated_flag_scope':'this read-only auditor, not earlier authorized changes in the session',
                              'worktree_changes':subprocess.check_output(['git','-C',str(root),'status','--porcelain'],text=True).splitlines(),
                              'report_commit_resolution':'git log -1 --format=%H -- <this report path>'},
            'production_mutated': False, 'prior_approval_assets_replaced': False}


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--root', type=Path, default=Path(__file__).resolve().parents[1])
    parser.add_argument('--ci-json', type=Path, help='Optional exact-HEAD snapshot; omitted during production, with final CI explicitly deferred')
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    if args.output.exists():
        parser.error('Earlier evidence is immutable; select a new output path')
    result = build(args.root.resolve(), args.ci_json.resolve() if args.ci_json else None)
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(result, ensure_ascii=False, indent=2) + '\n')
    print(json.dumps(result['summary'], ensure_ascii=False))
