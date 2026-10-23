# 전설급 병렬 제작 인계

전용 브랜치: `feature/pr122-legendary-parallel-20261023`.
PR #122 기준 조상은 `16bb178426134dbc5ffcc32306de0a2509352c8f`이며, 읽기 전용으로 확인한 신화급 HEAD는 `0ea07931a63c215fdbd1110eadee92510d79fe71`이다. 신화급 브랜치에는 쓰지 않았고 새 PR·병합·rebase·force push는 수행하지 않았다. 신화급 완료 뒤 통합한다는 기존 지시를 유지한다.

|제작 단위|저장된 상태|
|---|---|
|카탈로그 대상|전설급 40종|
|방향별 동작|1,319/1,320 구성, 7,914 자세|
|초안 신규 자세|6,953|
|초안 재사용 자세|원본 59 + 이전 초안 902|
|확정 오류 원화의 추가 교정|13 PNG, 신규 78 자세; 기존 구성을 대체하므로 구성 수에 더하지 않음|
|겹침 소유 영역 분리|기존 확정 622 + 도구 한도로 교정하지 못한 기존 원화 중 안전 58 + 새 교정 원화 2 = 682 원화|
|최종 활성 수정 연결|776 구성, 나머지 기존 구성은 원래 record를 연결|
|새 최종 승인|0; 기술 검사 PASS와 시각 품질 승인을 구분|

PNG 원본과 기존 SpriteFrames/record는 보존했다. 겹침 수정은 alpha>16 전경 RGBA를 정수 이동해 분리한 파생 atlas이며 자세 생성·resampling·recoloring을 하지 않았다. 모호한 소유 영역과 실제 원화 잘림은 임의 분할하지 않고 HOLD로 남겼다. 기존 WALK·다방향 DEATH·기존 승인 원장·카탈로그·저장 데이터·전투 수치는 변경하지 않았다.

실제 자산 및 런타임 입력 고정 커밋은 `d8aefaeb3c47c211fa66d76d1950cbda3130ba1b`이다. 이후 `992d9b12b648cdd6168361c79a7f4b95335ed023`는 증거와 검사 코드만 저장했다.

전용 연결 진입점은 `data/pr122_legendary_parallel_staging.json`이다. `corrections.active_revision_library`는 `revision-library-ownership-delta-through-batch013-v01.json`을 가리킨다. manifest SHA256은 `05dc2159db8cea02e4c9bdfe860eea62757db4b186281db06feb998756acfa9c`, staging SHA256은 `1d64457811204c04f2ab9014b74d46158774fede412ebaf0199f1ec18c05f32b`이다. 각 활성 record에는 원화 SHA, 6개 프레임, 방향·동작·ID, SpriteFrames, 등록 좌표 및 원본 증거가 연결된다.

독립 Godot 런타임은 같은 문서 경로의 `legendary_revision_library_v01.gd`와 `legendary_registered_clip_player_v01.gd/.tscn`이다. library의 `configure(staging_path, manifest_path)` 뒤 `instantiate_clip(key, direction, role)`로 실제 Node2D/AnimatedSprite2D를 만든다. PNG·record·등록 metadata SHA와 의존 연결을 검증하며, 사망은 한 번 재생한 뒤 마지막 프레임을 유지한다. 기존 Player/Main 연결은 보존했고 전용 staging에서 검사했다. 실제 게임 연결과 PR #122 통합 시 이 차이를 유지해야 한다.

전용 staging 폴더의 `.gdignore`는 편집기의 자동 production import를 분리한다. 모든 PNG와 TRES는 Git에 그대로 추적하며, 독립 loader는 FileAccess로 PNG 원문을 읽고 ImageTexture를 등록한 뒤 TRES를 명시적으로 로드한다. 새 PNG import sidecar가 없는 상태에서도 native/hybrid·격리 mixed·교정·fallback 네 종류의 실제 로더가 정상 작동했다. 신화급 완료 뒤 게임에 통합할 때 이 `.gdignore`를 제거하고, 전체 native import에 충분한 시간을 배정한 뒤 export에 원화가 포함되는지 별도로 검증해야 한다. 현재 검증을 production native import/export 승인으로 계산하지 않는다.

정수 분리로 늘어난 padding을 캐릭터 축소 기준으로 쓰지 않는다. 원래 가상 canvas에 대한 기존 ActorMotion 정규화를 유지한다. 176번은 별도로 검토한 원화별 고정 배율과 투영 지면 원점을 사용하며, 원본 59자세를 보존한다. S DEATH의 마지막 누운 자세 유지와 중간 동작 연결 HOLD는 별개다.

최종 실제 Godot 4.7.2/OpenGL 통합 재생은 전체 1회와 캡처 누락 17구성만의 한 차례 후속 검사로 마쳤다. 결과는 1,319 PASS, 기존 미생성 1, 기술 FAIL 0이다. 첫 검사 통과 1,302구성은 재검사하지 않았다. 초기 GPU/캡처 지연과 후속 검사 원문은 각각 보존했다. 실제 캡처 PNG는 로컬 증거 경로에 있으며 JSON에 SHA를 기록했다.

전체 게임 CI의 [첫 실행](https://github.com/zoog136-hash/-/actions/runs/40009886980)은 정확한 `992d9b12b648cdd6168361c79a7f4b95335ed023`에서 import 900초 제한으로 중단됐고, 후속 232검사는 실행하지 않았다. 원문 artifact와 `ci-v01-import-timeout-diagnosis.json`을 보존했다. staging 자동 import 분리 후 기존 `twilight-integration-validate.yml`을 한 차례만 다시 실행하며, 최신 정확한 HEAD·실행 URL·결론은 `final-github-ci-receipt-v02.json`을 따른다. 같은 제한이 다시 발생하면 추가 반복하지 않는다. 기술 재생 증거는 `final-runtime-integration-reconciled-v01.json`, 보존 검사는 `final-protected-originals-integrity-v01.json`이다.

자동 import 분리의 영향 검사에서 네 구성 모두 원문 SHA·6개 SpriteFrames 항목·실제 texture draw·loop/once 동작을 로드했다. 정상 속도 캡처는 3 PASS, 402 E ATTACK의 phase2 snapshot 누락은 검사 환경 HOLD로 보존했다. 같은 캡처 지연이 재발해 추가 시도하지 않았다. 이는 원화 미생성이나 source 로드 실패와 구분한다(`staging-import-exclusion-validation-v01.json`).

원인별 잔여 목록은 `remaining-findings-final-v02-KO.md`와 JSON을 따른다. 역사 원본 발견과 현재 활성 원화/record를 구분하며 카메라·무기/외형·동작 연결·접지 HOLD를 기술 PASS로 해제하지 않는다. 274 NE ATTACK은 최초 원화 생성 차단으로 미생성이다. 교정 도구 한도의 7개 실패와 106개 미호출은 이미 존재하는 초안의 교정 대기이며 미생성 구성 수에 더하지 않는다. 같은 실패를 반복 호출하거나 정상 클립을 다시 만들지 않았다.
