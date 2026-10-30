"""Fail-closed result parsing and bounded process execution for test_project.py.

The subprocess tests for this module use controlled programs, not the Godot engine.
"""
from __future__ import annotations

import json
import os
import re
import signal
import subprocess
import tempfile
import time
from pathlib import Path
from collections.abc import Mapping, Sequence

ERROR = re.compile(
    r'SCRIPT ERROR:|ERROR:|FAIL:|^\s*(?:[A-Z][A-Z0-9_]*_)?FAIL(?:ED)?(?=[:\s]|$)',
    re.MULTILINE,
)
REPORT = re.compile(r'\b[A-Z][A-Z0-9_]*_RESULT\s+(.+)$')
SUCCESS = re.compile(r'\b[A-Z][A-Z0-9_]*_OK\b')
SKIP = re.compile(r'\b[A-Z][A-Z0-9_]*_SKIP:')
OPTIONAL_RENDER_ENV = re.compile(
    r'^\s*#\s*TWILIGHT_OPTIONAL_RENDER_ENV:\s*([A-Z][A-Z0-9_]*)\s*$',
    re.MULTILINE,
)
# Fixed, existing TWILIGHT geometry contracts; not source-grid acceptance.
# Do not add generic gameplay tests here to hide source regressions.
LEGACY_GEOMETRY_TESTS = frozenset({
    # These suites explicitly install legacy_aden_fixture and assert
    # layout-1 cottage/courtyard/river coordinates. Without the existing
    # CLI flag, the installed A3 pack overrides that fixture at map load.
    # Active Aden acceptance remains in the separate source-runtime suites.
    'aden_building_test', 'aden_courtyard_test',
    'aden_shoreline_test', 'aden_terrain_polish_test',
    # field_world installs explicit pr84 layout-1 river/bridge gameplay
    # fixture; source A3 acceptance stays in unflagged live runtime suites.
    'field_world_test',
    'reference_object_placement_test', 'road_surface_render_test',
    'terrain_surface_render_test', 'world_region_portals_test',
    'world_regions_test', 'world_structure_test', 'world_terrain_coverage_test',
})
# This existing producer writes a counted summary rather than an _OK marker.
# Accept only its exact, positive-check, zero-failure report, for that test only.
RENEWED_SPAWN_SUMMARY = re.compile(
    r'^RENEWED MAP SPAWN TEST: ([1-9][0-9]*) checks, ([0-9]+) failures$',
    re.MULTILINE,
)
# These existing PR122 producers end with a _PASS summary, not _OK/JSON.
# Bind the exact terminal contract to its own suite; an arbitrary PASS line,
# zero-work summary, another actor's default-Main proof, or a partial prefix
# must never turn an unfinished subprocess into a successful check.
PR122_PASS_SUMMARIES = {
    'pr122_girtas_native_default_main_connection_test':
        r'PR122_NATIVE_DEFAULT_MAIN_PASS key=transform:267 tracks=48 poses=288 candidate_injection=0',
    'pr122_native_default_main_connection_test':
        r'PR122_NATIVE_DEFAULT_MAIN_PASS key=transform:393 tracks=48 poses=288 candidate_injection=0',
    'pr122_native_action_test':
        r'PR122_NATIVE_ACTION_PASS clips=[1-9][0-9]* all_six_phases=true attack_marker_frame=3 authoritative_clock_preserved=true native_foot_collision_class_preserved=true engine=.+ approvals_added=0',
    'pr122_native_batch_candidate_test':
        r'PR122_BATCH_CANDIDATE_INTEGRATION_PASS actors=[1-9][0-9]* clips=[1-9][0-9]* death_directions=[0-9]+ unsized_frame_fixtures=[0-9]+ production_switches=0 approvals_added=0',
    'pr122_native_locomotion_resource_test':
        r'PR122_NATIVE_RESOURCE_PASS tracks=[1-9][0-9]* poses=[1-9][0-9]* approvals_added=0 engine=.+',
    'pr122_native_main_connection_test':
        r'PR122_NATIVE_MAIN_PASS key=transform:[0-9]+ native_clips=48 directional_cases=40 plus_death=true authoritative_clock_inventory_collision_preserved=true catalog_replacements=0 approvals_added=0',
    'pr122_native_player_connection_test':
        r'PR122_NATIVE_PLAYER_CONNECTION_PASS actors=[1-9][0-9]* clips=[1-9][0-9]* native_phases=[1-9][0-9]* position_collision_class_combat_sequence_preserved=true engine=.+ production_catalog_switches=0 approvals_added=0',
    'pr122_native_reaction_test':
        r'PR122_NATIVE_REACTION_PASS actors=[1-9][0-9]* hit_cases=[1-9][0-9]* fps=30,60,120 headings=E,N catalog_candidate_without_profile_metadata=true moving_and_stationary=true all_six_phases=true hit_clock_combat_marker_collision_class_preserved=true turn_idle_death=true engine=.+ approvals_added=0',
    'pr122_monster_run_only_scope_test':
        r'PR122_MONSTER_RUN_ONLY_SCOPE_PASS monsters=318 run_cases=[1-9][0-9]* existing_walk=preserved transform_unknown=7 approvals_added=0',
    'pr122_transform_run_only_scope_test':
        r'PR122_TRANSFORM_RUN_ONLY_SCOPE_PASS cases=7 slow,fast,stationary unique,boss,class,unknown_preserved approvals_added=0',
}
PR122_DEATH_SUMMARY = re.compile(
    r'PR122_S_ONLY_DEATH_MAIN_RESULT directions=8 poses=6 '
    r'actual_staged=(?:true|false) art_approvals=0 failures=0'
)
PR122_NATIVE_FIXTURE_MODES = {
    'pr122_native_locomotion_resource_test': 'staging_resources',
    'pr122_native_batch_candidate_test': 'run_only_candidates',
    'pr122_native_action_test': 'native_profiles',
    'pr122_native_player_connection_test': 'native_profiles',
    'pr122_native_main_connection_test': 'representative_full_main',
}


