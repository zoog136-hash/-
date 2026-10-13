# TWILIGHT 실제 게임 수정 및 검증 결과 — 2026-10-13

기존 Main 게임의 전투·월드·HUD 경로를 수정한 중간 납품이다. 전체 리메이크와 사용자 시각 승인은 완료되지 않았다. 현재 열린 초안 [PR #98](https://github.com/zoog136-hash/-/pull/98)을 유지하며 main에 병합하지 않았다.

## 보존된 작업과 변경

- 브랜치: `feature/twilight-remake-20261013`.
- 작업 기준 main: `434b904d957fd2146b6d2e73325693a402028035` — 작업 시작 시 remote에서 직접 확인.
- 마지막 런타임 변경: `c79955089704f59edfb01d86a2e0daf128fffb2e`; 후속 테스트 변경: `c5e8783ce18592c566ce86f85cafde888bd1013c`.
- 기존 PR #96/#97, 다른 브랜치, 미커밋 파일을 보존했다. 선택한 기존 개선은 출처 커밋을 기록해 재사용했다. reset/force push/파일 삭제/PR 병합을 하지 않았다.
- Godot 4.7.2, Compatibility, 기존 2D 사선 시점과 로컬 저장 구조 유지. Daybreak를 사용하지 않았다.

실제 변경 파일과 목적:

| 경로 | 변경 |
|---|---|
| `scripts/animation/actor_motion.gd`, `scripts/player.gd`, `scripts/monster.gd` | 큰 delta에서도 타격 포즈와 이벤트 유지, 콜백 도중 취소/사망 대응, 상태이상 공격 취소 |
| `scripts/monsters/boss_director.gd`, `boss_geometry.gd` | 예고 시작 시 피해 범위를 고정하고 같은 기하/시계를 사용, 사망 중단과 상태 복원 |
| `scripts/world.gd`, `scripts/skills/skill_service.gd` | 공격/투사체의 개체 수명과 사이클 검증, 중복 피해·보상 방지, 자기 주변 스킬을 실제 strike 신호로 연결, 시전속도는 쿨타임에 적용 |
| `scripts/animation/combat_flights.gd`, `combat_vfx.gd` | 지연 해제 후 남은 시간만 비행, 표시에 따른 효과 예산, 원본 프레임 duration으로 사망 표시, 모션 감소 |
| `scripts/maps/field_renderer.gd`, `field_population.gd` | 발 주변 지붕/수관 가림 완화, 높은 구조물의 표시 유지, 살아 있는 스폰 슬롯/보스 중복 방지 |
| `scripts/ui/renewal_hud.gd`, 설정/스킬/아이템 표시 코드 | 실제 UI 입력 차단, 표시 설정을 월드에 반영, 숨은 연출 정지, 등급 연출, 세 개 로컬 물약 아이콘 복원 |
| `addons/twilight_l1j/*`, `scripts/loot/ground_loot_manager.gd` | 출처 ID와 이름이 일치하는 아이콘 선택, UI 도감/바닥 이미지 우선순위 분리 |
| `tools/test_project*.py`, 새 Godot 회귀시험 | 실제 import/boot/render 검사, 오류 로그/JSON 검증, 수정 경로의 회귀 검사 |
| `data/resource_delivery_ledger.json`, `tools/remake_resource_audit.py` | 기존 단일 장부에 현재 ID별 로드·대체·픽셀/해시·부족 상태 기록 |
| `docs/.gdignore`, `export_presets.cfg` | 연구 영상/도구/문서가 게임 임포트·실행 패키지에 들어가지 않도록 제외 |

이동·수동전투·AUTO·바닥 드랍·수동/AUTO 습득·인벤토리·장비·강화·소모품·변신·인형·성물·상점·저장 경로를 유지했다. 기존 DB의 스탯·드랍률·성장값은 변경하지 않았다. PvP/혈맹/거래/파티/채팅/퀘스트 및 변신 전용 액티브를 추가하지 않았다. 인형·성물 등 미구현 옵션의 완료 표시를 바꾸지 않았다.

## 전수 연결 결과와 원본 부족

ID별 상세 상태의 단일 기준은 [기존 장부](../../data/resource_delivery_ledger.json)의 `current_id_audit`이다. 아래 로드는 정적/프로시저/제한 모션 대체가 있는 경우도 포함한다. 표의 수치는 원본 모션 보유율이나 전수 시각 통과율을 뜻하지 않는다.

| 구분 | 실제 런타임 등록 | 유효 로드/대체 | 맵 스폰에서 참조 | 전용 원본 연속 모션 검증 |
|---|---:|---:|---:|---:|
| 클래스 | 13 | 13 | 해당 없음 | 0 |
| 변신 | 413 | 413 | 해당 없음 | 0 |
| 인형 | 166 | 166 | 해당 없음 | 0 |
| 성물 | 144 | 144 | 해당 없음 | 0 |
| 일반 몬스터 | 258 | 258 | 149 | 0 |
| 보스 | 60 | 60 | 28 | 0 |
| 맵 | 25 | 25 | 25 진입 경로 검사 | 해당 없음 |
| 통합 아이템 | 2,576 | 2,576 | 해당 없음 | 해당 없음 |
| 효과 | 125 | 125 | 해당 없음 | 별도 원본 효과 검증 미완료 |

아이템은 도감2,129 + 호환 조회487을 합친 런타임 기준이며 원시 DB485와 다르다. 고유 스폰 참조177, 슬롯 용량1,196은 종수/동시 출현 수가 아니다. 등록318 몬스터·보스 중 스폰 참조는177이다. 미확인 스폰 이름과 유효 표시 경로 누락은0이다.

현재 사용되는 생성 아틀라스723개/6,907트랙/41,442셀은 원본 연속 모션으로 집계하지 않았다. 변신은78개4방향/335개1방향, 인형은59개4방향/107개1방향, 성물은144개1방향 선언이다. 이는 원본 방향 검증이 아니다. 공통 재생기의8방향 입력/대체 지원과 전용8방향 원본 보유를 구분했다. 아틀라스의 합산 트랙별 고유 픽셀 수38,714 역시 원본 모션 증거가 아니다.

아이콘 선택은 도감ID2,129, 기존 L1J 후보10, 자체 계열 기호434, 세 개 로컬 물약 이미지3이다. 픽셀 중복578그룹은 자동으로 오류/독립 원본으로 판정하지 않았다. 전체 아이콘의 식별·등급·이름 시각 평가는 미완료다.

## 실제 게임 화면과 전투 증거

[변경 전 영상](evidence/production-play/baseline/production-play.mp4) / [변경 후 영상](evidence/production-play/feature/production-play.mp4) / [검사와 SHA256](evidence/production-play/verification.json).

두 영상은 기존 Main, 기본 기사/황금기사 변신, 실제 아덴 드레이크 스폰을 사용한다. 1280×720,30fps 기록, 각601프레임/20.033초/34개 assertion 통과. 실제8방향 입력, 자연스러운 보스 예고와 피격, 수동3회+AUTO9회 사이클, 실제520HP 처치, 자연 발생한 바닥 물약·동 광석, 수동 물약 습득14→15와 AUTO 광석 습득이 연결된다. 피해·드랍·스탯을 검사에서 강제하지 않았다. 품질 검사 용도로 다른136개체와 인구 갱신을 멈췄고 고정 seed/시작 위치를 사용했다. 보스 AI는 계속 실행돼 첫 피격/예고가 이동 후반과 겹친다.

기록의 변경 후 런타임은 `b81c8f1`이다. 당시 물약 아이콘이 대체 기호로 나타난 문제를 숨기지 않았다. 후속 `c799550`에서 실제 세 개 아이콘을 복원했고 [최종 실제 HUD](evidence/final-potion-hud.png)에서 확인했다. 기록에는 자연 레벨업35→36으로 열린 성장 패널이 습득 UI를 가리는 기존 문제와 큰 중복 보스/타깃 바도 남아 있다. 녹화는 동시 소프트웨어 렌더 환경이므로 성능 측정으로 사용하지 않았다.

선별한 전후 화면2개씩과 전체 동영상/사건 JSON은 Git에 전달한다. 나머지18개 PNG는 작업 환경에만 보관돼 영구 전달되지 않았다. 원본22프레임의 전체 해시 목록은 검증 JSON에 남아 있다.

| 평가 | 결과 | 근거/한계 |
|---|---|---|
| 몸·발·무기 정렬 | 미검증 | 표본 플레이는 확인했으나 모든 원본 오프셋/방향/레이어 전수 검사가 불가능 |
| 동작 식별 | 실패 | 기존 제한/생성 모션 유지; 전용8방향 연속 원본 부족 |
| 타격 동기 | 표본 통과, 전수 미검증 | 사이클/저FPS/중복/인터럽트 회귀와 실제 드레이크11회 피해 확인; 모든 공격 방식 시각 접촉 미검증 |
| 지형 가독성 | 실패 | 수관/지붕 가림 코드 검사는 통과; 전수 미술/전경 이동 시각 품질 미완료 |
| 보스 회피 가능성 | 미검증 |60보스 기하/시계693검사; 모든 보스의 실제 회피·돌진·플레이어 사망 녹화 미완료 |
| UI 조작 | 실패 | 입력399, 설정29, 실제 물약17검사 통과; 성장 패널/보스 바 가림 남음 |
| 성능 | 실패 | 단일 비교에서 전투 프레임/메모리 개선 미달; 아래 실측 |

## 실행한 시험과 실패 구분

환경: Linux x86_64, 공식 Godot4.7.2, Compatibility OpenGL, Mesa25.0.7 llvmpipe LLVM19.1.7, Xvfb. 모든 사용자 데이터 경로는 격리했다. 실제 사용자 세이브를 수정하지 않았다.

실행 명령의 주요 형태:

```sh
python3 tools/check_resource_integrity.py --root .
python3 tools/remake_resource_audit.py --root . --godot /path/to/Godot4.7.2 --reference-dir /workspace/research
python3 tools/test_project.py --godot /path/to/Godot4.7.2 --logs /workspace/evidence/feature/full-suite --timeout 150 --import-timeout 180
Godot4.7.2 --headless --path /workspace/twilight-clean --import
Godot4.7.2 --headless --path /workspace/twilight-clean --quit-after 60
Godot4.7.2 --headless --path /workspace/twilight-clean --script res://tests/remake_world_lifecycle_test.gd
```

원래 기준선 실행은 시간 기록 wrapper와900초 import 예산을 사용했다. 렌더가 필요한 시험은 실제 X 디스플레이에서 실행했다. 기준선 첫 import는 sandbox 설정/소켓 오류가 있어 실패 기록을 보존했고, 지원되는 네트워크/쓰기 가능한 XDG 환경에서 다시 실행한 warm import는 통과했다. 전체 시험은 그 이후 각 checkout에서 한 번씩 실행했다.

| 범위 | 통과 | 실패 | 건너뜀 |
|---|---:|---:|---:|
| 기준 main 전체139검사 |122|14|3|
| 변경본 전체147검사 원본 기록 |130|14|3|

후속 수정은 해당 항목만 다시 검사했다. `original_turn_undead_rewards_test`의 이미 삭제된 quest 참조와 `ui_pointer_transfer_test`의 deferred 필터 복원 대기 오류가 해소됐다. 새 UI 시험은29개 assertion이 통과했지만 결과 표식이 부적합했고, 구조화된 결과/조건부 OK로 수정했다. L1J 시험은 새 도감 UI 우선순위와 기존 external ground 경로를 혼동해 실패했으며, 각각의 실제 바인딩·ID·아이콘·바닥·저장·전투를 분리해95개 검사를 통과했다. assertion 삭제/실패 무시는 하지 않았다. 후속 UI29/물약16/L1J95는 실제 runner 파서로 통과했다. [후속 결과](evidence/logs/targeted-summary.json).

미해결 기존 실패12개: 바닥 습득/스킬 학습 timeout,25맵 내비게이션 cache, 원본 pack 필요3개, 기존 메뉴 기대, 몬스터/재스폰 계약, stun 쿨타임, 지역 레벨, world_structure의 map_id 스크립트 오류. 지역 시험은 기준선24맵/6,036검사/57기존 assertion 실패로 끝났으나 변경본은18맵 후540초 timeout으로 끝났다. **변경본의 추가 실행 지연은 미해결**이다. 테스트 성공으로 간주하지 않았다. 전체 실행 동안 개발 checkout이 변경됐으므로 이 전수 로그를 단일 최종 SHA의 clean-suite 성공으로 주장하지 않는다.

새 focused 검사: 공격 lifecycle158, 보스693/60개, 세계 lifecycle21, 맵2264, population9, readability42, 아이템6445, UI입력399 등 통과. 기존 save migration27, 물리 장비 인스턴스/강화·창고·자동사냥·드랍 검사가 통과했다. 세이브는 제공된 옛 형식 fixture/격리 복사 데이터로 검사했으며 실제 사용자 세이브 표본은 제공되지 않았다. 전체 원본 로그, 분류 및 후속 로그는 [증거](evidence/)와 `/workspace/evidence`에 보관했다. [전후 실패 비교](evidence/feature-comparison.json), [기준선](evidence/baseline-baseline-report.json), [변경본 독립 감사](evidence/feature-audited-summary.json).

## 성능 실측과 제한

같은 머신/해상도1280×720/seed/DB/스크립트 SHA/기존 import cache, 새 프로세스/세이브, Mesa 디스크 shader cache 비활성, 별도 Godot 작업 없이 baseline→feature를 한 번씩 순차 실행했다. 실제 오만1층24개체/6종을 사용했고 HP/ATK는 지속되는 동일 부하를 만들기 위한 검사값이다. 실제 AI/AUTO/피해 코드는 사용하되 밸런스 검증은 아니다.60워밍업+120샘플이며 첫 사용/반복은 프로세스 내 변신 frame cache 기준이다.

| 측정 | 변경 전 | 변경 후 |
|---|---:|---:|
| 첫 playable draw, 엔진 시계 |26.455초|23.643초|
| 아덴→오만1 포탈 draw |1,369.343ms|1,197.402ms|
| 첫 변신2종 draw |272.594 /231.650ms|243.168 /219.812ms|
| 반복 변신2종 draw |115.268 /124.009ms|110.663 /126.407ms|
| 전투 frame 중앙값 |51.797ms|55.780ms|
| 전투 frame p95 |81.246ms|89.223ms|
| draw calls 중앙값 |634|635.5|
| Godot allocator peak |385,688,421B|403,857,607B|

[원본 실측과 조건 비교](evidence/benchmark-comparison.json). 단일 비교로 통계적 개선을 확정하지 않는다. OS cache와 driver cold 상태가 일치한다고 주장하지 않는다. Linux 프로세스 RSS peak는 보고서에서 수집되지 않아 미검증이다. Android/Windows 실기기/60fps 결과로 해석하지 않는다. APK/실행 패키지 용량은 빌드하지 않아 미측정이다. 목표는60fps이고 현재 측정은 목표를 충족하지 못한다.

깨끗한 clone의 최초 import208.025초, headless Main boot→60프레임15.098초, 실제 세계 lifecycle21검사11.394초, 모두0 exit와 오류 없음. 이는 기준선 첫 import387.659초(환경 오류/동시 부하)와 서로 다른 조건이므로 개선율로 비교하지 않는다. 편집기 GUI 재임포트와 Android 맵/변신 성능은 미검증이다.

## 입력 자료와 권리/전달

다섯 요청 파일은 연결된 Drive에서 정상 접근해 크기/SHA256과 ZIP CRC를 검증했다. [입력 정보](evidence/reference-inputs.json), [독립 검증](evidence/reference-verification.json), [공식 영상 관찰](REFERENCE_OBSERVATIONS.md). 연구 원본은 `/workspace/research`에 두고 게임에 넣지 않았다.

키트: **26,775,284바이트**, SHA256 `99dd0cb2f02da039b56923b9f3b947ed7ef4f73843d7f4e0c0dcdd7006b98a98`. PC 리니지 본체21624/21653의3,512프레임이다. 원본 ticks/타격표·프레임/오프셋/해시 검증 및 동일 ActorMotion 복사본의41,346 diagnostic 검사에 통과했다. 검토 .tres는 Image.load/take_over_path로 진단했으며 실제 프로젝트 importer/게임 설치 성공이 아니다. 신원·무기/방향 매핑·시간 기준·재배포 조건이 확인되지 않아 런타임 ID에 적용하지 않았다.24tick/s는 검토 환산값이며 원작 확정 clock이 아니다.60fps 공식 영상은 관찰자료이며 스프라이트 FPS/타일/충돌 원본이 아니다.

기존 EXE/JAR/DLL 실행, 인증 우회, 토큰 수집, 유출 소스 취득은 하지 않았다. 단일 장부의 original_*는 미전달 상태를 보존한다. 새 원본 아트/사운드 납품이나 원작 전체 복원이라고 보고하지 않는다.

## 재현과 정확한 재개 지점

[실행/복원 절차](REPRODUCE.md), [단일 체크포인트](REMAKE_CHECKPOINT.md), [증거 SHA256](evidence/SHA256SUMS).

1. 현재 PR의 코드/리소스와 전달 증거를 확인한다. GitHub clean clone c799550에서 실제 import/boot/세계 lifecycle을 확인했다. 그 이후 변경은 테스트/보고서/장부이며 scripts/addons/Main/project/게임 DB/맵은 동일하다.
2. 새 코드 작성 전 미해결 timeout/기존 실패를 분류하고 regional 시험18번째 이후의 실제 병목을 profile한다. 동일 실패를 원인 변경 없이 반복하지 않는다.
3. 현재 P1 플레이를 기준으로 보스 바/성장·습득 팝업 가림을 해결하고 실제 플레이 시각 승인을 받는다. 현재 사용자 승인 없음.
4. 권리·개체 대응이 확인된 연속 방향/동작 입력부터 선별 적용한다. 모든 ID에 두 본체를 덮어쓰지 않는다. 전용 모션/무기/그림자/맵 타일 부족을 계속 표시한다.
5. Android SDK/정확한 템플릿/기기가 준비된 경우에만 테스트 APK→boot→실제 터치 플레이를 각각 검증한다. 현재 Java21만 확인했고 SDK/템플릿/기기 없음; Android 빌드/부팅/실기기 실행 모두 미검증이다.
6. 프로세스 RSS/패키지 크기 및 실제 PC GPU 성능을 보완하고 안전한 항목부터 기존 PR에서 작은 커밋으로 이어간다. 검증/사용자 승인 전 main 병합 금지.
