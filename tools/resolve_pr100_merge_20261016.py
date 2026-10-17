#!/usr/bin/env python3
"""One-time, pinned PR100 merge resolution. Never run on a dirty user checkout.

Invoked only by the temporary merge-preparation workflow after an inspected
three-way merge. The caller checks both parent SHAs and the exact conflict set.
"""
from pathlib import Path
import re
import subprocess

PAT = re.compile(r'^<<<<<<< [^\n]+\n(.*?)^=======\n(.*?)^>>>>>>> [^\n]+\n', re.M | re.S)
TEXT_PATHS = [
    'tests/benchmark_presentation_battles.gd', 'tests/capture_regions.gd',
    'tests/lineagem_ui_visual_smoke_test.gd', 'tests/remake_ui_local_item_icons_test.gd',
    'tests/renewed_map_spawn_test.gd', 'tests/skill_mechanism_smoke_test.gd',
    'tests/test_renewed_map_spawn_rules.py', 'tests/world_regions_test.gd',
    'tools/test_project.py', 'tools/test_project_runner_test.py', 'tools/test_project_support.py',
]


def replace_once(text, old, new):
    if text.count(old) != 1:
        raise ValueError(f'Expected one exact occurrence: {old[:100]!r}; got {text.count(old)}')
    return text.replace(old, new, 1)


def resolve(name, text):
    blocks = list(PAT.finditer(text))
    if not blocks:
        raise ValueError('Expected inspected conflict: ' + name)
    if name == 'tests/benchmark_presentation_battles.gd':
        if len(blocks) != 1:
            raise ValueError('Conflict count drift')
        text = PAT.sub(lambda _: blocks[0][2], text)
        guard = blocks[0][1].split('\tif not await _verify_cleanup(world):', 1)[1].split('\tvar point:', 1)[0]
        guard = '\tif not await _verify_cleanup(world):' + guard
        return replace_once(text, '\t\tworld.field_population.set_process(false)\n',
                            '\t\tworld.field_population.set_process(false)\n' +
                            ''.join('\t' + line if line.strip() else line for line in guard.splitlines(True)))
    if name == 'tests/capture_regions.gd':
        save = blocks[1][1] + blocks[1][2].split('\n', 1)[1]
        anchor = blocks[3][1].replace('Vector2(3550,4300) if map_id == "aden_world" else COORD.array_vector(world.field_map.data["review_points"]["central"])', '_active_play_anchor(world, map_id)')
        landmarks = blocks[4][2].replace('var found: bool', 'var landmark_found: bool').replace('_save_view(directory,id+"-landmark")', '_save_view(directory,id+"-landmark",world,id)')
        choices = [blocks[0][2], save, blocks[2][1] + '\n' + blocks[2][2], anchor, landmarks, blocks[5][1]]
    elif name == 'tests/lineagem_ui_visual_smoke_test.gd':
        choices = [blocks[0][2], '\t_check(compact != null and not compact.visible,"opening an unconnected window does not expose dead navigation")\n' + blocks[1][1]]
    elif name == 'tests/remake_ui_local_item_icons_test.gd':
        borrowed = '\tvar borrowed: Dictionary = ' + blocks[0][2].split('\tvar borrowed: Dictionary = ', 1)[1]
        choices = [blocks[0][1] + borrowed]
    elif name in {'tests/renewed_map_spawn_test.gd', 'tests/test_renewed_map_spawn_rules.py'}:
        choices = [blocks[0][2]]
    elif name == 'tests/skill_mechanism_smoke_test.gd':
        choices = [blocks[0][1]]
    elif name == 'tests/world_regions_test.gd':
        choices = [blocks[0][1] + '\t\tprint("REGION TIMING ",id," before_routes_ms=",Time.get_ticks_msec()-started_ms)\n']
    elif name == 'tools/test_project.py':
        choices = [
            'from test_project_support import classify_result, requires_renderer, run_isolated, timeout_budget, LEGACY_GEOMETRY_TESTS\n',
            blocks[1][2], blocks[2][2],
            blocks[3][1].split("            if name=='import':", 1)[0] + blocks[3][2],
        ]
    elif name == 'tools/test_project_runner_test.py':
        choices = ["                 raw=False, hang=False, child=False, extra_env=None, bake_output='NAV_BAKE_OK 1\\n',\n                 bake_code=0, bake_files=True, bake_hang=False):\n"]
    elif name == 'tools/test_project_support.py':
        decl = blocks[0][1] + '    re.MULTILINE,\n)\n' + blocks[0][2]
        budget = blocks[1][2].replace('    return requested\n',
            "    if name in {'original_based_mummy_lord_gameplay_test',\n                'original_based_seer_boss_gameplay_test',\n                'original_based_salah_gameplay_test'}:\n        # Preserve PR100's original-HP boss lifecycle budget.\n        return max(requested, 450)\n    return requested\n")
        choices = [decl, blocks[1][1] + '\n\n' + budget]
    else:
        raise ValueError('Not an inspected text conflict: ' + name)
    if len(choices) != len(blocks):
        raise ValueError('Conflict count drift: ' + name)
    result = PAT.sub(lambda _: choices.pop(0), text)
    if re.search(r'^(<<<<<<< |=======\s*$|>>>>>>> )', result, re.M):
        raise ValueError('Unresolved conflict: ' + name)
    return result


