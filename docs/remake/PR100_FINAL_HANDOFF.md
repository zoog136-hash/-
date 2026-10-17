# PR #100 최종 중단·인계 체크포인트

2026-10-15 UTC. 저장소 `zoog136-hash/-`, 기존 PR [#100](https://github.com/zoog136-hash/-/pull/100), 보존 브랜치 `feature/twilight-animation-20261013`.

**사용자 지시로 신규 제작·이미지 생성·새 게임 검증을 중단했다. 이 문서는 보존 및 다음 대화의 재개 지점이다. 이 대화에서는 새 PR·새 브랜치를 만들거나 main에 병합하지 않는다.** 모든 제작 담당자가 중단했으며 실행 중인 제작/Godot 검사가 없다. 이미 완료된 결과를 재생성하거나 덮어쓰지 않았다.

## 1. 최종 수량과 기준 커밋

**392/498종 완료(78.7%), 잔여 106종.** 마지막 사용자 기준 391종 이후, 중단 전에 자동검사와 실제 Main 시각 검토가 끝난 지옥의 쿠거 v3만 추가 보존했다. 이구아나·아그니는 자동검사 PASS이나 최종 Main 시각 검토가 끝나지 않아 완료에 포함하지 않았다.

| 분류 | 완료 | 전체 | 미완료 |
|---|---:|---:|---:|
| 영웅 이상 변신 | 140 | 180 | 40 |
| 일반 몬스터 | 212 | 258 | 46 |
| 보스 | 40 | 60 | 20 |
| 합계 | 392 | 498 | 106 |

실제 Main 개별 8방향 증거는 **121종**, canonical Main 보고서는 **255개**다. 기존 253개 보고서의 경로/SHA를 전부 보존하고 쿠거 2개를 추가했다. 392종 전체에 신규 개별 Main 전수검증이 끝났다는 뜻은 아니다. 원래 인계 374종 이후 누적 신규 완료는 18종이다.

- 마지막 검증 자산 커밋: **`fdfbab2c22ad0ff1b9f15e41742476a737c7481f`** — batch29 쿠거 v3, 392종. 원격 기존 브랜치에 push 확인.
- 직전 391종 커밋: `437680c6cdd40a7a6fc9958b2d267402303a8f50` — 검은 토끼 소녀328, 112자세.
- 문서·미완성 원본 보존 커밋은 위 자산 커밋의 후속이다. 문서를 포함한 정확한 최종 저장 SHA는 다음 읽기 전용 명령으로 얻는다. 자기 커밋 SHA를 문서 안에 미리 만들어 적지 않는다.

```sh
git log -1 --format=%H -- docs/remake/PR100_FINAL_HANDOFF.md
git rev-parse HEAD
git ls-remote origin refs/heads/feature/twilight-animation-20261013
```

수량 근거: [coverage.json](evidence/pr100-direction-fix/original-based/coverage/coverage.json), [기계 판독 전체 잔여 목록](evidence/pr100-direction-fix/original-based/final-handoff-20261015/remaining106.json), [독립 읽기 전용 감사](evidence/pr100-direction-fix/original-based/final-handoff-20261015/independent-readonly-audit.json). 현재 활성 연결은 검증된 392종 상태다. HOLD 2종의 임시 프로필과 5개 미추적 런타임 폴더는 정확한 바이트를 별도 보존한 뒤 작업용 경로로 옮겼으며 정상 완료 자산은 옮기지 않았다.

## 2. 중단 직전 완료 결과

batch29 쿠거 v3는 104자세/18원본 PNG다. W/NW/N/NE 공격·피격 20자세를 새로 작화하고 기존 84자세 원본 SHA를 유지했다. v1의 후방 팔레트와 v2의 뒤쪽 몸통 성장 실패는 보존했다. 원작 모션 추출이 아니라 기존 프로젝트 참조를 이용한 신규 2D 작화다.

- 실제 Main headless 2,312검사, OpenGL 2,434검사, 오류 0.
- 추가 시간 진행 Main 40,364검사, 104 native 자세/40역할, 오류 0. QA clock의 제어된 모션 시간이며 실제 AI/물리 검증은 별도 base Main 실행이다.
- 8방향 실제 AI 공격·8방향 실제 돌진 예고/이동/접촉, 원래 HP 25,100, 실제 무기 328회, 피격·사망·지면 드랍·수동 습득 PASS.
- root는 104 base 자세와 16 AI/돌진 화면을 검토하고 변경된 후방 4방향 시간 진행 표를 확인했다. 작성자가 아닌 다른 검토자가 전체 8방향/104 시간 진행 표를 승인했다.
- [batch29 보고서·원본·실패 이력](evidence/pr100-direction-fix/original-based/batch29/README.md), `batch29/summary.json`, `batch29/temporal-main/`.

기존 보스 특수 동작, Rabbit328, Nungma 및 이전 완료 개체 증거는 기존 batch23~31/coverage 경로에 유지했다. 과거 일부 배치는 전체 캡처 SHA 목록과 대표 PNG를 Git에 보존한 범위이며, 과거 모든 전체 화면 PNG 본문을 새 패키지에 포함했다고 주장하지 않는다. 아래 이번 미커밋 925개 자료는 전부 바이트 보존했다.

## 3. 미완성 자료의 무손실 보존 및 복원

보존 루트는 `docs/remake/evidence/pr100-direction-fix/original-based/final-handoff-20261015/`다. 아래 경로는 이 루트 기준이다.

| 자료 | 보존 범위와 검증 |
|---|---|
| `source-archives/` | 55파일/984,260,151바이트, ZIP 23개. 원본·실패 이미지·프롬프트·후보·수정 이력. 전체 파일 SHA와 ZIP CRC 확인, 별도 검토자가 2,387 ZIP 멤버를 읽고 인덱스의 2,243 SHA 및 기존 base 의존성을 확인 |
| `source-archive-inventory.json` | 원래 로컬 경로, 원격 보존 상대 경로, 크기, SHA-256. 모든 제작 중 자료는 완료 추가 0 |
| `runtime-evidence/pending-runtime-manifest.json` | 미커밋 런타임·프로필·fixture32·성공/실패 Main32 전체 캡처·로그·보고서·실행 코드·temporal32 전부 925파일/1,125,428,584 원본 바이트의 SHA |
| `runtime-evidence/pending-runtime-and-main32.tar.zst.part01`~`part09` | 원본을 손실 없이 압축한 685,662,735바이트. 결합 SHA `9ed7ae7d66ace5352daac3e927bc347ed1bce07c7fc732d54b7201010cc29bfe`. 전 925멤버의 압축 해제 스트림 SHA와 원본 SHA 일치, 9분할 결합 SHA 일치 |
| `runtime-evidence/parking-and-qualified-wiring.json` | 옮긴 HOLD 폴더/fixture32의 이전·새 경로, 정확한 WIP 프로필 SHA와 검증된 392 프로필 SHA. reset/clean/force push 없음, 완료 자산 이동/교체 0 |
| `runtime-evidence/transport-verification.json` | 전체 스트림 검증 완료 기록. 검증 후 제거한 것은 중복 생성 압축 운송 중간본뿐이며 원본/테스트 결과 삭제 0 |
| `pending106-source-reference-proof.json` | 잔여 106개 원본 참조의 실제 파일·Git 추적·SHA 확인. 한 장 참조가 8방향 모션 제공이나 외부 원작 라이선스 검증을 뜻하지 않음 |

로컬 원본도 `/workspace/scratch/pr100-continuation/`에 남아 있다. 임시 런타임은 `/workspace/scratch/pr100-final-handoff/parked-runtime/`에 보존했다. 새 환경에서는 이 절대 경로 대신 원격에 포함된 위 패키지를 사용한다. 런타임 패키지는 `pending-runtime/`, `main32-final/`, `main32-first-cast-alias-rejected/`, `temporal32/`, `batch32-root-import/`, `unicorn33-failed-preflight/`로 복원된다. 게임에 자동 연결하지 않는다.

**다음 명령은 다음 작업자의 자료 복원용이다. 제작을 재개하는 명령이 아니며 대상은 반드시 새 빈 디렉터리여야 한다.** Python 3.9 이상과 `zstd` CLI가 필요하다. 925개 스트림 검증은 완료했으나 디스크 공간 때문에 이 최종 helper를 이용한 별도의 전체 디스크 재복원은 수행하지 않았다. helper 문법 확인은 PASS다.

```sh
python3 docs/remake/evidence/pr100-direction-fix/original-based/final-handoff-20261015/runtime-evidence/restore_pending_bundle.py /tmp/pr100-restored-hold-evidence
```

helper는 분할·결합·멤버 SHA를 확인하고 기존 파일/비어 있지 않은 목적지/경로 이탈/링크를 거부한다. 프로필 전체를 생산 경로로 덮어쓰지 않는다. 후보의 옛 절대 `output_path`는 멤버 인덱스와 SHA로 새 scratch 위치에 재매핑한다.

원본 패키지 복원 순서 (아래 항목 2~5의 경로는 `source-archives/` 기준):

1. 이구아나·들개: `source-archives/iguana-and-wilddog/index.json` 기준 03 part01~03 → 04 → 05 → 06 delta. 최신 들개 재개 파일 `talking-island-wild-dog-authoring/STOPPED_HANDOFF_20261015.json`.
2. 유니콘·늑대: `unicorn/base05/` 두 ZIP → `unicorn/delta06-and-wolf-base/` 두 ZIP → `unicorn/final07-and-wolf-delta/` ZIP. delta06에 이전 늑대 base도 포함한다. 세 디렉터리의 index에 원본/멤버 SHA가 있다.
3. 무덤 가디언269: `tomb269/base/RESTORE_README.md`의 CAS `restore.py` → `tomb269/final-delta/RESTORE_README.md`의 `restore-final-delta.py`. ZIP의 CAS 객체를 단순 펼친 것을 완전한 작화 경로 복원으로 오인하지 않는다. 복원 후 `CURRENT_RESUME_STOP_FINAL.md`부터 읽는다.
4. 가디언: `guardian/base/` → `guardian/final-delta/`, 각각 index 확인. 안나276: wip01 → wip02 delta → wip03 final delta, 최신 `maid-anna276-authoring/STOP-RESUME-ANNA276.json`.
5. 데스 서번트: `death-servant/delivery-manifest.json`과 ZIP/멤버 인덱스. 아그니·드라이어드·커스번: `agni-dryad-curseburn-stop/CURRENT-RESUME.json`과 ZIP/멤버 SHA. 이구아나와 아그니의 임포트 이후 자료는 별도 runtime 패키지에도 있다.

ZIP 복원도 새 scratch에서 인덱스 순서와 SHA를 확인한다. 기존 완료 자산에 패키지를 직접 덮어쓰지 않는다. 보존한 실패 이미지는 완료로 승격하지 않는다.

## 4. 제작 중이던 개체·실패 원인·정확한 다음 지점

아래 모두 **HOLD/미완료**다. 이미 있는 자료를 먼저 읽고 다음 PR에서 검토한다. 중단 이후 새 이미지를 생성하거나 새 Main 검사를 실행하지 않았다.

| ID·이름 | 현재 상태/실패 원인 | 정확한 재개 위치 |
|---|---|---|
| transform:407 화염의 엔트 | 화염의엔트 기존HOLD 유지. 현재엄격8방향네이티브미연결, 이번세션새모션/Main없음. | docs/remake/PR100_COMPLETION_REPORT.md |
| transform:376 베테랑 낚시꾼 폴 | 베테랑낚시꾼폴 기존방향/보행소형시험실패. 이번세션수정없음, 이전실패증거보존. | ../resume-20261015/fisherman376-wip/diagnostic.json |
| transform:360 서커스단 카드 마술사 | 기존HOLD: 방향/카드손 외형 실패. 검증된전체5역할미연결. | docs/remake/PR100_COMPLETION_REPORT.md |
| transform:357 서커스단 단장 | 기존HOLD: attack2 crop 및N접촉/비례/발앵커 미승인. 승인35포즈는완료아님. | docs/remake/PR100_COMPLETION_REPORT.md |
| transform:352 알비노 뿔 개구리 | 알비노뿔개구리 변신352 기존HOLD. 완료된다른개체와혼동금지, 이번세션새모션/Main없음. | docs/remake/PR100_COMPLETION_REPORT.md |
| transform:276 메이드 안나 | 메이드안나 이전15개는같은지지다리/총그립위치불명확으로HOLD. 16번째frontcarry몸체모델미검토. 기존원본108×132불변, 외부아트생산사용없음. | source-archives/anna276/maid-anna276-wip03-final-delta-index.json; 복원후 maid-anna276-authoring/STOP-RESUME-ANNA276.json |
| transform:269 거대한 무덤 가디언 | 거대한무덤가디언112/51원본초기기하PASS. 앵커·helmet/core·NE발/팔레트와장무기비율검토미완료. 새E3/NE-HD5수정본 및팔레트3원본은미선택/HOLD, 팔레트나머지3미실행. | source-archives/tomb269/base/RESTORE_README.md; source-archives/tomb269/final-delta/RESTORE_README.md; 복원후 CURRENT_RESUME_STOP_FINAL.md |
| transform:7 바포메트 | 바포메트 변신7 기존HOLD. monster:바포메트와별도ID, 이번세션새모션/Main없음. | docs/remake/PR100_COMPLETION_REPORT.md |
| monster:공포의 아그니 공포의 아그니 | 104자세/16PNG. cast별칭 첫실행320오류/모드 보존. 선택별칭만제외한v2 Main1650/1778·시간진행104자세 자동PASS, 독립Main시각검토 미완료. fullDB 실제magic/floatingtrue/.52는overlay로복원됨. | runtime-evidence/pending-runtime-manifest.json; source-archives/agni-dryad-curseburn-stop/CURRENT-RESUME.json |
| monster:말하는 섬 들개 말하는 섬 들개 | 새E4개별원본 보행제안, head/core정합 미완료. 마지막idle16 원본은 중단후검사하지않음. | source-archives/iguana-and-wilddog/source-only-delta06-full-member-sha256.json; 복원후 talking-island-wild-dog-authoring/STOPPED_HANDOFF_20261015.json |
| monster:검은숲 늑대 검은숲 늑대 | 기존104전부완료아님. 반대보행/후방사망/새N카메라 수정보존. 최신NW/NE 원본은 중단후검사하지않음. | source-archives/unicorn/delta06-and-wolf-base/unicorn-wolf-source-delta06-index.json; source-archives/unicorn/final07-and-wolf-delta/unicorn-wolf-source-FINAL-PAUSED-delta07-index.json |
| monster:가디언 가디언 | E4만root물리보행시험 승인. N4/E·Nidle은 작성자기하·해부제안, 독립전체방향/나머지모션/Main 미완료. | source-archives/guardian/final-delta/index.json; 복원후 guardian-iron-monster-authoring/FINAL_USER_STOP_RESTART.txt |
| monster:분노의 데스 서번트 분노의 데스 서번트 | 104자세/16PNG 새N/NE사망6. 전역고유/전체원본사용 기하PASS, hood/skull/core/바닥앵커 불확실성 및 독립검토·Main 미완료. | source-archives/death-servant/delivery-manifest.json; source-archives/death-servant/portable-source-checkpoint.zip |
| monster:알비노 드라이어드 알비노 드라이어드 | N/NE10자세부분만존재, 새앞/측면출력4건이 도구 output moderation_blocked로 실패. 실패ID·정확프롬프트보존, 전체40/104성공아님. | source-archives/agni-dryad-curseburn-stop/CURRENT-RESUME.json; 복원후 albino-dryad-authoring/ |
| monster:알비노 유니콘 알비노 유니콘 | 104자세/29원본 후보06. 가벼운기하PASS이나 엄격한읽기전용검증 Standalone PNG must contain one connected visible body 실패. 임포트·Main33 미시작. 경계/alpha조건완화금지. | source-archives/unicorn/final07-and-wolf-delta/unicorn-wolf-source-FINAL-PAUSED-delta07-index.json; runtime-evidence/unicorn-readonly-failure.json |
| monster:알비노 이구아나 알비노 이구아나 | 112자세/31PNG. Main headless865/OpenGL987·시간진행112자세 자동검사 PASS, 실제Main 최종 독립시각검토 미완료. 원본E/W지지반전/N뒤꿈치/S캔버스592 수정보존. | runtime-evidence/pending-runtime-manifest.json; source-archives/iguana-and-wilddog/index.json |
| monster:알비노 피쉬맨 알비노 피쉬맨 | 기존HOLD: 사망20/24자세반복 실패. 고유프레임조건을완화하지않음. | docs/remake/PR100_COMPLETION_REPORT.md |
| monster:커스번 커스번 | 원본은붉은뿔악마/RIGHT손큰도끼/LEFT열린손. E/W10 초기출력은축/보행이도끼에가려불명확, 전체모션/Main 미완료. | source-archives/agni-dryad-curseburn-stop/CURRENT-RESUME.json; 복원후 curse-burn-authoring/source-proof.json |

특히 batch32는 이구아나 112자세/31PNG, 아그니 104자세/16PNG다. 최종 headless 2,515검사(865+1,650), GL 2,765검사(987+1,778), 시간 진행 80,793검사/216자세/80역할, 자동 오류 0. 실제 Main 최종 독립 시각 검토는 미완료다. base 성공 232장과 첫 실패 232장의 전체 화면, temporal 216개 자세 crop·6개 전체 화면·검사 코드/보고서를 runtime 패키지에 보존했다.

아그니 최초 optional `cast` 별칭은 기존 엄격 `attack_N` 요구와 충돌하여 두 모드 각각 320오류였다. 동일 104자세/16원본PNG에서 선택 별칭만 빼고 새 v2 리소스로 임포트하여 기존 공격 fallback과 테스트를 유지했다. raw 글로벌 프로필의 slash/false를 실제 최종 런타임이라고 주장하지 않는다. full DB overlay가 실제 magic/floating=true/scale .52를 복원한 읽기 전용 추적도 보존했다.

유니콘 후보06 SHA는 `f5e2e96cee8d9c13e38a5285be2ba9b663abe93267c0ec35542bf6576d01de26`다. 가벼운 기하 검사를 통과했지만 엄격 읽기 전용 preflight에서 `ValueError: Standalone PNG must contain one connected visible body`로 실패했다. 예외만으로 특정 PNG의 원인을 단정하지 않는다. importer 1125행 조건을 완화하지 말고 다음 작업자가 원본의 alpha/연결 성분과 후보를 진단한다. 유니콘 임포트·Main33은 시작하지 않았다.

기존 소형 시험 경로도 유지한다: `batch22-preflight/ringmaster-wip/checkpoint.json`, `batch22-preflight/card-magician-wip/checkpoint.json`, `batch22-preflight/fishman-wip/checkpoint.json`, `resume-20261015/fisherman376-wip/diagnostic.json` (모두 original-based evidence 루트 기준). 407/352/7의 기존 HOLD를 이번 세션에서 새 실패 원인으로 추측해 바꾸지 않았다.

## 5. 사용한 제작·임포트·검증 명령

다음은 **이전 실행의 재현 명령과 다음 PR용 절차**다. 이 중단 대화에서는 다시 실행하지 않는다. 이미지 제작은 각 원본 패키지에 보존한 정확한 imagegen 프롬프트·참조 SHA·수정 이력을 사용했다. 원본 이미지의 단순 반전/부분 합성/빈 프레임으로 자세 수를 늘리지 않는다.

```sh
# 엄격 읽기 전용 후보 검증 (지원하는 pose_files/mixed 후보)
python3 tools/import_original_based_motion.py --root . --validate-candidate /ABS/reviewed-candidate.json --actor ACTOR --key 'monster:NAME'
# 다음 PR에서 독립 작화 승인 후에만 적용; 새 리소스 이름으로 기존 정상 파일 보호
python3 tools/import_original_based_motion.py --root . --candidate /ABS/reviewed-candidate.json --actor ACTOR --key 'monster:NAME' --apply
python3 tools/check_resource_integrity.py --root .
python3 tests/original_based_motion_import_test.py
python3 tests/test_original_based_pose_files.py
python3 tests/test_original_based_direction_canvases.py
python3 tests/eight_direction_coverage_audit_test.py
python3 tests/original_based_identity_link_test.py
```

위 Python 검사들은 중단 전에 50+29+13+6+9=107개 PASS 기록이 있다. 초기 잘못된 unittest discover가 `Ran 0`인 실행은 성공 수량에 포함하지 않고 정확한 직접 실행으로 다시 확인한 50개 결과를 보존했다. importer의 `--candidate`는 `--apply`를 생략해도 legacy 자산 파일을 쓸 수 있으므로 dry run으로 사용하지 않는다. 읽기 전용은 `--validate-candidate`다.

이번 엔진은 Godot 4.7.2 `/workspace/scratch/bin/godot-pr100`였다. 새 환경에서는 동일 버전을 준비하고 실행 파일 경로를 명시한다. 임시 사용자 데이터와 결과 경로를 실행마다 분리한다. 아래 `/ABS/NEW-*`는 반드시 새 절대 디렉터리로 치환한다.

```sh
# batch29 보스 base Main, 실제 AI/무기/특수/드랍/습득
env XDG_DATA_HOME=/ABS/NEW-H/data XDG_CONFIG_HOME=/ABS/NEW-H/config XDG_CACHE_HOME=/ABS/NEW-H/cache TWILIGHT_PR100_BATCH_ISOLATED=1 TWILIGHT_PR100_BATCH_CONFIG=res://tests/fixtures/pr100_batch29.json TWILIGHT_PR100_BATCH_REPORT=/ABS/NEW-H/report.json /ABS/godot-4.7.2 --headless --path . --script res://tests/run_original_based_boss_batch.gd
env DISPLAY=:99 LIBGL_ALWAYS_SOFTWARE=1 XDG_DATA_HOME=/ABS/NEW-R/data XDG_CONFIG_HOME=/ABS/NEW-R/config XDG_CACHE_HOME=/ABS/NEW-R/cache TWILIGHT_PR100_BATCH_ISOLATED=1 TWILIGHT_PR100_BATCH_CONFIG=res://tests/fixtures/pr100_batch29.json TWILIGHT_PR100_BATCH_REPORT=/ABS/NEW-R/report.json TWILIGHT_PR100_BATCH_CAPTURE_DIR=/ABS/NEW-R/captures /ABS/godot-4.7.2 --path . --rendering-method gl_compatibility --script res://tests/run_original_based_boss_batch.gd
# 별도의 시간 진행 Main: production MotionController가 각 역할의 전 native phase를 진행
env DISPLAY=:99 LIBGL_ALWAYS_SOFTWARE=1 XDG_DATA_HOME=/ABS/NEW-T/data XDG_CONFIG_HOME=/ABS/NEW-T/config XDG_CACHE_HOME=/ABS/NEW-T/cache TWILIGHT_PR100_TEMPORAL_ISOLATED=1 TWILIGHT_PR100_TEMPORAL_CONFIGS=/ABS/fixtures.json TWILIGHT_PR100_TEMPORAL_REPORT=/ABS/NEW-T/summary.json TWILIGHT_PR100_TEMPORAL_CAPTURE_DIR=/ABS/NEW-T/captures /ABS/godot-4.7.2 --path . --rendering-method gl_compatibility --script res://tests/original_based_temporal_main_test.gd
```

일반 batch32는 같은 환경 변수에서 `tests/run_original_based_batch.gd`를 사용했다. fixture32는 미완료라 활성 테스트 폴더에서 따로 보존했으며 runtime 패키지에서 복원한다. Rabbit328 추가 검증은 기존 `tests/original_based_transform_temporal_main_test.gd`(최종 61,539검사/112자세 PASS)다. 실행 원문·정확한 코드 사본·환경은 batch29의 `assembly-code/`, `temporal-main/`와 runtime 패키지에 보존했다. 테스트 fixture/모델의 통과를 실제 Main 시각 승인으로 대신하지 않는다.

coverage 재집계는 기존 `tools/audit_eight_direction_coverage.py`의 `--root . --output-dir /ABS/NEW-COVERAGE` 및 기존 canonical 255개 각각의 `--gameplay-report`를 사용한다. `coverage/coverage.json`의 `recorded_main_evidence` 255항목에서 `path`를 coverage 디렉터리 기준으로 resolve한다. 최근 두 보고서만 넣어 기존 253개 근거를 지우지 않는다. 배치 증거 패키징 코드는 `batch29/assembly-code/`에, coverage 최종 실행 결과는 `batch29/batch29-coverage-audit.log`에 있다.

## 6. 기존 품질 기준과 통과 조건

1. 실제 8방향 Idle/Walk/Attack/Hit/Death를 전부 확인한다. 기본 2/3/3/2/3이면 104자세, walk4이면 112자세이며 방향/역할별 native 자세와 전역 고유성을 검증한다.
2. 발·지면 접촉점, 그림자·몸통·골반·머리 축을 일관되게 유지한다. 몸/다리 분리, 공중 부양, 원본과 다른 몸체 성장, 후방 머리/몸통 혼동은 HOLD다.
3. 실제 반대 지지다리 보행, 온전한 프레임, 자연스러운 방향 전환을 확인한다. 단순 좌우 반전·같은 지지다리·깨진/빈/파편 프레임은 불합격이다.
4. 앞/뒤/좌/우를 구별하고 원본 외형·팔레트·고유 특징·무기 손을 보존한다. 참조 기반 새 작화는 원본 추출로 표기하지 않는다.
5. production Main.tscn의 원래 맵·실제 MotionController에서 전 역할을 확인한다. 공격 marker와 실제 접촉, 실제 피격·사망·드랍·수동 습득, 보스 기존 특수 동작을 확인한다.
6. 기존 고품질 완료 개체와 실제 게임 화면의 크기·접지·화풍·모션을 비교한다. 정적 기하, 엔진 자동검사, 시간 진행 검사, 작성자가 아닌 시각 검토를 별도 기록한다. 하나라도 미완료/실패면 HOLD다.
7. 기존 필수 검사·원래 HP/전투/AI·완료 자산을 유지한다. 맵 지형/타일/경계/월드·오만의 탑·아덴월드 수정/삭제, 3D 도입은 범위 밖이다.
8. CI는 배치/중요 체크포인트 단위로 수행하고 개체마다 전체 CI를 반복하지 않는다. Android APK 빌드·정적 검증과 실제 기기 실행을 구별한다.

## 7. CI·APK·main 충돌

관측 시각 **2026-10-15 22:34:40 UTC**, CI 대상은 **391종 커밋 `437680c6cdd40a7a6fc9958b2d267402303a8f50`**다. [전체 작업 상태·artifact 메타데이터](evidence/pr100-direction-fix/original-based/final-handoff-20261015/final-CI-observation.json).

| 검사 | 최종 관측 | 실행 |
|---|---|---|
| Android ARM64 APK 빌드·정적 검사 | SUCCESS | [38812389847](https://github.com/zoog136-hash/-/actions/runs/38812389847) |
| Resource integrity | SUCCESS | [38812386688](https://github.com/zoog136-hash/-/actions/runs/38812386688) |
| Godot Validate | SUCCESS | [38812382354](https://github.com/zoog136-hash/-/actions/runs/38812382354) |
| Animation Presentation Validate | **CANCELLED: 41작업 중 40 SUCCESS, 1 CANCELLED, 0 FAILURE** | [38812374975](https://github.com/zoog136-hash/-/actions/runs/38812374975) |

취소된 작업은 [Original-based Main / werewolf-ghost, job116688508119](https://github.com/zoog136-hash/-/actions/runs/38812374975/job/116688508119)다. 취소 원인은 확인하지 않았으며 추측하지 않는다. 중단 후 수동 취소/재실행/dispatch는 하지 않았다. 이전 관측 `remote-observation.json`의 IN_PROGRESS는 당시 이력으로 남긴다. 전체 CI 성공으로 바꾸지 않는다. 과거 389종 `5e6565f6933cc112fc09bc65390c078a1c7282bc`의 animation38802089176은 39작업 성공한 과거 결과이며 최신 392종 CI의 대체 증거가 아니다.

392종과 최종 인계 문서 커밋에 대한 새 전체 CI는 **미실행**이다. CI 대기를 이유로 보존 작업을 멈추거나 불필요하게 재실행하지 않았다. batch29는 로컬 기존 보스 runner로 검증했으나 CI matrix 신규 항목 연결은 중단 시 미완료다. 다음 PR에서 기존 보스 검사 경로를 유지하며 이 항목을 추가한 뒤 통합검증한다.

391종 APK artifact `12010710561`은 1,188,784,199바이트, digest `sha256:39eb91ff905228338612d8be6f7c7783d5153d2f1ee9501971d26e2ea1343925`다. export logs artifact `12010342008`도 있다. GitHub 보존 만료 2027-01-13이므로 필요시 새 작업자가 다운로드/장기 보관한다. 이 APK 전체 바이너리를 인계 Git 패키지에 복제하지 않았다. **Android 실제 기기 실행은 미검증**이다.

PR #100은 **open/draft, merged=false**, 기존 관측 `mergeable=false`, `mergeable_state=dirty`다. main 관측 SHA **`e2119c37293a783e93b421ee0055d1318271b071`**, 충돌 미해결. 문서 작성/보존 과정에서 main 병합·충돌 해결·PR 삭제/닫기/새 PR 생성을 하지 않았다. 최종 push 후 원격 HEAD와 문서 blob을 다시 읽어 전달한다. 최종 원격 확인의 정확한 SHA는 최종 사용자 보고를 따른다.

## 8. 새 PR에서 우선 진행할 항목

**새 PR용 정확한 제안 브랜치명: `feature/twilight-animation-remaining-20261015`. 현재 이 브랜치와 새 PR은 생성하지 않았다.** 다음 대화에서 위 최종 저장 커밋을 시작점으로 새 브랜치를 생성하고 기존 PR #100을 보존한다. 사용자 승인 전 main 병합 금지는 계속 유지한다.

1. 최종 저장 SHA/coverage392/잔여106 및 보존 manifest의 SHA를 대조한다. 자료를 새 scratch에 복원하며 정상 활성 자산을 덮어쓰지 않는다.
2. **기존 Main32 캡처부터 검토한다.** 이구아나/아그니의 전 8방향·5역할·실제 AI·시간 진행 화면을 원본과 기존 완료 개체에 비교한다. 통과 전 완료 수를 올리지 않는다. 실패한 자세만 근거와 함께 다음 제작 범위로 정한다.
3. 유니콘 strict single-body preflight 실패를 진단하고, 무덤269 앵커/외형과 데스 서번트104 최종 source 검토를 진행한다. 승인되지 않은 전체 모션의 재생성을 먼저 시작하지 않는다.
4. 들개/늑대/가디언/안나/커스번의 정확한 소형 시험 재개 파일을 읽는다. 중단 시 반환된 미검토 raw와 미실행 프롬프트를 구분한다. 도구 차단된 드라이어드는 성공한 출력이 있는 것으로 세지 않는다.
5. 일반 10~20종·보스3~5종을 목표로 하되 품질상 배치를 줄인다. 경량 전수검사→실제 Main→독립 시각검토→커밋·push→수량 갱신 순서다. CI 중 독립 제작은 가능하나 실패와 시각 HOLD를 성공으로 기록하지 않는다.
6. batch29 CI matrix를 기존 boss runner로 연결하고 취소된 werewolf-ghost 회귀 경로를 확인한다. 이후 중요한 체크포인트에서 기존 필수 CI/Android APK를 실행한다. 실기기는 직접 실행 전까지 미검증이다.

## 9. 미완료 106종 전체 목록

ID는 실제 animation profile의 안정 키다. 몬스터에는 임의 숫자 ID를 만들지 않고 `monster:이름`을 사용한다. HOLD 18종 + 미제작/검증된8방향미연결 88종이며 전부 완료 수에서 제외했다. 세부 원본 path·SHA·실패 이유·재개 파일은 [remaining106.json](evidence/pr100-direction-fix/original-based/final-handoff-20261015/remaining106.json)에 개체별로 있다.

| ID | 이름 | 분류 | 상태 |
|---|---|---|---|
| transform:393 | 해방된 할파스 | 영웅이상변신 | 미제작_검증된8방향미연결 |
| transform:267 | 지배자 기르타스 | 영웅이상변신 | 미제작_검증된8방향미연결 |
| transform:411 | 신화-투사(여) | 영웅이상변신 | 미제작_검증된8방향미연결 |
| transform:242 | 플래티넘 바포메트 | 영웅이상변신 | 미제작_검증된8방향미연결 |
| transform:142 | 신화-투사(남) | 영웅이상변신 | 미제작_검증된8방향미연결 |
| transform:141 | 신화-총사(여) | 영웅이상변신 | 미제작_검증된8방향미연결 |
| transform:140 | 신화-총사(남) | 영웅이상변신 | 미제작_검증된8방향미연결 |
| transform:139 | 신화-다크엘프(여) | 영웅이상변신 | 미제작_검증된8방향미연결 |
| transform:138 | 신화-다크엘프(남) | 영웅이상변신 | 미제작_검증된8방향미연결 |
| transform:375 | 전설의 낚시왕 폴 | 영웅이상변신 | 미제작_검증된8방향미연결 |
| transform:339 | 실렌의 파수꾼 | 영웅이상변신 | 미제작_검증된8방향미연결 |
| transform:338 | 그랑카인의 역린 | 영웅이상변신 | 미제작_검증된8방향미연결 |
| transform:191 | 하딘의 영혼 | 영웅이상변신 | 미제작_검증된8방향미연결 |
| transform:166 | 다크 하딘 | 영웅이상변신 | 미제작_검증된8방향미연결 |
| transform:407 | 화염의 엔트 | 영웅이상변신 | HOLD_기존보류 |
| transform:406 | 화염의 네루파 | 영웅이상변신 | 미제작_검증된8방향미연결 |
| transform:405 | 화염의 페어리 | 영웅이상변신 | 미제작_검증된8방향미연결 |
| transform:386 | 벚꽃 소녀 | 영웅이상변신 | 미제작_검증된8방향미연결 |
| transform:376 | 베테랑 낚시꾼 폴 | 영웅이상변신 | HOLD_기존실패 |
| transform:360 | 서커스단 카드 마술사 | 영웅이상변신 | HOLD_기존보류 |
| transform:359 | 서커스단 트롬본 인형 | 영웅이상변신 | 미제작_검증된8방향미연결 |
| transform:358 | 서커스단 드러머 | 영웅이상변신 | 미제작_검증된8방향미연결 |
| transform:357 | 서커스단 단장 | 영웅이상변신 | HOLD_기존보류 |
| transform:352 | 알비노 뿔 개구리 | 영웅이상변신 | HOLD_기존보류 |
| transform:276 | 메이드 안나 | 영웅이상변신 | HOLD_외형보행파일럿 |
| transform:269 | 거대한 무덤 가디언 | 영웅이상변신 | HOLD_앵커외형수정 |
| transform:268 | 천상의 수호 기사 | 영웅이상변신 | 미제작_검증된8방향미연결 |
| transform:260 | 각성 켄라우헬 | 영웅이상변신 | 미제작_검증된8방향미연결 |
| transform:231 | 유니크 랜서 | 영웅이상변신 | 미제작_검증된8방향미연결 |
| transform:198 | 토끼 소녀 | 영웅이상변신 | 미제작_검증된8방향미연결 |
| transform:197 | 사단장 하퍼 | 영웅이상변신 | 미제작_검증된8방향미연결 |
| transform:182 | 랜스 마스터(블루) | 영웅이상변신 | 미제작_검증된8방향미연결 |
| transform:179 | 랜스 마스터(레드) | 영웅이상변신 | 미제작_검증된8방향미연결 |
| transform:155 | 데스 | 영웅이상변신 | 미제작_검증된8방향미연결 |
| transform:123 | 이실로테(총) | 영웅이상변신 | 미제작_검증된8방향미연결 |
| transform:16 | 각성:발록 | 영웅이상변신 | 미제작_검증된8방향미연결 |
| transform:11 | 베레스 | 영웅이상변신 | 미제작_검증된8방향미연결 |
| transform:9 | 헬바인 | 영웅이상변신 | 미제작_검증된8방향미연결 |
| transform:7 | 바포메트 | 영웅이상변신 | HOLD_기존보류 |
| transform:4 | 천상의 기사 | 영웅이상변신 | 미제작_검증된8방향미연결 |
| monster:바포메트 | 바포메트 | 보스 | 미제작_검증된8방향미연결 |
| monster:테베 아누비스 | 테베 아누비스 | 보스 | 미제작_검증된8방향미연결 |
| monster:테베 호루스 | 테베 호루스 | 보스 | 미제작_검증된8방향미연결 |
| monster:테베 오시리스 | 테베 오시리스 | 보스 | 미제작_검증된8방향미연결 |
| monster:공포의 아그니 | 공포의 아그니 | 일반몬스터 | HOLD_시각검토대기 |
| monster:얼음 여왕 | 얼음 여왕 | 보스 | 미제작_검증된8방향미연결 |
| monster:베레스 | 베레스 | 보스 | 미제작_검증된8방향미연결 |
| monster:아크모 | 아크모 | 보스 | 미제작_검증된8방향미연결 |
| monster:제로스 | 제로스 | 보스 | 미제작_검증된8방향미연결 |
| monster:그림 리퍼 | 그림 리퍼 | 보스 | 미제작_검증된8방향미연결 |
| monster:말하는 섬 들개 | 말하는 섬 들개 | 일반몬스터 | HOLD_보행소형시험 |
| monster:검은숲 늑대 | 검은숲 늑대 | 일반몬스터 | HOLD_보행제작중 |
| monster:검은숲 거미 | 검은숲 거미 | 일반몬스터 | 미제작_검증된8방향미연결 |
| monster:에바 왕국 상어전사 | 에바 왕국 상어전사 | 일반몬스터 | 미제작_검증된8방향미연결 |
| monster:에바 왕국 심해어인 | 에바 왕국 심해어인 | 일반몬스터 | 미제작_검증된8방향미연결 |
| monster:오만의 탑 공포의 악마 | 오만의 탑 공포의 악마 | 일반몬스터 | 미제작_검증된8방향미연결 |
| monster:지룡의 둥지 대지수호자 | 지룡의 둥지 대지수호자 | 일반몬스터 | 미제작_검증된8방향미연결 |
| monster:테베라스 아누비스 수호자 | 테베라스 아누비스 수호자 | 일반몬스터 | 미제작_검증된8방향미연결 |
| monster:테베라스 호루스 수호자 | 테베라스 호루스 수호자 | 일반몬스터 | 미제작_검증된8방향미연결 |
| monster:아틀란티스 심해창병 | 아틀란티스 심해창병 | 일반몬스터 | 미제작_검증된8방향미연결 |
| monster:아틀란티스 심연수인 | 아틀란티스 심연수인 | 일반몬스터 | 미제작_검증된8방향미연결 |
| monster:마계 악마전사 | 마계 악마전사 | 일반몬스터 | 미제작_검증된8방향미연결 |
| monster:천상계 성광기사 | 천상계 성광기사 | 일반몬스터 | 미제작_검증된8방향미연결 |
| monster:천상계 천사궁수 | 천상계 천사궁수 | 일반몬스터 | 미제작_검증된8방향미연결 |
| monster:가디언 | 가디언 | 일반몬스터 | HOLD_소스파일럿 |
| monster:공포의 레서 데몬 | 공포의 레서 데몬 | 일반몬스터 | 미제작_검증된8방향미연결 |
| monster:공포의 뱀파이어 | 공포의 뱀파이어 | 보스 | 미제작_검증된8방향미연결 |
| monster:공포의 켈베로스 | 공포의 켈베로스 | 일반몬스터 | 미제작_검증된8방향미연결 |
| monster:교만의 왕자 데우스 | 교만의 왕자 데우스 | 보스 | 미제작_검증된8방향미연결 |
| monster:교만의 제노사이더 | 교만의 제노사이더 | 일반몬스터 | 미제작_검증된8방향미연결 |
| monster:교만의 제라키엘 | 교만의 제라키엘 | 일반몬스터 | 미제작_검증된8방향미연결 |
| monster:교만의 킬 하운드 | 교만의 킬 하운드 | 일반몬스터 | 미제작_검증된8방향미연결 |
| monster:그리미 | 그리미 | 일반몬스터 | 미제작_검증된8방향미연결 |
| monster:놀 | 놀 | 일반몬스터 | 미제작_검증된8방향미연결 |
| monster:로머 | 로머 | 일반몬스터 | 미제작_검증된8방향미연결 |
| monster:분노의 데스 도그 | 분노의 데스 도그 | 일반몬스터 | 미제작_검증된8방향미연결 |
| monster:분노의 데스 라이더 | 분노의 데스 라이더 | 일반몬스터 | 미제작_검증된8방향미연결 |
| monster:분노의 데스 리퍼 | 분노의 데스 리퍼 | 일반몬스터 | 미제작_검증된8방향미연결 |
| monster:분노의 데스 서번트 | 분노의 데스 서번트 | 일반몬스터 | HOLD_소스최종검토대기 |
| monster:사라만다 | 사라만다 | 일반몬스터 | 미제작_검증된8방향미연결 |
| monster:스파이더 | 스파이더 | 일반몬스터 | 미제작_검증된8방향미연결 |
| monster:알비노 데몬 | 알비노 데몬 | 보스 | 미제작_검증된8방향미연결 |
| monster:알비노 드라이어드 | 알비노 드라이어드 | 일반몬스터 | HOLD_생성도구차단 |
| monster:알비노 디어 | 알비노 디어 | 일반몬스터 | 미제작_검증된8방향미연결 |
| monster:알비노 몽크 | 알비노 몽크 | 일반몬스터 | 미제작_검증된8방향미연결 |
| monster:알비노 변이된 골렘 | 알비노 변이된 골렘 | 일반몬스터 | 미제작_검증된8방향미연결 |
| monster:알비노 심해어 | 알비노 심해어 | 일반몬스터 | 미제작_검증된8방향미연결 |
| monster:알비노 유니콘 | 알비노 유니콘 | 보스 | HOLD_임포터실패 |
| monster:알비노 이구아나 | 알비노 이구아나 | 일반몬스터 | HOLD_시각검토대기 |
| monster:알비노 피닉스 | 알비노 피닉스 | 보스 | 미제작_검증된8방향미연결 |
| monster:알비노 피쉬맨 | 알비노 피쉬맨 | 일반몬스터 | HOLD_기존보류 |
| monster:에스카로스 치프 | 에스카로스 치프 | 일반몬스터 | 미제작_검증된8방향미연결 |
| monster:오만한 아스모데우스 | 오만한 아스모데우스 | 일반몬스터 | 미제작_검증된8방향미연결 |
| monster:오만한 우그누스 | 오만한 우그누스 | 보스 | 미제작_검증된8방향미연결 |
| monster:오만한 플레임 팽 | 오만한 플레임 팽 | 일반몬스터 | 미제작_검증된8방향미연결 |
| monster:왜곡의 메두사 | 왜곡의 메두사 | 일반몬스터 | 미제작_검증된8방향미연결 |
| monster:왜곡의 제니스 퀸 | 왜곡의 제니스 퀸 | 보스 | 미제작_검증된8방향미연결 |
| monster:왜곡의 타란툴라 | 왜곡의 타란툴라 | 일반몬스터 | 미제작_검증된8방향미연결 |
| monster:욥니르 | 욥니르 | 보스 | 미제작_검증된8방향미연결 |
| monster:잔혹한 아이리스 | 잔혹한 아이리스 | 보스 | 미제작_검증된8방향미연결 |
| monster:질투의 공주 이자벨 | 질투의 공주 이자벨 | 보스 | 미제작_검증된8방향미연결 |
| monster:질투의 아타바크 | 질투의 아타바크 | 일반몬스터 | 미제작_검증된8방향미연결 |
| monster:커스번 | 커스번 | 일반몬스터 | HOLD_초기소스시험 |
| monster:탐욕의 엔트키아 | 탐욕의 엔트키아 | 일반몬스터 | 미제작_검증된8방향미연결 |
| monster:탐욕의 여왕 벨리엘 | 탐욕의 여왕 벨리엘 | 보스 | 미제작_검증된8방향미연결 |
| monster:탐욕의 코아쿡 | 탐욕의 코아쿡 | 일반몬스터 | 미제작_검증된8방향미연결 |

이 문서와 보존 패키지를 기존 브랜치에 정상 커밋·push한 뒤 원격 반영을 확인하고 현재 대화의 제작을 종료한다. reset/clean/force push, 기존 PR 종료, 새 PR 제작은 하지 않는다.
