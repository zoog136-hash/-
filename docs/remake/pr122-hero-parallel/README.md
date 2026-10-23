# PR122 영웅급 — 독립 승인 및 보류·프레임 보완 현황

2026-10-23 최신 상태: 최초 미승인 대상 **25/25종 독립 승인 완료**. 후속 요청의 **보류 7종 + 프레임 부족 11종 = 18건**도 독립 처리 완료했다. 보류 7종은 기존 승인본을 재사용했고, 프레임 부족 11종은 기존 동작을 보존한 채 8방향 RUN만 48포즈씩 추가했다. 신규 원화 9장, 경비병 팔레트 재사용 2종이며 신규 WALK·사망 원화는 제작하지 않았다.

기존 캐릭터 승인 이력에 더해 세지 않는다. 원본 자산과 기존 25종 승인 항목은 변경하지 않았다. Main 재생 11종, 실제 입력 88건, 기존 8방향 사망의 30초 유지 검사 및 직접 내부 외형·동작 검수를 통과했다. 사용자 허용 미세 픽셀 오류는 원본·자동 발견 기록과 함께 보존했다. 정식 카탈로그 연결·PR122 병합·최종 전체 CI·Android 실기 확인은 별도 단계다.

최신 원장은 `data/pr122_hero_parallel_staging.json`의 `remediation_18`, 근거는 [후속 보완 결과](evidence/remediation18-20261023/final-review.json)다. 내장 이미지 생성은 복구돼 실제 PNG 생성에 성공했다. 아래 HTTP400·미승인 수치는 삭제하지 않은 **과거 이력**이다.

## 이전 제작 이력 보존

# PR122 영웅급 병렬 제작 — 미승인 후보 저장

> **원화 도구 HTTP 400 (reasoning 미지원):** 반복 재시도 금지. [2026-10-23 복구 지침](IMAGE_TOOL_HTTP400_RECOVERY_20261023.md)을 먼저 확인하고 이미지 도구의 지원 인자만 사용한다. 저장된 생성 요청은 보존하며 신규 원화를 만들었다고 보고하지 않는다. 별도 유료 API 호출은 사용자 승인 없이 실행하지 않는다.


브랜치 `feature/pr122-hero-parallel`, 기준 PR HEAD `5bf5d3195f97fda565f195f19344a4929597267e`.
기존 PR 브랜치·신화/전설급 자료·공통 코드·카탈로그·승인 자산은 변경하지 않았다.

## 범위와 현재 상태

기존 498종 원장의 ID와 카탈로그 `grade == 영웅`을 정확히 교차했다.
영웅급 **109종 = 기존 승인 이력 84종 + 미승인 25종**이다. 승인 84종 안의 기존 프레임 보완 11종은 별도 제작 대상에 넣지 않았다. 과거 `approval_preserved` 플래그가 아니라 현재 `VERIFIED_COMPLETED`/`FRAME_INSUFFICIENT` 상태를 사용한다. 따라서 이번 저장으로 승인 이력 405/498을 바꾸지 않는다.

미승인 25종 중 랜스 마스터 레드179·블루182 두 종의 공통 달리기 후보를 제작했다. **새 최종 승인 0, 기본 게임 적용 0, 미승인 잔여 25**다. 베레스11·바포메트7도 추가 제작·시험했으나 로브 결함으로 보류했다. 유니크 랜서231·각성 켄라우헬260도 이어 제작·검증했다. 나머지 19종은 새 프레임 미제작이다. 랜스 공유 48자세를 두 종에 연결했다. 로브 두 후보도 같은 원화 바이트를 공유하므로 각각 48자세를 별도 창작으로 세지 않는다. 이후 각성 켄라우헬48자세와 바포메트 신규 고유5동작144자세를 추가했다. 현재 선택 결과/검사는 `evidence/selected-validation-summary.json`과 맨 아래 r002 기록을 우선한다.

사용자 추가 지시에 따라 영웅급 신규 WALK를 제외했다. 전용 후보 SpriteFrames에는 WALK가 없으며 기존 경로의 WALK와 이전 승인 자산은 보존한다. 이동은 저속에서도 전용 RUN을 선택하는 기존 변신 정책을 이용한다.

## 실제 제작물과 품질 보류