def git(*args):
    return subprocess.check_output(['git', *args])


def main():
    expected_main = 'e2119c37293a783e93b421ee0055d1318271b071'
    if git('rev-parse', 'MERGE_HEAD').decode().strip() != expected_main:
        raise SystemExit('Refusing an uninspected merge parent')
    if git('merge-base', 'HEAD', 'MERGE_HEAD').decode().strip() != '02842fdd123bf14db46bed91a3cb68c36fa8b9b1':
        raise SystemExit('Unexpected merge base')
    conflicts = set(git('diff', '--name-only', '--diff-filter=U', '-z').decode().rstrip('\0').split('\0'))
    navigation = {p for p in conflicts if p.startswith('data/maps/navigation/')}
    if len(navigation) != 26 or conflicts != navigation | set(TEXT_PATHS) | {'.gitattributes', '.github/workflows/l1j-runtime-validate.yml'}:
        raise SystemExit('Conflict set drift; do not resolve automatically')
    for name in sorted(navigation):
        subprocess.run(['git', 'checkout', expected_main, '--', name], check=True)
    for name in TEXT_PATHS:
        path = Path(name)
        path.write_text(resolve(name, path.read_text(encoding='utf-8')), encoding='utf-8')
    Path('.gitattributes').write_text(
        '# Preserve actual Godot logs byte-for-byte, including their trailing blank lines.\n'
        'docs/world-structure-20261011/evidence/validation-logs/*.txt -whitespace\n'
        'docs/object-placement-20261011/evidence/validation-logs/*.txt -whitespace\n'
        'docs/remake/evidence/pr100-direction-fix/**/*.log -whitespace\n'
        '# Archived verification output is data; retain the original log bytes.\n'
        'docs/map-remake-20261015/expansion25/**/*.log -whitespace\n'
        'docs/map-remake-20261015/expansion25/**/validation-logs/*.txt -whitespace\n', encoding='utf-8')
    name = '.github/workflows/l1j-runtime-validate.yml'
    # PR's platform budgets/death-clock regression plus main's icon triggers.
    text = git('show', ':2:' + name).decode()
    text = replace_once(text, "      - 'scripts/ui/renewal_theme.gd'\n", "      - 'scripts/ui/renewal_theme.gd'\n      - 'scripts/ui/ground_alpha.gd'\n      - 'scripts/ui/item_visual_resolver.gd'\n      - 'data/ground_alpha.json'\n      - 'assets/ground_alpha/**'\n      - 'tests/ground_alpha_test.gd'\n      - 'tests/inventory_db_smoke_test.gd'\n")
    gl = "      - name: Install software OpenGL capture dependencies\n        if: runner.os == 'Linux'\n        run: sudo apt-get update && sudo apt-get install -y xvfb libgl1-mesa-dri\n"
    text = replace_once(text, gl, '')
    text = replace_once(text, '      - name: Import, boot and all regression checks with isolated saves\n', gl + '      - name: Import, boot and all regression checks with isolated saves\n')
    Path(name).write_text(text, encoding='utf-8')
    name = '.github/workflows/animation-presentation-validate.yml'
    text = Path(name).read_text(encoding='utf-8')
    text = replace_once(text, 'batch: [15, 16, 17, 18, 19, 20, 21, 23, 24, 25, 26, 27, 28, 30]',
                        'batch: [15, 16, 17, 18, 19, 20, 21, 23, 24, 25, 26, 27, 28, 29, 30]')
    text = replace_once(text, '          - batch: 31\n',
                        '          - batch: 29\n            script: run_original_based_boss_batch\n            timeout: 1200\n          - batch: 31\n')
    Path(name).write_text(text, encoding='utf-8')
    subprocess.run(['git', 'add', '--', *sorted(conflicts), name], check=True)
    if git('ls-files', '-u'):
        raise SystemExit('Unresolved index entries remain')
    print('PR100_INSPECTED_CONFLICTS_RESOLVED 39; main navigation preserved 26; cougar CI added')


if __name__ == '__main__':
    main()
