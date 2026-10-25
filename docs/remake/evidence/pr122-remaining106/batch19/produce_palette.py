import copy
import hashlib
import json
import subprocess
import sys
from pathlib import Path

ROOT = Path('/workspace/twilight')
PROFILE = ROOT / 'data/combat_animation_profiles.json'
MANIFEST = ROOT / 'data/pr122_palette_finish_20261019.json'
STAGE = sys.argv[1]
VISUAL = ('frames_path', 'layout', 'pixel_scale', 'sprite_offset',
          'embedded_shadow', 'authored_motion_weight', 'movement_fps',
          'movement_cadence_width_ratio', 'action_hit_frames', 'attack_hit_frame',
          'death_duration', 'hit_recoil', 'body_kind', 'native_width_ratio',
          'animation_names', 'floating', 'dedicated_attack')

# Explicit presentation substitutions. Original identities and source-HOLDs stay
# separate. No heuristic matching, new image claims, or battle database changes.
TRANSFORMS = [
 ('44','transform:176','d9e2eb','armored_spear_base'),
 ('179','transform:44','ff766b','same_lance_master_base_source_tinted'),
 ('182','transform:44','75aeff','same_lance_master_base_source_tinted'),
 ('231','transform:44','edcf8a','armored_spear_variant'),
 ('411','transform:413','efc8a2','female_chain_armored_fighter'),
 ('142','transform:283','efc8a2','male_chain_armored_fighter'),
 ('139','transform:346','bc9ddc','female_dark_armored_melee_proxy'),
 ('138','transform:139','bc9ddc','same_as_female_directional_visual'),
 ('141','transform:135','c4d5ef','female_ranged_proxy_bow_not_firearm'),
 ('140','transform:141','c4d5ef','same_as_female_directional_visual'),
 ('393','monster:드레이크','d5b3ef','winged_dragon_proxy_not_halpas_original'),
 ('267','monster:아시타지오','c7a0e3','horned_demon_proxy_not_girtas_original'),
 ('375','transform:102','efcf91','staff_caster_proxy_not_fishing_rod'),
 ('376','transform:375','bbd6b9','same_fishing_family_proxy'),
 ('339','transform:345','aacdc2','armored_sentinel_variant'),
 ('338','transform:399','e5a5a7','armored_greatsword_variant'),
 ('191','transform:102','bdd6f3','hadin_caster_variant'),
 ('166','transform:102','ab92cf','hadin_dark_caster_variant'),
 ('406','monster:서큐버스','f1b28c','winged_humanoid_fire_proxy'),
 ('405','monster:풍룡의 둥지 하피','f2c79b','winged_fairy_proxy_not_native_fairy'),
 ('386','transform:137','f2bdd6','female_pink_caster_proxy'),
 ('360','transform:102','cfb0e5','circus_caster_proxy_no_card_art'),
 ('359','monster:스파토이','e8ce91','circus_puppet_proxy_no_trombone_art'),
 ('358','transform:212','e5b3a4','circus_performer_proxy_no_drum_art'),
 ('357','transform:345','edc79a','circus_leader_armored_proxy'),
 ('276','transform:413','e9d1e5','female_humanoid_proxy_no_maid_costume'),
 ('268','transform:345','e6eaf3','celestial_armored_knight_variant'),
 ('197','transform:399','c2cdec','armored_commander_variant'),
 ('155','transform:258','c6b5db','reaper_variant'),
 ('123','transform:141','edc2d6','female_ranged_proxy_bow_not_firearm'),
 ('16','monster:아시타지오','f1ad8b','horned_fire_demon_variant'),
 ('9','monster:정예 다크엘프','b8b0df','dark_ranged_humanoid_proxy'),
 ('4','transform:345','f0dfab','celestial_knight_variant'),
]
MONSTERS = [
 ('얼음 여왕','transform:137','c5ddff','female_caster_proxy_native_queen_WIP_preserved'),
 ('그림 리퍼','transform:258','c4b5d5','reaper_family'),
 ('말하는 섬 들개','monster:불신의 다이어울프','d4bb9d','canine_proxy_native_dog_HOLD_preserved'),
 ('천상계 성광기사','monster:천상계 천상수호자','f1e5bb','celestial_armored_knight'),
 ('교만의 왕자 데우스','monster:커츠','ddc5a1','armored_boss_proxy'),
 ('교만의 제라키엘','monster:서큐버스','cbb5e7','winged_humanoid_boss_proxy'),
 ('놀','monster:늑대인간','d2b18e','canine_biped_proxy_native_gnoll_WIP_preserved'),
 ('로머','monster:오우거','c2bd9b','large_biped_proxy_native_identity_unverified'),
 ('분노의 데스 리퍼','transform:258','f0a7a1','reaper_rage_variant'),
 ('사라만다','monster:도마뱀','f2b285','lizard_fire_variant'),
 ('알비노 몽크','monster:에티','e0e9f5','white_primate_proxy_native_gorilla_WIP_preserved'),
 ('알비노 유니콘','monster:알비노 디어','e4ddf8','quadruped_proxy_no_unicorn_horn_native_HOLD_preserved'),
 ('에스카로스 치프','monster:마이노','c4b2dc','large_biped_chief_proxy'),
 ('오만한 아스모데우스','monster:아시타지오','d2b2db','horned_demon_boss_variant'),
 ('오만한 우그누스','monster:아시타지오','ddc79f','horned_demon_boss_proxy'),
 ('왜곡의 메두사','monster:라미아','a6c7b2','serpentine_humanoid_variant'),
 ('왜곡의 제니스 퀸','monster:라미아','cdb3e1','serpentine_queen_proxy'),
 ('욥니르','monster:에틴','b9d2de','large_biped_boss_proxy'),
 ('잔혹한 아이리스','monster:서큐버스','ddaec7','winged_female_boss_proxy'),
 ('질투의 공주 이자벨','transform:137','dcc2eb','female_caster_boss_proxy'),
 ('탐욕의 여왕 벨리엘','monster:서큐버스','e1c4a1','winged_queen_proxy'),
]