- 선택 후보: `assets/actors/eight_direction/hero_parallel/lance_shared/r041/`.
- 8방향 × 전용 RUN 6자세 = 서로 다른 RGBA 48자세. Skeleton2D/Bone2D의 고정 길이 2관절 IK와 연속 가중치 메시로 기존 재질을 변형했다. 단순 루트 상하 이동이나 동일 프레임 반복으로 제작하지 않았다.
- 두 개별 `lance_179/r041`, `lance_182/r041` 프로필에서 같은 SpriteFrames를 사용한다. 기존 색상과 대기/공격/피격/사망의 실제 텍스처·앵커·시간·타격 프레임을 유지한다. 일반 프로필 JSON은 수정하지 않았다.
- 원본 PNG 바이트를 직접 읽어 상체/장비 레이어를 보존한다. Godot import의 alpha-border RGB 변경을 신규 원화에 굳히지 않는다. 관절이 올라오면 상체 갑옷 레이어 뒤로 가린다. 기존 Player의 X0.90/Y1.00 표시 정책은 그대로이며 추가 전체 폭 보정은 없다.
- **품질 HOLD:** 원작 외형/색상/무기 동일성 미승인, 실제 신발 접지·보폭/속도 대응 미승인, r005에서 보류된 9자세의 분리 알파 성분은 r041에서 **0/48자세**로 수정했다. 실제 신발 접지와 원작 동일성은 여전히 미승인. 모델의 A/B 지지·AIR 표시는 실제 신발 픽셀 접지 승인이 아니다. 이 후보를 정식 카탈로그로 교체하면 안 된다.
- r001~r004의 원화·프로필·기하 기록과 실패 로그를 보존했다. r001 뼈 rest 초기화, r002 강체 조각 연결, r003 상체 겹침, r004 import RGB 문제를 숨기거나 성공으로 바꾸지 않았다.

## 실행 검증

공식 Godot **4.7.2.stable.official.ed1daf0bf**, Compatibility / Mesa llvmpipe.

- 원본 필수 리소스 검사: 723시트·41,442프레임 PASS, 기존 바이트/추적 보존.
- r005 재제작 무기록 검증: 전체 48자세 RGBA 정확 일치 PASS.
- 실제 Main 변신 API 임시 연결: 최종 결과는 `evidence/r005-visible-main/validation-headless.json` 기준이다. 8방향 × 대기/달리기/공격/피격/사망 전수 재생, 타격 마커 단일 방출·전투 시각·속도/충돌/인벤토리/카탈로그 유지.
- 실제 OpenGL Main: **직업 선택을 실제 확인하고 게임 진입한 뒤 1,641검사 PASS**. 두 후보의 각128프레임, 합계256프레임을 렌더링했으며 각8방향의 RUN6이 화면 안에서 서로 다른 픽셀을 보이는지 검사한다. `evidence/r005-visible-main/Main-all-poses-*.webp`가 최종 증거다. 손실 없는 인코딩이며 PNG와 RGBA 전체 일치를 `encoding.json`으로 검증했다. 큰 중복 PNG는 로컬 보존·SHA 기록이며 공개 전달은 WebP다. 채팅 이미지 출력은 없다.
- 이전 `evidence/Main-*.png`, `evidence/r003`, `evidence/r005`의 초기 캡처는 직업 선택 화면 가림으로 **시각 증거 무효**다. 재생 API 검사와 구분하며 `capture-superseded.json`에 표시하고 원본도 보존했다. 해당 캡처로 외형/가시성을 승인하지 않는다.
- 실제 키 입력과 Player 물리: 두 프로필 × 8방향, 96 physics tick의 위치/속도를 기존 프로필과 비교한다. 최종 결과는 `evidence/r005/keyboard-physics.json`과 로그를 기준으로 한다. 초기 disabled physics-space 및 import 전 실패는 별도 보존했고 성공으로 계산하지 않는다.
- 기존 전투 타이밍 회귀 PASS, 피해 공식 346개 정확 비교 PASS.
- `check_artifacts.py`: 리소스/상체 원본 재질 보존 PASS, **품질 HOLD로 종료 코드2**. 이것은 최종 승인 PASS가 아니다.

전체 CI33·Android 실기·기본 카탈로그 적용은 실행하지 않았다. 독립 기술 검사 통과와 정식 게임 적용·외형 승인을 구분한다.

## 이어하기와 통합

`data/pr122_hero_parallel_staging.json`이 영웅급 전용 원장이다. 신화급 staging은 읽기 전용으로 유지한다.
다음은 r041의 실제 신발 접지·보폭/속도 대응과 원작 외형·색상 검토다. 그 전에는 다른 체형에 이 창병 외형을 색만 바꿔 완료 처리하지 않는다. 나머지 우선순위/체형/장비 분류는 원장에 있다.

