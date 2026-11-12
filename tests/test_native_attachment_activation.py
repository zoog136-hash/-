"""Source-format/native ownership regressions; fixtures contain no original art."""
import copy
import hashlib
import json
from pathlib import Path
import sys
import tempfile
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'tools' / 'lineagem_original'))
import build_current523_identity_pack as identity
import original_spr


def fixture(text, native=True):
    return files_fixture({'list_0.spr': text}, native)


def files_fixture(files, native=True):
    with tempfile.TemporaryDirectory() as directory:
        paths = []
        for name, text in files.items():
            path = Path(directory) / name
            path.write_bytes(text.encode('cp949'))
            paths.append(path)
        declarations = identity.read_native_sprs(paths) if native else original_spr.read(paths)
    proofs = {name: {'sha256': hashlib.sha256(text.encode('cp949')).hexdigest()}
              for name, text in files.items()}
    return declarations, proofs


def first_layers(actor, role='idle'):
    return actor['roles'][role]['directions'][0][0]['layers']


class NativeAttachmentActivationTest(unittest.TestCase):
    def test_header_alias_is_one_file_remap_and_does_not_inherit_metadata_or_actions(self):
        declarations, proofs = fixture('''#100 1=200 original
110.framerate(24)
3.idle(1 1,7.4:2)
101.shadow(101)
105.clothes(1 102)
#101 1 ownshadow
#102 1 ownclothes
#200 1=300 mapped_file
110.framerate(5)
3.unused(0 1,88.1:99)
101.shadow(201)
105.clothes(1 202)
#201 1 mapped_shadow
#202 1 mapped_clothes
#300 1 deeper_file
''')
        actor, members, proof = identity.build_actor(100, declarations, proofs, (('idle', 3),))
        self.assertEqual([(x['kind'], x['source_sprite_id']) for x in first_layers(actor)],
                         [('shadow', 101), ('body', 200), ('clothes', 102)])
        self.assertEqual(actor['roles']['idle']['fps'], 24)
        self.assertEqual(proof['roles']['idle']['tokens'], [(7, 4, 2)])
        self.assertFalse(any('/300-' in member or '/201-' in member or '/202-' in member for member in members))
        body = next(x for x in proof['declarations'] if x['kind'] == 'body')
        self.assertEqual([x['sprite_id'] for x in body['declaration_path']], [100, 200])
        self.assertEqual([x['sprite_id'] for x in body['attribute_owner_declaration_path']], [100])
        self.assertEqual(body['file_remap_policy'], identity.FILE_REMAP_POLICY)
        self.assertIn(300, {x['sprite_id'] for x in proof['raw_candidate_declarations']})
        self.assertTrue(all(x['activation_inferred'] is False for x in proof['raw_candidate_declarations']))

    def test_header_alias_without_own_action_does_not_borrow_target_descriptor(self):
        declarations, proofs = fixture('''#10 1 source
110.framerate(24)
3.idle(0 1,8.0:1)
#20 1=10 file_only
''')
        with self.assertRaisesRegex(ValueError, 'absent native source action 20/3'):
            identity.build_actor(20, declarations, proofs, (('idle', 3),))

    def test_chained_action_alias_uses_immediate_shadow_owner_and_original_clothes_owner(self):
        declarations, proofs = fixture('''#10 1 descriptor_origin
110.framerate(24)
3.idle(1 1,7.4:2)
101.shadow(11)
105.clothes(1 12)
#11 1 shadow10
#12 1 clothes10
#20 1 immediate_owner
110.framerate(2)
3=10
101.shadow(21)
105.clothes(1 22)
#21 1 shadow20
#22 1 clothes20
#30 1 original_actor
110.framerate(3)
3=20
101.shadow(31)
105.clothes(1 32)
#31 1 shadow30
#32 1 clothes30
''')
        before = copy.deepcopy({key: [vars(x) for x in value] for key, value in declarations.items()})
        actor, members, proof = identity.build_actor(30, declarations, proofs, (('idle', 3),))
        self.assertEqual({key: [vars(x) for x in value] for key, value in declarations.items()}, before)
        self.assertEqual([(x['kind'], x['requested_sprite_id']) for x in first_layers(actor)],
                         [('shadow', 21), ('body', 20), ('clothes', 32)])
        action = proof['roles']['idle']
        self.assertEqual(action['native_descriptor_origin_sprite_id'], 10)
        self.assertEqual(action['native_body_request_sprite_id'], 20)
        self.assertEqual([x['target_sprite_id'] for x in action['native_action_alias_chain']], [20, 10])
        self.assertEqual((action['fps'], action['tokens']), (24, [(7, 4, 2)]))
        self.assertEqual(proof['native_activation_by_role']['idle']['shadow_metadata_owner_sprite_id'], 20)
        self.assertEqual(proof['native_activation_by_role']['idle']['clothes_metadata_owner_sprite_id'], 30)
        body = next(x for x in proof['declarations'] if x['kind'] == 'body')
        self.assertEqual(body['metadata_owner_sprite_id'], 30)
        self.assertEqual([x['sprite_id'] for x in body['attribute_owner_declaration_path']], [30])
        self.assertNotIn('Sprite/11-0.sp2', members)
        self.assertNotIn('Sprite/31-0.sp2', members)

    def test_last_shadow_low15_wins_but_raw_candidates_survive(self):
        declarations, proofs = fixture('''#20 1 actor
110.framerate(24)
3.idle(0 1,0.0:1)
101.shadow(21)
101.shadow(32790)
#21 1 inactive
#22 1 active
''')
        actor, _, proof = identity.build_actor(20, declarations, proofs, (('idle', 3),))
        shadow = next(x for x in first_layers(actor) if x['kind'] == 'shadow')
        self.assertEqual(shadow['requested_sprite_id'], 22)
        self.assertEqual(shadow['source_reference_index'], 1)
        source = next(x for x in proof['declarations'] if x['kind'] == 'shadow')['source_declaration']
        self.assertEqual((source['sprite_id'], source['source_line'], source['body']), (20, 5, '32790'))
        raw = next(x for x in proof['raw_candidate_declarations'] if x['sprite_id'] == 20)
        self.assertEqual([x['raw'] for x in raw['literal_references']], ['21', '32790'])

    def test_last_zero_shadow_clears_animated_projection(self):
        declarations, proofs = fixture('''#20 1 actor
110.framerate(24)
3.idle(0 1,0.0:1)
101.shadow(21)
101.shadow(0)
#21 1 inactive
''')
        actor, members, _ = identity.build_actor(20, declarations, proofs, (('idle', 3),))
        self.assertEqual([x['kind'] for x in first_layers(actor)], ['body'])
        self.assertEqual(members, {'Sprite/20-0.sp2'})

    def test_first_clothes_binding_preserves_order_and_repeated_targets(self):
        declarations, proofs = fixture('''#20 1 actor
110.framerate(24)
3.idle(0 1,0.0:1)
105.clothes(3 40 40 41)
105.clothes(2 42)
#40 1 repeated
#41 1 next
#42 1 inactive
''')
        actor, _, proof = identity.build_actor(20, declarations, proofs, (('idle', 3),))
        clothes = [x for x in first_layers(actor) if x['kind'] == 'clothes']
        self.assertEqual([x['requested_sprite_id'] for x in clothes], [40, 40, 41])
        self.assertEqual([x['target_index'] for x in clothes], [0, 1, 2])
        self.assertEqual(len({x['native_binding_id'] for x in clothes}), 3)
        raw = next(x for x in proof['raw_candidate_declarations'] if x['sprite_id'] == 20)
        self.assertEqual(len(raw['literal_references']), 2)
        self.assertFalse(raw['literal_references'][1]['count_valid'])

    def test_malformed_first_clothes_binding_never_falls_through_to_later_valid_list(self):
        declarations, proofs = fixture('''#20 1 actor
110.framerate(24)
3.idle(0 1,0.0:1)
105.clothes(2 40)
105.clothes(1 41)
#40 1 first
#41 1 later
''')
        with self.assertRaisesRegex(ValueError, 'invalid active clothes target count 20'):
            identity.build_actor(20, declarations, proofs, (('idle', 3),))

    def test_zero_clothes_request_stops_before_zero_and_all_later_candidates(self):
        for targets, expected in [('40 0 41', [40]), ('0 40 41', [])]:
            with self.subTest(targets=targets):
                declarations, proofs = fixture('#20 1 actor\n110.framerate(24)\n3.idle(0 1,0.0:1)\n'
                    + f'105.clothes(3 {targets})\n#40 1 prefix\n#41 1 after_zero\n')
                actor, members, proof = identity.build_actor(20, declarations, proofs, (('idle', 3),))
                self.assertEqual([x['requested_sprite_id'] for x in first_layers(actor) if x['kind'] == 'clothes'], expected)
                self.assertFalse(any(member.startswith('Sprite/0-') or member.startswith('Sprite/41-') for member in members))
                activation = proof['native_activation_by_role']['idle']
                self.assertTrue(activation['clothes_zero_target_prefix_applied'])
                self.assertEqual(activation['clothes_zero_target_stop']['target_index'], targets.split().index('0'))
                self.assertEqual(activation['clothes_zero_target_stop']['reason'], 'requested_high16_zero_always_null')
                raw = next(x for x in proof['raw_candidate_declarations'] if x['sprite_id'] == 20)
                self.assertEqual(raw['literal_references'][0]['targets'], list(map(int, targets.split())))
                self.assertIn(41, {x['sprite_id'] for x in proof['raw_candidate_declarations']})

    def test_zero_body_request_is_not_promoted_to_original_artwork(self):
        declarations, proofs = fixture('#0 1 null_request\n110.framerate(24)\n3.idle(0 1,0.0:1)\n')
        with self.assertRaisesRegex(ValueError, 'high16 zero is null'):
            identity.build_actor(0, declarations, proofs, (('idle', 3),))

    def test_auxiliary_own_auxiliaries_are_evidence_only(self):
        declarations, proofs = fixture('''#20 1 actor
110.framerate(24)
3.idle(0 1,0.0:1)
105.clothes(1 40)
#40 1 clothes
101.shadow(41)
105.clothes(2 42)
#41 1 nested_shadow
#42 1 nested_clothes
''')
        actor, members, proof = identity.build_actor(20, declarations, proofs, (('idle', 3),))
        self.assertEqual([(x['kind'], x['requested_sprite_id']) for x in first_layers(actor)], [('body', 20), ('clothes', 40)])
        self.assertEqual(members, {'Sprite/20-0.sp2', 'Sprite/40-0.sp2'})
        self.assertEqual({x['sprite_id'] for x in proof['raw_candidate_declarations']}, {20, 40, 41, 42})
        self.assertTrue(all(len(x['edge_path']) <= 1 for x in proof['declarations']))

    def test_forward_alias_is_not_resolved_by_a_later_definition(self):
        declarations, proofs = fixture('''#10 1 forward
3=20
#20 1 source_defined_later
110.framerate(24)
3.idle(0 1,0.0:1)
''')
        self.assertEqual(declarations[10][0].native_action_aliases[0]['registration_status'], 'source_descriptor_unavailable')
        with self.assertRaisesRegex(ValueError, 'absent native source action 10/3'):
            identity.build_actor(10, declarations, proofs, (('idle', 3),))

    def test_duplicate_action_destination_keeps_first_and_preserves_raw_events(self):
        declarations, proofs = fixture('''#10 1 source
110.framerate(24)
3.idle(0 1,8.2:3)
#20 1 actor
110.framerate(48)
3=10
3.later_literal(1 1,80.7:9)
3=30
#30 1 too_late
''')
        actor, _, proof = identity.build_actor(20, declarations, proofs, (('idle', 3),))
        self.assertEqual(proof['roles']['idle']['tokens'], [(8, 2, 3)])
        self.assertEqual(proof['roles']['idle']['fps'], 24)
        raw = declarations[20][0]
        self.assertEqual(raw.native_literal_action_declarations[0]['registration_status'], 'duplicate_destination')
        self.assertEqual(raw.native_literal_action_declarations[0]['descriptor']['tokens'], [(80, 7, 9)])
        self.assertEqual(raw.native_action_aliases[1]['registration_status'], 'duplicate_destination')

    def test_numeric_list_loading_order_and_no_resolve_from_source_frame_origin(self):
        declarations, proofs = files_fixture({'list_10.spr': '#100 1 requested\n3=20\n',
            'list_2.spr': '#20 1 earlier_source\n110.framerate(24)\n3.idle(0 1,0.0:1)\n'})
        actor, _, _ = identity.build_actor(100, declarations, proofs, (('idle', 3),))
        self.assertEqual(next(x for x in first_layers(actor) if x['kind'] == 'body')['requested_sprite_id'], 20)

    def test_source_pinned_raw_events_reconstruct_json_roundtrip_without_trusting_effective_rows(self):
        declarations, proofs = fixture('''#10 1 source
110.framerate(24)
3.idle(0 1,8.2:3)
#20 1 actor
3=10
''')
        expected, _, _ = identity.build_actor(20, declarations, proofs, (('idle', 3),))
        restored = copy.deepcopy(declarations)
        for matches in restored.values():
            for declaration in matches:
                declaration.native_literal_action_declarations = json.loads(json.dumps(declaration.native_literal_action_declarations))
                declaration.native_action_aliases = json.loads(json.dumps(declaration.native_action_aliases))
                declaration.native_action_descriptors = {3: {'untrusted': True}}
        identity.register_native_actions(restored)
        actual, _, _ = identity.build_actor(20, restored, proofs, (('idle', 3),))
        self.assertEqual(actual, expected)
        self.assertEqual(identity.native_action(restored, 20, 3)['tokens'], [(8, 2, 3)])

    def test_different_roles_can_have_different_immediate_owners_and_shadow_requests(self):
        declarations, proofs = fixture('''#10 1 source
110.framerate(24)
0.walk(0 1,0.0:1)
101.shadow(11)
#11 1 source_shadow
#20 1 actor
110.framerate(24)
0=10
3.idle(0 1,8.0:1)
101.shadow(21)
#21 1 own_shadow
''')
        actor, _, proof = identity.build_actor(20, declarations, proofs, (('idle', 3), ('walk', 0)))
        self.assertEqual([x['requested_sprite_id'] for x in first_layers(actor, 'idle')], [21, 20])
        self.assertEqual([x['requested_sprite_id'] for x in first_layers(actor, 'walk')], [11, 10])
        compact = identity.compact_roles(actor, proof)
        self.assertEqual([x['source_sprite_id'] for x in compact['idle']['layers']], [21, 20])
        self.assertEqual([x['source_sprite_id'] for x in compact['walk']['layers']], [11, 10])
        self.assertEqual(proof['body_sprite_ids_by_role'], {'idle': 20, 'walk': 10})

    def test_legacy_literal_ast_remains_supported_without_alias_inference(self):
        declarations, proofs = fixture('#20 1 actor\n110.framerate(24)\n3.idle(0 1,0.0:1)\n', native=False)
        actor, _, proof = identity.build_actor(20, declarations, proofs, (('idle', 3),))
        self.assertEqual(first_layers(actor)[0]['source_sprite_id'], 20)
        self.assertTrue(proof['existing_private_banks_require_regeneration'])
        self.assertFalse(proof['native_activation_by_role']['idle']['runtime_activation_verified'])


if __name__ == '__main__':
    unittest.main()