def write_json(path, value):
    path.write_text(json.dumps(value, ensure_ascii=False, indent=2) + '\n')

database = json.loads(PROFILE.read_text())
profile_text_before = PROFILE.read_text()
profiles = database['profiles']
manifest = json.loads(MANIFEST.read_text()) if MANIFEST.exists() else {
 'schema': 1, 'pr': 122, 'basis_head': subprocess.check_output(
     ['git','rev-parse','HEAD'], cwd=ROOT, text=True).strip(),
 'request': 'Prioritize fast existing-motion palette variants; preserve previous work.',
 'policy': 'EXPLICIT_PROJECT_MOTION_PROXY_NOT_NEW_NATIVE_ART_OR_APPROVAL',
 'approved_history_unchanged': 405, 'frame_quality_followup_unchanged': 14,
 'new_native_poses': 0, 'new_native_art_approvals': 0,
 'entries': [],
}
assert STAGE in ('transforms','monsters')
items = TRANSFORMS if STAGE == 'transforms' else MONSTERS
prefix = 'transform:' if STAGE == 'transforms' else 'monster:'
for suffix, donor_id, tint, basis in items:
    target_id = prefix + suffix
    assert not any(x['target'] == target_id for x in manifest['entries']), target_id
    existed = target_id in profiles
    before = copy.deepcopy(profiles.get(target_id, {'name': suffix}))
    assert not before.get('frames_path'), 'Never replace an existing native binding: ' + target_id
    donor = profiles[donor_id]
    assert donor.get('frames_path') and donor.get('layout') == 'directional8', donor_id
    frames_file = ROOT / donor['frames_path'].removeprefix('res://')
    assert frames_file.is_file(), frames_file
    result = copy.deepcopy(before)
    for field in VISUAL:
        result.pop(field, None)
        if field in donor:
            result[field] = copy.deepcopy(donor[field])
    result['color_tint'] = tint
    result['shared_visual_source'] = donor_id
    # Existing special family policies are intentional saved user preferences.
    result['shared_visual_policy'] = before.get('shared_visual_policy',
        'tinted_in_project_proxy_preserve_source_and_approval_status')
    result['shared_visual_basis'] = basis
    profiles[target_id] = result
    manifest['entries'].append({
      'target': target_id, 'name': before['name'], 'source': donor_id,
      'frames_path': donor['frames_path'], 'frames_sha256': hashlib.sha256(frames_file.read_bytes()).hexdigest(),
      'color_tint': tint, 'basis': basis, 'previous_profile': before if existed else None,
      'native_art_status': 'PRIOR_STATUS_UNCHANGED',
      'runtime_qa': 'PENDING', 'original_identity_verified': False,
    })
manifest['target_count'] = len(manifest['entries'])
manifest['stages'] = sorted(set(manifest.get('stages', []) + [STAGE]))
lines = profile_text_before.splitlines(keepends=True)
changed_ids = {prefix + item[0] for item in items}
found = set()
for index, line in enumerate(lines):
    for key in changed_ids:
        if line.startswith(json.dumps(key, ensure_ascii=False) + ':'):
            ending = ',\n' if line.rstrip().endswith(',') else '\n'
            lines[index] = json.dumps(key, ensure_ascii=False) + ':' + json.dumps(
                profiles[key], ensure_ascii=False, separators=(',', ':')) + ending
            found.add(key)
            break
rendered = ''.join(lines)
if changed_ids - found:
    assert rendered.rstrip().endswith('}}')
    rendered = rendered.rstrip()[:-2].rstrip() + ',\n' + ',\n'.join(
        json.dumps(key, ensure_ascii=False) + ':' + json.dumps(
            profiles[key], ensure_ascii=False, separators=(',', ':'))
        for key in sorted(changed_ids - found)) + '\n}}\n'
assert json.loads(rendered) == database
PROFILE.write_text(rendered)
write_json(MANIFEST, manifest)
print(json.dumps({'stage': STAGE, 'profiles_connected': len(items),
                  'new_images': 0, 'original_approvals_added': 0}))