def native_fixture_environment(name: str, register: Mapping,
                               env: Mapping[str, str]) -> tuple[dict[str, str], dict]:
    """Supply only missing inputs to existing, distinct native QA contracts.

    Resource staging explicitly forbids production approval, the batch fixture
    tests RUN-only candidates with a single S death, and sized Player/action
    fixtures require a native profile. The frame-only candidate remains covered
    by the real Main batch fixture. Existing approved actors retain their two
    independent default-Main tests; the injected Main smoke uses one complete
    representative actor and makes no all-actor gameplay claim.
    """
    if name not in PR122_NATIVE_FIXTURE_MODES:
        return {}, {}
    actors = register.get('actors')
    if not isinstance(actors, dict) or not actors:
        raise ValueError('Native fixture registry must contain actors')
    staging, profiles, run_only, approved = set(), set(), set(), set()
    complete = set()
    for key, actor in actors.items():
        if not isinstance(key, str) or not re.fullmatch(r'transform:[0-9]+', key) or not isinstance(actor, dict):
            raise ValueError('Malformed native fixture actor')
        production, detailed = actor.get('production_connected'), actor.get('detailed_completed')
        if type(production) is not bool or type(detailed) is not bool or production != detailed:
            raise ValueError('Inconsistent native approval flags: ' + key)
        tracks = actor.get('tracks')
        if (not isinstance(tracks, list) or not tracks
                or any(not isinstance(track, dict) or track.get('role') not in
                       {'idle', 'walk', 'run', 'attack', 'hit', 'death'} for track in tracks)):
            raise ValueError('Missing or malformed native fixture tracks: ' + key)
        if actor.get('native_track_count') != len(tracks) or actor.get('native_pose_count') != len(tracks) * 6:
            raise ValueError('Native fixture track/pose count drift: ' + key)
        identities = {(track['role'], track.get('direction')) for track in tracks}
        if (len(identities) != len(tracks)
                or any(direction not in {'E', 'SE', 'S', 'SW', 'W', 'NW', 'N', 'NE'}
                       for _, direction in identities)):
            raise ValueError('Duplicate or invalid native fixture direction: ' + key)
        if isinstance(actor.get('native_profile'), str) and actor['native_profile']:
            profiles.add(key)
            if len(tracks) == 48:
                complete.add(key)
        if production:
            approved.add(key)
        else:
            staging.add(key)
            deaths = [track for track in tracks if track['role'] == 'death']
            if (not any(track['role'] == 'walk' for track in tracks)
                    and len(deaths) <= 1 and all(track.get('direction') == 'S' for track in deaths)):
                run_only.add(key)
    # An actor that lacks a sized profile must be exercised by the existing
    # unsized-frame Main batch path, never silently removed from all runtime QA.
    if profiles | run_only != set(actors):
        raise ValueError('Native actor has no compatible runtime fixture: ' +
                         ','.join(sorted(set(actors) - profiles - run_only)))
    default_main = {'transform:393', 'transform:267'}
    if not default_main.issubset(approved & complete):
        raise ValueError('Existing approved full native actors lost default-Main coverage')
    if approved - default_main:
        raise ValueError('New native approval requires its own default-Main test')
    mode = PR122_NATIVE_FIXTURE_MODES[name]
    variable = 'TWILIGHT_NATIVE_MAIN_KEY' if mode == 'representative_full_main' else 'TWILIGHT_NATIVE_TEST_KEYS'
    compatible = {'staging_resources': staging, 'run_only_candidates': run_only,
                  'native_profiles': profiles, 'representative_full_main': complete}[mode]
    supplied = env.get(variable, '')
    explicit = variable in env
    # Preserve a caller's exact explicit environment; invalid or unsupported
    # requests fail instead of being trimmed, replaced or partially accepted.
    keys = supplied.split(',') if explicit else (
        ['transform:393'] if mode == 'representative_full_main' else sorted(compatible))
    if (not keys or len(keys) != len(set(keys)) or any(key not in compatible for key in keys)
            or (mode == 'representative_full_main' and len(keys) != 1)):
        raise ValueError('Empty, duplicate or incompatible native fixture scope for ' + name)
    updates = {} if explicit else {variable: ','.join(keys)}
    audit = {'contract': mode, 'scope_origin': 'explicit' if explicit else 'registry_default',
             'keys': keys, 'registry_actors': len(actors), 'profile_actors': sorted(profiles),
             'frame_only_batch_actors': sorted(set(actors) - profiles),
             'approved_default_main_actors': sorted(approved)}
    return updates, audit


