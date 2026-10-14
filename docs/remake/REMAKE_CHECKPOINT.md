# PR #100 현재 재개 지점 · 2026-10-14 batch15

- 기존 브랜치 `feature/twilight-animation-20261013`, 보존 커밋 `6067ec1e74fbb7a3ae469caf8f75b5ea9e294b6b`와 실제 GitHub head 일치를 확인한 뒤 이어서 작업했다. 이 문서를 포함하는 PR head에서 계속한다. 새 PR·main 병합·기록 삭제 금지.
- 현재 **351/498**, 변신 **136/180**, 일반 **180/258**, 보스 **35/60**. **남은 147종(44/78/25)**의 정확한 목록은 [미완료 ID](evidence/pr100-direction-fix/original-based/coverage/missing-native-sources.json). 이전 문단의 수치는 역사 기록이다.
- batch15: 잔혹한 아시타지오 재사용, 라미아 2종·수중정령 2종 원본 기반 제작. 81개 native 리소스, 45개 신규 디자인, 4,632개 실제 고유 자세. 5종 Main headless 6,194개 / OpenGL 6,450개 모두 통과. [상세 범위와 원시 증거](PR100_COMPLETION_REPORT.md).
- 공통 Flare 방향 순서 **W,NW,N,NE,E,SE,S,SW**, 매핑 **[4,5,6,7,0,1,2,3]** 유지. 새 임포트의 누락 조각 거부·단일 큰 캔버스 정규화만 보완했다. 기존 런타임·PNG/TRES 보존.
- 다음: 원본과 표시 설정이 동등한 연결을 먼저 확인하고 5~10종 단위로 제작·연결 → `tests/run_original_based_batch.gd`와 별도 fixture로 한 엔진당 여러 실제 Main 검사 → 현재 보고서·coverage 갱신 → 같은 브랜치 커밋·푸시. 성공한 각 이름의 Main 보고서만 완료 근거로 사용한다.
- 알비노 악어 초안은 계속 미연결. 기존 6개 시트의 프레임 외 79픽셀은 시각적 귀속 검토 전이며 임의 수정하지 않는다. 현재 커밋의 전체 CI·Android 내보내기는 푸시 후 확인, 실제 기기 실행은 미검증.

## 이전 세션 기록 보존

`8ea63b3`에서 수행한 상하 방향 수정과 이후 이력은 아래에 보존한다. 과거 방향 승인 중 잘못된 원본 순서는 위 현재 기준으로 정정됐으며, 과거 수량·경로를 현재 완료 상태로 사용하지 않는다.

# TWILIGHT 8방향 애니메이션 재구축

