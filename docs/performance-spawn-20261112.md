# 몬스터 준비와 반복 HUD 작업 — 2026-11-12

기준은 최신 main `28f3084a903d1cff4dbbd45c3a1ca5a0ed0a52a2`다. 별도 브랜치 `feature/android-spawn-budget-20261112`에서 작업했다. 거래소·캐릭터 생성·종료 문제는 범위 밖이다. 원본 파일, 게임 수치·배치·세이브, 픽셀·렌더 순서를 변경하지 않았다. #440의 Android UI 혼합 수정도 유지한다.

## 확인한 경로와 변경

사진의 523.384 **1303회**는 이전 실행에서 100ms 이상 걸린 프레임 수다. **12749ms**는 그 실행의 최악 한 프레임이며, **몬스터 배치 12432ms / 캐릭터 141ms / 맵 오브젝트 82ms**는 그 프레임의 구간이다. 현재 로딩 시간이나 서로 다른 프레임의 최근값 합이 아니다. 이전 캐시 개선만으로 이 과거 기록의 해결을 확정할 수 없다.

현재 `monster.setup`은 풀 재사용 때에도 기존 source view를 해제하고 `configure_admitted`를 동기 실행한다. preview는 선택 RUN/HIT를 각각 `load_bank`로 준비한 뒤 전체 bank에서 다시 준비했다. raw parse와 texture가 공유되어도 JSON·방향·프레임·레이어 검증과 track 확장은 반복된다. 이 중복은 코드와 실행 카운터로 확인했다. 사진의 12.432초 중 이 중복이 차지한 비율은 확인하지 못했다.

- **선택 액션:** 정확한 optional actor/action 인덱스 항목이 있는 경우 기존 pinned loader로 전체 bank를 한 번 시도한다. 성공하면 같은 결과를 사용한다. 항목 누락·불안전 경로는 바로 기존 독립 검증으로 간다. 결합 검증 실패도 기존 fallback을 실행하여 HIT 불가 시 RUN을 보존한다. 모든 manifest/action/member SHA·CRC·consumer·role actor·loop·dummy 제외 검증은 유지한다. 전역 track 캐시나 인스턴스 재생 상태 공유는 추가하지 않는다. 존재하지만 손상된 optional JSON은 결합 실패 한 번이 추가될 수 있다.
- **CRC:** received-member 검증의 IEEE CRC32를 slicing-by-8로 계산한다. 입력 전 바이트와 receipt 도메인은 그대로다. 고정 packed table 16KiB를 사용하며 입력은 보관하지 않는다. CRC 계산 변경은 메모리 감소 주장이 아니다.
- **현재 source 배치:** 기존 프레임당 2개 제한에 누적 setup 시간 4ms 제한을 함께 적용한다. 앞선 setup이 예산을 쓰면 두 번째 작업을 기존 짧은 retry로 연기한다. generic initial queue의 3개/4ms 정책과 구분한다. 현재 source region은 보통 그 initial queue 조건에 들어가지 않는다. **한 개의 동기 cold setup을 선점하거나 4ms 이내로 보장하지는 못한다.** 비동기 완료 작업을 추가하지 않아 새 generation·map 취소 경로도 없다.
- **퀵슬롯:** 한 번의 동기 refresh/stage 안에서 확보한 detached snapshot을 10칸/두 그룹에 전달한다. refresh의 snapshot은 11회에서 1회가 된다. 다음 refresh, 단독 slot 갱신, 클릭의 presented identity·페이지 검증은 최신 값을 다시 읽는다. 원본 카운트 해석기·SourceText·렌더러는 유지한다.

## 하위 계측

`frame_hitch.json`에 기존 section과 별도로 다음 inclusive detail을 기록한다.

| 경로 | detail / counter |
|---|---|
| 몬스터 | `spawn.total`, `spawn.setup`, `spawn.source_project`, `spawn.source_visual` |
| 액션 준비 | `source.role_selection`, `source.bank_configure`, `source.optional_probe`, `source.optional_combined_attempt` |
| 원본 확인 | `sp2.member_read_verify`, `sp2.member_read`, `sp2.member_sha256`, `sp2.member_crc32`, `sp2.member_file_read` |
| parse | `sp2.parse`, `sp2.parse_identity_sha256`, `sp2.parse_cache_read`, `sp2.structure_parse`, `sp2.parse_cache_write`, `sp2.shared_parse_hit/miss`, 기존 `sp2.disk_hit/miss/reject` |
| 픽셀·생성 | `sp2.pixel_decode`, 기존 `sp2.texture_create`, `sp2.texture_created` |

detail 행은 `[이름, 프레임 합계 ms, 호출 수, 한 호출 최대 ms]`다. 부모 detail·section과 중첩되므로 합산하면 안 된다. `texture_create`는 API 경과시간이며 GPU 완료 fence가 아니다. 파일 읽기·검증·cold 구조 파싱과 warm 재사용을 구분할 수 있지만, 기기 로그가 없는 이번 결과가 과거 프레임의 원인을 재현한 것은 아니다.

## 결과와 재현

공식 Linux Godot `4.7.2.stable.official.ed1daf0bf`, 격리 XDG 프로필을 사용했다. 아래 시간은 CPU 합성 microbenchmark이며 Android FPS·전체 spawn·RAM 수치가 아니다. 원본 아트와 실제 GPU draw를 대신 검증하지 않는다.