def requires_renderer(source: str, env: Mapping[str, str]) -> bool:
    """Only explicitly annotated, environment-gated captures may use headless."""
    if 'RenderingServer.frame_post_draw' not in source:
        return False
    optional = OPTIONAL_RENDER_ENV.findall(source)
    if len(optional) == 1:
        return bool(env.get(optional[0], '').strip())
    # Missing/ambiguous annotations retain mandatory real-render validation.
    return True


def timeout_budget(name: str, requested: int, import_timeout: int) -> int:
    """Keep exhaustive real-save audits bounded without dropping assertions."""
    if name == 'import':
        return max(requested, import_timeout)
    if name == 'world_regions_test':
        # Oman 1-5 each has independent full gameplay/physics/save checks;
        # 6-10 share a proven fast shard. The child preserves per-map bounds,
        # and the parent must not kill a valid full regional audit early.
        return max(requested, 7200)
    if name == 'remake_source_runtime_test':
        # Ten live boss/save lifecycles plus 50 real portal transitions and
        # rendered captures. Keep every floor and assertion in the private-pack
        # audit; installations without that pack still explicitly SKIP it.
        return max(requested, 480)
    if name == 'original_skill_learning_conditions_test':
        return max(requested, 540)
    if name == 'eight_interactions_test':
        # Real UI events plus repeated complete floor/inventory save-load cycles.
        return max(requested, 300)
    if name == 'aden_faith_png_monster_spawns_test':
        # Five real PNG maps, eighteen walking gates, nine boss save/death/
        # wall-clock lifecycles and a fresh Main boot share one subprocess.
        # The unchanged 1,261-assertion audit completed in 166.5s in PR #152;
        # retain every assertion and bound this test without changing game time.
        return max(requested, 300)
    if name == 'hunting_paths_test':
        # All 25 real maps and 10,666 physical-route assertions take ~124s
        # locally; leave bounded room for shared CI runners without skipping any.
        return max(requested, 300)
    if name in {'aden_faith_png_runtime_test', 'tower_png_normal_runtime_test'}:
        # The tracked five-map OpenGL audit walks every reviewed route, tests
        # physical boundaries/zoom/portals and round-trips real saves. The
        # PR156 native-PNG job hit the generic 150-second cap without an
        # assertion failure; preserve its full workload with a bounded budget.
        return max(requested, 300)
    if name == 'pr122_native_locomotion_resource_test':
        # The default staging contract has 313 tracks, each observed for
        # 80 real 60Hz frames (>417s before texture decode). Every track stays
        # checked; child isolation bounds memory, this total bounds wall time.
        return max(requested, 900)
    if name in {'pr122_native_action_test', 'pr122_native_player_connection_test',
                'pr122_native_batch_candidate_test'}:
        # Exhaustive default scopes now run in isolated actor processes. Keep
        # every actor while bounding repeated scene setup and texture decoding.
        return max(requested, 600)
    if name == 'ground_loot_system_test':
        # The unchanged 166-check full GUI/physics/save/loot suite completed
        # in ~112 seconds in its dedicated workflow, but exceeded the generic
        # 150-second subprocess cap in the concurrently loaded integration job.
        # Give only this exhaustive real-play suite bounded CI headroom.
        return max(requested, 300)
    if name in {'original_based_mummy_lord_gameplay_test',
                'original_based_seer_boss_gameplay_test',
                'original_based_raziel_watcher_gameplay_test',
                'original_based_salah_gameplay_test'}:
        # Preserve PR100's original-HP boss lifecycle budget.
        return max(requested, 450)
    if name == 'original_based_transform_temporal_main_test':
        # This inherited 10-case Main/120Hz audit runs all original gameplay,
        # save/drop checks and continuous pose playback, not a short smoke.
        return max(requested, 2400)
    return requested


