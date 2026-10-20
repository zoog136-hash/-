from pathlib import Path
P=Path(__file__).parent
source=P/'finish-NW-DEATH-full-six-validated-original-fabric-volume-v09.py'
s=source.read_text()
s=s.replace("D=P/'actual-NW-DEATH6-final-original-fabric-volume-v09'","D=P/'actual-NW-DEATH-single-phase0-rest-transverse-final-v10'")
s=s.replace('actual-NW-DEATH6-original-white-fold-raw-v08/NW-DEATH-six-actual-native-source-common-root-and-floor-raw-contract-v08.json','actual-NW-DEATH-single-phase0-rest-transverse-raw-v10/NW-DEATH-single-phase0-rest-transverse-source-root-and-floor-contract-v10.json')
s=s.replace('final-original-fabric-v09.png','rest-transverse-final-v10.png')
s=s.replace('assert len(rows)==6','assert len(rows)==1')
s=s.replace('NW-DEATH-final-six-exact-native-source-root-and-floor-contract-v09.json','NW-DEATH-single-phase0-rest-transverse-final-source-root-and-floor-contract-v10.json')
s=s.replace('NW-DEATH-final-six-exact-original-fabric-operator-opaque-and-floor-proof-v09.json','NW-DEATH-single-phase0-rest-transverse-opaque-and-floor-proof-v10.json')
s=s.replace('ACTUAL_FINAL_NW_DEATH6_VALIDATED_CLOTH_OPERATOR_PROPAGATED_PENDING_INDEPENDENT_FINAL_ROIS','ACTUAL_SINGLE_PHASE0_NATIVE_UPPER_REST_TWIST_CORRECTION_PENDING_QC')
s=s.replace('same_phase2_exact_png_reproduced=True','validated_phase2_unchanged_in_existing_six=True')
s=s.replace('phase2_exact_PASS_reproduced=True','phase2_not_rerendered=True')
exec(compile(s,str(source),'exec'),globals())
