> 최신 상태: 사용자 요청으로 제작·검증을 중단하고 전체 작성물을 저장했다. [중단 저장 인계](TWILIGHT_PR122_STOP_20261019.md)를 먼저 읽는다. 전체 로컬 회귀와 현재 HEAD 전체 CI는 미완료다.

# PR #122 — 2026-10-19 사용자 요청 중단·저장 및 새 대화 인계

> 후속 제작 재개 기록: [batch17 최신 상태·원화·검증](TWILIGHT_PR122_BATCH17_20261019.md). batch17 신규 승인0/누적405를 유지하며 미승인 원화67장과 실패를 보존했다. 아래는 원래 중단 저장 기록이며 원문을 유지한다. 최신 HEAD의 전체 CI는 PR/Actions에서 별도로 확인한다.

사용자 최종 지시는 “지금 하던거 그대로 저장하고 커밋해 그리고 새대화로 이어 나갈수 있도록 프롬프트 줘”다. 이 저장에서는 추가 제작을 멈춘다. 다음 대화에서 재개 지시를 받으면 아래 상태부터 이어간다. 기존 PR #122만 사용하고 main 병합, force push, rebase, 다른 PR 수정은 하지 않는다.

저장소 `zoog136-hash/-`, PR https://github.com/zoog136-hash/-/pull/122, 브랜치 `feature/twilight-remaining106-20261016`, 대상 `feature/twilight-animation-20261013`. 이번 제작 재개 시작 SHA는 `baf194e17d2dc0d8c8fd38a11218060e7107e26d`, 마지막 로컬 제작 안전 커밋은 `d069778458783e054d4755448f00f9dd18a04e86`다. 이 인계 파일을 포함하는 최신 커밋은 `git log -1 --format=%H -- docs/remake/TWILIGHT_PR122_RESUME_20261019.md`로 확인하고 실제 PR 원격 HEAD와 대조한다.

## 집계와 보존

전수 대상 498종의 중복 없는 마지막 로컬 승인 상태는 정상 391, 기존 프레임 부족 14, SOURCE_HOLD 16, IN_PROGRESS 1, NOT_AUTHORED 76이다. 승인 이력 누적 405에는 프레임 부족 14가 포함된다. 미승인 잔여는 93이다. 이번 재개에서 6종을 실제 Main/연속 재생 검토 후 연결했으며, 새로운 원화 296자세와 별도 팔레트 수정 3건을 제작했다. 이 숫자는 최종 CI 통과나 사용자 시각 승인 수가 아니다. 병행 원격의 대체 외형 연결은 추가 완료로 합산하지 않는다.

완료 6종: `monster:알비노 변이된 골렘` 144자세, `monster:알비노 디어` 144자세, `transform:269` 거대한 무덤 가디언 112자세 복구·보완, `monster:스파이더` 128자세, `monster:검은숲 거미`와 `monster:왜곡의 타란툴라` 각 기존 동일 참조 확인 후 스파이더 텍스처 공유. 두 거미 파생 연결은 새 원화 0장이다. 무덤 가디언은 기존 WIP 복구이며 112자세를 신규 제작했다고 계산하지 않는다.

실물은 `assets/actors/eight_direction/original_based/`의 `albino_mutated_golem_batch16_authored`, `albino_deer_batch16_authored`, `tomb_guardian269_batch16_repaired`, `spider_project_batch16_authored`, `dark_forest_spider_batch16_project`, `distorted_tarantula_batch16_project`에 있다. `docs/remake/evidence/pr122-remaining106/batch16/`의 개체별 `*-completion-decision.json`, `*-source-preservation.json`, Main/Temporal reports, `individual-approvals.json`을 확인한다. 모든 완료본을 다시 생성하거나 일괄 덮어쓰지 않는다.

마지막 제작 승인 전수 원장은 `batch16/all498-after-spider-family.json`이다. 병행 원격 통합 후의 연결 변화와 승인 여부는 별도 `authoring-stop-20261019/remote-integration.json`을 확인한다. 과거 원장에 상속된 CI_pending=0은 새 HEAD의 통합 CI 성공을 뜻하지 않는다.