| 작업 | 전 → 후 | 범위 |
|---|---|---|
| NPC 형태(5 core + RUN)/8방향/32토큰 | bank 2 → 1회, 레이어 5376 → 4608회; 중앙값 255.267 → 235.806ms | tiny invented SP2/action, warm metadata |
| 4 core + RUN/HIT/8방향/32토큰 | bank 3 → 1회, 레이어 6144 → 4608회 | tiny invented SP2/action, warm metadata |
| HIT 인덱스 누락 | bank 3 → 3회, 레이어 4608 → 4608회; 중앙값 223.659 → 239.827ms | 선행 전체 확장 없음; lookup/잡음 포함 |
| 존재하지만 손상된 HIT | bank 3 → 4회, 레이어 4611 → 8454회; 중앙값 253.992 → 425.261ms | 추가 결합 실패 비용; 결과 동일 |
| 833000 bytes CRC | 중앙값 33.585 → 27.333ms | 같은 binary 입력, 번갈아 9회 |
| 2097152 bytes CRC | 중앙값 87.136 → 72.904ms | 같은 binary 입력, 번갈아 9회 |
| 10탄약 스킬 퀵슬롯 refresh | 평균 2.123 → 0.399ms | 200회, 실제 SourceText/Noto setter, draw 제외 |
| 같은 퀵슬롯 작업량 | snapshot 2200 → 200회; ammo/index 22000 → 2000회 | 표시 digest·4000 setter 동일 |

액션 시간은 번갈아 3회 warm sample의 중앙값이며 전체 core 검사가 병행 중이었다. NPC와 2 optional 스트레스 사례를 구분한다. 위 숫자를 기기 지연 감소의 보장으로 사용하지 않는다. 원시 카운터·samples·source SHA는 [기계 판독 증거](performance-spawn-20261112-evidence.json)에 보존했다.

회귀: CRC 독립 Python zlib oracle 149검사, 배치 예산 8검사, 퀵슬롯 35검사, optional 선택·상태·tracks·모든 역할/방향 픽셀·손상 거부·같은 owner 재설정 106검사. 기존 공유 lease·parse cache·frame hitch·bank memo 검사도 통과했다. Astra 독립 설계 검토에서 고우선 필수 수정은 발견되지 않았으며, 추가 무작위 CRC 139건도 일치했다(이 보조 실행은 Godot 4.6.3이므로 공식 4.7.2 검사를 대체하지 않는다).

전체 transition gate와 원격 CI 결과는 PR에 최종 기록한다. 현행 resource checker는 `NO_LEGACY_RESOURCES ok tracked=20`이다. AGENTS가 명시한 옛 `tools/check_resource_integrity.py`는 현재 저장소에 없어 실행이 exit 2로 끝났다. 이를 성공으로 세지 않았으며 현행 checker와 두 필수 CI를 사용한다. 새 아트·비공개 APK·복호 키는 커밋하지 않는다.

```sh
# 공식 4.7.2를 지정하고 별도 XDG 디렉터리를 사용한다.
godot --headless --path <stage> --script res://tests/reference_sp2_optional_roles_test.gd
godot --headless --path <stage> --script res://tests/source_crc32_test.gd
godot --headless --path <stage> --script res://tests/benchmark_source_crc32.gd
godot --headless --path <stage> --script res://tests/current523_population_budget_test.gd
godot --headless --path <stage> --script res://tests/original_ui_quickslot_snapshot_test.gd
# 선택 액션/퀵슬롯 비교의 baseline 지정은 각 benchmark 파일 주석 참조.
```

## 남은 확인

첫 manifest bake, 단일 cold parse/pixel decode/upload, 재사용 monster의 view 재생성, 각 drawn layer의 metadata/file stat 확인, 변신 대량 카드·가방 재stage·퀘스트 scene 반복 읽기는 남는다. 현재 hot path라는 정적 후보와 Android 지배 비용이라는 실측은 구분한다. 원본 identity·저장·활성 owner를 무너뜨리는 캐시 생략이나 풀 확장은 적용하지 않았다.

기기에서 같은 APK/팩/세이브 복사본으로 첫 입장과 동일 종 재진입, 맵 전환·재소환·보스, 정지 상태, 가방·변신·퀘스트를 비교해야 한다. `frame_hitch`의 새 details/counters와 실제 RSS/GPU 메모리를 함께 수집해야 전체 체감·메모리 개선을 확정할 수 있다. 이 환경의 core map input은 의도된 `old_map_pack_removed` 0-file 경로이므로 실제 비공개 source terrain 순회나 Android 기기 시험을 주장하지 않는다.

원본 Android/Windows 보고서와 직접 읽은 XP Hero IL2CPP 근거는 [정적 비교](performance-spawn-source-comparison-20261112.md)에 분리했다. XP Hero 변조 APK는 설치·실행하지 않았다. 메타데이터의 pool·async·LRU 선언을 함수 본문·스케줄·실측 속도로 해석하지 않는다.

동시 open PR #436은 이전 끊김 요약/SourcePack bake key, #441은 splash/완료 후 타이틀 입력을 변경한다. 둘은 이 브랜치에 합치지 않았고 해당 파일도 변경하지 않았다. 이 PR은 별도 검토 대상이며 병합하지 않는다.