`build_roster.py`는 기존 승인 항목을 재집계하지 않는다. 기존 파일은 덮어쓰지 않도록 baker가 새 리비전을 요구한다. 읽기 전용 재현은 `TWILIGHT_HERO_VERIFY_BAKE=1`로 실행한다. 테스트는 별도 `XDG_DATA_HOME`의 마지막 디렉터리 이름을 `twilight-test-*`로 지정해야 한다.

PR HEAD는 작업 중 `dc867da691e20fa72b96b960c6c6b4176c8e5a74`까지 진행됐으며 읽기 비교만 했다. API의 300경로 제한 가능성이 있어 전체 충돌 검증 완료를 주장하지 않는다. 저장 커밋은 영웅급 전용 세 경로만 추가하므로 기존 신화/전설 파일을 덮어쓰지 않는다. 통합 전에 최신 HEAD 전체 경로와 충돌을 다시 확인하고, 사용자 명시적 병합 지시 뒤에만 순차 통합한다. 현재 후보는 품질 보류이므로 정식 적용 대상이 아니다.

기존 source donor 및 프로젝트 상위 `assets/actors/eight_direction/ATTRIBUTION.md`, `UPSTREAM-CREDITS.txt`의 출처를 유지한다. 원작 제3자 ZIP/SPX 전체 전달·재배포 권한·원작 외형 승인으로 해석하지 않는다.

## 2026-10-20 계속 제작 저장 (기준 35227311)

- r006~r041 실패·중간 원화를 삭제하지 않고 보존했다. 원본 opacity ground, source inverse bind, 고정 관절 길이, 1px UV 메시/4배 래스터, 방향별 재질 분할을 수정했다. r041의 SE는 기존 idle_1 frame1 원본을 사용하며 정확한 region/margin/source SHA를 기록한다. 48자세의 큰 분리 성분 0, 원본 상체·장비 레이어 바이트 보존 PASS다. 자동 분석 임계값은 alpha16/성분12픽셀로 유지했다.
- r041 무기록 재제작 RGBA48 일치 PASS. 실제 OpenGL Main 1,739검사·256자세 렌더 PASS, 실제 키 입력16경우/96틱 기존 위치·속도 일치 PASS. 최신 증거는 `evidence/lance_shared-r041-visible-main/`이다. 이전 r005 수치는 역사 기록이다.
- 베레스11·바포메트7: 기존 승인 monster donor를 읽기 재사용했으며 hero 동일성 승인은 승계하지 않는다. r001/r002 신규48자세를 각각 생성하고 hero 전용 프로필을 연결했다. 기존 두 donor가 참조하는 같은 Salah PNG 때문에 신규 RGBA도 동일하다. **별개 고유 원화 또는 두 종의 원작 외형 승인으로 집계하지 않는다.**
- 로브 r001 관절/재질 분할 실패38/48, r002 연속 cloth mesh 실패37/48로 둘 다 품질 HOLD다. 가려진 무릎/발목 제어점은 실제 원화 관절 실측이라고 하지 않고 authored_hidden_robe_control로 기록한다. 실패 파일과 로그를 보존하며 지원 발 목표를 움직여 reach 검사 실패를 감추지 않는다.
- 로브 r002 실제 OpenGL Main은 각1,040검사·128자세 PASS, 실제 키 입력 각8경우/48틱 위치·속도 일치 PASS다. 최신 증거는 `evidence/{beres_hero,baphomet_hero}-r002-visible-main/`이다. 리소스/컨트롤러 통과는 로브 결함 또는 외형을 승인하지 않는다.
- 기술 검사 합계3,819개, 실제 렌더512자세, 물리192틱 비교. 4종 후보 시도, 정식 승인0, 기본 게임 연결0, 미승인25 유지. 전체 CI33은 반복 실행하지 않았다.
- 다음은 남은21종의 기존 donor/체형/장비와 reference를 교차 검토한다. 다른 체형을 색상만 바꿔 완성하지 않는다. 원작 ZIP/SPX는 이 환경에 없으며 카탈로그 PNG가 다방향 원화 승인 자료를 대신하지 않는다.

## 계속 제작 2차 묶음 — 공통 창병 추가/켄라우헬/바포메트 신규 원화

첫 계속 저장 `f857d2b8bad25d56fa262dff1b03a6fe0d826e17`을 정상 push한 뒤 제작을 이어갔다.

