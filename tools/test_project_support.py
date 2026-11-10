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
SCALAR_FAILURE_COUNT = re.compile(r'\b(?:failures|errors|failed)=(\d+)\b')
SCALAR_TOTAL_COUNT = re.compile(r'\b(?:checks|cases|entries|tests)=(\d+)\b')
# Explicit final summaries that state their own failure/error count. Accepted
# only when every such line in the output reports zero; any nonzero count, or a
# JSON summary without a "failures" list, never passes.
COUNT_SUMMARY = re.compile(
    r'^(?P<label>[A-Za-z][A-Za-z0-9_ ]*?)(?::|\s)\s*(?P<checks>\d+) checks?\s*(?:,|/)\s*(?P<bad>\d+) (?:failures?|errors?)\s*$'
    r'|^(?P<label2>[A-Z][A-Z0-9_]*)(?:_RESULT|_PASS)?\b.*?\bchecks=(?P<checks2>\d+)\b.*?\b(?:failures|errors)=(?P<bad2>\d+)\b'
    r'|^(?P<label3>[A-Z][A-Z0-9_]*)\s+(?P<json>\{.*\})\s*$'
    r'|^(?P<label4>[A-Z][A-Z0-9_]*_PASS)\s*$',
    re.MULTILINE)


def reserved_receipt_prefixes() -> tuple[str, ...]:
    """Receipts registered to one suite; no other suite may pass with them."""
    return tuple(prefix for prefix, _ in SCALAR_RESULT_CONTRACTS.values()) + \
        tuple(prefix for prefix, _ in SCALAR_ONLY_CONTRACTS.values())


def zero_failure_summary(output: str) -> bool:
    # Registered suite-specific receipts keep their exact, own-suite contract.
    reserved = tuple(prefix for prefix, _ in SCALAR_RESULT_CONTRACTS.values()) + \
        tuple(prefix for prefix, _ in SCALAR_ONLY_CONTRACTS.values())
    found = False
    for match in COUNT_SUMMARY.finditer(output):
        if match.group(0).startswith(reserved):
            continue
        if match.group('label4'):
            found = True
            continue
        if match.group('json') is not None:
            try:
                report = json.loads(match.group('json'))
            except json.JSONDecodeError:
                continue
            if not isinstance(report, dict) or 'failures' not in report:
                continue
            if report['failures'] != []:
                return False
            found = True
            continue
        bad = match.group('bad') if match.group('bad') is not None else match.group('bad2')
        checks = match.group('checks') if match.group('checks') is not None else match.group('checks2')
        if bad != '0':
            return False
        if checks is not None and int(checks) == 0:
            return False
        found = True
    return found
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
# Exact contracts for existing, non-JSON Godot test receipts. These are not
# generic success markers: empty, malformed, truncated, or failed results fail.
SCALAR_RESULT_CONTRACTS = {
    'source_npc_live_placement_test': (
        'SOURCE_NPC_LIVE_RESULT ',
        re.compile(r'^SOURCE_NPC_LIVE_RESULT checks=(?P<checks>[1-9][0-9]*) failures=(?P<bad>[0-9]+) actual_placement=6/6$')),
    'reviewed_existing_monster_visuals_test': (
        'EXISTING_MONSTER_SOURCE_RESULT ',
        re.compile(r'^EXISTING_MONSTER_SOURCE_RESULT checks=(?P<checks>[1-9][0-9]*) errors=(?P<bad>[0-9]+) replaced=2$')),
    'source3_drop_extensions_main_test': (
        'SOURCE3_DROP_EXTENSIONS_MAIN_RESULT ',
        re.compile(r'^SOURCE3_DROP_EXTENSIONS_MAIN_RESULT checks=(?P<checks>[1-9][0-9]*) errors=(?P<bad>[0-9]+)$')),
    'source3_drop_extensions_test': (
        'SOURCE3_DROP_EXTENSIONS_RESULT ',
        re.compile(r'^SOURCE3_DROP_EXTENSIONS_RESULT identities=24 rows=41 checks=(?P<checks>[1-9][0-9]*) errors=(?P<bad>[0-9]+)$')),
    'source3_item_links_test': (
        'SOURCE3_ITEM_LINK_RESULT ',
        re.compile(r'^SOURCE3_ITEM_LINK_RESULT checks=(?P<checks>[1-9][0-9]*) errors=(?P<bad>[0-9]+) links=252 stats_imported=0$')),
    'source3_reviewed_drop_main_test': (
        'SOURCE3_DROP_MAIN_RESULT ',
        re.compile(r'^SOURCE3_DROP_MAIN_RESULT phase=(?:write|read|empty) checks=(?P<checks>[1-9][0-9]*) failures=(?P<bad>[0-9]+)$')),
}
SCALAR_ONLY_CONTRACTS = {
    'source_npc_six_test': ('SOURCE_NPC_SIX ',
        re.compile(r'^SOURCE_NPC_SIX checks=[1-9][0-9]* failures=(?P<bad>[0-9]+) placement=checked_by_live_test$')),
    'source_npc_six_render_test': ('SOURCE_NPC_RENDER ',
        re.compile(r'^SOURCE_NPC_RENDER slots=8 actors=6 failures=(?P<bad>[0-9]+) placement=diagnostic_only$')),
    'reviewed_source_monsters_test': ('REVIEWED_SOURCE_MONSTERS ',
        re.compile(r'^REVIEWED_SOURCE_MONSTERS checks=[1-9][0-9]* failures=(?P<bad>[0-9]+)$')),
    'source3_reviewed_drop_test': ('SOURCE3_DROP_TEST ',
        re.compile(r'^SOURCE3_DROP_TEST phase=(?:write|read|empty|drift) failures=(?P<bad>[0-9]+)$')),
}


