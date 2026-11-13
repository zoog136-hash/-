# Source view 반복 작업 감소

기준 main `fb81d7e01258477aca9a54fc0abd79bcaef44af6` (#450 포함). 별도 `feature/android-source-view-work-20261113` 브랜치다. 퀘스트·거래소·캐릭터 생성 및 미병합 #442/#444/#447 변경은 포함하지 않는다.

## 변경과 보존 조건

1. NPC의 기존 immutable prepared snapshot에 노드 구성 정보만 저장한다. 모든 role/direction/frame을 훑어 최대 body layer 수와 effect identity별 첫 등장 descriptor를 계산하던 일을 snapshot당 한 번 수행한다. live snapshot hit에서는 프레임 순회가 없다. 기존 weak index를 사용하며 별도 전역 strong cache는 없다. 마지막 소유자가 해제되면 구성 정보도 소멸한다.
2. Sprite2D, 재질, 재생 clock, strict/compatible 정책과 Girtas 조건은 각 view에서 계속 구성한다. 동일 physical ID의 첫 등장 규칙, explicit source instance ID, 그리기 순서를 보존한다. loaded bank 결과의 구조/바이트와 mutable 호출 경로는 유지한다. 바뀐 manifest는 새 snapshot과 새 구성을 사용한다.
3. 이미 로컬 텍스처를 가진 visible effect의 같은 프레임 내 중복 `render_layer` 검증을 2회에서 1회로 줄인다. 새 텍스처 경로는 기존 2회를 유지한다. 첫 검증이 parsed member key를 준비하여 다른 view의 공유 텍스처를 재사용할 수 있기 때문이다. 숨김·미해결·누락 node도 계속 검증하며, 파일 변경/삭제는 cold/warm 모두 거부한다. 변경 파일 재검증 정책을 완화하지 않는다.
4. `Current523SourceBankView.advance`는 attack일 때만 공격 완료 판단용 duration을 계산한다. idle/walk/run/hit/death에서 버리던 전체 프레임 순회를 생략한다. 실제 preview의 재생 clock 계산과 공격 종료 경계는 유지한다.

원본 리소스, 화질, 배치 수, 진행/저장 데이터는 변경하지 않는다. 구성 정보는 이미 snapshot이 보유한 immutable descriptor를 참조한다. 추가 메모리는 고유 effect 수에 비례하는 작은 참조 목록이며, 전체 RAM 감소량을 주장하지 않는다.

## 합성 측정

공식 Godot 4.7.2, Linux headless, 5 role × 8 direction × 128 token의 **직접 만든** action 입력 및 작은 SP2 3개를 사용했다. 5회 각각 첫 view와 snapshot을 공유하는 후속 view 두 개를 구성했다. 후속 표본은 10개이며, 아래는 호출 경계에서 잰 중앙값이다.

| 구간 | 기준 main | 변경 후 |
| --- | ---: | ---: |
| 후속 view 전체 configure | 17.122ms | 9.156ms |
| 그중 노드 구성 구간 | 8.167ms | 0.110ms |
| 첫 view 전체 configure | 475.920ms | 472.030ms |

실행 순서를 바꾼 별도 반복에서도 후속 configure 중앙값은 18.057ms → 9.162ms였고 결과 hash/signature는 모두 같았다. 첫 구성 시간은 유의미한 개선으로 해석하지 않는다. 새 구성 정보의 후속 frame scan은 10개 표본 모두 0이었다. 모든 표본에서 playback track 직렬화 SHA-256과 노드 구성 signature가 기준과 같았다. 이 수치는 Android, 원본 데이터, disk-cold 로딩, 전체 Monster.setup, FPS 또는 사진의 13.944초에 대한 실측이 아니다. OS/CPU 상태에 따라 시간은 달라질 수 있으며, CI에 속도 임계값을 두지 않는다.

재현 스크립트: `tools/benchmarks/benchmark_source_view_layout.gd`. 기존 `tests/benchmark_reference_sp2_attributes.gd` fixture를 사용한다. 각 revision을 분리된 프로젝트 및 XDG_DATA_HOME/XDG_CONFIG_HOME/XDG_CACHE_HOME에서 실행하고 `--output=<별도 JSON 경로>`를 전달한다. 사용자 저장/설치 팩을 지우거나 같은 user://에서 측정하지 않는다.

## 검증

- 신규 layout 회귀 60개: 노드 순서·instance identity·최초 스타일, strict/compatible/Girtas 행렬, 결과 바이트, last-owner 해제, manifest 변경 후 새 구성.
- 신규 effect/clock 회귀 131개: cold 2회/warm 1회, 숨김·누락 node, 파일 변경/삭제, unknown parsed key를 가진 새 bank에서 공유 텍스처 재사용(추가 pixel decode/upload 없음), 예산 거부, nonreference PNG, 공격 종료 경계·인스턴스 독립성.
- 기존 prepared bank 161, identity 31, projection 21, sharing 62, Girtas guard 28, compositor 22,620검사 통과. script/runtime 오류 없음. 새 두 검사를 필수 core gate에 포함했다. 최종 원격 core·리소스·OpenGL 결과는 PR의 해당 head 검사를 따른다.
- `check_no_legacy_resources.py --root .`: 추적 리소스 20개 통과. 규칙에 남아 있는 `tools/check_resource_integrity.py`는 현재 main에 없으며, 현행 리소스 CI를 사용한다.

## 원본 비교 및 남은 병목

기존 Android/Windows 정적 보고서의 cache hit 재사용과 소유권 분리, XP Hero IL2CPP의 pool/cache 선언은 반복 준비를 조사한 참고다. 이번 Godot 구성 정보 메모와 검증 통합은 자체 구현이며 원본 함수 몸체의 동일 구현이나 실행 성능 증명이 아니다. XP Hero 변조 APK는 실행하지 않았다.

첫 metadata validation, parse, track timing 구성 및 첫 pixel decode/upload는 여전히 동기 작업이다. 이번 변경은 단일 setup의 최대 프레임 시간이나 13.9초 지연 해결을 보장하지 않는다. #450의 setup 단계·NPC ID·build 기록으로 실제 기기 cold/warm 비용을 구분해야 한다. 보이지 않는 리소스를 삭제하거나 강제로 품질을 낮추는 조치는 하지 않았다.
