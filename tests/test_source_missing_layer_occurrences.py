"""Opt-in omission regressions; synthetic DTOs, never original artwork evidence."""
import copy
from pathlib import Path
import sys
import unittest

sys.path.insert(0,str(Path(__file__).resolve().parents[1]/"tools"/"lineagem_original"))
import build_reference_sp2_bank as bank


def layer(kind, physical, ordinal=None, requested=None, native=True, member=None):
    result={"kind":kind,"source_sprite_id":physical,"member":member or f"Sprite/{physical}-0.sp2"}
    if native:
        requested=physical if requested is None else requested
        result.update(native_binding_id=f"native:100:A3:{kind}:R{requested}:D{None if kind=='body' else 0}:T{ordinal}",
                      requested_sprite_id=requested,source_reference_index=None if kind=='body' else 0,target_index=ordinal)
    return result


def fixture(layers, frames=2):
    actor={"roles":{"source_action:3":{"directions":[[{"layers":copy.deepcopy(layers)} for _ in range(frames)] for _ in range(8)]}}}
    proof={"declarations":[{**copy.deepcopy(item),"declaration_path":[{"sprite_id":item["source_sprite_id"],"raw_own104":"8"}],
                           "edge_path":[{"raw":"ordered_original_operand"}]} for item in layers],
           "raw_candidate_declarations":[{"raw":"retained original source trace"}],"unrelated_proof":{"kept":True}}
    return actor,proof,{item["member"]for item in layers}


def retained(actor):
    return actor["roles"]["source_action:3"]["directions"][0][0]["layers"]


class MissingLayerOccurrenceTests(unittest.TestCase):
    def test_native_repeated_present_file_after_missing_occurrence_is_stopped(self):
        layers=[layer("body",100),layer("clothes",200,0),layer("clothes",300,1),layer("clothes",200,2)]
        actor,proof,members=fixture(layers);before_actor=copy.deepcopy(actor);before_proof=copy.deepcopy(proof)
        result,kept,filtered,omitted=bank.omit_missing_layers(actor,members,proof,{"Sprite/100-0.sp2":{},"Sprite/200-0.sp2":{}})
        self.assertEqual([x.get("target_index")for x in retained(result)],[None,0])
        self.assertEqual(kept,{"Sprite/100-0.sp2","Sprite/200-0.sp2"})
        self.assertEqual([x.get("target_index")for x in filtered["declarations"]],[None,0])
        self.assertEqual({x["native_binding_id"]for x in omitted},{layers[2]["native_binding_id"],layers[3]["native_binding_id"]})
        self.assertEqual(filtered["raw_candidate_declarations"],before_proof["raw_candidate_declarations"])
        self.assertEqual(filtered["unrelated_proof"],{"kept":True})
        self.assertEqual(actor,before_actor);self.assertEqual(proof,before_proof)
        for frames in result["roles"]["source_action:3"]["directions"]:
            self.assertTrue(all([x.get("target_index")for x in frame["layers"]]==[None,0] for frame in frames))

    def test_distinct_requested_owners_sharing_one_file_are_not_one_occurrence(self):
        layers=[layer("body",100),layer("clothes",500,0,210),layer("clothes",600,1,211),layer("clothes",500,2,220)]
        actor,proof,members=fixture(layers)
        result,_,filtered,omitted=bank.omit_missing_layers(actor,members,proof,{"Sprite/100-0.sp2":{},"Sprite/500-0.sp2":{}})
        self.assertEqual([x.get("requested_sprite_id")for x in retained(result)],[100,210])
        self.assertEqual([x.get("requested_sprite_id")for x in filtered["declarations"]],[100,210])
        self.assertEqual({x["requested_sprite_id"]for x in omitted},{211,220})

    def test_repeated_successful_prefix_keeps_each_instance(self):
        layers=[layer("body",100),layer("clothes",200,0),layer("clothes",200,1),layer("clothes",300,2),layer("clothes",200,3)]
        actor,proof,members=fixture(layers)
        result,_,_,_=bank.omit_missing_layers(actor,members,proof,{"Sprite/100-0.sp2":{},"Sprite/200-0.sp2":{}})
        self.assertEqual([x.get("target_index")for x in retained(result)],[None,0,1])
        self.assertEqual(len({x["native_binding_id"]for x in retained(result)}),3)

    def test_no_missing_identity_preserves_original_objects_and_all_occurrences(self):
        layers=[layer("body",100),layer("clothes",200,0),layer("clothes",200,1)]
        actor,proof,members=fixture(layers)
        result,kept,returned_proof,omitted=bank.omit_missing_layers(actor,members,proof,{member:{} for member in members})
        self.assertIs(result,actor);self.assertIs(returned_proof,proof);self.assertEqual(kept,members);self.assertEqual(omitted,[])
        self.assertEqual(len(retained(result)),3)

    def test_absent_body_is_rejected(self):
        layers=[layer("body",100),layer("clothes",200,0)]
        actor,proof,members=fixture(layers)
        with self.assertRaisesRegex(ValueError,"body file absent"):
            bank.omit_missing_layers(actor,members,proof,{"Sprite/200-0.sp2":{}})

    def test_shadow_omission_does_not_stop_clothes(self):
        layers=[layer("shadow",400,0),layer("body",100),layer("clothes",200,0),layer("clothes",200,1)]
        actor,proof,members=fixture(layers)
        result,_,_,omitted=bank.omit_missing_layers(actor,members,proof,{"Sprite/100-0.sp2":{},"Sprite/200-0.sp2":{}})
        self.assertEqual([x["kind"]for x in retained(result)],["body","clothes","clothes"])
        self.assertEqual(omitted[0]["kind"],"shadow")

    def test_legacy_physical_projection_is_intentionally_unchanged(self):
        layers=[layer("body",100,native=False),layer("clothes",200,native=False),layer("clothes",300,native=False),layer("clothes",200,native=False)]
        actor,proof,members=fixture(layers)
        result,_,filtered,omitted=bank.omit_missing_layers(actor,members,proof,{"Sprite/100-0.sp2":{},"Sprite/200-0.sp2":{}})
        self.assertEqual([x["source_sprite_id"]for x in retained(result)],[100,200,200])
        self.assertEqual(len(filtered["declarations"]),3)
        self.assertEqual(omitted,[{"kind":"clothes","source_sprite_id":300,"policy":bank.MISSING_LAYER_POLICY,"absent_files":["Sprite/300-0.sp2"]}])

    def test_compatibility_policy_remains_conservative_across_whole_action(self):
        layers=[layer("body",100),layer("clothes",200,0),layer("clothes",300,1),layer("clothes",200,2)]
        actor,proof,members=fixture(layers)
        actor["roles"]["source_action:3"]["directions"][0][1]["layers"][2]["member"]="Sprite/300-8.sp2"
        members.add("Sprite/300-8.sp2")
        identities={member:{}for member in members if member!="Sprite/300-8.sp2"}
        result,_,_,_=bank.omit_missing_layers(actor,members,proof,identities)
        # This opt-in whole-action shape is an existing approximation, not a
        # claim that the native lookup failed for the otherwise present pose.
        self.assertEqual([x.get("target_index")for x in retained(result)],[None,0])
        self.assertEqual(len(result["roles"]["source_action:3"]["directions"][0][1]["layers"]),2)


if __name__=="__main__":unittest.main()
