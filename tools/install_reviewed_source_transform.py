#!/usr/bin/env python3
"""Install individually pixel-reviewed transformation bodies from the pinned input.

The package decoder is an offline data parser, never a source game executable.
Original art remains local: do not publish it without separate authorization.
"""
import argparse
import hashlib
import importlib.util
import json
from pathlib import Path
import zipfile

ARCHIVE_SHA = "fcc4daa36165d5046275a1cb11f7a6bf9a9e4bac67571a3a861abdfd6f8f8d4c"
SEMANTIC_SHA = "415755eaaeccafa47b4fe4c9fee22be6540690e33528b3b6b1ea4246e7c37412"
TARGET20_IMAGE = "assets/catalog/7ee8bedee1bbbe400a7276ab.png"
TARGET20_IMAGE_SHA = "afbed7ac289f707f4eb4dc8c6d0c7c14a6059a53a8703e257c93502bb4dd3c9b"
TARGET20_REVIEW = {
    "target_id":"transformation:inven:20",
    "target_name":"다크 나이트",
    "selected_model":"SPR-U-20652d3fc411993f558b",
    "selected_source":"source2",
    "selected_body_model":3054,
    "selected_binding":"PB0334",
    "original_catalog_image":TARGET20_IMAGE,
    "original_catalog_image_sha256":TARGET20_IMAGE_SHA,
    "original_catalog_source_image_url":"https://static.inven.co.kr/image_2011/site_image/lineagem/dataninfo/polymorph/20.png?v=261001c",
    "original_image_library":{"library_file_id":"libfile_2d9437c2ad748191b21dc4f081af8afe","file_id":"file_000000004dcc81f788cf6010f71788fb","filename":"7ee8bedee1bbbe400a7276ab.png","version":0},
    "actual_target_pixels_reviewed":True,
    "matching_features":["rounded grey plate helmet and broad shoulder armor","long black cape with central red lining/panel","one long sword and no large shield"],
    "rejected_body110":"Actual body110 has a large shield and long spear. It matches the separately identified ordinary 흑기사46, not the target20 sword/cape pixels.",
    "page_evidence":[{"url":"https://lineagem.inven.co.kr/db/polymorph/20","observed":"Separate Dark Knight entry; sword-master collection with Silver Knight, Sword Master and Arc Knight."},{"url":"https://lineagem.inven.co.kr/db/polymorph/46","observed":"Separate ordinary black-knight entry; spear collections with skeleton spear and Dudamara orc."}],
    "decision":"Same character/form supported by actual distinguishing armor/cape/weapon pixels, explicit local body3054 black-knight definition and separate sword/spear collection context. Collection membership alone was not sufficient.",
    "same_pixels_or_authenticated_client_version_claim":False,
    "candidate_override_scope":"Only target20: replace its earlier bilingual-name-only body110 candidate with the actually reviewed body3054. Do not broaden any other candidate or merge variants.",
}
HEADINGS = [3, 4, 5, 6, 7, 0, 1, 2]  # E SE S SW W NW N NE
ACTIONS = {"idle": 3, "walk": 0, "attack": 1, "hit": 2, "death": 8, "cast": 18, "special": 30}
ALIASES = {"run": "walk", "turn": "idle", "recovery": "attack", "corpse": "death", "ranged_attack": "attack", "float": "idle", "energy": "idle", "equip": "idle", "unequip": "idle", "activate": "idle", "summon": "idle", "despawn": "death"}

def module(name, path):
    spec = importlib.util.spec_from_file_location(name, path)
    loaded = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(loaded)
    return loaded

def same_body_reference(pkg, binding, action, step, heading):
    """Resolve a gap only within the already selected source/body/variant."""
    try:
        return pkg.resolve(binding['binding_id'], action, step, heading)
    except (ValueError, IndexError) as error:
        original_action = next(a for a in binding['actions'] if a['code'] == action)
        original = original_action['references'][step]
        candidates = []
        ordered_actions = [action] + [a['code'] for a in binding['actions'] if a['code'] != action]
        for candidate_action in ordered_actions:
            selected = next(a for a in binding['actions'] if a['code'] == candidate_action)
            for candidate_heading in [heading] + [h for h in range(8) if h != heading]:
                for candidate_step in sorted(range(len(selected['references'])), key=lambda i: abs(i-step)):
                    try:
                        ref = pkg.resolve(binding['binding_id'],candidate_action,candidate_step,candidate_heading)
                        candidates.append(ref)
                        break
                    except (ValueError, IndexError):
                        pass
                if candidates: break
            if candidates: break
        if not candidates: raise ValueError('No valid frame in the exact selected source/body/variant') from error
        ref = dict(candidates[0])
        ref['explicit_same_body_fallback'] = {'reason':str(error),'original_action_code':action,'original_sequence_step':step,'original_heading':heading,'original_reference':original,'replacement_action_code':ref['action_code'],'replacement_sequence_step':ref['sequence_step'],'replacement_heading':ref['heading_slot']}
        return ref