## 이동과 반대 방향을 바라보는 오류 — 후속 수정
- 사용자 피드백으로 이전 방향 시각 검증의 오류 확인. 실제 source 방향은 `W,SW,S,SE,E,NE,N,NW`이며 기존 해석은 180도 반대였음.
- 기준 작업 SHA `d52e296a4e7408eb1acbf8a25f98ca1871366ed8`, main 재확인 `80076490518942647ad538ae440a91a3d3605c7e`. PR #100에서 계속 작업.
- 기존 두 본체만 방향별 원본 프레임/장비 layer 순서로 다시 합성. 게임 이동 벡터·판정·공통 재생 코드는 수정하지 않음. 신규 전체 리소스 제작/원본 ZIP 재추출 없음.
- 수정 전 방향 픽셀 검사 40건 실패 재현. 수정 후 기사 8시점 reference 포함 **1,362 assertions PASS**, 타격 lifecycle 158 / catalog / restore PASS.
- 최초 import의 sandbox 로컬 TCP 생성 오류를 기록. 네트워크 권한이 제공된 같은 명령에서 import 완료 / ERROR 없음. Daybreak 사용 없음.
- runtime 완료 SHA `292c80363fbc88d18a004277f740749b86b7fd71`. 실제 Main에서 이동 변위 화살표와 원본 방향 번호를 표시하는 선택적 QA 가이드를 사용해 8방향 화면을 모두 검토. 모션/입력 방향 일치 확인. 몬스터 전수 시각 검증은 아님.
- 최종 Main 녹화 PASS: 712프레임 / 23.733초, 기사 9타격 / 해골 5타격, 사망·바닥 드랍·수동 습득·변신 왕복. [수정 영상](https://drive.google.com/file/d/1yK6vMn9c8FhdTpnv1Zhr1JcFFmilvcnM/view). 새 리소스 해시·로그는 `evidence/direction-correction/`.
- 다음 실행: PR #100의 최신 코드를 받아 Godot 4.7.2로 실행 → 고급 흑기사 장착 → WASD/방향키 이동. 현재 수정은 두 기존 본체의 방향 오류이며 전체 외형 확장/Android 검증은 기존 미완료 상태를 유지.

## 기준 / 작업 보존
- 기준 main: `434b904d957fd2146b6d2e73325693a402028035` (2026-10-13 원격 재확인).
- 작업: `feature/twilight-animation-20261013`, `/workspace/twilight-animation`.
- 이전 `feature/twilight-remake-20261013`, PR #98, `1216c00756fe602173fb7346a452c9586d9f5754` 및 미커밋 파일은 별도 checkout에 보존. 착수 시 별도로 이식하지 않았으며 이후 main에 병합된 변경은 아래 merge에 포함.
- PR: [#100](https://github.com/zoog136-hash/-/pull/100), draft. main 병합 금지.

## 1단계 조사
- `Main.tscn` → `world.gd` → `player.gd` / `monster.gd` → 기존 `animation_catalog.gd`, `actor_motion.gd`가 실제 표시/공격 마커를 관리.
- 기사 기본 외형 `assets/sprites/classes/warrior.png`: 740×580, 5열×5행, 4방향 이동과 공통 공격. 8시점 원본이 아님.
- 일반 몬스터 `해골 근위병`: 기존 DB 및 맵 스폰, 검 근접 공격. 기존 family plate + shader 자세 변형. 전용 8시점 모션 없음.
- 소스 키트 SHA-256 `99dd0cb2f02da039b56923b9f3b947ed7ef4f73843d7f4e0c0dcdd7006b98a98`의 두 본체 21624/21653은 PC 계열 남녀 용기사. 기사/해골 대응 및 재배포 권리 미확인으로 해당 ID에 임의 적용하지 않음. 기존 외부 검증/추출 기록 재사용.
- 기존 재생기는 방향별 SpriteFrames, 원본 duration 및 타격 프레임 샘플링을 지원. 별도 재생기를 만들지 않고 실제 연속 프레임을 연결할 예정.
- 기사 + 해골의 게임 내 이동/공격 시각 검증 전 전체 ID 확장 금지.

## 기준 검사
- 편집 전 `python3 tools/check_resource_integrity.py --help` 및 `python3 tools/check_resource_integrity.py --root .`: PASS, 723 atlases / 41442 cells / 233420026 bytes. 이 수치를 원본 연속 모션 수로 주장하지 않음.
- Godot 4.7.2 + Compatibility 유지. `tools/test_project.py` 유효. 동일 main의 이전 전체 기준선 122 PASS / 14 FAIL / 3 SKIP 재사용; 이번 애니메이션 변경은 관련 회귀 및 실제 렌더로 검사 예정.
- 초기 리소스 임포트 캐시는 동일 main checkout에서 복사. 새 파일은 실제 Godot import로 검증 예정.

## 미완료 / 다음 실행
- Flare Game `af6eee6d339ac98011864bfe89da837fe7769c28`의 공개 2D PNG를 검토 후 변환. CC BY-SA 3.0, 출처/이용 조건/해시를 `assets/actors/eight_direction/`에 포함.
- 검/방패를 든 흑기사 `transform:46`, 기본 외형 `class:0`, 일반 몬스터 `해골 근위병`에만 연결. 2본체 × 8방향 × (대기 4 + 이동 8 + 공격 4) = 256개 고유 프레임. 대기 왕복 재생의 재사용 프레임은 중복 집계하지 않음.
- 원본 2D 오프셋, 방향별 장비 레이어 순서 보존. 방향 대응은 8시점 이미지로 확인. 기존 공통 재생기를 사용하며 이 대상에만 root 흔들기/회전/셰이더 가짜 방향을 제거.
- 최초 import는 편집기 XDG_CONFIG_HOME 미설정 오류 발생. 쓰기 가능한 환경변수와 동일 main의 texture `.import` 메타데이터까지 복원한 수정 명령으로 종료 코드 0, ERROR 없음. 로그: `/workspace/evidence/animation-20261013/import-fixed.log`.
- `eight_direction_animation_test.gd`: 930 assertions / 0 failures. `actor_motion_test.gd`, `authored_state_motion_test.gd`, `monster_motion_test.gd`: PASS. 로그: `/workspace/evidence/animation-20261013/`.
- 첫 Main 캡처는 선택한 좁은 지역에 누적 8각 이동 경로가 들어가지 않아 FAIL. 실제 스폰 후보들을 확인하고 왕복 8방향 통행 경로로 검사 동선을 수정. 게임 맵/충돌은 수정하지 않음.
- 수정된 Main 캡처 PASS (`animation-native-spokes`): 23.53초, 706프레임, 8방향 키 입력, 실제 AI 추적/피격, 기사 9타격, 몬스터 사망, 바닥 드랍 2개 및 수동 습득, 변신 교체/복귀. 실제 PNG 화면 검토 완료. 이것은 사용자 시각 승인이 아님.
- 이후 피격 2 / 사망 6프레임 추가. 본체별 실제 서로 다른 픽셀 프레임 176개, 합계 352개. 동작/방향별 프레임 슬롯은 384개(피격과 사망 일부 공유); 두 수치를 구분.
- 사망은 해당 profile의 0.8초 연속 동작 후 fade. 기존 비대상 사망 시간, 판정/드랍/제거 중복 방지 유지. 플레이어는 기존 즉시 부활 + corpse VFX 경로를 그대로 사용함; 부활 전 카메라 정지 연출은 추가하지 않음.
- 추가 리소스 import를 기다리지 않고 실행한 검사에서 미임포트 PNG 오류가 발생한 기록은 실패로 보존. 120초 import timeout 이후 300초 예산으로 완결. 완결 로그 `import-complete.log` 및 이후 `*-verified.log`의 1,314 assertions / 0 failures, 기존 모션 3종 PASS 확인.
- `animation_restore_test`, `animation_catalog_test` PASS. 카탈로그 시험은 1방향이라는 과거 가정 대신 실제 새 8방향 5동작 전부를 검증하도록 확장.
- 전후 동일 장면 촬영 및 업로드 완료(아래 최종 기록). 전체 외형 확장, Android, 사용자 시각 승인 미완료/미검증.

## 최신 main 반영
- 작업 도중 PR #96/#97/#98이 main `80076490518942647ad538ae440a91a3d3605c7e`에 병합됨. 새 작업 브랜치에 merge하여 기존 작업을 보존. 이번 PR은 #100 (draft).
- merge commit `5a4a48ef19c67ca781cced2ed3433ac64357162f`: 최신 main 기능 보존 및 애니메이션 1,314 assertions / 타격 lifecycle 158 checks PASS. 최종 Main 영상 23.7초, 711프레임 PASS.
- 5단계: 알파 여백을 제거해 10장 아틀라스 원시 RGBA 합계 96MiB → 15.516MiB (83.84% 감소). 384프레임의 알파/가시 픽셀 차이 0. 원래 256×256 발 캔버스는 AtlasTexture.margin으로 복원. 실제 프로세스 메모리 피크와는 구분.
- runtime 완료 SHA `fe0cef3` (이후 증거/문서만 추가). 새 PNG 재임포트 후 1,314 assertions 재통과.
- GitHub clean clone `/workspace/twilight-animation-delivery` 초기 .godot 없음 확인. import 244.949초 / boot 13.536초 / native-frames 0.737초 / restore 16.979초, 모두 종료 0 / ERROR 없음.
- 마지막 패킹본 Main 실제 화면/녹화 PASS: 23.7초 / 711프레임, 기사 9타격, 해골 AI 공격, 사망/드랍/수동 습득 및 변신 왕복. 렌더 경고는 llvmpipe V-Sync 변경 미지원 1건. 성능 비교용 실행이 아님.
- 마지막 추가 회귀: `authored_frames_test`, `full_visual_manifest_test` PASS. `animation_presentation_test`의 고정 fade 시점 가정을 새 profile 길이에 맞춘 후 76,231 checks PASS. 0.8초 동작의 마지막 자세를 잘라내어 기존 검사에 맞추지 않음. 초기 실패와 이후 성공 로그 모두 보존.
- 전후/비교 MP4를 제공된 Drive 폴더에 업로드. 비교 파일 재다운로드 SHA-256 `656c774a6954db430a93b28efce36805b0caec6f9f6e1dcb65b305dda782d83c` 일치. 링크/전체 해시는 `evidence/eight-direction/video-delivery.json`, `video-files.json`. 익명 공개 접근은 미검증.
- 새 runtime SHA `fe0cef3106442b4369852b08ba82e5e790fa7ecb` 이후 변경은 회귀 fixture 및 증거/문서. 검증 프로세스는 종료되었고 자동 재개 작업은 없음. 원래 checkout의 미커밋 변경을 삭제하거나 초기화하지 않음.
- 상세 결과/부족 수량/실행 방법: `docs/remake/ANIMATION_REBUILD_REPORT.md`. 다음 실행: Godot 4.7.2로 Main 실행 → 메뉴/변신/고급 흑기사 장착. 전체 확장 전 남은 ID에 맞는 독립 연속 모션 확보 필요. 본체 2종을 다른 ID에 복제하지 않음.
- 아래는 이전 PR #98 체크포인트 원문 보존 기록이며, 이번 8방향 검증 상태는 위 기록을 따름.

<details><summary>이전 PR #98 기록</summary>

# TWILIGHT remake checkpoint — 2026-10-13

Status: scoped integration implemented; whole remake incomplete. No user visual approval, no main merge.

- Branch: `feature/twilight-remake-20261013`; open draft PR [#98](https://github.com/zoog136-hash/-/pull/98).
- Independently queried main / baseline: `434b904d957fd2146b6d2e73325693a402028035`.
- Latest production commit: `c79955089704f59edfb01d86a2e0daf128fffb2e`, pushed to the existing PR branch. Prior recording production commit: `b81c8f16e77fd747fd2ec8f5e5a664f587c1a1d6`.
- Existing PRs #96/#97 and other branches preserved; selected runner/item fixes reused with attribution. No reset, force push, deletion of uncommitted work, or merge.
- Engine: official Godot 4.7.2 Linux x86_64, verified official SHA512 and ZIP CRC; Compatibility preserved. No Daybreak capability invoked.

## Completed changes

Shared actor attack timeline and large-delta strike pose; cancellation/death lifecycle; immutable boss attack geometry; pooled-life guards for attacks/projectiles; one-shot reward claims; self-area skill uses the same strike signal; cast speed affects cooldown. Presentation settings reach actual live actors/VFX/projectiles. World input excludes UI/touch events. Item rarity motion respects visibility/reduced motion. Native source-ID icon rejection retained, with three exact local potion icons restored. Canopy/roof occlusion and tall-prop viewport retention improved. Population avoids duplicate live slots/boss keys. Research media excluded from import/export without deleting it.

Call paths: `Main.tscn -> scripts/world.gd -> Player/Monster scenes`; `animation/actor_motion.gd` emits strikes; world queues resolve actual damage/flight contact. `maps/field_population.gd`, DB catalog and boss director retain spawns/drop identities. Ground-loot manager and pickup controller own floor items; world instance enhancement and save writer keep saves. `renewal_hud.gd` connects UI signals to world. Runtime VisualManifest/AnimationCatalog keep bounded caches.

## Verification available

- Pre-edit and current resource integrity: PASS, 723 generated WebP / 41,442 cells / 233,420,026 bytes; originals remain not delivered.
- All-ID runtime audit regenerated after potion fix: classes13, transforms413, dolls166, relics144, normals258 (149 spawn-referenced), bosses60 (28 spawn-referenced), maps25, merged items2576, effects125. All have effective load/fallback paths. No per-ID visual completion or dedicated original motion claimed.
- Genuine matched Main game recordings: 20.033s / 601 frames / 34 assertions each; eight-direction input, native Drake warning/hit, three manual plus nine AUTO attack cycles, unchanged520HP death, naturally earned floor drops, manual potion + AUTO ore pickup. Recording commit predates potion fix; follow-up focused icon test16 and item audit6445 pass.
- Baseline full suite:139 executed,122pass/14fail/3skip. Feature full suite147 executed,130pass/14fail/3skip. Two new result/expectation failures were corrected by tests-only c5e8783 and passed targeted29/16/95checks. Remaining12existing failed tests and feature540s regional timeout unresolved; keep all raw failures.
- New focused tests already passed: actor lifecycle158; boss geometry693/60bosses; world lifecycle21; all maps2264; population9; readability42; item visuals6445; native UI input399; per-instance/save tests have preserved logs.
- Five authorized Drive references have size/SHA256/CRC verification. Two PC Lineage actors21624/21653 provide3512 source frames; ticks/hit offsets independently checked, including41,346 diagnostic assertions. Bodies are research-only; identity/directions/clock/rights unconfirmed. No redistribution into game.

## Processes and evidence

Both full suites and all bounded follow-up engines have finished. No further suites or background resume scheduled. Old zombie children are not running work. One stale source diagnostic was terminated after ownership verification, with cleanup evidence. No automatic future resume promised.

Raw logs: `/workspace/evidence/{baseline,feature}`. Selected delivery evidence: `docs/remake/evidence/`. Production research originals: `/workspace/research`, outside Godot project. Independent clean GitHub clone: `/workspace/twilight-clean`, integrity passed at c799550; cold import208.025s, Main boot15.098s, world lifecycle21 checks passed, all exit0/error-free. Runtime files unchanged by tests-only c5e8783. Test-generated docs/images in working trees remain untouched; uncommitted ledger/docs preserved.

## Completed evidence and remaining action

- Matched recordings are copied into `docs/remake/evidence/production-play`; recording production b81c8f1 and later potion-HUD c799550 kept distinct. Selected4PNG plus movies/JSON delivered; other18PNG remain only local.
- Matched baseline/feature performance run once sequentially after engines finished: frame p50 51.797→55.780ms, p95 81.246→89.223ms; Godot allocator peak385688421→403857607B. Boot draw26.455→23.643s. No60fps/overall improvement claim; process RSS/device/package size unverified.
- Final focused test code c5e8783: UI29/localicons16/L1J95 passed through actual suite parser; final GL potion screenshot17checks passed. Source-ID catalog UI precedence and reviewed ground binding are independently checked.
- Clean GitHub source reproduction passed without /workspace/research or worker import cache; exact runtime source c799550 remains authoritative. See REPRODUCE.md, VALIDATION.md and evidence SHA256SUMS.
- Test-generated docs/images in existing working tree paths are deliberately uncommitted and untouched. No reset/deletion. Only intended ledger/remake docs/evidence and README are staged for delivery.

Next work on same PR:

1. Profile feature world_regions18th map/540s timeout; resolve baseline12failed tests without bypassing assertions or installing fake source completion. Review failure logs before rerunning only changed cases.
2. Fix existing boss/target bar and natural growth-panel/pickup occlusion; obtain real user visual approval. Current quality matrix in VALIDATION.md remains fail/unverified in several areas.
3. Apply only licensed identity-matched articulated2D source frames per ID. Missing dedicated8direction/body/weapon/shadow/actions remain; do not cover all entities with actors21624/21653.
4. Improve measured combat frame time/memory; record process RSS/actual GPU/package size with matched conditions. Current Linux software-render data is not Android performance.
5. Android SDK/4.7.2 templates/device missing; APK build, boot and touch play remain separate unverified steps. Windows device performance and user's actual save-copy regression unverified.
6. Keep original_* not_delivered and the single current-ID ledger authoritative. Do not merge main without required checks and user approval.

Next supported commands:

```sh
git status --short
git log -3 --oneline
# read docs/remake/VALIDATION.md and evidence/feature-comparison.json first
# run only the changed regression case using the official Godot4.7.2 binary
# no full-suite retry without a diagnosed and changed cause
```

</details>

## 영웅 이상 / 몬스터 확장 — 최소 연결 검증 완료
- 기존 작업 브랜치 `feature/twilight-animation-20261013`, draft PR #100 유지. 기준 main `80076490518942647ad538ae440a91a3d3605c7e`, 확장 전 마지막 정상 커밋 `cb0cd1c046ed349a9395255050c56cf7d44cdf6b`.
- 현재 실제 DB 영웅 이상 변신 180, 일반 258 / 보스 60. 예정 수량과 실제 적용 수량을 구분.
- 신화-기사(여) `transform:131`: 검/방패 여성 장비 레이어, 실제 드레이크: elite wyvern 8방향 idle/walk/attack/hit/death 및 cast/ranged/special 연결. 원본 복원이 아닌 공개 CC BY-SA 3.0 2D 적합 외형 적용.
- 입력 PNG/메타데이터 181파일, 300,715,675B를 pinned Git blob 및 SHA-256으로 검증. 연구 입력 `/workspace/research/flare`, 게임에는 사용 atlas만 포함. `expansion_source_receipt.json`에 영수증 보존.
- Godot 4.7.2 Compatibility: 변환/import 성공. 기존 8방향 1,362 assertions, 새 확장 2,499 assertions, 타격 lifecycle 158 checks, 변신/인형/성물 restore PASS.
- 실제 Main 녹화 `expansion-knight-drake-verified`: 종료 0 / ERROR 없음, 20.267초·608프레임, 실제 8방향 이동, 기사 14 타격·보스 5 타격, 보스 사망·바닥 드랍 2·수동 습득·변신 왕복. 자동 회복 전 최저 체력으로 피격 검증. Linux llvmpipe 소프트웨어 렌더; FPS/Android 성능 증거 아님.
- 초기 캡처 실패 원인과 로그 보존: 마법형 보스 사거리를 근거리 사거리로 가정한 검사 동선; 다음 캡처는 레벨업 회복 후 최종 HP만 비교한 검사 가정. 게임 수치·AI·보상은 수정하지 않고 실제 키 입력 접근과 최저 HP 기록으로 해결. JSON 수치 배열 검사의 float/int 비교 실패도 검사에서 정규화; 프레임 내용은 바꾸지 않음.
- 확장 일반 시스템: 동작별 contact pose, 기존 공통 재생기 사용, decoded atlas lookup cache 96MiB 예산. 실제 메모리 피크·전체 화면 검증 미완료.
- 현재 추가 2 외형만 실제 게임 검증 통과. 다음 실행: 남은 확인된 장비/종족 recipe 변환 → 전수 연결/import/회귀 → 실제 활·시전 Main 검증. 35 shared outfits의 대량 적용은 최소 검증 통과 후에만 진행.

## 확장 1차 — 실제 검/활/시전 검증 및 전체 연결 완료
- 최소 적용 저장 커밋 `7af22e0206a8abd94647b55c28b32d5e83901e92`를 기존 PR #100에 push 완료.
- 영웅 이상 126/180, 일반 몬스터 119/258(기존 해골 근위병 포함), 보스 31/60에 실제 연속 8방향 연결. 34개 공유 장비/종족 리소스(남녀 장비 조합 15, 생물/언데드 원본 변형 19)를 사용하며 per-ID 전용 원본 모션 수와 구별.
- 신화-요정(여)135 + DB 훈련용 활: actual Main 20.467초 / 614프레임, 13 발사, 실제 ranged_attack 0/1/2/3 source poses, Drake 사망·바닥 드랍·습득·변신 복귀 PASS.
- 신화-마법사(여)137 + DB 훈련용 지팡이: actual Main 23.033초 / 691프레임, 기존 HUD 마법 액션 22회 시전, Drake 사망·바닥 드랍·습득·변신 복귀 PASS. 마법 공식을 바꾸지 않음.
- 확장 후 native 35,455 assertions / presentation 76,336 checks / boss geometry 60종·693 checks / world lifecycle 21 / weapon rules PASS. 새 Python identity/rollback 2개 PASS. 모든 변신413·몬스터318의 실제 registry load/fallback probe 누락 0.
- 원본 입력 선택 후 recipe가 변경되어 입력 PNG 2개가 누락된 첫 확장 변환을 종료. 해당 2개만 pinned Git blob/크기/SHA로 보완, 정상 30개 변환을 재사용하고 남은/수정 5개만 변환. fail-fast 입력 검사 추가. 원본 입력 183파일 / 309,516,282B, 프로젝트에는 사용하는 PNG 92,415,885B만 추가.
- 이름/주무기 대조로 천사궁수·창병·기마/특수 개체 7종의 부적합 대체 후보를 제거하고 이전 설정/기본 폴백을 복원. 데스나이트는 실제 skeletal-knight source, 심해마녀는 여성 staff source로 수정. `prior_visual_profile`로 자신의 확장 후보 철회 시 원래 외형 복원 지원; 다른 기능의 아트/설정을 변경하지 않음.
- 무기 선택은 첫 실제 주무기 보너스가 범용 body label보다 우선. 사신의 사이드 등 없는 전용 무기는 미확보 유지.
- 비사용 임시 생성 2개 폴더는 삭제하지 않고 `/workspace/research/unbound-animation-output`으로 보존, 게임 import/export 영역에서 제외.
- 부족: 영웅 이상 54, 일반 139, 보스 29는 기존 유효 외형 유지. 정적 전수 검증과 실제 화면 표본 3 플레이어 + Drake를 구분. Android·전체 ID의 시각 검증·새 GPU 성능 측정 미완료.
- 추가 공개 2D 생물 스프라이트(늑대/촉수)의 출처·라이선스와 원본 PNG/동작표를 조사 중. 3D 생성/모델 실행 없음. 아직 게임 적용이나 완료로 집계하지 않음.


## 2026-10-13 확장 전달 / 최신 main 보존

- 작업 브랜치 `feature/twilight-animation-20261013`, 기존 draft PR #100 유지. 확장 runtime `3d0447618e68d4a386ef0c4ce407e80d2cecd97e` push 확인. 이후 최신 main `02842fdd123bf14db46bed91a3cb68c36fa8b9b1`의 아이템 icon 변경을 충돌 없이 merge했다.
- 새 runtime 리소스 291파일은 로컬·Git blob·provenance SHA-256 일치. 실제 Main 검/활/지팡이 영상 3개를 지정 Drive 폴더에 업로드하고 전체 파일 재다운로드 해시 일치 확인. `evidence/animation-expansion/video-delivery.json`에 링크/크기/해시 및 검증 범위.
- CI `38359754605`: 새 native actor를 이전 정적 이미지와 비교하던 2개 조건 실패. static bridge 검사 유지 + 선언한 native SpriteFrames와 실제 pose 표시 검증으로 수정. `38359754626`: stun cooldown 실패는 `/workspace/evidence/baseline/full-suite/skill_mechanism_smoke_test.log`에도 존재. 전투 계산/쿨타임을 이번 범위에서 수정하지 않았다.
- 남은 입력: Hero+ 54, 일반 몬스터 139, 보스 29의 대응 연속 프레임. 모든 미연결 ID와 구체적인 이유는 단일 resource ledger의 `sequential_actor_art.missing_native_motion`. 전수 시각/Android/GPU 성능/전체 보스 고유 모션은 미완료.
- 후속 후보 연구만 존재: OGA Danimal Wolf archive SHA-256 `b2aa63b7627c8b52e1f68c2a8bfda7b23c6cf9dd1ade66407ae1dd040fb22e4d`, tentacle PNG `b7d166c16f860d49a0094368cdf50baf8d0b38c733eb918d93789d056f43dc2c`. `/workspace/research/open-sprite-expansion` 외부 보관. 아직 변환/게임 연결/영구 전달 아님. wolf 그리드 메타데이터 지원과 compass/정체성 검증이 먼저다. 늑대인간에 사족 늑대를 매핑하지 않는다.
- 다음 명령: `git status --short; git log -4 --oneline`으로 이 기록 이후의 전달 커밋 확인, `python3 tests/animation_expansion_plan_test.py`, `python3 tools/check_resource_integrity.py --root .`. 완료한 34외형을 재생성하지 않는다.

- GitHub의 `3d04476`을 `/workspace/twilight-animation-expanded-delivery`에 새로 clone. 캐시 없이 import 204.941초, boot 16.141초, native 15.445초, restore 22.683초, runtime registry 27.294초 모두 오류 없이 통과. 새 리소스 291파일 SHA 확인, 연구파일 복원 없이 실행. 명령/결과/로그 `evidence/animation-expansion/clean-delivery/`.
- 첫 native pose 비교 수정 검사는 최초 프레임(attack)을 기대했으나 setup이 즉시 해당 방향 idle을 적용하므로 2건 실패했다. 실제 상태가 요구하는 `idle_<facing8>`의 첫 프레임을 엄격히 비교하도록 수정했다. 실패 로그 보존.

- 최신 main 보존 merge **`dec79a632bb1cbb33f9de4d1d9073ac28dbb75de`**, 기존 static bridge와 새 native actor의 상태 검증/CI 확대 **`b516f38f32af2c82f23005a5df6526f9b7418cce`**. 로컬 L1J 실제 교전 101 checks 및 최신 main의 item icon 193 checks 통과. 최신 명령/로그 `latest-main-validation-reviewed.json`. 최종 전달 문서 커밋은 이후 `git log` 확인.
