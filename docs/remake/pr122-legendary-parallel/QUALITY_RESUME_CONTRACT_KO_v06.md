전설급 미호출106개 재개 계약 v06

현재는 준비만 완료했습니다. 이미지 호출, 실제 claim/once-lock 예약, 현재 자산·staging·원장 변경, 최종 corpus audit은 모두 0입니다. 기존 v02/v04/v05 producer·queue·plan·요청·checkpoint는 보존합니다.

새 파일은 `prepare_quality_resume_v06.py`, `quality-v02/generate_correction_once_v03.js`, `quality-v02/correction_generation_queue_v05.js`, `quality-v02/correction-plan-v06.json`입니다. 재결속한 요청만 `quality-v02/requests/transform_113-W-attack-correction-v04.json`에 새로 저장했습니다. 기존 compiler/delivery는 사용하되 실제 실행과 Git 작업은 delivery 담당입니다.

준비 plan은 SHA로 고정한 원래 checkpoint의 미호출106개만 허용합니다. 앞선13성공·7실패와274 NE ATTACK 차단 원화는 대상이 아닙니다. 기존 성공 중339 SW·275 SW 카메라 HOLD도 재호출하지 않습니다.

현재 READY71개, WAIT35개입니다. WAIT32개는 아직 호출하지 않은 IDLE 부모의 새 카메라·정상 guard 증거를 기다립니다.245 NW/NE ATTACK과338 N HIT의3개는 이미 시도했거나 HOLD인 부모이므로 자동 해제하거나 부모를 재시도하지 않습니다. 각 WAIT의 actor·방향·동작과 사유는 plan의 `jobs`에 있습니다.

READY는 WAIT와 별도로294~308의15개 map에 2~5 actor 단위로 저장합니다. 마지막6개는3+3으로 나누고, 같은 actor만 있는 묶음은 다른 READY 묶음과 균형을 맞춥니다. 교정 batch는 역할을 섞을 수 있으나 각 source의 동작·방향과 원래 plan index/batch는 보존합니다. WAIT 때문에 다른 READY 원화 제작을 멈추지 않습니다.

실제 재개 전 root가 reset 시각과 도구 상태를 확인하고 별도로 호출을 지시해야 합니다. 안전 경계는 원래 reset 범위의 늦은 값인 `2026-10-23T20:55:39+00:00`입니다. root 승인 인자 기본값은 `false`이고, 이 경우 코드가 image tool이나 claim 단계에 진입하지 않습니다. 아직 실제로 실행하거나 예약하지 않았습니다.

이 인자는 내부 실행 guard입니다. 사용자의 기존 제작·수정 지시는 이 작업을 이미 허용하며, 사용자에게 재승인을 요구하는 절차가 아닙니다. root가 시간·도구 상태를 확인한 뒤 실행할 때만 내부 인자를 켭니다. 동시수20은 상한이고, 실제 재개는 작은 batch에 맞춰 `concurrency`를2~5 등으로 낮출 수 있습니다. plan의 같은 `batch`에 속한2~5개 candidate를 선택하면 해당 map도 바로 완성할 수 있습니다.

그 시점에 같은 functions 실행 컨텍스트에서 생성기 파일 내용을 `store("qualityGenerateOnceV03", source)`로 로드하고 queue 파일 내용을 함수식으로 `eval`합니다. queue 입력은 다음 계약입니다.

```js
{
  plan_path: "/workspace/legendary_work/docs/remake/pr122-legendary-parallel/quality-v02/correction-plan-v06.json",
  candidates: null,
  concurrency: 20,
  root_authorized_image_calls: true // root의 새 실제 호출 지시 후에만
}
```

`candidates`는 선택적으로 candidate ID 배열을 받습니다. 미호출 allowlist·요청 SHA·actor/방향/동작·이전 source SHA를 생성 직전에 다시 확인합니다. 지원되는 image 요청 키는 prompt/referenced_image_paths/transparent_background뿐입니다. 새 reference는 실제 호출 전 필요한 내부 확인만 하고 채팅 이미지/Base64를 출력하지 않습니다. 별도 유료 API는 사용하지 않습니다.