- 유니크 랜서231: 기존 프로필의 동일 spear_captain 소스를 확인하고 r041 공통RUN48을 신규 hero 전용 프로필에 연결했다. 원화 추가 쓰기0, 서로 다른 새 원화48로 재집계하지 않는다. 실제 Main1,153검사/128자세 및 키 입력8방향48틱 PASS다. 외형/고유 무기/신발 접지는 HOLD다.
- 각성 켄라우헬260: 기존 동일 체형 transform10 소스를 읽기 재사용했다. r001~r011을 보존하고 r011을 선택했다. alpha16/12픽셀 기준의 분리 성분을 8/48에서3/48로 줄였다. 고정 뼈 길이/실제 원본 상체·무기 레이어를 보존했다. 실제 Main1,473검사/192자세, 키 입력8방향48틱 PASS다. 최초 제작 중 staging 갱신 직후 임포트하지 않은 리소스 검사 실패는 별도 보존했고, 최종본을 다시 임포트해 PASS를 확인했다. 각성 외형/신발 접지/남은3자세는 HOLD다.
- 켄라우헬 donor의 cast는 이번 근접 공격 전용 후보에서 복사하지 않는다. idle/attack/hit/death 원본 클립의 각 텍스처·region/margin·상대 duration·fps는 그대로 보존하고 새RUN만 추가했다. WALK는 없다. Main 캡처 열수와 예상 phase 수는 실제 리소스에서 계산하므로 6프레임보다 긴 기존 동작을 잘라서 통과시키지 않는다.
- 바포메트 신규 고유 RUN 원화: 기존 Salah 재질의 로브 결함을 새로운 원화의 승인으로 대체하지 않았다. 별도 `baphomet_unique/r001/source-run.png`를 실제 생성하고 원본/요청/바이트 SHA를 보존했다. 결과는 요청1536x2048과 달리1086x1448이며, 정확한6x8 배열/181px셀/48개 서로 다른 RGBA다. 원본을 확대·수정하지 않고 AtlasTexture181px셀+37px여백으로256px 가상 캔버스에 등록했다.
- 신규 원화 Main RUN 전용 검사: 64검사/실제 화면48자세 PASS, lossless WebP 보존. alpha>16 기준3셀 가장자리, 원작 외형/카메라/실제 발지지 품질은 HOLD다. 이 새 원화에는 idle/attack/hit/death가 없으며, 서로 다른 Salah 동작을 섞어 완성 처리하지 않는다. 기존 hero7 후보는 보존하고 `unique_art_candidates`에 별도 기록한다.
- 6종의 5동작 후보 기술 검사 및 추가48자세의 고유RUN만 검증한 상태다. 정식 신규 승인0·기본 카탈로그 적용0·미승인25를 유지한다. **기술PASS6종은 완료6종이 아니다.** 새 고유RUN 후보를 완성1종으로 더하지 않는다.
- 최신 PR 원격 `f91818460bd75667d9d1b135cebbcd355daea64a` 전체 변경 경로5,411개와 읽기 비교했다. 영웅급 경로 교집합0, Player/actor_motion/프로필/카탈로그/프로젝트 런타임 코드 변경0, 미승인25개 기존 프로필 설정 변경0이다. `evidence/latest-pr-read-only-audit.json` 기준이며 실제 병합/리베이스/PR 변경은 하지 않았다. 원격이 다시 진행될 수 있으므로 통합 직전 재확인이 필요하다.
- 내부 디자인 텍스트 분석은 선택 사항이며 정식 외형 승인으로 승격하지 않는다. 모델/정확한 revision/입력 SHA/질문/원문 설명을 보존하고 chat 이미지·Base64를 출력하지 않는다.

## 바포메트 신규 고유5동작 r002 실제 연결

위 RUN-only 기록 이후 대기/피격/사망 companion48셀과 공격48셀도 실제 생성했다. 모든 원본/정확한 요청/생성 원본 경로/SHA를 `baphomet_unique/r001`과 evidence에 보존했다. 이 새 세 시트만으로 r002를 구성했다. 기존 Salah 동작을 섞지 않았다.

