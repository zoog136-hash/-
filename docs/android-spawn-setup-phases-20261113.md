# 523.427 기기 기록 후속: 단일 setup 단계 계측

기준 main: `a9cdea9c29a2feacf83fbf47dff5b4b6cf22403e` (#446 병합). 별도 브랜치이며 퀘스트·거래소·캐릭터 생성은 수정하지 않는다.

## 확인한 증거와 한계

사용자 사진을 이 작업환경에 materialize하여 직접 확인했다. 화면 버전 523.427, 이전 실행 끊김 470회, 최대 한 프레임 14,526ms, 몬스터 배치 14,064ms, `spawn.total` 14,027ms×1, `spawn.setup` 13,944ms×1, `sp2.bank_load` 581ms×1, 그리기·엔진 213ms, 캐릭터 148ms다. 전체 프레임 → 배치 → spawn → setup → bank는 중첩 구간이므로 합산하지 않는다. 33%는 세 작업 중 하나 완료이며 시간 비율이 아니다.

사진 SHA-256: `1614f1057b1bd66d0daa1c807e05c20416bd9469a57f98a4fe86ff7d394a1be8`. 사진 자체나 원본 클라이언트 바이너리는 저장소에 추가하지 않았다.

#446 이후 main APK 작업 [43340241721](https://github.com/zoog136-hash/-/actions/runs/43340241721)이 성공했고, `playtest-latest`의 release target/본문에서 **523.428 / a9cdea9**를 확인했다. 사진의 523.427은 이 변경 전 화면이다. 다만 사진은 이전 실행 기록을 보여 주므로, 사진의 화면 버전만으로 이전 실행의 APK/마운트된 업데이트 팩 조합까지 확정할 수 없다. 새 기록에는 probe 시작 시 마운트된 `build_info.json`의 버전과 커밋을 남긴다. 여기서는 Android 기기 실행이나 13.9초 지연을 재현하지 못했다.

## 변경

- `Monster.setup`을 감싸 성공·거절 모두 마지막 단계까지 기록한다. reset, admission, binding, bound_admission, definition, projection, identity, legacy_view, current_view, actor_identity, loot_identity, stats_reset, boss_combat, overhead_ui, animation, presentation의 **한 setup 내 겹치지 않는 경계**를 기록한다.
- 100ms 이상 setup 중 프레임당 가장 느린 한 개만 `slow_spawn`에 보존한다. NPC/Sprite 숫자 ID, 성공 여부, 전체 usec와 단계별 usec만 갖고 전체 NPC 원문/이력/텍스처는 복제하지 않는다. 기존 최악 12프레임 제한을 유지한다. 로딩 안내에는 그 단일 NPC의 가장 느린 두 단계를 추가한다.
- view 선택, role 구성, 재생 트랙 구성, 노드 생성, context 복사, overlay binding, 자식 연결, 첫 프레임을 기존 inclusive `details`로 구분한다. 기존 SP2 파싱·픽셀 렌더·텍스처 생성 계측과 연결한다. `view.roles` 안의 bank/트랙/노드 시간과 부모 setup을 더하지 않는다. 텍스처 생성 API 시간은 GPU 완료 시간이 아니다.
- 보스 전투 설정에서 NPC ID 불일치, TestNPC 및 허용된 세 가지 일반 몬스터 전투 계약에 속하지 않는 비보스는 **catalog 접근 전에** 기존과 동일하게 거절한다. 이전에는 거절할 몬스터도 catalog 파일 해시·압축 해제·JSON 읽기를 먼저 할 수 있었다. 보스 및 세 가지 계약은 기존 원문/스프라이트/host adoption 검증을 계속 통과해야 한다. 풀 재사용 시 clear 순서도 유지한다.
- catalog 요청/hit/불필요 접근 생략 횟수와 검증·압축 해제·JSON 시간을 기록한다. 해당 catalog를 실제 필요로 하는 첫 보스의 비용은 남아 있다. 이것은 자료 접근을 피하는 자체 개선이며 사진의 13.9초 원인이라고 확정하지 않는다.

## 검증

공식 Godot 4.7.2, 분리된 XDG/스테이징에서 다음 검사를 실행했다.

- 새 단계 기록 12검사: 거절 경로, 단일 setup 시간과 단계 합 일치, 최장 하나만 유지, 프레임 초기화, 사진 문구, 내부 비용을 가리는 부모 항목 제외, 실행 버전, 파일 왕복 보존, 비활성 계측.
- 새 보스 catalog admission 13검사: 부적격 일반 몬스터 catalog 요청 0회, 세 가지 계약은 catalog/adoption 검증까지 도달, 보스 성공, Sprite 변경 거절, 재사용 상태 정리, 잘못된 ID/TestNPC 선거절. 합성 계약이며 원본 catalog 실행 증거가 아니다.
- 기존 hitch 26, prepared bank 161, SP2 렌더 2,775, NPC effect anchor 24검사 통과. 기존 보스 숫자 계약 errors=[]; 모든 실행에서 script/runtime 오류 없음.
- `check_no_legacy_resources.py --root .`: 추적 리소스 20개 통과. 규칙에 적힌 `tools/check_resource_integrity.py`는 기준 main에 없어 실행 불가이며, 현재 실제 resource CI를 별도로 확인한다.
- 새 두 검사를 필수 core gate에 추가했다. 실제 Main·저장 보존·원본 경로 및 resource CI의 최종 결과는 PR 검사에서 확인한다.

성능 향상 ms/배율, 원본 전체 통합, Android RAM 감소 또는 기기 종료 해결을 주장하지 않는다. 새로 강한 캐시를 추가하지 않았고, 원본 리소스/화질·플레이 규칙·저장 데이터는 변경하지 않았다. 단일 동기 setup은 여전히 프레임 예산을 초과할 수 있으며 이번 변경은 hard deadline/비동기 파싱을 제공하지 않는다.

## 다음 실기기 재현

1. 이 PR이 포함된 빌드를 설치/업데이트하고 표시 버전과 커밋을 기록한다. 523.428에는 #446만 들어 있고 이 PR 계측은 없다.
2. 기존 저장/설치 팩을 삭제하지 않고 같은 맵에 진입한다. 첫 진입, 같은 종 반복 배치, 재진입을 구분한다. 의도적인 cold cache 삭제는 하지 않는다.
3. `FRAME_HITCH` logcat 또는 `user://frame_hitch.json`을 보존한다. 앱을 다시 열면 이전 실행은 `frame_hitch.prev.json`이며 다음 로딩 사진에서도 단일 NPC/상위 두 단계가 표시된다. 지원되는 Android debug 실행이라면 `adb logcat -v threadtime`에서 `FRAME_HITCH`를 수집할 수 있다.
4. 기록의 `build`, `map`, `frame`, `slow_spawn`을 먼저 비교한다. `phases_usec`는 해당 한 setup의 비용이다. `details`와 cache hit/miss counters는 같은 프레임의 여러 호출을 합산할 수 있으므로 호출 수를 함께 본다. `current_view`가 크면 view selection/roles/playback_tracks/source_nodes/first_frame 및 SP2 세부 비용으로 좁힌다.
5. 단일 setup의 느린 경계와 재현된 원본 입력을 확인한 뒤 그 작업을 분할/사전 준비한다. 계측만으로 아직 확인되지 않은 13.9초 원인을 추정해 콘텐츠를 제거하지 않는다.

## 원본 및 참고 클라이언트와의 구분

기존에 확인한 Android 1.10.18a 텍스처 cache hit/비동기 이미지 queue와 Windows P10의 raw/graphics cache hit 및 placement queue 보고서는 **정적 분석**이다. XP Hero 27.0.0 변조 APK는 실행하지 않았으며 IL2CPP metadata의 pool/cache/async/release 선언만 구조 근거다. 이들은 불필요한 로딩과 소유권을 분리해 조사하는 참고이며 이번 admission 선거절이나 Godot 단계별 계측이 원본과 동일한 구현임을 증명하지 않는다. 원본 실행 성능 수치로 전용하지 않는다.

#442 optional-role/spawn budget, #444 cold parse, 별도 초기 로딩 및 퀘스트 작업을 임의로 통합하지 않았다. #442 통합 시 #446의 optional-cohort cache isolation 패치 필요성은 기존 문서를 따른다.