생성기와 map/helper는 요청의 실제 파일 stem을 공유합니다. 예를 들어 request `-correction-v03.json`이면 claim·receipt도 `-correction-v03.json`, tool 결과는 `-correction-v03-result.json`입니다. 이는 기존 delivery가 찾는 이름과 같습니다. 모든 과거 v02/v03/새 버전의 같은 actor·방향·동작 claim/receipt를 먼저 확인하며, 버전과 관계없는 공통 `.once.lock`을 원자적으로 생성해 동시 중복도 막습니다. 기존 흔적이 있으면 WAIT하고 image tool을 다시 부르지 않습니다. stale claim의 수동 회수는 원래 반환 원화/증거부터 찾아야 하며 이 코드가 재호출하지 않습니다.

이미지 최대 동시수는20입니다. 반환 후 메타데이터 저장은 별도 settlement로 회수해 빈 이미지 슬롯을 다시 채웁니다. map 쓰기는 직렬이며 phase 끝에 모든 settlement와 map 결과를 회수합니다. 공통429/quota가 다시 발생하면 새 대상을 더 호출하지 않고 이미 정상 진행 중인 요청만 회수합니다. 개별 실패 원문은 Base64를 제외하고 보존하며 재시도하지 않습니다.

기존 mixed24개는 guard2개+신규 중간4개를 유지합니다. native3개는 기존 legacy sequence·좌표·RGBA·timing을 그대로 사용합니다. 임의 중간 자세 재사용이나 crop 추론은 없습니다.113 W ATTACK은 현재 선택된 isolation IDLE record/TRES의 정확한 SHA·source·region·margin·RGBA SHA로 guard0/5를 새 요청에 결속했습니다. guard PNG는 바꾸지 않았습니다.

WAIT32개를 나중에 materialize하려면 다음 JSON 계약의 명시적 증거를 root가 준비합니다. `quality_review`의 `records` 행에는 동일한 slot/record SHA와 `camera_result:"RESOLVED_STATIC"`, `idle_guard_result:"HEALTHY_STATIC"`, `reviewed_guard_phases:[0,5]`가 있어야 합니다. 또한 현재 선택 record/TRES, 실제 Godot6프레임 PASS, 정확한 REMOTE_SAVED commit의 해당 artifact SHA가 모두 일치해야 합니다. 카메라만 해결됐거나 대기 동작이 HOLD이면 정상 guard로 가정하지 않습니다.

```json
{
  "frozen_review_sha256": "bce7e7260712a27515627806a88690158f47bf8ddf4cd172dba5b5ba3eee00c6",
  "parents": [{
    "slot": ["transform:ID", "D", "idle"],
    "record": {"path": "res://...record.json", "sha256": "..."},
    "SpriteFrames": {"path": "res://...SpriteFrames.tres", "sha256": "..."},
    "quality_review": {"path": "docs/...review.json", "sha256": "..."},
    "validation": {"path": "docs/...validation.json", "sha256": "..."},
    "remote_receipt": {"path": "docs/...remote-saved.json", "sha256": "..."}
  }]
}
```

이후 새 plan/request 버전을 사용해 helper를 `--dry-run`으로 먼저 확인하고 `--prepare`합니다. 예를 들어 기존 READY의 회수가 끝난 다음 `--dependency-evidence <JSON> --request-revision v05 --output-plan correction-plan-v07.json --first-batch 309`를 사용합니다. 기존 plan/request는 덮어쓰지 않습니다. 검증된 guard 두 자세를 사용할 수 있는 dependent source만4개 신규 중간 자세로 만들며, 이전 six-new였다는 이유로 여섯 자세를 다시 만들지 않습니다. 이미 시도/HOLD인3개 부모는 증거 파일을 넣어도 자동 해제하지 않습니다.

기존 quality compiler는 새 request를 읽어 PNG를 변경 없이 보존하고 SpriteFrames를 구성합니다. 신규 batch map의 경로는 기존 `quality-correction-batchNNN-map.json` 형식이며, delivery는 실제 request stem과 같은 receipt/tool 결과를 받습니다. 원격 저장·최소 검사와 HOLD 상태는 별도로 유지하고 최종 승인으로 계산하지 않습니다.
