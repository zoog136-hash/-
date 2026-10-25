"""New immutable queen RUN correction requests; no shared production mutation."""
import hashlib
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[5]
OUT = Path(__file__).resolve().parent
REF = OUT / "references/queen-project-canonical-crop.png"

COMMON = """Use the supplied local character artwork as the identity reference, and newly draw a SIX-POSE RUN animation contact sheet of this SAME adult ICE QUEEN boss. Preserve her pale adult face, long SILVER HAIR and ornate SILVER CROWN, fitted BLACK-and-GOLD breastplate/armor, long VIOLET-BLACK flowing dress, exactly TWO large violet feather wings attached solidly to the back, and exactly ONE purple-and-gold staff firmly gripped in her anatomical LEFT hand. The dress slit exposes ONLY her anatomical RIGHT upper thigh. Both legs must be clearly traceable from each hip to its own knee, ankle and boot: the LEFT thigh has dark fabric/stocking, the RIGHT thigh has pale skin at the slit. No limb switches or missing hidden support leg. Same ornamentation, body proportions and feather-wing anatomy throughout; fine painted dark-fantasy game sprite rendering with mature realistic anatomy and mythic-tier boss detail. Full staff, crown, both wings, hem and BOTH boots always inside the frame.

This correction is about GENUINELY OPPOSITE ANATOMICAL SUPPORT, not six versions of the same leading bare thigh. The layout is TWO COLUMNS by THREE ROWS, with matching opposite contacts SIDE BY SIDE to make the difference unambiguous. The six squares are independent fresh skeletal poses, not copies, mirror flips or whole-body shifts. LEFT COLUMN is first half of stride: TOP-LEFT: anatomical RIGHT boot contacts flat on the invisible ground ahead of pelvis, RIGHT knee extended, LEFT boot is flexed behind and clearly OFF the ground; MIDDLE-LEFT: RIGHT boot supports under pelvis with compressed knee, LEFT covered knee and LEFT boot swing visibly FORWARD and UP with clear air below; BOTTOM-LEFT: short FLIGHT, LEFT covered leg extended forward/down while RIGHT exposed slit leg extends back/up, both boots above the invisible ground. RIGHT COLUMN is second half of stride: TOP-RIGHT: anatomical LEFT covered leg extends FORWARD and LEFT boot contacts flat ahead of pelvis, RIGHT exposed slit knee bends BACK and RIGHT boot is visibly OFF ground; MIDDLE-RIGHT: LEFT boot supports under pelvis, RIGHT pale thigh/knee and RIGHT boot swing visibly FORWARD and UP with air below; BOTTOM-RIGHT: short FLIGHT, RIGHT bare-thigh leg extended forward/down, LEFT covered leg extends back/up, both boots above the invisible ground. Do not draw the bare RIGHT thigh as the planted leading leg in both top cells. Show an obvious DIFFERENT support foot in top-left vs top-right. These column halves will be played left-column top-to-bottom, then right-column top-to-bottom. Keep staff with LEFT hand through all phases, subtle shoulder counterrotation, recognizable weight over planted boot, bent toe-off and ankle articulation. Skirt panels separate enough to reveal both lower legs during stride while remaining a long ornate gown. Hair, feathers and cloth trail behind and follow through differently in each pose. Wings stay attached and do not replace legs or hide the support exchange. The character RUNS on feet, not levitates or hovers.

Single fixed orthographic/isometric camera per sheet, identical camera and facing in every cell. Small whole figures with VERY LARGE empty transparent gutters: all visible pixels fit within the central 50 percent width and central 65 percent height of each of the six equal cells. Align each cell's invisible ground baseline at about 84 percent of its height; planted soles sit there and flight soles are a little above it. One connected full character silhouette per cell. No overlap of full bounding boxes. TRUE RGBA transparency, alpha0 background. No visible floor, no ground plane, no cast shadow, no text/numbers/grid, no effects/glow/particles/haze, no floating loose feathers, no tiny detached specks. Save the generated PNG locally. Never add walking/attack/death cells. """