REVIEWS = [
    ("7", "바포메트", "PB0227", "baphomet_source2", [24,16], 86.0/69.0, "Horned goat skull, two hooves and ring staff; explicit morph definition -> body 53."),
    ("10", "켄라우헬", "PB0126", "ken_lauhel_source2", [24,16], 1.2, "Unique ken lauhel body 2419; gold shoulder plates, black/red cloak and long silver sword; soles visible beside cloak."),
    ("52", "어쌔신 마스터", "PB0156", "assassin_master_source2", [24,16], 1.3, "Unique assasin master body 2843; white head wrap, red cloak/gold trim, paired curved blades and visible boots."),
    ("74", "다크엘프 위자드", "PB0164", "darkelf_wizard_source2", [24,18], 1.3, "Unique darkelf wizard body 3376; white head and shoulder wraps, black robe and forked staff; robe contact/boots inspected."),
    ("91", "소녀 케레니스", "PB0207", "young_kelenis_source1", [24,18], 1.2, "Unique young kelenis body 8774; long blue hair, gold bodice, dark long skirt and tall staff; distinct from adult Kelenis 2468."),
    ("28", "데몬", "PB0103", "demon_source2", [24,18], 1.0, "Unique demon body 1180; red muscular torso, black/red wings, paired white horns and clawed feet; not Balrog."),
    ("77", "키위패롯", "PB0198", "kiwi_parrot_source2", [24,18], 1.5, "Unique kiwi parrot body 4147; orange crest/body, blue wings/tail and two grounded clawed feet."),
    ("81", "미들오움", "PB0182", "middle_oum_source2", [24,18], 1.8, "Unique middle oum body 3644; hunched dark ridged body, short legs and visible pale soles; no lookalike alias chosen."),
    ("86", "라쿤", "PB0191", "raccoon_source2", [24,18], 1.6, "Unique raccoon body 4038; orange-brown fur, dark eye mask, ringed tail. Four-paw footprint center checked in all eight idle/walk views."),
    ("85", "페이퍼 맨", "PB0109", "paperman_source2", [24,18], 1.3, "Unique paperman body 1538, also explicitly referenced by paperman morph; flat blue back/white front and paper-thin profile are source identity, not a missing body. Both soles checked across eight views."),
    ("83", "거대 개미", "PB0073", "giant_ant_source2", [24,18], 1.6, "Unique giant ant body 1037; black segmented abdomen, antennae and six legs. Fixed ground center within the leg support polygon reviewed in eight views."),
    ("67", "서큐버스", "PB0095", "succubus_source2", [24,18], 1.3, "Unique succubus body 1112 and explicit succubus morph; violet body/clothes, pale hair, horns, wings and booted feet. Fixed toe/torso ground projection checked over eight-view idle and walking poses."),
    ("239", "펌프킨", "PB0117", "pumpkin_source2", [24,18], 1.4, "Unique pumpkin body 2412; orange jack-o-lantern head, ragged draped body and slender arms. Fixed lower-body ground projection reviewed in eight views, preserving the source hovering/ragged hem motion."),
    ("397", "뱀파이어", "PB0150", "vampire_source2", [24,18], 1.3, "Unique vampire body 2757 and explicit vampire morph alias; black/red-lined high-collar cape, pale face and white shirt. Cloak hem/sole contact center reviewed across eight-view idle and walking poses; source spell 18 explicitly substitutes absent attack 1."),
    ("226", "가드리아", "PB0344", "gadria_source2", [24,18], 1.4, "Unique Legend_Gadria body 17633; gold helmet/armor, white split skirt, bow and visible gold boots. Eight-view strides and planted/raised soles checked with a fixed torso ground projection; not another archer."),
]
# Individually inspected source2 variants; each remains a separate target record.
REVIEWS += [('87',
  '고블린',
  'PB0296',
  'reviewed_87_source2',
  [24, 18],
  1.6,
  'Green goblin, small pointed helmet, curved sword and round shield. Actual eight-heading idle and walk pixels inspected. Specific '
  'source/model/variant pinned; alternative fingerprints remain distinct, with no claim of identical files, frames, colours or versions.'),
 ('84',
  '눈 사람',
  'PB0322',
  'reviewed_84_source2',
  [24, 18],
  1.4,
  'Three snow spheres, carrot nose, buttons, brown cap and stick arms; lower sphere contact center. Actual eight-heading idle and walk '
  'pixels inspected. Specific source/model/variant pinned; alternative fingerprints remain distinct, with no claim of identical files, '
  'frames, colours or versions.'),
 ('79',
  '라이칸스로프',
  'PB0310',
  'reviewed_79_source2',
  [24, 18],
  1.25,
  'Dark grey lycanthrope with a long muzzle, swept mane, pale limbs and spiked club; distinct from brown werewolf 1110. Actual '
  'eight-heading idle and walk pixels inspected. Specific source/model/variant pinned; alternative fingerprints remain distinct, with no '
  'claim of identical files, frames, colours or versions.'),
 ('78',
  '젤라틴 큐브',
  'PB0330',
  'reviewed_78_source2',
  [24, 18],
  1.2,
  'Green gelatin cube with visible suspended yellow bones; lower-face contact center, not an invented leg. Actual eight-heading idle and '
  'walk pixels inspected. Specific source/model/variant pinned; alternative fingerprints remain distinct, with no claim of identical '
  'files, frames, colours or versions.'),
 ('72',
  '오크 전사',
  'PB0255',
  'reviewed_72_source2',
  [24, 18],
  1.2,
  'Green armored sword orc with curved sword, shield and orange crest. Actual eight-heading idle and walk pixels inspected. Specific '
  'source/model/variant pinned; alternative fingerprints remain distinct, with no claim of identical files, frames, colours or versions.'),
 ('71',
  '두다-마라 오크',
  'PB0281',
  'reviewed_71_source2',
  [24, 18],
  1.5,
  'Dudamara orc carrying a long spear and small shield, as explicitly named by the morph definition. Actual eight-heading idle and walk '
  'pixels inspected. Specific source/model/variant pinned; alternative fingerprints remain distinct, with no claim of identical files, '
  'frames, colours or versions.'),
 ('70',
  '해골 창병',
  'PB0306',
  'reviewed_70_source2',
  [24, 18],
  1.3,
  'Bare skeleton with long spear, not the archer or sword skeleton. Actual eight-heading idle and walk pixels inspected. Specific '
  'source/model/variant pinned; alternative fingerprints remain distinct, with no claim of identical files, frames, colours or versions.'),
 ('69',
  '해골 궁수',
  'PB0300',
  'reviewed_69_source2',
  [24, 18],
  1.3,
  'Skeleton carrying a bow and back quiver; bony feet and front/back bow views checked. Actual eight-heading idle and walk pixels '
  'inspected. Specific source/model/variant pinned; alternative fingerprints remain distinct, with no claim of identical files, frames, '
  'colours or versions.'),
 ('68',
  '장로',
  'PB0214',
  'reviewed_68_source2',
  [24, 18],
  1.4,
  'Elder in yellow/white robes with a broad paddle-like staff; robe/sole contact center. Actual eight-heading idle and walk pixels '
  'inspected. Specific source/model/variant pinned; alternative fingerprints remain distinct, with no claim of identical files, frames, '
  'colours or versions.'),
 ('66',
  '오크 궁수',
  'PB0250',
  'reviewed_66_source2',
  [24, 18],
  1.4,
  'Green orc archer with curved bow and back quiver. Actual eight-heading idle and walk pixels inspected. Specific source/model/variant '
  'pinned; alternative fingerprints remain distinct, with no claim of identical files, frames, colours or versions.'),
 ('65',
  '오크',
  'PB0242',
  'reviewed_65_source2',
  [24, 18],
  1.3,
  'Green broad-bodied orc with axe and light shoulder pieces; distinct from sword-orc and orc-bow bodies. Actual eight-heading idle and '
  'walk pixels inspected. Specific source/model/variant pinned; alternative fingerprints remain distinct, with no claim of identical '
  'files, frames, colours or versions.'),
 ('64',
  '해골',
  'PB0208',
  'reviewed_64_source2',
  [24, 18],
  1.2,
  'Sword-and-round-shield skeleton; bare bones and feet, no spear or bow. Actual eight-heading idle and walk pixels inspected. Specific '
  'source/model/variant pinned; alternative fingerprints remain distinct, with no claim of identical files, frames, colours or versions.'),
 ('63',
  '늑대인간',
  'PB0317',
  'reviewed_63_source2',
  [24, 18],
  1.25,
  'Brown werewolf with long muzzle, mane, pale claws and spiked club; distinct from grey lycanthrope 1108. Actual eight-heading idle and '
  'walk pixels inspected. Specific source/model/variant pinned; alternative fingerprints remain distinct, with no claim of identical '
  'files, frames, colours or versions.'),
 ('62',
  '킹 버그베어',
  'PB0284',
  'reviewed_62_source2',
  [24, 18],
  1.1,
  'Large grey king bugbear, horned/spiked club and yellow loincloth; distinct from pale bugbear 152. Actual eight-heading idle and walk '
  'pixels inspected. Specific source/model/variant pinned; alternative fingerprints remain distinct, with no claim of identical files, '
  'frames, colours or versions.'),
 ('61',
  '버그베어',
  'PB0261',
  'reviewed_61_source2',
  [24, 18],
  1.1,
  'Large pale bugbear with red loincloth and dark studded club; distinct from grey king bugbear 894. Actual eight-heading idle and walk '
  'pixels inspected. Specific source/model/variant pinned; alternative fingerprints remain distinct, with no claim of identical files, '
  'frames, colours or versions.'),
 ('223',
  '스톤 골렘',
  'PB0220',
  'reviewed_223_source2',
  [24, 18],
  1.2,
  'Broad segmented stone golem with stone fists, heavy feet and actual embedded dark shadow; foot soles reviewed independently of shadow '
  'bbox. Actual eight-heading idle and walk pixels inspected. Specific source/model/variant pinned; alternative fingerprints remain '
  'distinct, with no claim of identical files, frames, colours or versions.'),
 ('49',
  '흑장로',
  'PB0267',
  'reviewed_49_source2',
  [24, 18],
  1.4,
  'Dark elder in black/grey hooded robe with pale staff head; explicit dark elder morph. Actual eight-heading idle and walk pixels '
  'inspected. Specific source/model/variant pinned; alternative fingerprints remain distinct, with no claim of identical files, frames, '
  'colours or versions.'),
 ('47',
  '다크엘프',
  'PB0320',
  'reviewed_47_source2',
  [24, 18],
  1.3,
  'Pale-haired dark elf archer with dark/light fitted armor and bow; explicit darkelf definition. Actual eight-heading idle and walk '
  'pixels inspected. Specific source/model/variant pinned; alternative fingerprints remain distinct, with no claim of identical files, '
  'frames, colours or versions.'),
 ('46',
  '흑기사',
  'PB0035',
  'reviewed_46_source2',
  [24, 18],
  1.2,
  'Dark armored knight with tall shield and spear; ordinary black-knight morph explicitly uses body 110. Not ancient/neo black knight '
  '3054. Actual eight-heading idle and walk pixels inspected. Specific source/model/variant pinned; alternative fingerprints remain '
  'distinct, with no claim of identical files, frames, colours or versions. Source3 TW3.80 polymorph ordinary black knight 4923/8800 and '
  'NPC 45165 gfx4003 explicitly map to body110; ancient/neo3890/6267 and NPC81030 gfx3890 map to3054 and are not selected.'),
 ('45',
  '난쟁이',
  'PB0238',
  'reviewed_45_source2',
  [24, 18],
  1.8,
  'Short green-clad dwarf with round pack/shield and short weapon; short-legged foot center. Actual eight-heading idle and walk pixels '
  'inspected. Specific source/model/variant pinned; alternative fingerprints remain distinct, with no claim of identical files, frames, '
  'colours or versions.'),
 ('43',
  '데스나이트',
  'PB0272',
  'reviewed_43_source2',
  [24, 18],
  1.3,
  'Death Knight in pale skeletal armor, curved helmet/spikes and orange blade details; selected source2 all_nonconflicting_packs body 240, '
  'not assumed equal to source1 BASE/SHARDS. Actual eight-heading idle and walk pixels inspected. Specific source/model/variant pinned; '
  'alternative fingerprints remain distinct, with no claim of identical files, frames, colours or versions.'),
 ('236',
  '오크 소드',
  'PB0255',
  'reviewed_236_source2',
  [24, 18],
  1.2,
  'Green armored sword orc with curved sword, shield and orange crest. Actual eight-heading idle and walk pixels inspected. Specific '
  'source/model/variant pinned; alternative fingerprints remain distinct, with no claim of identical files, frames, colours or versions.'),
 ('235',
  '오크 보우',
  'PB0250',
  'reviewed_235_source2',
  [24, 18],
  1.4,
  'Green orc archer with curved bow and back quiver. Actual eight-heading idle and walk pixels inspected. Specific source/model/variant '
  'pinned; alternative fingerprints remain distinct, with no claim of identical files, frames, colours or versions.'),
 ('233',
  '오크 워리어',
  'PB0255',
  'reviewed_233_source2',
  [24, 18],
  1.2,
  'Green armored sword orc with curved sword, shield and orange crest. Actual eight-heading idle and walk pixels inspected. Specific '
  'source/model/variant pinned; alternative fingerprints remain distinct, with no claim of identical files, frames, colours or versions.'),
 ('157',
  '다크엘프 시프',
  'PB0171',
  'reviewed_157_source2',
  [24, 18],
  1.3,
  'Darkelf thief with pale hair, burgundy back/shoulder piece and short blades; selected all_nonconflicting_packs, no BASE/SHARDS mixing. '
  'Actual eight-heading idle and walk pixels inspected. Specific source/model/variant pinned; alternative fingerprints remain distinct, '
  'with no claim of identical files, frames, colours or versions.'),
 ('37',
  '발록',
  'PB0143',
  'reviewed_37_source2',
  [24, 18],
  0.9,
  'Dark massive Balrog with broad bat wings, long tail and horned head; selected source2 all_nonconflicting_packs and not red demon 1180. '
  'Actual eight-heading idle and walk pixels inspected. Specific source/model/variant pinned; alternative fingerprints remain distinct, '
  'with no claim of identical files, frames, colours or versions.'),
 ('25',
  '실버 나이트',
  'PB0336',
  'reviewed_25_source2',
  [24, 18],
  1.3,
  'Silver knight in bright silver armor, pale cloak and long silver sword; distinct from black knight 3054 and ordinary shield/spear '
  'knight 110. Actual eight-heading idle and walk pixels inspected. Specific source/model/variant pinned; alternative fingerprints remain '
  'distinct, with no claim of identical files, frames, colours or versions.'),
 ('19',
  '블랙 위자드',
  'PB0338',
  'reviewed_19_source2',
  [24, 18],
  1.3,
  'Black wizard in dark blue robe and tall headwear, with red orb/ring staff and long back ribbons. Actual eight-heading idle and walk '
  'pixels inspected. Specific source/model/variant pinned; alternative fingerprints remain distinct, with no claim of identical files, '
  'frames, colours or versions.'),
 ('11',
  '베레스',
  'PB0292',
  'reviewed_11_source2',
  [24, 18],
  1.3,
  'Beleth with horned skull helmet, dark armor and long double-ended staff; distinct from goat-skull ring-staff Baphomet. Actual '
  'eight-heading idle and walk pixels inspected. Specific source/model/variant pinned; alternative fingerprints remain distinct, with no '
  'claim of identical files, frames, colours or versions.'),
 ('6',
  '케레니스',
  'PB0326',
  'reviewed_6_source2',
  [24, 18],
  1.3,
  'Adult Kelenis with short dark hair, dark fitted dress/robe and pale trim; distinct from young Kelenis 8774. Actual eight-heading idle '
  'and walk pixels inspected. Specific source/model/variant pinned; alternative fingerprints remain distinct, with no claim of identical '
  'files, frames, colours or versions.')]