저장 시 원격은 다른 작업 5커밋이 추가된 `a3eafeeb7fe81c805e15d230241016221d6d5c5f`였다. 같은 PR 브랜치의 정상 merge로 두 이력을 보존했다. 로컬 변경 프로필 6개와 원격 변경 54개 중 겹친 골렘·거미 4개는 위 실제 Main 검증 제작본을 유지했고, 나머지 원격 50개 프로필은 정확히 보존했다. 대체 외형 41개 원장 중 겹친 4개에는 `superseded_by_native_pack`와 실제 승인 근거를 기록했고 나머지 37개 후보 및 병행 SPX 선택 미리보기도 유지했다. 원격의 이름·색상 공유는 추가 완료 0종으로 집계했다. 통합 뒤 실제 Main·전수 연결·전체 CI는 사용자 중단 저장 지시에 따라 미실행이며 다음 제작의 로컬 검증에 포함한다. 두 Python 단위 세트 6+9건, 병행 공유 연결 정적 검사와 필수 리소스 검사는 저장 시 PASS다.

## 바로 이어갈 미완성 제작

`batch16/authoring-stop-20261019/preservation-manifest.json`이 모든 새 WIP PNG 18장(몽크 16, 여왕 2), 정확한 이미지 생성 요청·입력 경로, SHA, 실패 이유 및 복사된 제작/검증 스크립트의 원장이다. 원본 바이트를 변경하거나 폐기하지 않았다. `requests/`의 인덱스는 이전 절대 경로도 보존한다. 새 환경에서는 매니페스트의 Git 경로로 복원하고 SHA를 확인한다. `workflow-drivers/`는 당시 드라이버의 원문이며 `/workspace/runtime/batch16` 경로를 새 환경에 맞게 복원해야 한다. 이미 완료된 promote 스크립트는 재실행하지 않는다. 실패한 `stage_monk.py`의 긍정적 review 필드는 제안 입력일 뿐 승인 증거가 아니다.

1. **알비노 몽크**는 인간 수도승이 아니라 원본 `atlas_3.png region[0,899,328,300]`의 흰 고릴라다. E/SE/S/SW v02 + W/NW/N/NE 총 8장으로 128자세 기하 검사는 통과했지만 SW_v02의 idle 2개가 반대쪽을 본다. 올바르게 왼쪽을 보는 SW_v03과 2열 SW_v04는 foreign-body rectangle 검사에 실패했다. 단독 SW idle 2장은 alpha>100, 8-neighbor 몸체 수 4/25로 엄격한 단일 몸체 조건에 실패했다. 보행 반대 지지발과 몸통 동작은 시각 검토 미완료다. 제작용 프로필 연결·Main 검증·완료 승인은 없다.
2. **얼음 여왕**은 기존 검정/금색/보라 날개, 은발, 왼손 지팡이, 오른쪽 슬릿 다리를 유지한다. 새 E/S 각 16자세만 있다. E는 foreign-body rectangle 실패, S는 16개 대신 12개로 합쳐진 몸체이며 death0에 여분 지팡이도 보인다. 나머지 6방향은 미제작이다. 기존 batch14 idle과 실패 기록을 보존하며 Main/프로필 연결은 없다.
3. 키가 크고 넓은 개체에서 16자세 한 시트가 반복해서 겹치면 검사를 완화하지 말고 역할·방향별 넓은 원본 시트로 나눈다. 골렘/디어의 방향별 3개 공격과 분리된 6~8개 보행 구조를 재사용한다. 이미지 이동/복제/반전을 원본 동작으로 표시하지 않는다. 픽셀 정리로 엄격한 몸체 검사를 우회하지 않는다.
4. 새 `phase_grid2`는 2열 시간 순서 입력을 지원하고 phase-grid 단위 6검사를 통과했다. 완성 기준 104/112/128/144자세의 엄격한 일대일 교체 경로는 9검사를 통과했다. 이것은 여왕/몽크 원화 통과를 뜻하지 않는다. 2열의 실제 중심이 고정 셀 중심과 다를 수 있으므로 필요한 경우 검토한 명시적 source_anchors를 사용하며 프레임별 임의 배율 변경은 금지한다.
5. 그 뒤 잔여 93종 및 기존 프레임 부족 14종의 충분한 원본을 배치 처리한다. 실패 개체를 이유와 함께 격리하고 제작 가능한 나머지를 계속한다. 프레임 부족 14 ID: 258,412,288,401,176,351,349,328,249,218,173,167,110,2. 기존 도구리/사신 보행·run 후보와 HOLD/UNRECOVERED는 완료로 바꾸지 않는다.