# The PR122 pipeline and its tests were removed (2026-11-07, 2026-11-10).
PR122_PASS_SUMMARIES: dict = {}



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


ANNOTATION_LINE = re.compile(r"SCRIPT ERROR|ERROR:|_FAIL\b|FAIL:|FAILED|TIMEOUT|Traceback|Error\b")


def failure_annotation(name: str, output: str, limit: int = 900) -> str:
    """One GitHub `::error::` line naming the failed check and its first causes.

    Job logs and artifacts can be unreachable from review tooling, while
    check-run annotations stay readable. The full log is still written.
    """
    lines = [line.strip() for line in output.splitlines() if ANNOTATION_LINE.search(line)]
    if not lines:
        lines = [line.strip() for line in output.splitlines() if line.strip()][-3:]
    detail = " | ".join(dict.fromkeys(lines[:12]))[:limit]
    detail = detail.replace("%", "%25").replace("\r", "").replace("\n", "%0A")
    title = re.sub(r"[^A-Za-z0-9_. -]", "_", name)
    return "::error title=TWILIGHT check failed: " + title + "::" + (detail or "no output")


def classify_result(name: str, returncode: int, output: str) -> tuple[bool, bool]:
    """Return (passed, skipped); errors always override success/skip markers."""
    if returncode != 0 or ERROR.search(output):
        return False, False
    reports = []
    scalar_summaries = 0
    scalar_receipts = []
    scalar_contract = SCALAR_RESULT_CONTRACTS.get(name)
    for line in output.splitlines():
        match = REPORT.search(line)
        if match:
            if scalar_contract is not None and line.startswith(scalar_contract[0]):
                parsed = scalar_contract[1].fullmatch(line)
                if parsed is None or parsed.group('bad') != '0':
                    return False, False
                scalar_receipts.append(parsed)
                continue
            payload = match.group(1).strip()
            if not payload.startswith(('{', '[')):
                # Scalar receipt such as "X_RESULT checks=207 errors=0": it
                # passes only when it states failure/error counts and all are
                # zero. A nonzero or count-less scalar receipt fails closed.
                counts = SCALAR_FAILURE_COUNT.findall(payload)
                totals = SCALAR_TOTAL_COUNT.findall(payload)
                if (line.startswith(reserved_receipt_prefixes()) or not counts
                        or any(value != '0' for value in counts) or any(value == '0' for value in totals)):
                    return False, False
                scalar_summaries += 1
                continue
            try:
                report = json.loads(payload)
            except json.JSONDecodeError:
                return False, False
            if not isinstance(report, dict) or report.get('failures') != []:
                return False, False
            reports.append(report)
    if name in PR122_PASS_SUMMARIES:
        pattern = PR122_PASS_SUMMARIES[name]
        marker = pattern.split(' ', 1)[0]
        summaries = [line for line in output.splitlines() if line.startswith(marker)]
        # Do not let a generic _OK, an inner actor PASS or SKIP replace the
        # suite's final, nonempty summary. Earlier error/JSON checks still win.
        passed = (not SKIP.search(output) and len(summaries) == 1
                  and re.fullmatch(pattern, summaries[0]) is not None)
        return passed, False
    spawn_summaries = RENEWED_SPAWN_SUMMARY.findall(output)
    if name == 'renewed_map_spawn_test':
        # Missing, contradictory, duplicate, or nonzero summaries fail closed.
        if SKIP.search(output) or len(spawn_summaries) != 1 or spawn_summaries[0][1] != '0':
            return False, False
        return True, False
    # Import/boot/cache preparation must actually run; SKIP cannot authorize them.
    # Exact scalar receipt suites likewise fail closed: a SKIP marker must not
    # turn a counted, positive receipt into a skipped pass.
    if SKIP.search(output):
        if (name in ('import', 'boot', 'bake_navigation')
                or scalar_contract is not None or name in SCALAR_ONLY_CONTRACTS):
            return False, False
        return True, True
    if scalar_contract is not None:
        # A restart child emits only three checks; require the full live-game
        # receipt as well, rather than counting that child as a complete test.
        full_live = (name != 'source_npc_live_placement_test'
                     or any(int(m.group('checks')) >= 100 for m in scalar_receipts))
        return bool(scalar_receipts) and full_live, False
    if name in SCALAR_ONLY_CONTRACTS:
        prefix, pattern = SCALAR_ONLY_CONTRACTS[name]
        receipts = [line for line in output.splitlines() if line.startswith(prefix)]
        return (len(receipts) == 1 and (parsed := pattern.fullmatch(receipts[0])) is not None
                and parsed.group('bad') == '0'), False
    return (name in ('import', 'boot') or bool(reports) or scalar_summaries > 0
            or bool(SUCCESS.search(output)) or zero_failure_summary(output)), False


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