REVIEWS += [("42", "블레이즈", "PB0204", "blaze_source1", [24,18], 1.3,
    "Exact original source1 definition 4618 is named blaze (not only the lv blaze alias); body4618, pale short hair, fitted dark armor with gold trim and short blade. Eight-heading idle, walk and attack pixels inspected; anatomical boot center fixed across files. Other aliases do not authorize other bodies.")]

BASE_VARIANT_OVERRIDES = {
    "43": ("PB0051", "death_knight_source1_base", "Source1 BASE body240, fingerprint884444e8fe9656885f53: pale skeletal plate armor, crested helmet, orange blade details. Eight-heading idle/walk/attack and fixed boot support reviewed directly. The supplied semantic review recommends this exact BASE; no SHARDS or source2 file is mixed."),
    "157": ("PB0168", "darkelf_thief_source1_base", "Source1 BASE body3412, fingerprint3ffe07e46a79727d5ebd: pale hair, burgundy shoulder/back piece, dark fitted clothes and short blades. Eight-heading idle/walk/attack and fixed boot support reviewed directly. Explicit BASE pin; no different SHARDS fingerprint is mixed."),
    "37": ("PB0139", "balrog_source1_base", "Source1 BASE body2538, fingerprintb36236426e30172201a5: massive dark horned demon, bat wings, long tail and clawed feet. Eight-heading idle/walk/attack and fixed claw support reviewed directly. Exact BASE recommended by semantic input; distinct SHARDS/source2 fingerprint excluded from this body."),
}
REVIEWS = [(r[0],r[1],BASE_VARIANT_OVERRIDES[r[0]][0],BASE_VARIANT_OVERRIDES[r[0]][1],r[4],r[5],BASE_VARIANT_OVERRIDES[r[0]][2]) if r[0] in BASE_VARIANT_OVERRIDES else r for r in REVIEWS]
REVIEWS += [("20","다크 나이트","PB0334","dark_knight_source2",[24,18],1.3,
    "Actual existing target20 PNG shows rounded plate helmet, broad shoulders, long black cape, red central lining/panel and a long sword without a large shield. These distinguishing features match body3054, not shield/spear body110. Explicit source2 black knight definition and sword-family collection context corroborate the actual pixels. Eight-heading idle/walk/attack and fixed boot/hem support directly reviewed; one exact source2 variant only.")]