## SPX와 비공개 자료

이전 단계에서 1,700 SPX/44그룹, 14,534 레코드/14,304 유효 이미지/230 의도될 수 있는 빈 레코드를 검증했다. 본체 21624/21653은 기존 498종에 임의 대응하지 않는다. 36효과 그룹은 442 유효/486 레코드 후보 재생 검증이며 정확한 게임 스킬 연결은 0이다. CSB 후보 3개, OGG 이벤트 참조 4개, 미확보 10831/10832 등은 HOLD다. 원본 ticks·마커·run 정의·선택 레이어 코드는 이미 구현되었으나 시간/레이어 종합 승인은 PARTIAL이다.

Drive 원본 폴더: https://drive.google.com/drive/folders/11fcRnrEJAanWR6fIYaor4U34_ib1DgcH ; A3: https://drive.google.com/drive/folders/1KQ42RjHIfL3eMUhietgzQ8lru4smFoW0 ; 검증 키트: https://drive.google.com/drive/folders/10oMrKaN0HKrY-WRFFNGi6HmBIYL_NPvP . A2002 ZIP SHA `d5438f74b486e42481ad34badb527794bbda10a591388c2177e580f2af8c34d7`, patch_1 ZIP SHA `7ffef58d56fcbb162897dcf846633f1dd12b97851d0e0894ad7c510656fbc7d0`. 같은 SHA는 캐시를 재사용한다.

제3자 원본 SPX/PNG/CSB/OGG와 인증서·비밀은 공개 Git에 추가하지 않는다. `/workspace/private-spx`와 큰 Main 캡처·캐시는 로컬에 남아 있으며 새 환경에 영구 전달됐다고 보고하지 않는다. 비공개 백업 ZIP(488,139,444바이트, SHA `965f51e3f8ff7e61b3e769b35e4788bec2d8c6672ef8a363df39c4b6fdd6ddde`) 업로드는 이전 자동 승인 검토에서 거절되어 **NOT_DELIVERED**다. 승인 없이 재시도하거나 우회하지 않는다. 원본 Drive ZIP은 별도이며 접근 가능 여부를 다시 확인한다. 이전 미커밋 사신 PNG 2장과 QA 초안은 여전히 UNRECOVERED다.

## 검증과 최종 저장

Godot 기준 4.7.2 official ed1daf0bf, 실제 Main 및 OpenGL3 Compatibility를 사용했다. 로컬 6종의 Main/연속 전 프레임 검증은 개별 원장에 보존했다. 120Hz QA 시계는 실시간 성능 보증이 아니다. 무덤 가디언 원본 논리 RGBA 약306MiB, Main maxRSS 약1.51GiB로 Android 메모리 합격을 주장할 수 없다. VRAM 미측정, Android 실기기 NOT_RUN.

저장 전 필수 원본 무결성 검사는 723시트/41,442프레임 PASS다. 새 HEAD 전체 통합 CI와 Android 빌드 재검증은 **NOT_RUN/PENDING**이다. 과거 baf의 33개 CI 성공은 이번 변경의 성공 증거로 재사용하지 않는다. 이 사용자 요청 중단 저장에서는 최종 전체 워크플로를 수동 실행하지 않는다. 다음 제작을 끝내고 로컬 정적·실행·전수 연결 검사 후 논리 단위 로컬 커밋을 합쳐 원격 푸시하고, 최종 게임 HEAD에서 전체 필수 CI를 검증한다. 개체 1~2종마다 원격 푸시/CI를 반복하지 않는다. main 병합은 별도 사용자 승인 전 금지한다.
