# 전설급 병렬 제작 인계 — 2026-10-23

전용 브랜치: `feature/pr122-legendary-parallel-20261023`. 원화·프레임·등록 데이터의 최종 고정 커밋은 `0fe2882e594dedd30b5ce74f172edf4aed545122`이다. 이후 커밋은 증거와 인계 문서만 저장한다. 신화급 브랜치에는 쓰지 않았으며 새 PR·병합·rebase·force push를 수행하지 않았다. 신화급 완료 뒤 PR #122에 통합한다.

| 제작 단위 | 저장된 결과 |
|---|---|
| 대상 | 카탈로그 전설급 40종 |
| 초안 | 1,319/1,320 구성, 7,914/7,920 자세 |
| 최초 초안 신규·재사용 | 신규 6,953 + 원본 59 + 이전 초안 guard 재사용 902 |
| 오류 원화 교정 | 성공 원화 109개, 추가 제작 604자세 |
| 겹침 분리 | 누적 721개 원화; 정수 RGBA 분리, 신규 자세 0 |
| 원화 생성 없는 guard 수정 | 6개 선택 대상 중 2개 재결속, 부모 오류가 남은 4개 HOLD |
| 의존 교정 잔여 | 15개 WAIT: 부모 카메라 7·외형 3·대기 동작 부적합 5 |
| 새 정밀 제작 최종 승인 | 0 |

교정 604자세는 기존 구성을 대체하므로 7,914자세에 더하지 않는다. PNG·SpriteFrames 연결 또는 기술 검사 PASS만으로 캐릭터 최종 승인에 포함하지 않았다. 기존 34종 승인 이력과 원장은 보존했다.

전용 연결 진입점은 `data/pr122_legendary_parallel_staging.json`이다. staging SHA256은 `cba956f72e441a282542e45f24d4c5ab299a54853657ea7e2e2a7df80efbcfca`, 활성 manifest는 `quality-v04/revision-library-ownership-through-batch001-v12.json`, SHA256은 `e26aa7d12d916f6164e71e48c523f0b2c5688efe026b3f0b89bc3b5fdfacd22b`이다. 각 record에는 ID·방향·동작·6프레임·원화 요청과 SHA·SpriteFrames·등록 좌표를 연결했다.

전체 초안 검토 원문 `whole-review-frozen-v01.json`과 `technical-single-review-v01.json`은 변경하지 않았다. 이후에는 새 교정 원화만 한 차례 검토하고 공통 원인별로 수정했다. 정상 클립을 다시 생성하지 않았다. 마지막 메타데이터 대조와 잔여 목록은 [remaining-findings-final-v06-KO.md](remaining-findings-final-v06-KO.md)를 따른다. 원문 [v05 JSON](remaining-findings-final-v05.json)과 초기 MD는 보존하고 표시 정정은 v06에서 설명한다. 작은 [972구성 TSV](remaining-findings-active-clips-final-v05.tsv)에서 severity·ID·방향·동작·원인을 바로 볼 수 있다.

최종 오류·불확실성 투영은 972구성이며 최고 severity는 ERROR380·HOLD591·BLOCKED1이다. 별도 QA 환경 HOLD2구성은 이 목록과 중복되므로 더하지 않는다. 이는 불량 원화 972개나 새 시각 관측 972개를 뜻하지 않는다. clipped_or_foreign_body338구성은 같은 원본113개와 lossless 파생225개의 frozen finding을 보수적으로 유지한 것으로, 수정 후 새 결함338개를 확인했다는 뜻이 아니다. 참조 source1,120파일도 불량 원화 수가 아니다. 정상 클립 재생성의 근거로 사용하지 않는다.

최종 대조의 전제 조건 실패2건은 native176의 후속 문서 커밋 연결과 원본/사본 texture 경로 별칭 처리였다. 원문 실패·이전 gate는 보존하고 해당 증거 및 metadata projector만 보완했다. 176의33클립/198프레임 metadata와 경계 fixture4개로 원본59자세 재사용 분류를 확인했다. 원화·record·region·margin·RGBA·anchor·실제 재생은 변경하지 않았으며, 최종 metadata 대조 완결은1회다.

신화급과 같은 소유 영역 분리 방식을 재사용했다. alpha>16 전경 RGBA를 원래 해상도로 정수 이동하고 여백을 추가했다. 원본 PNG는 불변이며 확대·재색칠·회전·자세 합성은 하지 않았다. 늘어난 atlas 여백으로 캐릭터가 작아지지 않도록 원래 가상 canvas를 유지했다. 113 W ATTACK은 부모 guard의 가상 canvas·원점·고정 배율을 그대로 상속하도록 고쳤다. 176번은 원화별 고정 배율과 검토한 지면 원점을 적용하고 원본 59자세를 보존했다.

소유 영역이 모호한 qc054·qc102는 강제로 분할하지 않았다. qc102의 카메라 수정과 소유권 HOLD는 별개다. qc122(112 N HIT)의 손·검 좌우 연결, 176 S DEATH의 중간 자세 연결, 나머지 카메라·외형·접지·동작 HOLD도 기술 PASS로 해제하지 않는다.