- 각6x8/181px 원본 셀을 확대·재색칠하지 않고 AtlasTexture margin으로256px 캔버스에 등록한다. IDLE2/RUN6/ATTACK6/HIT2/DEATH2 ×8방향 =144자세/40트랙이다. 이전 RUN-only 리소스·로브 후보/실패물은 그대로 유지한다.
- hero7 전용 프로필의 기존 실제 전투 간격·공격 마커1·피격/사망 시간·물리 속도·충돌·기존 표시 폭 정책을 보존했다. 공격 원화 요청도 impact를 정확히frame1로 지정했다. 단, 요청한 내용이 실제 화상에서 충족됐다는 시각 승인은 아니다.
- 선택 후보는 `assets/actors/eight_direction/hero_parallel/baphomet_unique/r002/`로 갱신했고 이전 로브 후보는 `prior_candidates`에 남겼다. 새 원화가 5동작 모두 연결되었으므로 RUN-only의 누락4동작 보류는 새 r002에 적용하지 않는다.
- 실제 OpenGL Main1,021검사/144자세 캡처 PASS, 실제 키 입력8방향/48틱 위치·속도 기존과 일치 PASS. RUN48 전체 큰 분리 알파 성분0, 원본 전체 셀 바이트 보존 PASS다. 증거는 `evidence/baphomet_unique-r002-visible-main-unique_full/`이다. source cell hash·region·margin40트랙을 검사하며, 생성 원화에 존재하지 않는 가짜 Skeleton 관절 증명을 만들지 않는다. 기존 rig 후보에는 원래의 관절 길이 검사가 계속 적용된다.
- **품질은 HOLD**: 원작 외형 동일성, 세 시트 사이 디자인 일치, 실제8방향 카메라, 신발 지지/보폭과 이동 속도 대응, RUN3셀 가장자리 검토가 남았다. 픽셀 해시가 다르다는 이유로 자연스러운 달리기를 승인하지 않는다. 새 원화도 최종 승인0이다.
- 로컬500M 모델 설명은 일부가 `Head.`/`Clothing.`으로 불충분하고 무기를 잘못 인식할 가능성이 있어 정식 품질 승인으로 사용할 수 없다. 입력SHA/모델revision/질문/답변은 `local-design-triage.json`에 보존했다. 이 모델의 문장만으로 캐릭터 외형을 바꾸거나 승인하지 않았다.
- 현재6종 후보 시도, 새 기본 게임 적용0/최종 승인0/미승인25 유지. 미제작19종은 별도 고유 외형·체형별 모션 제작이 필요하다. 기존 PR122에는 병합하지 않았다.

## 2026-10-22 신규 사망 S1방향 정책 / 실제 제작 계속

최신 정책은 [POLICY_20261022.md](POLICY_20261022.md)를 따른다. 기존 다방향 사망과 승인84종은 유지하며, 신규 사망 원화만 S1방향으로 제작한다. WALK 제외/다른4동작8방향은 그대로다.

- 후보6종의 기존 방향을 줄이지 않았다. 적용 전219개 기존 영웅급 원화/리소스 SHA를 보존하고 재검사한다. 기존 실패/HOLD/초기 페이드 실패 보고서도 남겼다.
- 하퍼197 RUN48을 추가 제작하고 그 체형의 기존8방향 나머지 동작/사망을 재사용했다. 새 사망 원화0이며 RUN7/48재질 연결은 품질HOLD다.
- 메이드 안나276의 새 원화4시트를 파일로 보존했다. IDLE3/RUN6/ATTACK6/HIT3은 각각8방향, DEATH6은 S1방향만 있다. 고유150자세이며 사망8입력 연결을 포함한 재생 참조는192개다. 단일 `DeathSouth.tres`를8개 death트랙이 같은Texture 객체로 공유한다. 기존 unapproved chain-armour donor는 복장 불일치로 혼합하지 않고 원본을 유지했다.
- 정사각 원화 셀을 같은 비율로 정규화하고 시트/방향마다 고정 앵커만 적용했다. 각 phase마다 발을 지면에 붙이거나 AIR를 없애는 보정은 없다. 생원화와 정규화 결과의 SHA/변환 계보/재현 검사 결과를 남겼다. 이는 실제 신발 접지 승인과 별개다.
- 초기 runtime의 alpha0 문제를 재현하고 opt-in 패치를 별도 검토/커밋했다. 이후 최신 PR `4fda626b`에 같은 기능의 공식 구현을 발견하여 후속 커밋 `fb5b5c16`에서 공통 파일을 그 구현과 정확히 정렬했다. 초기 opt-in 커밋 `2fdfa219`/패치는 보존된 과거 기록이며 최신 PR에 단독 적용하지 않는다. 원본 PR브랜치는 수정/병합하지 않았다.
- 실제 feature Main8후보×8키입력64경우: S공유선택/1회순방향 재생/30초최종frame유지/반복die재시작금지/예약공격취소/기존충돌·속도·인벤토리 보존 PASS. 기존 authored source의 마지막 자세 유지와 초상화 대체 표시 fade도 PASS. 단일 S 트랙만 있는 리소스의 8방향 선택까지 총168,937검사 PASS. 전체5동작 Main검사9,117개/실제1232재생참조, 키입력물리384틱 기존결과일치 PASS. 최종기준은 `evidence/death-south-20261022/feature-main-death-policy-opengl.json`이다.
- 전투타이밍/바닥드랍/저장27검사만 표적회귀 실행했고 전체CI33은 실행하지 않았다. 채팅이미지첨부는 하지 않았다.
- 현재 기술후보8종, 신규최종승인0/기본카탈로그적용0/미승인25, 미착수17종이다. 원작외형/실제접지/시트간일치 등HOLD는해제하지 않았다. 독립기술검사PASS를캐릭터완료로집계하지 않는다.