CAMERAS = {
    "E": "Every cell is exact EAST side view: face, chest, knees and toes point screen RIGHT. Clearly show the dark LEFT boot landing as the forward foot in TOP-RIGHT, while the exposed pale RIGHT thigh folds BEHIND it. The bare thigh must not always be the leading plant.",
    "SE": "Every cell faces SOUTHEAST, down-right on screen, a FRONT-right diagonal isometric view: face/front breastplate visible, both feet advance down-right. TOP-RIGHT plants the dark-covered LEFT leg toward down-right and folds the pale RIGHT thigh backward. Keep the diagonal camera unchanged during the stride.",
    "S": "Every cell is SOUTH/front view, running toward the viewer, chest and crown symmetrical front, toe direction down screen. Anatomical RIGHT bare thigh is on viewer LEFT; anatomical LEFT covered leg is on viewer RIGHT. TOP-LEFT plants the viewer-LEFT RIGHT boot, TOP-RIGHT plants the viewer-RIGHT LEFT boot while the bare viewer-left knee/boot lifts and trails. Do not keep the same viewer-left support in both top cells.",
    "SW": "Every cell faces SOUTHWEST, down-left on screen, a FRONT-left diagonal isometric view: face/front breastplate visible, toes advance down-left. TOP-RIGHT plants the dark-covered anatomical LEFT leg toward down-left and folds the pale RIGHT thigh backward. Never mirror a rightward sheet because the staff remains anatomical LEFT.",
    "W": "Every cell is exact WEST side view: face/chest/toes point screen LEFT. TOP-RIGHT clearly plants the dark-covered anatomical LEFT boot toward screen LEFT while the bare RIGHT thigh bends BACK toward screen RIGHT. Never mirror EAST: staff remains anatomical LEFT.",
    "NW": "Every cell faces NORTHWEST, upper-left on screen, a REAR diagonal view. Viewer sees BACK of crown/head/silver hair, BACK armor and both wing attachment roots; front breastplate and face are turned away. Toes run toward upper-left and heels toward lower-right. Only a tiny ear/cheek silhouette is acceptable; no frontal face or visible chest. Make rear pelvis and alternating boots visible below gown. Staff stays in anatomical LEFT hand.",
    "N": "Every cell is NORTH straight BACK view, running AWAY from viewer up-screen. Viewer sees only back of crown/head/silver hair, BACK armor and both wing roots, no face or front breastplate. Toes run up-screen, heels toward viewer; wings lie on either side of the spine. Both alternate boots must be visible below the rear hem. Anatomical LEFT hand with staff appears on viewer LEFT.",
    "NE": "CRITICAL CAMERA CORRECTION: every cell faces NORTHEAST, upper-RIGHT on screen, and is a clear REAR THREE-QUARTER view. Viewer looks at BACK of crown and BACK of silver-haired head, spine/back armor, rear skirt and both rear wing attachment roots. Toes travel away toward upper-right, heels face lower-left viewer. The FACE, EYES, FRONT BREASTPLATE and FRONT CLEAVAGE are entirely turned AWAY and must NOT be visible. Do not produce an E/SE side/front silhouette. Turn the whole torso and hips away, not just the head. Back hair covers the upper back between wing roots, far shoulder foreshortened, near rear shoulder visible. The two wings project back-left and back-right from actual shoulder blades; alternate rear boot/heel supports stay readable below the trailing rear hem. Maintain this exact rear-right camera in ALL SIX cells. Staff stays in anatomical LEFT hand.",
}

for direction, camera in CAMERAS.items():
    request = {
        "schema": "pr122-queen-run-correction-request-v1",
        "actor": "monster:얼음 여왕", "direction": direction, "role": "run", "revision": "r001",
        "pose_count": 6, "source_grid": [2, 3], "playback_source_slots": [0, 2, 4, 1, 3, 5],
        "neutral_contact_source_slots": [0, 1],
        "references": [str(REF)], "reference_sha256": hashlib.sha256(REF.read_bytes()).hexdigest(),
        "request": {"prompt": COMMON + "\n\n" + camera, "referenced_image_paths": [str(REF)], "transparent_background": True},
        "preserve_all_results": True, "production_connected": False, "new_approvals": 0,
    }
    path = OUT / "requests" / f"queen-{direction}-run6-v01.json"
    payload = (json.dumps(request, ensure_ascii=False, indent=2) + "\n").encode()
    if path.exists():
        assert path.read_bytes() == payload, "Use a fresh revision instead of overwriting"
    else:
        path.write_bytes(payload)
print("8 new RUN correction requests saved; opposite-support column-pair design")