PENDING_REASONS = {
    "라쿤": "Quadruped paw/ground center and complete eight-view animation review pending.",
    "페이퍼 맨": "Translucent/flat paper body composition and grounded contact not established.",
    "거대 개미": "Multiple leg contact points; grounded center and complete direction review pending.",
    "서큐버스": "Winged/floating pose; ground projection and source shadow composition unverified.",
    "블레이즈": "Source lv blaze label does not establish the exact target transformation form.",
    "펌프킨": "Draped/hovering pumpkin body; anatomical ground projection unverified.",
    "다크 나이트": "Dark knight/black knight form distinction requires identity review despite one candidate fingerprint.",
    "뱀파이어": "Cloak obscures feet; stable anatomical ground center and all actions remain unverified.",
    "가드리아": "Legend_Gadria pixels inspected; airborne/one-foot poses lack a verified stable ground projection.",
}

def install(archive, package, root, review):
    assert hashlib.sha256(archive.read_bytes()).hexdigest() == ARCHIVE_SHA, "input SHA mismatch"
    with zipfile.ZipFile(archive) as z:
        assert z.testzip() is None, "ZIP CRC failure"
        for rel in ["package_reader.py", "decoder/spr_decode.py", "action_bindings.jsonl", "asset_requests.jsonl", "content_blobs.jsonl"]:
            assert z.read("transformation_source_candidates_v1/" + rel) == (package / rel).read_bytes(), rel
    from PIL import Image
    pkg = module("source_package", package / "package_reader.py").Package(package)
    decoder = module("source_spr_decoder", package / "decoder/spr_decode.py")
    target_id, name, binding_id, folder, foot_grid, scale, identity_basis = review
    binding = pkg.bindings[binding_id]
    candidate = next(c for c in pkg.candidates if c['twilight_id'] == 'transformation:inven:' + target_id)
    assert candidate['name'] == name
    if target_id == '20':
        assert hashlib.sha256((root/TARGET20_IMAGE).read_bytes()).hexdigest() == TARGET20_IMAGE_SHA
        assert binding['binding_id'] == TARGET20_REVIEW['selected_binding'] and binding['representative_id'] == TARGET20_REVIEW['selected_model']
    else:
        assert binding['representative_id'] in candidate['source_model_representatives']
    assert binding['matched_name_candidate']
    actions = dict(ACTIONS)
    available = {a['code'] for a in binding['actions']}
    action_fallbacks = {}
    for role, action in actions.items():
        if action not in available:
            replacement = next(code for code in [1,18,30,3,0] if code in available)
            action_fallbacks[role] = {'requested_action_code':action,'replacement_action_code':replacement,'reason':'Action absent; explicit sequence from the same source/body/variant only.'}
            actions[role] = replacement
    sprites, resolved = {}, {}
    for role, action in actions.items():
        source_action = next(a for a in binding["actions"] if a["code"] == action)
        for direction, heading in enumerate(HEADINGS):
            refs = [same_body_reference(pkg, binding, action, step, heading) for step in range(len(source_action["references"]))]
            for ref in refs:
                path = Path(ref["blob_path"])
                if path not in sprites:
                    data = path.read_bytes()
                    assert hashlib.sha256(data).hexdigest() == ref["blob_sha256"]
                    sprites[path] = decoder.Sprite(data)
            resolved[role, direction] = refs
    bounds = [s.metadata()["file_union_tile_bounds_original_grid"] for s in sprites.values()]
    canvas = [min(b[0] for b in bounds), min(b[1] for b in bounds), max(b[2] for b in bounds), max(b[3] for b in bounds)]
    width, height = canvas[2] - canvas[0], canvas[3] - canvas[1]
    # Reviewed anatomical ground center between the two feet in breathing
    # poses. Shared for all files/frames, never alpha-bbox recenter each frame.
    foot = [foot_grid[0] - canvas[0], foot_grid[1] - canvas[1]]
    output = root / "assets/local_source_transforms" / folder
    output.mkdir(parents=True, exist_ok=True)
    resource = "res://assets/local_source_transforms/" + folder + "/"
    ext, sub, animations, tracks = [], [], {}, []
    frame_number = 0
    for atlas_index, role in enumerate(actions, 1):
        count = len(resolved[role, 0])
        atlas = Image.new("RGBA", (width * 8, height * count))
        ext.append(f'[ext_resource type="Texture2D" path="{resource}{role}.png" id="{atlas_index}"]')
        for direction in range(8):
            frames = []
            refs = resolved[role, direction]
            for step, ref in enumerate(refs):
                sprite = sprites[Path(ref["blob_path"])]
                image, placement = sprite.render(ref["frame_index"], canvas_bounds=tuple(canvas))
                if image.getbbox() is None:
                    alternatives = [(i, r) for i, r in enumerate(refs) if i != step]
                    for _, alternative in sorted(alternatives, key=lambda pair: abs(pair[0]-step)):
                        replacement_image, replacement_placement = sprites[Path(alternative['blob_path'])].render(alternative['frame_index'],canvas_bounds=tuple(canvas))
                        if replacement_image.getbbox() is not None:
                            original = ref
                            ref = dict(alternative)
                            ref['explicit_same_body_fallback'] = {'reason':'Empty source body frame; retain nearest real frame of the same action/body/source/variant.','original_action_code':original['action_code'],'original_sequence_step':step,'original_heading':original['heading_slot'],'original_frame_index':original['frame_index'],'replacement_action_code':alternative['action_code'],'replacement_frame_index':alternative['frame_index']}
                            image, placement = replacement_image, replacement_placement
                            break
                    assert image.getbbox() is not None, (role, direction, step)
                atlas.paste(image, (width * direction, height * step))
                key = f"frame_{frame_number}"
                frame_number += 1
                sub.append(f'[sub_resource type="AtlasTexture" id="{key}"]\natlas = ExtResource("{atlas_index}")\nregion = Rect2({width*direction}, {height*step}, {width}, {height})\nfilter_clip = true')
                # Keep target clock/marker interpolation. Raw source durations
                # remain provenance; no unsupported tick conversion.
                frames.append('{"duration": 1.0, "texture": SubResource("' + key + '")}')
                tracks.append({**{k:v for k,v in ref.items() if k not in ["blob_path", "warning"]}, "role":role, "game_direction":direction, "placement":placement})
            animations[f"{role}_{direction}"] = (frames, role not in ["attack", "hit", "death", "cast", "special"])
        atlas.save(output / f"{role}.png")
    for alias, role in ALIASES.items():
        for direction in range(8): animations[f"{alias}_{direction}"] = animations[f"{role}_{direction}"]
    serialized = []
    for animation_name, (frames, loop) in animations.items():
        serialized.append('{"frames": [' + ', '.join(frames) + '], "loop": ' + str(loop).lower() + ', "name": &' + json.dumps(animation_name) + ', "speed": 9.0}')
    tres = f'[gd_resource type="SpriteFrames" load_steps={len(ext)+len(sub)+1} format=3]\n\n' + '\n\n'.join(ext+sub) + '\n\n[resource]\nanimations = [' + ',\n'.join(serialized) + ']\n'
    (output / "SpriteFrames.tres").write_text(tres)
    files = {p.name:hashlib.sha256(p.read_bytes()).hexdigest() for p in output.iterdir() if p.suffix in [".png", ".tres"]}
    original_profiles = json.loads((root / "data/combat_animation_profiles.json").read_text())["profiles"]
    layout = original_profiles.get("transform:" + target_id, {}).get("layout", "still")
    entry = {"name":name, "grade":candidate["grade"], "frames_path":resource+"SpriteFrames.tres", "required_layout":layout, "pixel_scale":scale, "sprite_offset":[(width/2-foot[0])*scale*0.90,(height/2-foot[1])*scale], "source_model":binding["representative_id"], "binding_id":binding_id, "body_model_prefix":binding["body_model_prefix"], "source":binding["source"], "variant":binding["variant"], "input_sha256":ARCHIVE_SHA, "identity_basis":identity_basis, "direction_review":"h1 back = N; h5 chest/front = S; h3 profile right = E; h7 profile left = W; all diagonal views checked.", "game_to_source_heading":HEADINGS, "canvas_original_grid":canvas, "foot_original_grid":foot_grid, "foot_in_canvas":foot, "foot_review":"Anatomical midpoint of two grounded feet/robe hem in breathing poses, compared against walking poses. One fixed anchor across every source file; no per-frame bbox recentering.", "original_grid_origin_in_canvas":[-canvas[0],-canvas[1]], "reference_client_origin_in_canvas":[-canvas[0]+24,-canvas[1]-36], "actions":actions, "action_fallbacks":action_fallbacks, "same_model_aliases":ALIASES, "same_model_alias_action_codes":{alias:{"original_source_action_code":None,"replacement_source_action_code":actions[role],"replacement_role":role,"reason":"Target presentation state has no distinct source action code; explicit same body/source sequence."} for alias,role in ALIASES.items()}, "timing_policy":"Preserve target duration, markers, movement cadence and hit clocks; source durations recorded raw only.", "attachments":binding["attachments"], "composition_limits":"Offline opaque RLE; palette/t/blend/color keys and separate shadow composition not certified. No replacement attachment added.", "files_sha256":files, "rendered_frames":frame_number}
    (output / "provenance.json").write_text(json.dumps({"entry":entry,"tracks":tracks,"spr_headers":{p.name:s.metadata() for p,s in sprites.items()}},ensure_ascii=False,indent=2))
    manifest_path = root / "data/source_transform_visuals.json"
    manifest = json.loads(manifest_path.read_text()) if manifest_path.exists() else {"schema":1,"scope":"Local-only reviewed source visuals; original art not authorized for public push.","entries":{},"excluded_grades":["신화","유일"]}
    manifest["entries"]["transform:" + target_id] = entry
    selected = set(manifest["entries"])
    manifest["pending_candidates"] = [{"id":c["twilight_id"],"name":c["name"],"reason": PENDING_REASONS.get(c["name"], "Definition only; no original body pixels supplied." if not c["has_raw_model_payload"] else "Multiple source model fingerprints/variants require exact form selection.")} for c in pkg.candidates if "transform:"+c["twilight_id"].split(":")[-1] not in selected]
    manifest_path.write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+"\n")
    print(json.dumps({"output":str(output),"canvas":canvas,"frames":frame_number,"sha256":files},ensure_ascii=False))