def classify_result(name: str, returncode: int, output: str, *,
                    expected_native_keys: Sequence[str] | None = None) -> tuple[bool, bool]:
    """Return (passed, skipped); errors always override success/skip markers."""
    if returncode != 0 or ERROR.search(output):
        return False, False
    reports = []
    death_summaries = []
    for line in output.splitlines():
        match = REPORT.search(line)
        if match:
            if name == 'pr122_s_only_death_main_test' and line.startswith('PR122_S_ONLY_DEATH_MAIN_RESULT'):
                if PR122_DEATH_SUMMARY.fullmatch(line) is None:
                    return False, False
                death_summaries.append(line)
                continue
            try:
                report = json.loads(match.group(1))
            except json.JSONDecodeError:
                return False, False
            if not isinstance(report, dict) or report.get('failures') != []:
                return False, False
            reports.append(report)
    if name == 'pr122_s_only_death_main_test':
        return not SKIP.search(output) and len(death_summaries) == 1, False
    if name in PR122_PASS_SUMMARIES:
        pattern = PR122_PASS_SUMMARIES[name]
        marker = pattern.split(' ', 1)[0]
        summaries = [line for line in output.splitlines() if line.startswith(marker)]
        # Do not let a generic _OK, an inner actor PASS or SKIP replace the
        # suite's final, nonempty summary. Earlier error/JSON checks still win.
        passed = (not SKIP.search(output) and len(summaries) == 1
                  and re.fullmatch(pattern, summaries[0]) is not None)
        if passed and expected_native_keys is not None:
            # The valid producer syntax must describe this invocation's scope,
            # not a different actor or an accidental unfiltered child run.
            if (not expected_native_keys
                    or len(expected_native_keys) != len(set(expected_native_keys))):
                return False, False
            if name == 'pr122_native_main_connection_test':
                actual = re.search(r' key=(transform:[0-9]+) ', summaries[0]).group(1)
                passed = list(expected_native_keys) == [actual]
            elif name in {'pr122_native_player_connection_test', 'pr122_native_batch_candidate_test'}:
                actual = int(re.search(r' actors=([0-9]+) ', summaries[0]).group(1))
                passed = actual == len(expected_native_keys)
        return passed, False
    spawn_summaries = RENEWED_SPAWN_SUMMARY.findall(output)
    if name == 'renewed_map_spawn_test':
        # Missing, contradictory, duplicate, or nonzero summaries fail closed.
        if SKIP.search(output) or len(spawn_summaries) != 1 or spawn_summaries[0][1] != '0':
            return False, False
        return True, False
    # Import/boot/cache preparation must actually run; SKIP cannot authorize them.
    if SKIP.search(output):
        return (False, False) if name in ('import', 'boot', 'bake_navigation') else (True, True)
    return name in ('import', 'boot') or bool(reports) or bool(SUCCESS.search(output)), False