# A GDScript runtime error aborts the current function; tests that never reach
# quit() then idle until the timeout (69 of 75 timeouts in run 42023183132).
# Any SCRIPT ERROR already fails classification, so after a short grace period
# the runner stops the process instead of waiting. The verdict is unchanged.
SCRIPT_ERROR_GRACE_SECONDS = 20.0
STOPPED_AFTER_SCRIPT_ERROR = 'STOPPED_AFTER_SCRIPT_ERROR'


def run_isolated(command: Sequence[str], *, env: Mapping[str, str], timeout: float,
                 cwd: str | None = None,
                 script_error_grace: float | None = SCRIPT_ERROR_GRACE_SECONDS) -> subprocess.CompletedProcess:
    """Capture logs loss-tolerantly and clean up descendant processes on timeout."""
    import threading
    kwargs = {'start_new_session': True} if os.name == 'posix' else {
        'creationflags': subprocess.CREATE_NEW_PROCESS_GROUP,
    }
    with subprocess.Popen(
        command, stdout=subprocess.PIPE, stderr=subprocess.PIPE,
        text=True, encoding='utf-8', errors='replace', env=env, cwd=cwd, **kwargs,
    ) as process:
        chunks: dict[str, list[str]] = {'out': [], 'err': []}
        first_error: list[float] = []

        def pump(stream, key: str) -> None:
            for line in iter(stream.readline, ''):
                chunks[key].append(line)
                if not first_error and 'SCRIPT ERROR:' in line:
                    first_error.append(time.monotonic())
            stream.close()

        readers = [threading.Thread(target=pump, args=(process.stdout, 'out'), daemon=True),
                   threading.Thread(target=pump, args=(process.stderr, 'err'), daemon=True)]
        for reader in readers:
            reader.start()
        began = time.monotonic()
        stopped_early = False
        try:
            while process.poll() is None:
                now = time.monotonic()
                if now - began >= timeout:
                    _stop_tree(process)
                    for reader in readers:
                        reader.join(5)
                    raise subprocess.TimeoutExpired(command, timeout, output=''.join(chunks['out']),
                                                    stderr=''.join(chunks['err']))
                if (script_error_grace is not None and first_error
                        and now - first_error[0] >= script_error_grace):
                    _stop_tree(process)
                    stopped_early = True
                    break
                time.sleep(0.2)
            process.wait(timeout=10)
        except subprocess.TimeoutExpired:
            raise
        except BaseException:
            _stop_tree(process)
            raise
        for reader in readers:
            reader.join(5)
    stdout = ''.join(chunks['out'])
    stderr = ''.join(chunks['err'])
    returncode = process.returncode
    if stopped_early:
        stderr += f'\n{STOPPED_AFTER_SCRIPT_ERROR} after {script_error_grace:.0f}s grace; SCRIPT ERROR already fails this check\n'
        returncode = returncode if returncode not in (0, None) else 1
    return subprocess.CompletedProcess(command, returncode, stdout, stderr)



