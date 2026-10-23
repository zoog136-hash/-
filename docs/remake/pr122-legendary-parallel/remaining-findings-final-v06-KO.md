전설급 최종 증거 대조와 활성 구성 잔여

확정 검토 `6bcd94f5a086`의 역사 원본·오류 목록은 보존했습니다. 최종 승인 추가0.

역사 issue 발생건수와 현재 활성 clip 수는 별도입니다. 대체된 원본의 HOLD는 활성 원본에서 같은 오류가 확인됐다는 뜻이 아닙니다.

현재 오류·불확실성 투영은 4666건이며, 중복 제거한 활성/미생성 구성은 972개입니다. 원인별 구성 수는 서로 겹칠 수 있습니다.

|현재 원인|ERROR 구성|HOLD 구성|BLOCKED 구성|
|---|---:|---:|---:|
|ALPHA_BRIDGE_BETWEEN_TEMPORAL_POSES|0|30|0|
|CONNECTED_OR_OPAQUE_POSE_LAYOUT|0|11|0|
|DETACHED_FOREGROUND_OWNER_AMBIGUOUS|0|103|0|
|FOOT_REGISTRATION_DRIFT|0|250|0|
|FOREIGN_POSE_FOREGROUND_INSIDE_FRAME|123|1|0|
|INCONSISTENT_TEXTURE_CANVAS_WITHIN_CLIP|0|476|0|
|MISSING_REQUIRED_SLOT|0|0|1|
|VISIBLE_FOREGROUND_TOUCHES_FRAME_EDGE|0|797|0|
|VISIBLE_FOREGROUND_TOUCHES_SOURCE_EDGE|0|34|0|
|VISIBLE_HEIGHT_VARIATION|0|77|0|
|articulation|0|11|0|
|blocked|0|0|1|
|camera|22|37|0|
|clipped_or_foreign_body|338|12|0|
|identity_weapon_action|2|9|0|
|idle_role|0|3|0|
|scale_registration|0|258|0|

SUPERSEDED_REQUIRES_QA와 수정 record 재검토 HOLD는 이전 원본과 현재 clip을 구분하는 불확실성입니다. 기존 결함의 잔존 확정으로 집계하지 않았습니다.

원래 미생성은274 NE ATTACK moderation BLOCKED1개입니다. 교정 PNG 109개/604신규자세를 저장했습니다. 과거429거절7건은 한도해제 후 각각1회 복구됐으며, 현재 생성차단0·의존 부모 HOLD로 미호출15개를 별도로 남겼습니다.

176 등록 33구성/198프레임은 기술 등록만 확인했습니다. 카메라·동작 승인0입니다. guard-only6건은 정상 중간4자세를 보존한 자원수정2건과 부모HOLD4건으로 구분했습니다.

정확한 actor·방향·동작·원본/활성 record/source SHA·proof·원인별 ERROR/HOLD/BLOCKED 목록은 [remaining-findings-final-v05.json](remaining-findings-final-v05.json)에 있습니다. PNG 재열람·전체 시각 재검토·추가 생성0.


별도 QA 환경 HOLD는 2건/2구성입니다. 원화 결함과 분리했고, 기존 전체 실제 재생1319 PASS 증거는 별도로 유지합니다. staging 자동 import 분리는 네이티브 import/export 통합 승인이 아닙니다.


기존 전체 CI2는 216 PASS / 12 FAIL / 5 SKIP로 실패했습니다. CI1 import시간초과와 관찰자401은 별도 역사 증거이며, 원화 오류나 CI2 결과로 합치지 않았습니다.


최신 활성 런타임 증거는 1318 PASS / 1 FAIL / 1 BLOCKED입니다. 변경98개 실제재생에서97 PASS·캡처1 FAIL을 그대로 유지했습니다. 정상1221개는 역사 증거를 사용했고 다시 재생하지 않았습니다.

이미 계산한 중복 제거 목록: [활성 잔여·불확실성972구성 TSV](remaining-findings-active-clips-final-v05.tsv), [별도 QA환경HOLD2구성 TSV](remaining-findings-QA-environment-clips-final-v05.tsv). TSV는 severity·actor ID·방향·동작·원인 목록만 내보냈고 분류를 바꾸지 않았습니다.

[표시 보완 근거](remaining-findings-final-v05-presentation-clarification-v06.json)는 원본v05 보고서와 raw runtime·CI SHA를 연결합니다. 원본 JSON/MD는 보존했고 전체 대조를 다시 실행하지 않았습니다.

최고 severity 기준972구성은 ERROR380 / HOLD591 / BLOCKED1입니다. 이는 확정 오류와 불확실성을 함께 보존한 투영 집합이며 실제 품질 불량972개를 새로 확인했다는 뜻이 아닙니다. 별도 QA환경HOLD2개는 이972구성과 모두 중복됩니다.

`clipped_or_foreign_body` ERROR338개는 현재 같은 원본 SHA를 선택한113개와 같은 원본의 lossless derivative를 선택한225개입니다. 수정 후 새로 관측한338개가 아니라, 유효한 frozen 시각 finding을 현재 선택 경로에 대조한 값입니다. 정수 소유권 분리 proof가 있어도 결합된 잘림·형상 문제의 의미를 별도 시각근거 없이 해제하지 않았으므로 원래 ERROR_VISUAL severity를 보수적으로 유지했습니다. 새 시각 재검토를 하지 않았고 이 설명으로 dataset·분류를 바꾸지 않았습니다.