최초 실제 Godot 4.7.2/X11/OpenGL 검사는 전체 한 차례와 당시 캡처 누락 17개만의 후속 검사로 1,319 PASS·1 미생성을 기록했다(`final-runtime-integration-reconciled-v01.json`). 이후 변경·영향을 받는 98개만 한 차례 재생했으며 97 PASS·1 FAIL이다. 177 NW HIT는 초반 0~2프레임이 실시간 캡처에 남지 않았고 마지막 프레임 유지는 통과했다. 캡처/시간 지연을 의심하지만 원인은 확정하지 않았다. 같은 유형이 반복되어 추가 재시도와 원화 재생성을 하지 않았다. 원문 FAIL을 PASS로 바꾸지 않았다.

현재 활성 구성의 증거를 합치면 1,318 PASS·1 캡처 FAIL·1 미생성이다. 정상 1,221클립은 재생하지 않았다. 공통 player/library/capture 코드 네 파일도 CI 기준 a2db 이후 변경되지 않았다. 현재 결합 증거는 `final-runtime-integration-through-corrections-v02.json`, 새 실측 원문은 `final-correction-render-integration-v01.json`이다. 이전 402 E ATTACK의 phase2 캡처 제한과 새 177 NW HIT 제한은 서로 다른 QA 환경 HOLD로 보존한다.

전체 게임 CI의 [첫 실행](https://github.com/zoog136-hash/-/actions/runs/40009886980)은 import 900초 제한으로 중단돼 후속 232검사를 실행하지 못했다. 전설급 staging의 자동 import를 분리한 뒤 [두 번째 실행](https://github.com/zoog136-hash/-/actions/runs/40014699342)을 정확한 `a2dbbb01659e562980653c8d33898d3b7d761e58`에서 수행했다. import·boot는 통과했고 233개 중 216 PASS·12 FAIL·5 SKIP이다. 후속 floor-loot·combat·monster-crowd 세 단계는 앞 단계 실패로 건너뛰었다. 추가 전체 CI는 실행하지 않았다.

CI 실패 12개는 보존된 애니메이션 검사 3개(몬스터 사망·WALK·native 확장), 검사 선행 조건 2개(레지스터 상태·미지정 환경 변수), 출력 판정 계약 7개로 구분했다. PASS 출력만으로 실패를 통과 처리하지 않았다. 정확한 테스트명·원인·로그 SHA는 [ci-v02-failure-list-KO.md](ci-v02-failure-list-KO.md)와 `ci-v02-focused-failure-diagnosis-v01.json`에 있다. 원본 ZIP·summary·실패 로그 12개·검사 코드 참고본을 보존했다. 인증 만료 관찰 기록과 실제 CI 결론은 구분하며 최종 결론은 `final-github-ci-receipt-v02-completed-v01.json`을 따른다.

274 NE ATTACK은 최초 생성 도구 차단으로 미생성이며 반복 요청하지 않았다. 과거 quota 오류로 PNG가 없던 7개만 한도 초기화와 정상 경로 복구를 확인한 뒤 각 한 번씩 제한적으로 복구했다. 7개 모두 PNG를 저장했으며 과거 오류·claim은 덮어쓰지 않았다. 성공한 원화와 새로운 시각 HOLD는 다시 생성하지 않았다. 별도 유료 API와 지원하지 않는 reasoning 옵션은 사용하지 않았다.

전용 Godot 진입점은 `legendary_revision_library_v01.gd`와 `legendary_registered_clip_player_v01.gd/.tscn`이다. `configure(staging_path, manifest_path)` 뒤 `instantiate_clip(key, direction, role)`로 실제 Node2D/AnimatedSprite2D를 만든다. 사망은 한 번 재생한 뒤 마지막 프레임을 유지한다. `production_connected=false`이며 기존 Player/Main·전투 수치·타격 판정은 보존했다.

전용 staging의 `.gdignore`는 편집기 자동 production import를 분리한다. PNG와 TRES는 Git에 추적하고 독립 loader는 FileAccess/ImageTexture로 원문 PNG를 등록한 뒤 TRES를 명시적으로 로드한다. 현재 결과는 production native import/export 승인이 아니다. 신화급 완료 뒤 통합할 때 `.gdignore`를 제거하고 전체 native import 시간과 export 원화 포함 여부를 별도로 확인해야 한다.

최종 보존 검사 `final-protected-originals-integrity-v02.json`은 고정 커밋 0fe2882e에서 PASS다. 허용된 세 경로 밖 변경 0, 카탈로그와 원장 바이트 동일, 원본 723 atlas·41,442프레임·233,420,026바이트를 보존했다. 기존 WALK·다방향 DEATH·신화급·유일급·영웅급 원화·저장 데이터·드랍·인벤토리는 변경하지 않았다. PR 기준 조상은 `16bb178426134dbc5ffcc32306de0a2509352c8f`, 작업 중 읽기 전용으로 확인한 신화급 HEAD는 `0ea07931a63c215fdbd1110eadee92510d79fe71`이다.