# Audits reuse this runner contract, rather than copying its execution loop.
# Tests whose assertions require a private, user-supplied original pack that
# GitHub CI never has. Their authors state that absence is not a pass, so the
# runner records them as PRIVATE_INPUT_UNAVAILABLE (never PASS) with the
# missing variables, instead of letting each fail or hang until its timeout.
# Evidence: Integration run 41986133718 on main 4d18a44 (2026-11-05).
PRIVATE_INPUT_REQUIREMENTS: dict[str, tuple[str, ...]] = {
    "base508_pack_test": ("TWILIGHT_BASE508_PACK",),
    "base508_game_api_test": ("TWILIGHT_BASE508_PACK", "TWILIGHT_BASE508_REGISTRATION", "TWILIGHT_LEGACY_ART_ROOT"),
    "base508_registered_navigation_test": ("TWILIGHT_BASE508_PACK", "TWILIGHT_BASE508_REGISTRATION", "TWILIGHT_LEGACY_ART_ROOT"),
    "base508_shared_land_context_test": ("TWILIGHT_BASE508_SHARED_CONTEXT_PACK",),
    "dungeon_execution_contract_test": ("TWILIGHT_DUNGEON523_PACK",),
    "dungeon_execution_main_test": ("TWILIGHT_DUNGEON523_PACK",),
    "dungeon_installed_play_pack_test": ("TWILIGHT_DUNGEON523_PACK",),
    "dungeon_remaining_play_test": ("TWILIGHT_DUNGEON523_PACK", "TWILIGHT_DUNGEON523_PREVIOUS_PACK"),
    "guardian_media_test": ("GUARDIAN_ORIGINAL_MEDIA_PACK",),
    "half_elixir_main_test": ("TWILIGHT_HALF_ELIXIR_SOURCE",),
    "half_elixir_source_test": ("TWILIGHT_HALF_ELIXIR_SOURCE",),
    "inventory_registry523_test": ("TWILIGHT_AUTO_INVENTORY523_FILE",),
    "inventory_source523_test": ("TWILIGHT_AUTO_INVENTORY523_FILE",),
    "inventory_supplier523_contract_test": ("TWILIGHT_AUTO_INVENTORY523_FILE",),
    "local_presentation_region_test": ("TWILIGHT_PATCH523_CONTENT",),
    "mastery523_effects_main_test": ("TWILIGHT_MASTERY523_PACK",),
    "mastery523_operations_test": ("TWILIGHT_MASTERY523_PACK",),
    "mastery523_ticket_main_test": ("TWILIGHT_MASTERY523_PACK",),
    "monsterbook523_test": ("MONSTERBOOK523_PACK", "MONSTERBOOK523_SHA256"),
    "title523_test": ("TWILIGHT_TITLE523_ZIP",),
    "title523_main_test": ("TWILIGHT_TITLE523_ZIP",),
    "totem_main_ui_test": ("TWILIGHT_TOTEM_PACK",),
    "totem_progression_test": ("TWILIGHT_TOTEM_PACK",),
    "totem_runtime_test": ("TWILIGHT_TOTEM_PACK",),
    "patch523_item_use_test": ("TWILIGHT_PATCH523_DROP_ZIP",),
    "patch523_full_item_catalog_test": ("TWILIGHT_PATCH523_DROP_ZIP",),
    "patch523_full_item_delivery_test": ("TWILIGHT_PATCH523_DROP_ZIP",),
    "patch523_full_item_use_test": ("TWILIGHT_PATCH523_DROP_ZIP",),
    "patch523_full_item_effects_test": ("TWILIGHT_ITEM_EFFECT_EXPECTATIONS",),
    "patch523_pack_upgrade_test": ("TWILIGHT_PATCH523_DROP_ZIP", "TWILIGHT_PATCH523_OLD_ZIP"),
    "source_dungeon_runtime_test": ("TWILIGHT_DUNGEON523_PACK",),
    "source_map_review_pack_test": ("TWILIGHT_MAP84_REVIEW_PACK",),
    "source_map_runtime_field_test": ("TWILIGHT_SOURCE77_EDGE_ORACLE",),
    "presentation_effect_pack_test": ("TWILIGHT_PRESENTATION_EFFECT_PACK", "TWILIGHT_PRESENTATION_EFFECT_BAD_PACK"),
    "source_optimization_integration_test": ("TWILIGHT_PATCH523_CONTENT",),
    "tower_png_normal_runtime_test": ("TWILIGHT_OMAN_PNG_PACK",),
}