최종 전달 파일·SHA 목록은 `evidence/death-south-20261022/delivery-manifest.json`, 통합 검토는 `runtime-review/REVIEW_20261022.md`를 기준으로 한다. 신규 최종 승인0이므로 영웅급25종 전체 완료 상태가 아니다.


## 2026-10-22 계속 제작 — 정확한 동일 대상 원화 재사용

- 화염의 엔트407/알비노 뿔 개구리352는 `original_based` provenance의 실제 대상 catalog 경로와 SHA가 일치하는 기존 원화를 찾았다. 이 원화의 idle/attack/hit/death 8방향을 원래 texture/region/margin/duration/fps 그대로 읽기 재사용하고, 신규 RUN48자세씩을 별도 hero 경로에 제작했다. 기존 walk 원본도 삭제하지 않았고 신규 WALK는 만들지 않았다. 신규 사망 원화0, 기존 사망 방향8 모두 보존이다.
- 새로운 달리기는 실제 생성 원화를 균일 비율로 정규화하고 각 방향의 고정 앵커로 등록했다. per-phase 접지 스냅/폭 늘이기/반복 프레임은 없다. 기존 proxy tint를 새 원화에 중복 적용하지 않도록 후보 전용 profile에서 WHITE를 사용한다. 원작 동일성·실제 해부학적 지지·접지·카메라·다른 동작과의 원화 연속성은 별도 HOLD다. 원화 연결 검사 결과 엔트2/48, 뿔 개구리20/48 분리 성분이 있어 최종 승인하지 않았다.
- 하퍼197 r002 연속 하체 mesh 후보는 분리 성분7/48→6/48이다. 실제 Main1474검사, 키입력8방향48틱, 사망8입력/30초유지 PASS이며 품질 HOLD다. 이전 r001과 wrapper는 그대로 보존했다. 켄라우헬260 r012 실험은3→7/48로 악화되어 선택하지 않았고, 기존 r011을 유지한다. 실패 실험/원화/리소스/로그를 삭제하지 않는다.
- 엔트와 뿔 개구리는 각각 실제 Main1101검사와 전동작128재생참조를 통과했고, 키입력16경우96물리틱의 위치·속도가 기존과 일치했다. 사망16입력46554검사 PASS, 기존 원본의 방향별 collapse 재생·마지막 자세 유지 PASS다. 새로운 S-only 원화는 만들지 않았다.
- 기존 virtual-canvas metadata에 따른 균일 확대/축소를 검사할 수 있도록 hero 전용 QA를 보완했다. 실패했던 최초 scale/provenance 검사 로그와 구체적 원인은 `evidence/exact-reuse-20261022/qa-contract-update.json`에 보존했다. 공통 런타임은 수정하지 않았다. 최초 editor import의 쓰기 불가 기본 config 경로 오류도 보존했고, 독립 XDG config/cache에서 정상 재임포트했다.
- 현재 기술후보10종/미착수15종, 선택본 Main11319검사/1488재생참조/물리480틱, 신규 최종승인0/기본 카탈로그 적용0/미승인25 유지. 기존250자산 SHA 보존 PASS. 전체 CI는 반복하지 않았다. 다음 제작은 남은15종의 고유 외형과 공격 방식에 맞는 원화를 확보하고 후보의 접지/재질 연결을 보완하는 단계다.


## 2026-10-22 후속 제작 — 헬바인 공통 RUN / 후면 소스 보완