def _stop_tree(process: subprocess.Popen) -> None:
    """Kill only the process tree/session created by this runner."""
    if os.name == 'posix':
        # The leader can already be dead while descendants still own its pipes.
        try:
            os.killpg(process.pid, signal.SIGKILL)
        except ProcessLookupError:
            pass
    elif process.poll() is None:
        try:
            subprocess.run(
                ['taskkill', '/PID', str(process.pid), '/T', '/F'],
                stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
                check=False, timeout=5,
            )
        except (OSError, subprocess.TimeoutExpired):
            pass
        if process.poll() is None:
            process.kill()


def run_isolated(command: Sequence[str], *, env: Mapping[str, str], timeout: float,
                 cwd: str | None = None) -> subprocess.CompletedProcess:
    """Capture logs loss-tolerantly and clean up descendant processes on timeout."""
    kwargs = {'start_new_session': True} if os.name == 'posix' else {
        'creationflags': subprocess.CREATE_NEW_PROCESS_GROUP,
    }
    with subprocess.Popen(
        command, stdout=subprocess.PIPE, stderr=subprocess.PIPE,
        text=True, encoding='utf-8', errors='replace', env=env, cwd=cwd, **kwargs,
    ) as process:
        try:
            stdout, stderr = process.communicate(timeout=timeout)
        except subprocess.TimeoutExpired as original:
            _stop_tree(process)
            try:
                stdout, stderr = process.communicate(timeout=5)
            except subprocess.TimeoutExpired:
                # An escaped descendant may retain a pipe. Never hang on it.
                process.stdout.close()
                process.stderr.close()
                stdout, stderr = original.stdout, original.stderr
            raise subprocess.TimeoutExpired(command, timeout, output=stdout, stderr=stderr) from None
        except BaseException:
            _stop_tree(process)
            raise
    return subprocess.CompletedProcess(command, process.returncode, stdout, stderr)