# Tests of the pre-remake authored Aden layout. source_map_runtime.supports()
# deliberately serves aden_world from the current source map even under
# --legacy-map-layouts, so these fixtures no longer exist in the game (user's
# map transition to current523, 2026-11). They are kept in the repository and
# reported as LEGACY_MAP_RETIRED (never passed). Checks that also cover other
# maps (e.g. native_png_teleport_test, world_regions_test) stay active.
RETIRED_LEGACY_MAP_TESTS = frozenset({
    "aden_building_test", "aden_courtyard_test", "aden_shoreline_test", "aden_terrain_polish_test",
    "field_world_test", "reference_object_placement_test", "road_surface_render_test",
    "terrain_surface_render_test", "world_region_portals_test", "world_structure_test",
    "world_terrain_coverage_test",
    "aden_batch_review_test", "aden_hut_collision_test", "aden_mobile_occlusion_test",
    "aden_mobile_streaming_test", "aden_png_scale_migration_test",
})


# Per-test opt-in flags/roots that only assert "this run uses a fresh isolated
# profile". The runner always allocates one, so it states that explicitly.
ISOLATION_ROOT_VARIABLES = ("TWILIGHT_GROWTH96_TEST_ROOT", "TWILIGHT_TJ_TEST_ROOT")
# Test-only guards of the form `VAR != "1" or XDG_DATA_HOME empty -> quit`.
# None is read by production scripts; the runner's fresh profile satisfies them.
ISOLATION_FLAG_VARIABLES = ("TWILIGHT_OWNED_RETURN_TEST", "TWILIGHT_REGIONAL_RETURN_TEST",
                            "TWILIGHT_SOURCE_AMMO_TEST", "TWILIGHT_SOURCE_BOOK_TEST",
                            "TWILIGHT_SOURCE_RECOVERY_TEST", "TWILIGHT_SOURCE_WISDOM_TEST",
                            "TWILIGHT_TICKET_CONTRACT_TEST")


def missing_private_inputs(name: str, env: Mapping[str, str]) -> list[str]:
    return [key for key in PRIVATE_INPUT_REQUIREMENTS.get(name, ()) if not env.get(key, "").strip()]


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