- 헬바인9의 기존 longbow 체형에서 실제 Skeleton2D/Bone2D RUN48을 제작했다. idle/attack/hit/death 8방향은 원래 프레임·타이밍 그대로 재사용하며, 고유 헬바인 외형 승인으로 계산하지 않는다. r001의 후면 재질 연결 결함3/48을 찾았다.
- 켄라우헬260 r013 / 헬바인9 r002는 N의 기존 walk source pose를 새 RUN 리깅의 입력으로만 재사용하고 NE는 같은 체형 NW 원화를 좌우 반전해 연결했다. 신규 WALK 클립은 만들지 않는다. 보존한 source reference에 `mirrored_x`를 명시하고 미러링을 적용한 원본 재질과 출력 상체/무기를 비교한다. 기존 dead/attack/hit/idle 방향을 미러링하거나 교체하지 않는다. 두 RUN 후보의 분리 성분은 각각3→0/48이다. 미러링의 원작 외형·손잡이 연속성·실제 접지는 별도 HOLD다.
- 데스155의 신규 원화4종(run/attack/support/S-death) 요청은 이미지 도구 HTTP400 `Unknown parameter: 'reasoning'` 오류로 생성되지 않았다. 실제 원화 파일은0이며 완료 수치에 더하지 않는다. 기존 reaper_male donor를 사용한 RUN48 대체 시도는 분리 성분40/48로 실패하여 선택하지 않았다. 실패 자산·prompt·오류·검사 로그를 보존한다.
- `build_full_art_candidate.gd`는 다음 고유 원화 묶음 연결을 위해 준비한 제작 도구다. 구문 검사만 통과했고 신규 raw source가 없어 아직 실행하지 않았다. 이 도구가 있다는 이유로 데스 원화 또는 게임 연결이 완료됐다고 하지 않는다.
- 천상의 기사4/수호 기사268은 공통 authoring-source 자료에서 flying이며 텍스트 triage도 서로 다른 날개/갑옷을 설명한다. 둘의 분류를 winged_armored_humanoid로 보완했으며, 같은 범용 plate 갑옷 파일을 색상만 바꿔 둘의 고유 완성으로 계산하지 않는다. 로컬 모델의 설명은 시각 승인으로 사용하지 않는다.
- 내부 이미지 검토는 기존 인계 문서의 “내부 검토 목적도 예외가 아니다” 지시가 있어 예외 허용을 질의했다. 채팅 이미지 첨부 금지는 유지하고, 답변을 받기 전에는 해당 내부 도구를 사용하지 않는다. 원화 생성 오류와 시각 승인 제한은 `evidence/next-unique-20261022/production-blockers.json`에 기록한다.

최종 선택본 검증: 켄라우헬r013/헬바인r002 각각 실제 Main1474검사, 키입력 합계16경우96틱, 사망16입력46554검사 PASS. 선택 후보11종, 시도 후 미선택1종(데스155), 미착수13종, 최종승인0/기본적용0/미승인25다. 선택본 전체 Main 12793검사/1680재생참조, 물리528틱, 고유 캐릭터별 사망88입력이다. 기존250자산 SHA 불변 PASS.


## 2026-10-23 내부 시각 검토 허용 후 실제 승인3종

사용자 “내부 이미지 허용해 제작해” 지시로 내부 검토 제한을 해제했고 채팅 이미지 첨부 금지는 유지한다. 기존 자동/로컬 모델 설명을 최종 승인으로 사용하지 않고 실제 기준 이미지·각 자세·Main 렌더를 직접 비교했다. 기존 기술 후보9종은 외형이 달라 최종 승인하지 않았다. 자세한 실패 이유와 기존 잘못 잘린 생성 시트는 `evidence/visual-review-20261023/review.json` 및 원래 자산 경로에 보존한다.

- **승인352 알비노 뿔 개구리**: `frog_native_352/r004`. 정확한 기존 대상 원화를 가상448px→256px 캔버스로 균일 정규화한 후, 원래 발 위치·관절 굽힘 방향을 지키는 골격 RUN48을 새로 제작했다. 배/몸통을 팔다리 스킨에서 분리해 원본 재질 그대로 보존하고 SW는 자연스러운 SE 미러링을 사용한다. 분리 성분13→6→3→0/48, 직접 외형·8방향·팔다리 교대·Main 재생 검토 PASS.
- **승인407 화염의 엔트**: `ent_native_407/r005`. 정확한 기존 검은 나무/주황 잉걸 원화를 사용하고, 몸통과 원래 뿌리 발 위치를 보존하는 RUN48을 제작했다. 해부학적 길이에 맞춰 미리 정한 짧은 뿌리 보폭을 사용하며 도달 실패를 숨기기 위해 지지 발을 옮기지 않는다. 실패 r002의 IK 오류와 r001/r003/r004를 보존했다. 최종 분리 성분0/48, 직접 시각·Main 검토 PASS.
- 위2종의 idle/attack/hit/death 모든8방향은 기존 texture/region/margin/duration/fps 그대로 읽기 재사용했다. 기존 WALK 원본도 보존했고 신규 WALK는 없다. 신규 사망 원화0이다. 각각 Main1194검사/128재생참조, 실제 키입력 합계16경우96틱, 사망16입력46554검사를 통과했다.
- **승인405 화염의 페어리**: `fire_fairy_405/r003`. 기존 도감에 있는 실제 작은 주황/금빛 날개 생물의 원화를 사용했다. 날개·몸·두 다리를 분리해 원화 UV로 그리는 관절 리그를 직접 제작했다. 좌우 날개 쌍은 허용된 미러링을 사용하며, 실제3D yaw와 날갯짓을 투영해8방향을 표현한다. 다리는 원화 폭을 보존하는 얇은 리본으로 각각 교대한다. 새 손그림 원화0, 재사용 원화1, 서로 다른 리그 자세150/런타임 참조192다. 기존 전혀 다른 harpy 사망8방향은 원래 경로에 보존하며 새 페어리는 S 단일 사망6자세만 만들었다.
- 페어리는 Main1215검사/192재생참조, 키입력8경우48틱, 사망8입력26279검사를 통과했다. 단일 `DeathSouth.tres`만 로드한8방향 선택도 검사했다. 공격은 기존 frame1/판정 시계를 유지하며 사망은 한 번 추락해 바닥에 눕고30초 뒤에도 마지막 자세를 보인다. 원본 부위 UV/변환/검은 도감 바깥 matte 제외 기준을 rig-proof에 기록한다. 초기 r001/r002와 제작 오류는 보존했다.