def apply_semantic_support(root, package, support_path):
    data = support_path.read_bytes()
    assert hashlib.sha256(data).hexdigest() == SEMANTIC_SHA, "semantic input SHA mismatch"
    support = json.loads(data)
    by_target = {c['twilight_id'].split(':')[-1]:c for c in support['candidates']}
    models = {m['id']:m for m in json.loads((package/'models.json').read_text())['models']}
    manifest_path = root/'data/source_transform_visuals.json'
    manifest = json.loads(manifest_path.read_text())
    manifest['scope'] = 'Locally committed, individually reviewed source visuals; no public upload authorized.'
    manifest['semantic_support_input'] = {'library_file_id':'libfile_c1cfa888f34081918ac90e4ad9f393d4','version':0,'filename':'transformation_30_semantic_support.json','bytes':len(data),'sha256':SEMANTIC_SHA,'cross_version_or_same_pixel_equality_claim':False}
    for key, entry in manifest['entries'].items():
        model = models[entry['source_model']]
        entry['model_fingerprint_sha256'] = model['model_fingerprint_sha256']
        entry['sample_sha256'] = model['sample_sha256']
        entry['foot_review'] = 'Fixed support/ground projection reviewed from actual idle and walking pixels; model-specific physical features are described in identity_basis. Same anchor across all files; no per-frame bbox recentering. Target actor root and existing 0.90 horizontal display factor preserved.'
        if key == 'transform:20':
            assert hashlib.sha256((root/TARGET20_IMAGE).read_bytes()).hexdigest() == TARGET20_IMAGE_SHA
            entry['target_image_identity_review'] = TARGET20_REVIEW
        target = by_target.get(key.split(':')[-1])
        if target:
            # The support file spells 눈사람 without the catalog's space.
            # Require the same pinned ID and exact Korean letters; retain the
            # original catalog name in every runtime entry.
            assert ''.join(target['target_name_ko'].split()) == ''.join(entry['name'].split())
            assert target['recommended_local_model_prefix'] == entry['body_model_prefix']
            alternatives = target['alternative_model_variants_kept_separate']
            matched = [a for a in alternatives+[target['chosen_model']] if a['source']==entry['source'] and a['fingerprint_SHA256']==entry['model_fingerprint_sha256'] and a['variant']==entry['variant']]
            assert matched and all(a['sample_actual_pixels_inspected'] for a in matched), key
            entry['semantic_support'] = {
                'input_sha256':SEMANTIC_SHA,
                'decision':target['decision'],
                'recommendation_scope':target['recommendation_scope'],
                'independent_actual_form_review':target['actual_form_review'],
                'recommended_source_variant':{k:target['chosen_model'][k] for k in ['source','variant','representative_id','fingerprint_SHA256']},
                'selected_variant_reason':'The selected exact source/variant is independently inspected in the support input and locally in eight headings. Recommended BASE pins are followed for Death Knight, Darkelf Thief and Balrog; other inspected source2 alternatives remain separately pinned.',
                'SQL_polymorph_local_explicit_base_chain':target['SQL_polymorph_local_explicit_base_chain'],
                'SQL_npc_local_explicit_base_chain':target['SQL_npc_local_explicit_base_chain'],
                'alternative_fingerprints_not_merged':sorted({a['fingerprint_SHA256'] for a in alternatives if a['fingerprint_SHA256']!=entry['model_fingerprint_sha256']}),
                'same_target_pixels_verified':False,
                'same_source3_version_pixels_verified':False,
            }
        provenance_path = root / entry['frames_path'].removeprefix('res://')
        provenance_path = provenance_path.parent/'provenance.json'
        provenance = json.loads(provenance_path.read_text())
        provenance['entry'] = entry
        provenance_path.write_text(json.dumps(provenance,ensure_ascii=False,indent=2))
    manifest_path.write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n')

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--archive",type=Path,required=True)
    parser.add_argument("--package",type=Path,required=True)
    parser.add_argument("--semantic-support",type=Path,required=True)
    parser.add_argument("--root",type=Path,default=Path(__file__).resolve().parents[1])
    args = parser.parse_args()
    for review in REVIEWS:
        install(args.archive,args.package,args.root,review)
    apply_semantic_support(args.root,args.package,args.semantic_support)
