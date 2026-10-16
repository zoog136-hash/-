# TWILIGHT 잔여 106종 후속 작업 — 2026-10-16

사용자 최신 지시: 하던 검증 수정을 커밋으로 보존하고 PR #100 병합을 중단한다. 별도 후속 PR에서 제작을 먼저 진행한다. PR #100은 병합하지 않았다.

후속 브랜치: `feature/twilight-remaining106-20261016`. PR #100의 미병합 392종을 그대로 승계하기 위해 `feature/twilight-animation-20261013`의 `f43c22daa6e9967185465a98abd1b8840d7593a0`를 기반으로 한다. 현재 후속 PR의 비교 기준도 이 브랜치다. main의 병합 완료를 가정하지 않는다.

기존 작업은 `a0ad979eb6325d72f7a36e9a24eaa1b7c439aaed`에 보존했고, 원격의 `2a7f8b4` 및 `f43c22d` 검증 수정까지 후속 브랜치에 승계했다. 변경은 검증 도구·테스트·증거 문서에 한정한다. 정상 392종 에셋·게임 데이터·맵·전투 공식·기존 255개 canonical Main 보고서는 변경하지 않는다.

현재 완료는 **392/498**, 잔여 **106 = HOLD 18 + 미제작/미연결 88**이다. 원본 분류는 `original-based/final-handoff-20261015/remaining106.json`을 그대로 유지한다. 106개 원본 참조의 실제 SHA-256을 다시 확인한 결과는 `evidence/pr100-direction-fix/remaining106-resume-20261016/remaining-source-preservation.json`에 있다.

기존 검증 수정의 정리:

- 신규 맵 위 실제 Main 캡처 위치를 찾는 후보만 늘리고 원래 지형·전경·다른 개체 거리 검사는 그대로 유지한다.
- 실제 사용자 저장 폴더 격리와 Windows 경로 검증을 유지하며, 변신 회귀는 기존 10종 전체 fixture를 실행한다.
- 승인된 과거 provenance의 실제 행/원본 PNG/Atlas 영역/기존 앵커를 읽는다. 누락·중복·변조는 실패한다. 기존 남성 리퍼의 96자세 예외는 기존 개체 ID·경로·provenance SHA가 정확히 일치할 때만 인정한다. 신규 개체의 프레임 기준은 바꾸지 않는다.
- 실제 변신 10종 재생에서 엔진 606,718검사/1,032 native phases는 통과했으나 stdout 요약에 `failures` 배열이 없어 엄격한 공용 runner가 실패 처리했다. 생산자가 실제 배열을 기록하도록 수정하며, 누락 배열을 허용하는 파서 완화는 하지 않는다. 수정 후 전체 재실행 결과는 checkpoint에 별도로 기록한다.
- 충돌 해결 중 잘못 잘린 중간 테스트 파일은 로컬 runner가 즉시 실패시켰다. 원본 3개 커밋에서 재구성하여 전체 검사 본문을 복구했다. 이 중간 실패 로그도 scratch에 보존했다. 최신 runner 단위검사 31개는 통과했다. 이는 실제 게임 검사와 구분한다.

WIP 복원 및 다음 재개 위치:

1. 이구아나: 112자세 읽기 전용 검사 통과. 별도 정적/시간순 프레임 검토 기록은 있으나 최신 코드에서 실제 Main AI·접촉·피격·사망 화면의 최종 검토가 남아 **HOLD**.
2. 아그니: 보존된 104자세 및 16개 PNG의 SHA 일치. 별도 프레임 검토 기록은 있으나 기존 whole-sheet 형식의 안전한 `--validate-candidate` 지원과 최신 Main 최종 검토가 남아 **HOLD**. `--candidate`만 실행하는 방법을 dry run으로 사용하지 않는다.
3. 유니콘: 9개 단독 자세 중 8개가 기존 alpha>100 단일 몸체 검사에서 분리 픽셀로 실패한다. 선택된 이동 원본 PNG 2개는 복원 자료에서 찾지 못했다. 기존 원본/실패 자료를 보존하고 실패 자세만 추후 수정한다. **HOLD**.
4. 거대한 무덤 가디언: base 636개 및 delta 31개를 SHA 확인하여 복원했다. 앵커·외형·후속 원본 선택 검토가 남아 **HOLD**.
5. 분노의 데스 서번트 및 기존 파일럿: 복원 자료와 실패 이력을 유지하고 독립 원본/Main 검토를 먼저 수행한다.

현재 환경의 복원 경로는 `/workspace/scratch/pr100-restored-20261016`, `/workspace/scratch/pr100-authoring-restored-20261016`, `/workspace/scratch/pr100-tomb269-restored-20261016`이다. 이 경로가 다음 환경에도 존재한다고 가정하지 않는다. 영구 원본은 기존 FINAL_HANDOFF에 명시된 저장소의 ZIP/CAS 분할 파일이며 기존 복원 스크립트와 SHA 증거를 이용해 복원한다. 현 환경 복원 증거와 실패 진단은 `merge-final-20261016`에 보존한다.