def run_native_fixture_cases(command: Sequence[str], *, name: str, keys: Sequence[str],
                             env: Mapping[str, str], timeout: float, case_timeout: float,
                             cwd: str, logs: Path) -> tuple[bool, str, list[dict]]:
    """Run every default-scope actor without accumulating native PNG caches.

    Each child executes the original GDScript assertions with an isolated save
    and its own exact terminal summary. No skipped/unfinished child can pass
    the aggregate. Explicit caller scopes do not use this default-only path.
    """
    if not keys or len(keys) != len(set(keys)):
        raise ValueError('Native actor subprocess scope must be nonempty and unique')
    logs.mkdir(parents=True, exist_ok=True)
    started = time.monotonic()
    results = []
    messages = []
    for key in keys:
        if re.fullmatch(r'transform:[0-9]+', key) is None:
            raise ValueError('Invalid native fixture subprocess key')
        remaining = timeout - (time.monotonic() - started)
        if remaining <= 0:
            row = {'key': key, 'passed': False, 'status': 'NOT_RUN_TOTAL_TIMEOUT'}
            results.append(row)
            messages.append('NATIVE_FIXTURE_CASE ' + json.dumps(row))
            continue
        with tempfile.TemporaryDirectory(prefix='twilight-test-native-') as data:
            child_env = dict(env)
            child_env['TWILIGHT_NATIVE_TEST_KEYS'] = key
            child_env.update(XDG_DATA_HOME=data, APPDATA=data, LOCALAPPDATA=data,
                             XDG_CONFIG_HOME=str(Path(data) / 'config'),
                             XDG_CACHE_HOME=str(Path(data) / 'cache'))
            child_started = time.monotonic()
            try:
                process = run_isolated(command, env=child_env,
                                       timeout=min(case_timeout, remaining), cwd=cwd)
                output = process.stdout + process.stderr
                passed, skipped = classify_result(name, process.returncode, output,
                                                   expected_native_keys=[key])
                passed = passed and not skipped
                code = process.returncode
                status = 'PASS' if passed else 'FAILED'
            except subprocess.TimeoutExpired as exc:
                stdout = exc.stdout.decode(errors='replace') if isinstance(exc.stdout, bytes) else (exc.stdout or '')
                stderr = exc.stderr.decode(errors='replace') if isinstance(exc.stderr, bytes) else (exc.stderr or '')
                output = 'TIMEOUT ' + str(exc) + '\n' + stdout + stderr
                passed, code, status = False, None, 'TIMEOUT'
            except OSError as exc:
                output = 'PROCESS_START_FAILED ' + str(exc)
                passed, code, status = False, None, 'START_FAILED'
            path = logs / (key.replace(':', '_') + '.log')
            path.write_text(output, encoding='utf-8')
            row = {'key': key, 'passed': passed, 'status': status, 'returncode': code,
                   'seconds': round(time.monotonic() - child_started, 3), 'log': str(path)}
            results.append(row)
            messages.append('NATIVE_FIXTURE_CASE ' + json.dumps(row))
            if not passed:
                messages.append('NATIVE_FIXTURE_FAILED ' + key + '\n' + output[-4000:])
    passed = len(results) == len(keys) and all(row['passed'] for row in results)
    report = {'actors_requested': list(keys),
              'actors_attempted': sum(row['status'] != 'NOT_RUN_TOTAL_TIMEOUT' for row in results),
              'actors_completed': sum(row.get('returncode') is not None for row in results),
              'actors_passed': sum(row['passed'] for row in results),
              'failures': [row['key'] for row in results if not row['passed']],
              'seconds': round(time.monotonic() - started, 3), 'total_budget': timeout}
    messages.append('NATIVE_FIXTURE_AGGREGATE ' + json.dumps(report))
    return passed, '\n'.join(messages) + '\n', results


# Audits reuse this runner contract, rather than copying its execution loop.
PREPARATION = ("import", "bake_navigation", "boot")


def select_checks(checks: list[tuple[str, list[str]]], only: str = "",
                  shard_index: int = 0, shard_count: int = 1) -> tuple[list, dict]:
    if shard_count < 1 or not 0 <= shard_index < shard_count:
        raise ValueError("Require shard-count >= 1 and 0 <= shard-index < shard-count")
    names = [name for name, _ in checks]
    if len(names) != len(set(names)):
        raise ValueError("Duplicate check names cannot be attributed safely")
    if names[:3] != list(PREPARATION):
        raise ValueError("Import, navigation and boot must precede runtime tests")
    runtime = checks[3:]
    if only:
        if shard_count != 1 or shard_index != 0:
            raise ValueError("--only and sharding cannot be combined")
        selected = set(only.split(","))
        unknown = selected - set(names)
        if unknown:
            raise ValueError("Unknown tests: " + ", ".join(sorted(unknown)))
        result = [check for check in checks if check[0] in selected]
    elif shard_count > 1:
        assigned = [check for i, check in enumerate(runtime) if i % shard_count == shard_index]
        if not assigned:
            raise ValueError("An empty runtime shard must not pass preparation alone")
        result = checks[:3] + assigned
    else:
        result = list(checks)
    plan = {"shard_index": shard_index, "shard_count": shard_count,
            "discovered_tests": [name for name, _ in runtime],
            "selected_tests": [name for name, _ in result if name not in PREPARATION],
            "preparation": list(PREPARATION)}
    return result, plan