3종은 독립 제작/실제 Main 검증/직접 시각 검토를 승인한 **통합 준비 자산**이다. 정식 기본 카탈로그 적용0, PR122 병합0이며 기존 승인84종과 원래405종 공통 원장은 변경하지 않았다. 최종 승인은 staging의 `final_approved`와 바이트 SHA가 고정된 별도 approval receipt를 기준으로 한다. 제작 시점의 리소스 WIP 메타데이터는 원본 보존을 위해 그대로 두며 그 메타데이터만으로 승인하지 않는다. 자동 검사·리깅 도구는 승인 자산을 재제작하거나 재승인하지 못하도록 보호했다. `pending_total`은 이제 실제 남은22종이며 `target_scope_total=25`는 최초 작업 범위를 보존한다.

새 고유 원화 생성 도구는 여전히 HTTP400 `Unknown parameter: reasoning`으로 실패한다. 실제 기준 이미지로 재시도한 요청/오류를 남겼고 생성 성공으로 계산하지 않았다. 승인3종은 이 오류와 독립적으로 기존 원화의 적절한 재사용·새 관절 제작으로 완성했다. 전체CI33은 반복하지 않았다.

### 2026-10-23 — HTTP payload recovery and continued insectoid production

The compatibility Images caller now filters its serialized HTTP body to the seven
image fields, even if a caller injects reasoning/text controls. Seven tests pass.
The reviewed Death155 3 × 2 run prompt remains byte-for-byte unchanged. Its single
execution preflight stopped before HTTP because OPENAI_API_KEY is not configured;
zero API-generated source PNGs are claimed. See IMAGE_TOOL_HTTP400_RECOVERY_20261023.md
and evidence/visual-review-20261023/image-compat-single-probe.json.

Source reuse continued with Nerupa406: insectoid portrait-part rig, grounded leg IK,
three visible claw parts and antennae, 8-heading idle/run/attack/hit and one S death
shared across all death inputs. Revisions r001/r002 and r001 authoring source are
preserved. R002 has 150 baked articulated poses; its 192 runtime phase references
pass actual Main (1,215 checks), keyboard displacement comparison (48 physics ticks),
and S-death/last-pose hold checks (26,279 checks). Material connections in 34 of
48 run poses and rear/contact completeness remain HOLD. It is not approved.

Approved for later integration: 352, 405, 407 (3). Pending: 22 of the original 25.
Default catalog/game connections: 0. No PR122 merge was performed. All 286 previously
tracked hero PNG/WebP/TRES/JSON files still match the pre-session Git blobs exactly.
The shared motion runtime matches read-only PR122 head ffd856e9; that branch and its
mythic/legendary production were left untouched. No full CI rerun.

### Latest result after the user’s minor-pixel instruction

Nerupa406 r007 is now independently approved for all five actions after source-specific
dark-ink preservation, one shared leg-bind setting, and a closed body shell using
one UV definition. Twelve contact/bend/peak-attack previews passed before full
baking and were reused; the full sheet rendered 138 additional cells (150 total,
142 distinct RGBA poses). Final run connection warnings: 0. Actual Main/Player,
8-input shared S death/30-second corpse hold, keyboard physics and read-only bake
reproduction passed. Old failed/superseded resources and logs remain preserved.

New source paintings: 0. Existing source reuse: 4 characters. Latest additional
approval: Nerupa’s idle/run/attack/hit/death (5 actions); total independently ready
characters: 4 (352/405/406/407), pending: 21. Formal game connections: 0. The built-in
image tool’s saved HTTP400 reasoning failure remains unresolved; no identical
retry or further unauthenticated API fallback was made after the latest instruction.