## 후속 PR에서 실제 진행한 작업

초안 PR [#122](https://github.com/zoog136-hash/-/pull/122)를 생성하고 `5018aac`까지 push했다. PR #100에는 push하거나 병합하지 않았다.

whole-sheet 후보도 기존의 동일한 분석·중복/alpha/영역/앵커·원본·출력 충돌·프로필 보존 검사를 모두 수행한 뒤 파일 생성 직전에 반환하는 `--validate-candidate` 경로를 추가했다. 기존 설치 동작과 생성되는 바이트는 유지한다. `--candidate`만 사용하는 명령은 여전히 파일을 만들 수 있으며 dry run이 아니다. 임의 input_mode는 거부한다.

기존 importer와 새 읽기 전용 성공/실패/충돌/CLI 보존 검사 54개, 기존 pose-file 및 방향 입력 검사 42개가 통과했다. 아그니 실제 보존 후보는 이 경로에서 104자세 PASS, `read_only=true`, `applied=false`, `completed_added=0`이다. 16개 원본 PNG는 기존 복원 runtime과 SHA가 모두 같다. 이구아나·아그니의 production 후보 폴더는 생성되지 않았다.

보존된 아그니 실제 Main 전투 스크린샷 중 나무에 가려 개체를 명확히 검토할 수 없는 장면이 확인됐다. 정적 샘플과 자동 PASS만으로 완료 승인하지 않는다. 실제 production Main을 복사한 별도 검증 경로 `/workspace/scratch/remaining106-main-review-20261016/project`에 기존 HOLD 2종의 보존 프로필만 겹쳐 최신 재현을 준비한다. 실제 저장소의 profiles와 승인 자산은 그대로 유지하며, 모든 게임 검사와 시각 증거가 충족되기 전에는 연결 완료로 승격하지 않는다.

## 이번 커밋 정리 시점의 검증 결과

- 후속 코드 `36795804a75c893db9680d8553d0929d90427c79`까지 원격 전달 완료.
- 기존 변신 10종 전체 실제 Main 재실행: **606,800검사, 1,032 native phases, 실패 0**. 엄격한 공용 wrapper도 PASS. 96자세 남성 리퍼 1종과 104자세 기존 9종을 실제 기록 그대로 검증했다. 이 시간 진행 검사는 headless이며 OpenGL 시각 증거로 주장하지 않는다.
- 함께 실행한 Godot 검사 전체 **5/5 PASS, skip 0, 미실행 0**. 경로 격리 13, 원본 프레임 336, 기존 보스 기술/맵 계약 154, 아이콘 27 검사를 포함한다.
- 격리 복사본의 이구아나·아그니 실제 Main headless 재현: **2,499검사, 실패 0**. 각각 AI 8방향, 112/104 자세 샘플, 실제 원본 HP/무기 피해/피격/사망/지면 드랍/수동 습득을 통과했다. 별도 복사본의 보호 파일 5,282개 SHA가 실제 작업 저장소와 같으며 변경한 프로필은 보존 WIP 2키뿐이다. 실제 저장소에는 두 후보를 연결하지 않았다.
- 이구아나·아그니의 최신 OpenGL 전투/생명주기 시각 검토는 아직 남았다. 기존 가려진 아그니 화면을 합격 증거로 사용하지 않는다. 두 개체 모두 HOLD, **신규 완료 0종**, 총 완료 392종이다.
- 새 코드 HEAD의 GitHub 확인 당시 검사 1개 대기. 전체 필수 CI 성공을 선언하지 않는다. Android APK 신규 빌드·실제 기기 검사는 미검증이다.

원본 로그·보고서·격리 복사 SHA 증거는 `remaining106-resume-20261016/latest-Main-validation.zip`에 CRC 및 SHA-256 확인 후 저장했다. 파일별 목록과 정확한 검증 범위는 `latest-Main-validation-manifest.json`에 있다. 다음 작업은 별도 복사본에서 **새 빈 사용자 폴더**로 OpenGL batch32를 실행하고 가림 없는 실제 AI/접촉/피격/사망/드랍/습득 화면을 독립 검토하는 것이다. 검사나 맵을 바꾸어 통과시키지 않는다.

## PR #122 실제 제작 재개 — batch01

사용자의 긴급 재개 지시에 따라 중간 체크포인트에서 종료하지 않고 실제 OpenGL 검증을 실행했다. 이구아나112/아그니104 전체 native 자세의 실제 Main 시간 진행80,793검사, 원래 게임 OpenGL2,749검사, 추가 가림 없는 실제 AI·접촉·피격·사망3단계·드랍·수동습득3,395검사를 모두 통과했다. 같은 Main에서 기존 완료 지옥의 쿠거와의 비교295검사와 별도 독립 사후 시각 판정도 PASS다. UI가 근접했던 초기 비교 화면을 승인에 쓰지 않고 카메라만 조정하여 미니맵 가림 검사를 추가했다. 기존 검사·맵·전투 코드는 유지했다.

최종 독립 시각 PASS를 기록한 뒤 읽기 전용 검사를 거쳐 production에 두 개체를 연결했다. 원본 PNG47개와 두 SpriteFrames 모두 검토한 WIP의 SHA와 일치하며 재생성/리사이즈하지 않았다. 다른1,447개 기존 프로필 값은 모두 그대로이고 두 실제 연결 프로필도 검토한 격리 Main과 같다. production import 후 부팅·8방향·native 확장·original-based canvas4종의 실제 프로세스 종료코드0과4/4 PASS를 확인했다. 첫 import의 sandbox 로컬 editor socket 차단 로그도 보존하고, 네트워크 사용이 허용된 환경에서 오류 없는 import를 확인했다. 실패 판정은 삭제/필터링하지 않았다.

`docs/remake/evidence/pr122-remaining106/batch01/`에 개체별 독립 판정, canonical을 덮어쓰지 않은 새 Main4개 보고서, 보존 SHA, 실제 framebuffer378개·QA보드15개 등을 분할 ZIP15개(469,316,628바이트)로 저장했다. 모든 ZIP CRC/멤버 SHA를 확인했다. 새 배치 CI workflow는 실제 Main headless·OpenGL·216자세시간진행·기존완료개체비교를 그대로 실행하며 기존 필수 workflow를 대체하지 않는다.

**runtime 연결394 / 최종 완료392 / 로컬PASS이나 CI·APK대기2 / HOLD16 / 미제작·미연결88**로 구분한다. 필수 CI와 APK가 충족되기 전까지 이2종을 최종 완료로 올리지 않는다. Android 실기기는 계속 미검증이다. CI 대기 중 데스 서번트의 보존104자세 독립 원본 검토를 진행하고 있으며, 다음으로 격리 Main에서 모델·앵커·실제 근접 접촉을 검증한다. 유니콘의 누락 원본2개와 실패자세8개, 무덤 가디언의72개 미검토 nonwalk 앵커 때문에 다른 제작을 멈추지 않는다. PR #100 병합과 새 PR 생성은 하지 않는다.

자동·정적·시간 진행·실제 Main headless/OpenGL·독립 시각 검토를 분리한다. 전 항목 통과 전에는 연결 완료 수량을 올리지 않는다. 최신 HEAD CI와 Android APK는 별도 확인 대상이며 실제 Android 기기 검사는 미검증이다. PR #100 병합 작업은 재개하지 않는다.

## Batch02 — continued actual Main and local WIP repair (UTC 2026-10-16 05:59)

- Last pushed production checkpoint: f244b7155fa0d6334ec06e654232b52926db3a54 on existing PR122; PR100 merge stays stopped.
- Death Servant104 isolated trial: actual AI/lifecycle1412 automatic checks, continuous native OpenGL40364 automatic checks/all104 phases, same-Main Hell Cougar baseline comparison. Separate visual HOLD at S impact: claw visibly above player on actual damage contact. No production connection. Repaired only that single source pose; foreground hand perspective still unapproved, other103 original poses unchanged. Preserve automatic PASS separately from final visual HOLD.
- Tomb269: generated three previously unstarted NE walk palette repairs; strict one-body/whole-region PASS, silhouette overlap98.7–99.1% with prior poses. Updated51-source112-slot SOURCE-ONLY candidate (local E weapon/NE heel/NE palette fixes) passes unchanged geometry/full-source/uniqueness guards. All final visual flags FALSE; remaining72 nonwalk roots, model scale and actual Main not approved.
- Unicorn local alpha correction failed (9→35 components,450171 main foreground pixels changed). Raw output/request preserved, no threshold or original edits. Two missing approved source PNGs remain HOLD.
- Delivered all314 servant evidence members in nine lossless tar.zst parts, every member SHA verified. Additional production diagnostics ZIP delivers ignored logs including failed sandbox import and successful confirmation. No protected game/runtime changes in batch02. QA baseline comparison now accepts an optional bounded unique JSON subject list; existing two-subject defaults remain.
- Fully qualified392; connected394; local PASS pending CI/APK2; HOLD16; not-authored/not-connected88. f244 resource CI SUCCESS, actual-Main running, other required workflows/APK queued; Android physical device UNVERIFIED. CI waiting and actor HOLD are not stop conditions: continue single-pose correction and next WIP.
