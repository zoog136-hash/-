## 2026-10-15 · 단장 E 보행 소규모시험 통과

**374/498 완료 · 미완료124 · 개별Main103 · 신규완료0 유지.** 단장357의 E한방향3자세는 독립 **PASS_E_ONLY_THREE_PHASE_GAIT_PILOT** 이다. 첫·마지막의 허벅지 겹침 순서가 바뀌어 지지/스윙다리 교대를 확인했고 중간은 passing이다. 숨은 다리의 정체는 추정하지 않았다. alpha/foreign/crop/경계0. [3고유자세PNG·정확prompt·좌표근거](evidence/pr100-direction-fix/original-based/batch22-preflight/ringmaster-wip/checkpoint.json). 발의source y733/726/705가 달라 최종 per-pose groundanchor와 idle기준 크기검토는 아직 필요하다.

방향별 임포터 **`dead8bbe758d7772047c89c588112cf5bfa6a38a` push·원격 일치 확인**, 46테스트 및 실제E기하검사만 통과했다. [새 Animation38733313019](https://github.com/zoog136-hash/-/actions/runs/38733313019)는해당SHA queued이며 dce의이전CI를대체한다(취소는실패/성공으로세지않음). guard수정031통합도대기중. 이제단장 idle/attack/hit/death를승인guide기준으로제작중이며7방향보행은미제작이다. **전체104·scale/발·실제Main 미완료이므로미연결**이다.

## 2026-10-15 · 방향별 시트 임포터 검증 체크포인트

**완료 374/498 · 미완료 124 · 개별 Main 103종, 신규 완료 0종.** 새 `sheets[].directions` 입력으로 한 방향씩 제작한 시트를 합칠 수 있다. 최종 5역할 모두 8방향·최소2자세·역할별 동일 프레임 수가 모여야 파일/프로필 쓰기를 시작한다. 누락/중복방향/필수역할 간 프레임 재사용/캔버스·크기 검토 누락은 거절한다. subset은 명시 `canvas_size`와 `scale_review_note`가 필요하며 `blocks4x2` subset은 금지한다. 기존 full8 columns/rows/blocks 출력 바이트·좌표·mtime은 유지한다.

Python **46/46 PASS**, 합성104포즈(8개단방향/40개역할방향/혼합)의 기존 coverage 감사 통과 및 실패시 전체 SHA·mtime 불변을 확인했다. 실제 단장 E3시트도 새 API 기하검사만 3고유자세 PASS; 진단 canvas1280은 실제 scale 승인값이 아니다. [검증 요약/API 예](evidence/pr100-direction-fix/original-based/recovery-20261015/subset-importer/verification-summary.json). 이 형식의 실제 Main 적용은 아직 없으며 전체104/발·크기 검토 후 시행한다.

제작용 Python/test 이외 runtime/game data/기존 자산은 ce199와 차이 0이다. Android ce199 성공, 원래 통합 ce199 실패는 보존하고 guard수정031d 통합 재검증은 대기 중이다. 새 helper에 대한 애니메이션 CI는 이 체크포인트 push 후 요청한다. 단장 guide보존 `07bba22cffc983a797a723a1681ca247bbd38287` push/원격 일치 확인.

## 2026-10-15 · 단장357회전표 WIP 보존

완료374/498·잔여124·개별Main103유지. 단장357의8view회전표만1차통과,독립검토/E한방향보행3phase시험중이다. 짧은puffed바지/빨간두다리/부츠/손의짧은완드와전·옆·후방구분을확인했다. mask세부표정은새작화추론으로원작애니메이션사실로주장하지않는다. [원본/PNG/정확prompt/geometry/SHA](evidence/pr100-direction-fix/original-based/batch22-preflight/ringmaster-wip/checkpoint.json). **5역할미완성/미연결/Main미실행/신규0**. 카드최종HOLD보존 `e55d6b4ba1252db9f560aa7f5cb91fa88c80a5a0` push·원격일치확인. subset임포터미커밋WIP테스트중이며최종전체8direction만허용하는보호는통과전사용하지않는다.

## 2026-10-15 · 수정통합재요청 / 다음357작은시험

CIguard수정 **`031d747d34ab0df2e28361b0236e7c4ac79e2f0e` push·원격일치확인**. 새 [통합38731518098](https://github.com/zoog136-hash/-/actions/runs/38731518098) 는해당SHA로queued,성공아님. 기존ce199실패는그대로보존한다. 신규subset임포터WIP는이통합SHA에포함되지않는다.

카드360HOLD자료·수정된독립판정·초기판정을모두보존했다. **S보행교대PASS 인정, NE방향/NW·N카드손FAIL** 을근거로보류한다. [카드최종보존](evidence/pr100-direction-fix/original-based/batch22-preflight/card-magician-wip/checkpoint.json). 다음 [후보357서커스단단장](evidence/pr100-direction-fix/original-based/batch22-preflight/backup-clean-candidates.json)은원본전신/짧은바지/두신발/짧은완드·SHA·중복0확인후회전표와E한방향3phase보행만시험중이다. 328은예비이며제작미진행. **완료374/498·잔여124·개별Main103·신규0 유지**.

## 2026-10-15 · 통합CI실패 원인수정 / 재검증대기

완료374/498·잔여124·개별Main103 유지. ce199 [통합38722879756](https://github.com/zoog136-hash/-/actions/runs/38722879756)은 **FAIL: 194PASS+3SKIP(비공개맵)+1FAIL** 이다. guard24검사가실패한것이아니라 RESULT에actual `failures`배열이없어상위fail-closed파서가거절했다. guard출력에실제 `failures.duplicate()`를추가했고검사/파서는완화하지않았다. Godot4.7.2실제guard24/실패0,같은상위파서PASS, subprocess runner회귀20/20PASS를[로그/실패원문/원인](evidence/pr100-direction-fix/original-based/recovery-20261015/ci-recovery)에보존한다. **원격통합재실행전으로성공주장없음**. Androidce199성공및runtime범위374는동일.

카드walk2독립검토에서S는반대다리교대가확인되어기존author의전방향보행실패추정을정정한다. E/W는가림으로교대미증명이고, **NE앞뒤방향전환·NW/N카드손변경** 으로HOLD는유지한다. 원본author판정은기록보존하고독립정정자료를추가한다. 새후보357은짧은바지/빨간두다리/짧은완드의명확한실루엣으로 E한방향3phase보행을먼저시험중이다. subset임포터구현은미검증WIP이며이수정커밋에포함하지않는다.

## 2026-10-15 · 카드 마술사walk2 HOLD / 방향별 작은시험으로전환

완료374/498·잔여124·개별Main103·신규완료0유지. 카드360은walk2도다리교대불명확/NE앞뒤방향·NW카드손변경으로반복실패해 **HOLD/추가제작중단** 한다. 승인idle16+rotation8 및양쪽실패원본/정확prompt/geometryPASS/시각FAIL을[WIP보존](evidence/pr100-direction-fix/original-based/batch22-preflight/card-magician-wip/checkpoint.json)한다. 104recipe없음·미연결·Main미실행. 이전idle독립판정/실패1보존 `c1a1724c1e72f2f195321f67ed450062dc47213e` push/원격일치확인.

새후보는한방향3phase보행을먼저작게시험한다. 제작임포터의방향subset입력은구현/검증중이며 **최종5역할모두8방향이모이지않으면preflight실패/파일·profile변경0** 을보장하는테스트후에만사용한다. 기존실패검사완화/held재시도/누락복제없음.

## 2026-10-15 · 카드 마술사idle독립통과 / walk1거절

완료374/498·잔여124·개별Main103·신규완료0유지. rotation8/idle16독립검토PASS: E는발/코끝동쪽+상체휴식twist로SE복제/가짜반전이아님을확인했다. 원거리alpha>25 잔상0/침범0. **walk1은24고유프레임이어도실제반대다리교대가없어거절**했고, 원본/정확prompt/시각FAIL/geometryPASS를ZIP보존한다. 마지막walk2시도중,5동작/실제Main승인전연결없음. [독립판정/실패보존](evidence/pr100-direction-fix/original-based/batch22-preflight/card-magician-wip/checkpoint.json). 이전idle보존 `f1b41f4955f555da7e34ea85c11129f14481d105` push/원격일치확인.

## 2026-10-15 · 카드 마술사idle16 WIP 보존

완료374/498·잔여124·개별Main103유지. 카드마술사360 **1/5동작idle16실포즈 제작검토통과, 독립8방향검토중**. E의상체비틀림과발/코방향을재검한다. 640가상canvas에서연결/누락/침범/경계검사통과. [원본PNG/정확prompt/SHA](evidence/pr100-direction-fix/original-based/batch22-preflight/card-magician-wip/checkpoint.json). 미연결/Main미실행/신규완료0. 회전표보존 `4aa23e082187ed392a548a5c4c77078a58fe03d9` push·원격일치확인. 다음walk3pose×8방향을진행중이며,전5동작과독립검토가끝나기전런타임연결없음.

## 2026-10-15 · 카드 마술사8방향회전 WIP 보존

**완료374/498·잔여124·개별Main103·신규완료0 유지**. 카드마술사360의8방향회전guide만1차승인(독립재검중),5동작미완성/미연결/Main미실행이다. 8분리body와crop누락/침범0, 모자·보라금코트·손의카드·부츠를확인했다. 저해상도원본에서확인불가한카드A/하트무늬·얼굴세부는새작화추론으로기록한다. [PNG/정확prompt/geometry/SHA보존](evidence/pr100-direction-fix/original-based/batch22-preflight/card-magician-wip/checkpoint.json). [독립원본검토](evidence/pr100-direction-fix/original-based/batch22-preflight/card-magician-source-independent-review.json). 다음은idle2pose×8방향소규모시험이며실제Main검증전완료로세지않는다.

## 2026-10-15 · 다음 위험파일럿: 카드 마술사360

완료374/498·잔여124·개별Main103유지. 피쉬맨HOLD및독립보고/발좌표WIP/미실행Main계획은 `2257054789865720e151e2c1ee32cddf0fb188d6` push·원격일치확인. 추가피쉬맨생성을중단했다.

다음은 **서커스단 카드 마술사(transform:360)** 의8방향회전/idle소규모시험이다. [원본검토후보](evidence/pr100-direction-fix/original-based/batch22-preflight/next-card-magician-source.json): catalogPNG SHA `1a681f05f5f709f7885d017619926fa677830cdfa00a031722bdb7921a958ac7`,온전한모자/장갑/카드/두발및여백,기존완료중복0확인. 외부catalogportrait기반새2D동작이며원작애니메이션회수주장없음. 독립원본검토→회전/idle→전체5동작104자세/발anchor→실제Main후에만연결·수량갱신한다. 현재미연결/완료0.

## 2026-10-15 · 피쉬맨 사망 반복누락 HOLD

**완료374/498·잔여124·개별Main103, 신규완료0**. 피쉬맨은사망시트2회모두24필요중20포즈만생성되어제작중단/HOLD한다. 승인4/5동작80포즈및양쪽불합격원본PNG/정확prompt/geometry를[체크포인트](evidence/pr100-direction-fix/original-based/batch22-preflight/fishman-wip/checkpoint.json)에보존했다. partial-runtime연결·누락복제·방향추정배정·Main시험없음. 향후재개하더라도실제발anchor와전체104자세승인이먼저필요하다. 피격/APK증거commit `ebc6eeb436c738cca1e1c02a84844f919ce26914` push/원격일치확인. 다음은온전한원본전신을가진새후보를검토한다.

## 2026-10-15 · Android 통과 / 피쉬맨 피격 WIP 보존

완료 **374/498·잔여124·개별Main103 유지**. 피쉬맨은4/5동작80실포즈 정적검토통과, 사망1차는24필요중20만생성되어거절/ZIP보존했다. **미연결·Main미실행·신규완료0**. 마지막사망재시도와실제발anchor검토후에만Main으로진행한다. 공격S창끝을ground로쓰지않도록per-pose발기준점을검토한다. [WIP](evidence/pr100-direction-fix/original-based/batch22-preflight/fishman-wip/checkpoint.json). 공격보존 `baf264c0ed09139f2dc437b7093167e42d44be03` push·원격일치확인.

[ce199 Android38722918015](https://github.com/zoog136-hash/-/actions/runs/38722918015) **SUCCESS**, verifier passed=true/ARM64/failures0. workflow APK SHA256 `08fb065357e0e7774203b76f61ee16dd40462b893cf0b70a97509639c286f8b2`, artifact11969130086(948719355bytes ZIP). [메타데이터](evidence/pr100-direction-fix/original-based/batch21-completed/ci-android-ce199-success.json). APK본체를별도다운로드/독립해시검사하지않았고Android실기기미검증이다. 현재까지runtime/game data는ce199와동일해완료374범위에해당한다. 통합ce199실행중·애니메이션dce5048대기중이며성공으로세지않는다.

## 2026-10-15 · 피쉬맨 공격 WIP 보존

피쉬맨 **3/5동작(idle/walk/attack),64실포즈정적승인**. 공격수정본24포즈는8방향windup/전방창찌르기/recovery와창·그물·손연결,침범/누락/경계0을확인했다. 피격·사망미완성/런타임미연결/Main미실행이므로완료374/498·잔여124유지. 독립투명도/외형재검토도Main전에진행한다. PNG/SHA/정확prompt와공격1차거절ZIP을[WIP](evidence/pr100-direction-fix/original-based/batch22-preflight/fishman-wip/checkpoint.json)에보존한다. 이전이동보존 `603fd3d228ef4b2288992951247ada7b84fe3bde` push·원격일치확인.

## 2026-10-15 · 피쉬맨 이동 WIP 보존

완료374/498·잔여124 유지. 피쉬맨 **idle16+walk24=40실포즈,2/5동작정적승인**, 미연결/Main미검사다. walk1은geometry가맞아도실제좌우교대보행이없어거절했고, walk2는8방향모두전진발→passing→반대발이확인됐다. 이크기차이를512canvas에강제로맞추지말고임포터비례정규화를사용한다. [WIP](evidence/pr100-direction-fix/original-based/batch22-preflight/fishman-wip/checkpoint.json). idle보존commit `c5ea60d204760a88f737570fff2463a3442594f1` push/원격일치확인. 공격·피격·사망을계속제작중이며신규완료0.

## 2026-10-15 · 피쉬맨 idle WIP 보존

**완료374/498·잔여124·개별Main103 유지.** 알비노피쉬맨은8방향회전표와idle16실포즈만정적통과(1/5동작), **미연결/실제Main미실행/신규완료0**이다. 나머지walk·attack·hit·death를같은blocks4x2여백구조로시험중이다. idle1차는추가3px여백에이웃픽셀이들어가거절했고 원본PNG/정확프롬프트/진단을ZIP보존했다. idle2차는몸체침범·누락·경계잘림0이며512virtualcanvas에서통과했다.

복구어려운승인idle/회전표·원본참조가이드·SHA는 [WIP checkpoint](evidence/pr100-direction-fix/original-based/batch22-preflight/fishman-wip/checkpoint.json)로보존한다. partial sheet를런타임에연결하거나완료로세지않는다. 파이프라인검증34/34 및기존출력불변은이전push **`dce5048f17712c6c6d7a7ce97414e2f45e6756a4`** 에있다.

현재CI: ce199통합실행중/APK대기, ce199애니메이션은최신helper검사로대체되어cancelled(실패/성공아님). 새 [dce5048 애니메이션38725467814](https://github.com/zoog136-hash/-/actions/runs/38725467814)는queued. runtime/game data는ce199와동일하다. CI관측시점이후상태는GitHub에서해당SHA/run으로확인한다.

## 2026-10-15 · Batch22 경량검사 / 제작 파이프라인 체크포인트

완료 수량은 **374/498·잔여124·개별Main103**으로 유지한다. 완료3종 증거 커밋 **`53e17aee7371e0aac6eb6a7ab84ae3ff9681fb39` push 성공**, local/remote 일치 확인.

- 말하는섬들개·검은숲늑대는 각각idle시트2회프레임침범검사실패로 **HOLD/미연결/신규완료0**. 원본·완성애니메이션은 변경하지 않았다. 실패 PNG/프롬프트/정확좌표/SHA를 각 [들개 ZIP](evidence/pr100-direction-fix/original-based/batch22-preflight/dog-held-authoring.json), [늑대 ZIP](evidence/pr100-direction-fix/original-based/batch22-preflight/wolf-held-authoring.json)으로CRC검증해보존한다.
- 임포터에 **`directions_axis: blocks4x2`**를 추가했다. phase마다4열×2행에 E/SE/S/SW, W/NW/N/NE를 놓고 원본픽셀변경없이기존logical8방향으로읽는다. synthetic5동작104포즈임포트·coverage검증, 중복/셀충돌/침범거절 및 기존columns/rows geometry·SpriteFrames 바이트보존을 포함해 **34/34 통과**. 실제늑대불합격시트는새packing에서도거절된다. 실패를우회한기능이아니다.
- 다음은 **알비노피쉬맨**의온전한전신/창/그물/발참조가이드로위험시험진행중이다. 이웃게집게조각과본체손실0을구분해기록한다. 거미3종/디어/이구아나/크랩은참조경계에걸친몸체부위가있어성급히생성하지않는다. 현재Batch22승인완료0.
- ce199의통합CI실행중, 애니메이션·APK는runner대기중이다. 새packing은제작용Python만변경하며완료3종runtime/QA/game data는ce199와같다. 새helper에대해서는별도애니메이션CI를실행한다. **대기/진행을성공으로계산하지않는다**.
- [파이프라인 검사](evidence/pr100-direction-fix/original-based/batch22-preflight/pipeline-checkpoint.json). 재개시기존HOLD를재연결하지말고최신HEAD/CI상태확인→피쉬맨외형/시트경량검사→승인대상만새fixture→Main headless/OpenGL/드랍·수동습득→체크포인트push로진행한다. source222건SHA불일치0.

## 2026-10-15 · Batch21 회수 검증 완료 · 374/498

**신규 완료3종: 알비노 악어거북349·악몽의 잭 오 랜턴173·도구리288.** 검증 완료 **374/498 (75.1%)**, 미완료 **124**. 영웅 이상139/180·일반200/258·보스35/60. 개별 실제 Main8방향 증거 **103/498**. 원본 기반 신규3외형/독립동작설계3개/실제 고유자세312개이며, cast 별칭·360개 검사샘플을 고유자세 수에 더하지 않는다.

- 실제 Main headless **7,819**, OpenGL **7,142** 검사, 실패0. 각3종8방향 입력·공격·피격·사망/respawn·실제AI추적/공격·원래 장비로 처치·바닥드랍·수동UI습득을 확인했다. N/S idle/contact/death 및 실제전투26화면 육안검토 통과. 북쪽 거북 공격은 3단계 횡베기와 타깃영역 교차를 정성검토했으며, 픽셀단위 충돌시스템을 새로 구현/증명했다는 뜻은 아니다.
- 원격WIP5종 중 **화염의 엔트407(공격 머리외형 불일치), 알비노 뿔개구리352(공격내 저알파 배경잔상)**는 원래3fb프로필로 복원·보류했다. 바포메트7도 기존보류 유지. PNG/TRES/출처·원래5종fixture·실패/중단로그는 보존하며 완료에서 제외한다. accepted fixture는3종/held2종을 명시한다.
- 기존assets/scripts/data/Main **4,704파일**을 대조했다. 차이는 combat profile 문서1개이며 허용된 신규3개 profile만 변경했다. 기존완료 profile 변경0, 원본222개 참조·원격회수PNG/TRES 바이트 보존. 임포터30/30·identity9/9·coverage6/6·guard24·native35,742·기존canvas640 통과.
- Main203개 기존보고서+신규6개를 coverage에 연결했다. 전체480캡처 **751,102,064bytes**의SHA를 기록하고 N/S대표18PNG만Git보존했다. 나머지 원본PNG는 현재환경에만 있으며 전달완료로 주장하지 않는다. CI에서 재생성한다.
- 검증한 runtime/QA 코드 체크포인트 **`ce19943619ba8ea0874446e6eee72ee3926bf739`**는 push후원격일치 확인. 해당커밋 [통합38722879756](https://github.com/zoog136-hash/-/actions/runs/38722879756)·[애니메이션38722899266](https://github.com/zoog136-hash/-/actions/runs/38722899266)·[Android38722918015](https://github.com/zoog136-hash/-/actions/runs/38722918015)를dispatch했으며 기록시점queued, 성공으로계산하지 않는다. 뒤의완료증거commit은문서/coverage/PNG만추가하며runtime코드는동일하다. Android실기기미검증, main충돌그대로·병합하지않음.
- [배치 검증/보존](evidence/pr100-direction-fix/original-based/batch21-completed/validation-summary.json) · [실제Main 결과](evidence/pr100-direction-fix/original-based/batch21-completed/render.json) · [대표화면](evidence/pr100-direction-fix/original-based/batch21-completed/captures) · [최신coverage](evidence/pr100-direction-fix/original-based/coverage/coverage.json).
- 다음 Batch22는 일반10종 source SHA/영역/appearance 점검10/10. 이웃조각/잘린원본 위험을 별도보류 기록했다. 말하는섬들개는 완전한 primary body 참조가이드와8방향회전표를 통과해 동작시트 시험중이며 **미완성/미연결**이다. [다음 원본점검](evidence/pr100-direction-fix/original-based/batch22-preflight/source-preflight.json).

## 2026-10-15 · 회수 WIP 품질 보류 / 실제 Main 최종 검사 중

동일 브랜치 병합 체크포인트 **`d0b53c484c0500a485ecebf5c8372c6194499014` push 성공**, 로컬·원격 HEAD 일치 확인. 원격 `7cec254`와 로컬 `13676c6`/runner WIP 커밋을 모두 조상으로 보존했다. main은 병합하지 않았다.

- **검증 완료371/498·잔여127·개별 Main100 유지**. 회수5종 중 화염의 엔트407(공격 머리 외형 불일치)·알비노 뿔개구리352(공격 crop 내부 붉은/회색 저알파 haze)는 보류하며 원래3fb 프로필로 복원했다. PNG/TRES/출처와 실패시험은 그대로 보존한다. 신규 완료로 계산하지 않는다.
- 승인 전 실제 Main 대상은 악어거북349·악몽의 잭173·도구리288 **3종**. source SHA·8방향104실포즈·기하 정적검토 통과, 실제 Main headless/OpenGL 및 수동습득은 진행 중이다. 원래5종 fixture는 남기고 accepted fixture/held 목록을 별도 기록한다. 초기 clearing 실패5개와 품질보류로 중단한130 종료들은 성공이 아니다.
- QA는 같은 실제 맵의 검색반경만 확장했다. 지형/다른 몬스터를 숨기지 않는다. 임포터 병합 테스트 **30/30**, 리소스SHA·캔버스640·identity9 통과. 기존10종 headless15,158/실패0은 추가 AI/drop 검사가 도입되기 전 회귀범위이며 신규완료 수량이 아니다.
- 중복 제작8 PNG는 **19,090,877bytes** [초안 ZIP](evidence/pr100-direction-fix/original-based/recovery-20261015/duplicate-authoring-drafts.zip), SHA `14b196d76e99aa2a54731a68c066394b3a495449609fd0f38206a368a27f36c7`, CRC검증으로 보존했다. 런타임에는 연결하지 않았다.
- [엔트 보류](evidence/pr100-direction-fix/original-based/recovery-20261015/remote-fire-review.json) · [나머지3종 외형검토](evidence/pr100-direction-fix/original-based/recovery-20261015/remote-three-review.json) · [악어거북 검토](evidence/pr100-direction-fix/original-based/recovery-20261015/remote-turtle-review.json) · [실패/중단 이력](evidence/pr100-direction-fix/original-based/recovery-20261015/batch21-failed-and-held-history.json).

## 2026-10-15 · 동시 원격 체크포인트 복구 중

첫 push 직전 원격이 `7cec25402501fe0672e8f040edb89604d3270606`으로 진전하여 일반 push가 거절됐다. 강제 push 없이 로컬 보호 커밋 `13676c6`과 runner WIP 커밋을 보존하고 **동일 PR 브랜치의 원격 변경만 병합**한다. main 병합은 하지 않는다. 원격에서 이전 세션의 미완성 4파일 및 변신5종 WIP가 회수됐다. 원격 PNG/TRES/출처는 덮어쓰지 않는다. 중복 제작은 중단하고 초안/지시/해시는 별도 보존한다. 아래의 "원격에 없어서 재구현"은 최초3fb 복구 시점 기록이며, 현재는 양쪽 구현을 결합한다.

새 변신5종은 임시 연결 상태로 아직 **완료 수 371/498 및 개별 Main100종에 포함하지 않는다**. 원격의 실패한 foreground-clear 위치 선택 검사를 수정하고 새 Main headless/OpenGL 묶음검사와 외형 검토가 모두 통과한 뒤 수량을 갱신한다.

## 2026-10-15 · PR100 복구 / 임포터 보호 체크포인트

- 기존 PR #100 / `feature/twilight-animation-20261013` 유지. 복구 기준 원격 HEAD `3fbdea4e6a9632e8858c0d6e16ce670acff4138a`. 이전 작업환경·미커밋 4파일은 현재 환경에서 접근 불가하여 원격의 정상 커밋에서 복구했다. 이전 변경 전체 복구를 주장하지 않는다.
- 보고서와 coverage 일치: **371/498 연결·127 미완료**, 변신136/180·일반200/258·보스35/60, 개별 Main 8방향 검증 **100종**. Batch20이 마지막 완료. 신규 완료 **0종**.
- 임포터는 모든 시트·SpriteFrames·출처·profile을 쓰기 전 검사한다. 뒤쪽 충돌/잘못된 입력에서 부분 결과를 남기지 않으며 기존 authored 및 native sequential8/directional8 완료 profile을 덮어쓰지 않는다. 동일 입력 재실행은 bytes·mtime 유지. 회귀 **28/28** 통과.
- 기존 리소스 723시트/41,442프레임 SHA 검사 통과. Godot4.7.2 초기 설정 경로 오류는 실패 기록으로 보존했고 작업 폴더 XDG 설정 재임포트는 오류0. 보호 대상 assets/scripts/data/Main **4,704파일 불변**.
- 변신 배치 실행기는 원격에 없어서 재구현 중이며 기존10종 headless/OpenGL 회귀 진행 중이다. 화염의 엔트·알비노 악어거북 새 생성모션은 **WIP/미연결**. 동일 원본인 아타바크/살라흐도 표시 외형·크기가 달라 재사용 거절했다.
- 기준 HEAD의 통합[38707935974](https://github.com/zoog136-hash/-/actions/runs/38707935974)·애니메이션[38707950473](https://github.com/zoog136-hash/-/actions/runs/38707950473)·Android[38707965290](https://github.com/zoog136-hash/-/actions/runs/38707965290)는 성공. 이 체크포인트의 새 HEAD CI는 별도 확인 전이며 Android 실기기 미검증. main 충돌 유지·병합하지 않음.
- [복구 및 검사 증거](evidence/pr100-direction-fix/original-based/recovery-20261015/checkpoint.json). 재개: 최신 remote HEAD 조회 → 이 보고서 → WIP 제작물 승인/보류 → 묶음 Main 검증 → 완료 수량 갱신 → 같은 브랜치 commit/push/HEAD 대조. 로그·이미지는 파일에 저장하고 요약만 출력한다.

## Batch21 WIP checkpoint — 2026-10-15

User-requested checkpoint: five transformations provisionally connected (Fire Ent, Albino Horn Frog, Albino Snapping Turtle, Nightmare Jack, Doguri), 520 newly authored poses. **Validated total remains 371/498; individual Main headless/OpenGL validation remains 100/498.** Four initial headless cases passed; Jack passed a targeted retry after adding an explicitly reviewed cast track sharing its authored spell gesture. No additional poses are counted for this alias.

OpenGL evidence is incomplete: the new conservative foreground-clear position search rejected all five cases. Correct the QA position selection and rerun actual Main before counting these actors. Baphomet remains held, unlinked and uncounted. New-commit CI/Android are not run; Android device execution is untested. Evidence and rejected authoring drafts are preserved in `evidence/pr100-direction-fix/original-based/batch21/`.

## 2026-10-15 · Batch20 실제 Main 검증 완료

- 추가 5종: 공포의 나이트메어, 오만한 레비아탄, 알비노 악어, 왜곡의 키메라, 질투의 스켈레톤 윙.
- 연결 **371/498 (74.5%)**, 잔여 **127**. 영웅 이상136/180, 일반200/258, 보스35/60. Native99개, 원본 기반 외형63개, 실제 고유 픽셀 자세6,496개.
- 개별 실제 Main headless+OpenGL 8방향 증거 **100/498 (20.1%)**. 연결 수량과 화면 검증 수량은 별도 집계한다.
- 이번 외형5개·독립 동작 설계5개·자세512개. 스켈레톤은 검토한 실제 사망2프레임을 그대로 사용하여96자세이며, 다른4종은 각104자세다. 없는 프레임을 복제하거나 수량을 부풀리지 않았다.
- Main headless4,421검사, OpenGL4,903검사 모두 실패0. 각 대상8방향 AI·공격/타격·피격·사망 종료·드랍·수동 습득 통과. 실제 Main552장 저장, 저장소에는71장 대표 원본 PNG와 전체 SHA목록을 보존했다. 나머지 캡처는 로컬에 보존하고 CI에서도 다시 생성한다.
- Godot4.7.2 임포트 통과. 초기 제한된 소켓 접근 오류를 진단으로 보존하고 필요한 네트워크 권한으로 재실행하여 오류0을 확인했다. Native35,742 및 canvas640검사 통과. 원본222개SHA와 기존보호파일4,574개 불변, 기존연결371프로필 불변, 신규5프로필만 변경. 전투/AI/드랍/아이템/맵/세이브 코드 변경 없음.
- 보류: 레서 데몬/아스모데우스 공격 추출 겹침 반복, 메두사 공격 추출/자세 누락 및 피격·사망 이미지 생성 서비스 차단, 켈베로스 정면 머리 수 오류 반복. 기존 사라만다/댄싱 소드 보류 유지. 모두 완료에서 제외했다. 생성33시트 중 채택15개, 나머지18개와 제작기록은 SHA검증 ZIP으로 보존했다.
- 이 내용의 새 HEAD CI·Android는 푸시 후 별도 실행한다. 97af603 체크포인트 결과는 별도 파일로 구분하며 신규 HEAD 성공으로 간주하지 않는다. Android 실기기 **미검증**. main 충돌은 후속 단계로 남기고 병합하지 않았다.
- 다음 묶음: 화염의 엔트, 알비노 뿔 개구리, 알비노 악어거북, 악몽의 잭 오 랜턴, 바포메트의 원본 카탈로그 이미지 확인 완료.
- 증거: [batch20/validation-summary.json](evidence/pr100-direction-fix/original-based/batch20/validation-summary.json), [현재 검증표](evidence/pr100-direction-fix/original-based/coverage/coverage.json).

# PR #100 후속 수정 및 검증

## 2026-10-14 새 세션 · batch19 원본 기반 5종

기존 PR #100의 `feature/twilight-animation-20261013`에서 원격·로컬 **`8b93a700f7e2bf0cbe99299b1b6751aab9db9c63`** 일치와 깨끗한 작업 트리를 확인했다. 최신 main `6fd15c8`은 조회만 했다. **기란 평원 도마뱀전사·독침 킬러비·사악한 셸로브·왜곡의 웅골리언트·공포의 이프리트** 5종을 추가했다. 현재 연결 **366/498종(73.5%)**, 미완료 **132종**이며, 변신 **136/180**, 일반 몬스터 **195/258**, 보스 **35/60**이다. 개별 이름의 8방향 Main headless와 OpenGL 증거가 모두 있는 범위는 별도로 **95/498종(19.1%)**이다. 연결 수를 전체 개별 화면 검증 수로 계산하지 않는다.

신규 **5외형·520개 고유 픽셀 자세**, 누적 native 리소스 **94개**, 원본 기반 **58외형·5,984자세**다. 웅골리언트는 원본의 녹색 몸체·다리를 유지하면서 셸로브의 동작 설계를 활용했다. 따라서 새 기본 동작 설계 **4개와 원본별 외형 변형 1개**로 구분한다. 원본 애니메이션을 회수한 결과는 아니다. 원본 참조 **222건 SHA**, 기존 연결 프로필 **366개**, 기존 에셋·런타임·참조 파일 **4,550개**를 보존했다.

실제 Main 묶음은 headless **5,414개**, OpenGL **5,946개** 검사에서 실패 0개다. 각 이름의 8방향 실제 AI 추적·공격 접촉, 5동작 104자세, 피격·사망 종료·바닥 드랍·수동 습득을 확인했다. 원래 마법 공격과 부유 설정을 유지했다. 이프리트 자세 화면에 멈춘 다른 몬스터가 겹치는 문제를 발견해 **검사용 위치 선택만** 보완했다. 다른 배우나 지형을 숨기지 않고 빈 지점으로 이동하여 이프리트 OpenGL **1,630개**를 추가 통과했다. 초기 겹침 화면도 보존한다. 기존 전투·AI·아이템·맵·세이브 코드는 변경하지 않았다.

기존 플레이어·보스 방향 회귀 **7,703개**, native 확장 **35,742개**, 캔버스 **640개**, Python **35개**가 통과했다. Godot **4.7.2** 전체 임포트와 실제 Main OpenGL 부팅도 통과했다. [검증 범위](evidence/pr100-direction-fix/original-based/batch19/validation-summary.json) · [70장 대표 게임 화면](evidence/pr100-direction-fix/original-based/batch19/captures) · [방향표](evidence/pr100-direction-fix/original-based/coverage/all-identities-eight-directions.csv). 672장 전체 캡처의 SHA를 기록했고, 이 중 재검사 전 이프리트 112장은 최종 외형 검토에서 대체했다. 저장소에 보존하지 않은 PNG를 전달 완료로 주장하지 않는다.

**사라만다·불신의 댄싱 소드**는 2회 방향 검토 실패 후 보류했으며 연결하지 않았다. 사라만다의 NW 이동 일부가 SE로 남았고, 검은 SE/SW 방향이 일관되지 않았다. 제외된 초안 8개와 정확한 지시·실패 원인은 [보존 ZIP](evidence/pr100-direction-fix/original-based/batch19/authoring-drafts.zip)에 있다. 도마뱀전사·이프리트의 공격 프레임 침범은 해당 시트만 수정한 뒤 정적 검사를 통과했다. 단언을 제거하거나 수량을 부풀리지 않았다.

이 커밋의 전체 CI·Android는 푸시한 정확한 HEAD로 실행하여 별도 기록한다. **Android 실기기 실행은 연결된 기기가 없어 미검증**이다. 다음 묶음은 공포의 레서 데몬·공포의 나이트메어·왜곡의 메두사·오만한 아스모데우스·오만한 레비아탄이며 원본 SHA 확인을 마쳤다. 기존 PR을 유지하며 새 PR·main 병합·강제 푸시는 하지 않는다.

## 2026-10-14 재개 · batch18 정령 3종과 누적 6종 검증

기존 PR #100 브랜치에서 batch17 보존 커밋 **`d03f4c3732b3f112d8f326802a9085e62e3b02e6`**에 이어 작업했다. 시작 체크포인트 `1de5363`와 기존 완료 355종을 보존했다. **검은숲 나무정령·화룡의 둥지 불꽃정령·풍룡의 둥지 폭풍정령**을 추가해 현재 **361/498종 연결, 137종 미완료**다. 영웅 이상 변신 **136/180**, 일반 몬스터 **190/258**, 보스 **35/60**. 이번 재개 작업의 추가 연결은 누적 **6종**이다.

정령의 실제 기존 원본은 낮은 아치 형태의 광물 몸체다. 이름만 보고 나무나 사람 형태로 바꾸지 않았다. 금색 원본의 동작을 검토한 뒤 불꽃·폭풍 원본에 맞는 재질/색상 변형에 재사용했다. **새 기본 동작 디자인 1개와 색상/재질 변형 2개**이며, 서로 독립적으로 설계한 동작 3개로 세지 않는다. 새 3리소스에는 312개의 서로 다른 픽셀 자세가 있고, 누적 native 리소스는 **89개**, 원본 기반 리소스 외형은 **53개·5,464자세**다. 나무정령의 지상 설정, 불꽃·폭풍정령의 기존 부유 설정, 이름별 원본 SHA·마법 공격·능력치를 보존했다.

실제 Main headless **3종/4,783개**, OpenGL **3종/5,141개**, 실패 0개다. 방향별 실제 AI 추적과 마법 공격, 5동작 104자세, 피격·사망·바닥 드랍·수동 습득을 검사했다. 상하 방향, 공격 접촉 자세, 사망 높이와 발 기준을 실제 화면에서도 검토했다. 이전 묶음에서 통과한 공통 회귀 이후 런타임/도구 코드는 변경하지 않았으며, 최종 커밋의 전체 검사는 CI에서 별도로 실행한다. [검증·보존 범위](evidence/pr100-direction-fix/original-based/batch18/validation-summary.json) · [실제 Main 결과](evidence/pr100-direction-fix/original-based/batch18/render.json) · [선별 N/S 화면](evidence/pr100-direction-fix/original-based/batch18/captures).

기존 Main 보고서 177개에 새 6개를 더해 **183개**와 방향표를 연결했다. 전체 캡처 336장의 해시를 기록하고 대표 N/S 화면 18장을 저장했다. 처음 반응 시트에 잘못 추가된 사람형 몸통/다리는 원본의 아치 구조로 수정한 뒤 적용했으며, 제외한 초안과 정확한 지시문은 [ZIP](evidence/pr100-direction-fix/original-based/batch18/authoring-drafts.zip)에 보존했다. 시작 시 에디터 소켓 권한 오류의 원문도 [별도 로그](evidence/pr100-direction-fix/original-based/batch18/initial-editor-socket-denied.log)에 보존한다. 현재 임포트는 오류 없이 통과했다.

**이 커밋의 Android·전체 CI는 푸시 후 확인한다. Android 기기 실행은 미검증**이다. 시작 체크포인트 `1de5363`의 [전체 통합](https://github.com/zoog136-hash/-/actions/runs/38524065173), [애니메이션](https://github.com/zoog136-hash/-/actions/runs/38524069047), [Android](https://github.com/zoog136-hash/-/actions/runs/38524072066)는 모두 성공 종료했으며 새 커밋의 결과로 사용하지 않는다. 재현 설정은 `res://tests/fixtures/pr100_batch18.json`이고, CI 묶음 행렬에도 batch18을 추가했다. 미완료 137종은 [목록](evidence/pr100-direction-fix/original-based/coverage/missing-native-sources.json)에서 계속 추적한다.

## 2026-10-14 재개 · batch17 오크 방향 수정과 3종 연결

PR #100의 실제 브랜치 `feature/twilight-animation-20261013`과 원격·로컬 HEAD **`1de5363b4fa006ff35ba22d11365c6ce3049264e`** 일치를 확인하고 깨끗한 체크아웃에서 재개했다. 최신 main `6fd15c82280a3f3dd136abe749ce1b53b31f8261`은 조회만 했으며 기존 PR 브랜치를 유지한다. 기존 완료 355종의 프로필·PNG·SpriteFrames·런타임 코드를 변경하지 않았다.

**오크 마법사·불신의 미믹·불신의 비홀더 3종**을 연결하고 실제 Main headless/OpenGL에서 검증했다. 현재 **358/498종 연결, 140종 미완료**다. 영웅 이상 변신 **136/180**, 일반 몬스터 **187/258**, 보스 **35/60**. 원본 기반 3외형·312개 실제 고유 자세를 추가해 native 리소스 **86개**, 원본 기반 **50외형·5,152자세**가 됐다. 원본 애니메이션 복원이나 모든 기존 이름의 개별 플레이 완료를 의미하지 않는다.

오크의 이전 초안은 E/SE·W/SW 시점 반복과 잘못된 NE 방향을 그림 자체에 포함했다. 공통 런타임 방향표는 바꾸지 않았다. 독립 8방향 회전표에서 NW를 교정한 뒤 대기/이동·공격·피격/사망을 나눠 제작했다. 큰 동작 시트에서 발견된 이웃 몸체의 프레임 침범은 더 작은 역할별 시트와 여백 수정으로 해결했다. 미믹의 방향 수정 도중 사망 자세가 공격으로 바뀐 초안은 제외했다. 최종 세 외형은 원본 SHA·표시 높이·능력치·공격 유형을 유지하며, 비홀더의 기존 부유 특성과 오크/비홀더의 실제 마법 투사체도 보존했다.

묶음당 모드별 한 엔진으로 실행한 **Main headless 3종/3,692개, OpenGL 3종/4,004개**가 모두 실패 0개다. 방향별 실제 AI 추적·공격·피격·사망 종료·바닥 드랍·수동 습득, 5동작 모든 자세와 발 위치를 검사했다. 방향 **1,362개**, 기존 native **35,742개**, 캔버스 **640개**, 전투 수명주기 **158개**, 관련 Python **35개**도 통과했다. 임포트 첫 실행의 에디터 소켓 생성 권한 오류를 기록했고, 소켓 연결을 허용한 실행에서는 임포트 오류 없이 통과했다. [묶음 검증·보존 범위](evidence/pr100-direction-fix/original-based/batch17/validation-summary.json) · [실제 Main 결과](evidence/pr100-direction-fix/original-based/batch17/render.json) · [선별 N/S 화면](evidence/pr100-direction-fix/original-based/batch17/captures) · [초안 및 정확한 제작 지시 ZIP](evidence/pr100-direction-fix/original-based/batch17/authoring-drafts.zip).

전체 336장 캡처의 해시를 기록하고 대표 N/S 대기·공격·사망 18장만 저장소에 보존했다. 나머지 캡처의 원본 PNG 전달을 주장하지 않는다. 기존 171개 Main 보고서를 보존하면서 새 6개를 더해 177개와 5,880행 방향표를 연결했다. 기존 알비노 악어 ZIP은 그대로이며, 최신 보존 초안에도 NE 공격 및 최종 NW 사망 방향 문제가 남아 있어 미연결이다.

보존 커밋 `1de5363`의 [애니메이션 CI](https://github.com/zoog136-hash/-/actions/runs/38524069047)와 [Android CI](https://github.com/zoog136-hash/-/actions/runs/38524072066)는 성공 종료를 확인했다. **새 커밋의 전체 CI·Android는 푸시 후 별도 확인하며, Android 기기 실행은 미검증**이다. 재현은 기존 batch16 실행 절차에서 설정을 `res://tests/fixtures/pr100_batch17.json`으로 바꾸고 새 격리 사용자 디렉터리를 사용한다. CI의 묶음 행렬에도 batch17을 추가했다.

## 2026-10-14 안전 인계 · batch16 현재 상태

보존 커밋 `6067ec1e74fbb7a3ae469caf8f75b5ea9e294b6b`에서 재개한 이번 세션은 **9종 추가**, 현재 **355/498종 연결·143종 미완료**다. 변신 **136/180**(44 미완료), 일반 몬스터 **184/258**(74), 보스 **35/60**(25). **83개 native 리소스·47개 원본 기반 디자인·4,840개 실제 고유 자세**를 사용한다. [현재 미완료 ID](evidence/pr100-direction-fix/original-based/coverage/missing-native-sources.json)와 방향표를 성공한 Main 보고서 **171개**로 갱신했다. 연결 수를 모든 기존 이름의 개별 플레이 완료 수로 바꾸어 해석하지 않는다.

첫 5종은 **`62ad60ae118c28f6f11bfc6facb3d5564e2ba929`**로 같은 PR #100에 푸시했다. 두 번째 계획 5종 중 **블루 하피·질투의 좀비 나이트·질투의 좀비 메이드·불신의 임프 4종**을 실제 Main으로 검증했다. 블루 하피는 기존 하피 그림을 재사용했고, 좀비 두 이름과 임프는 기존 원본에서 2개 디자인/208자세를 새로 그렸다. 각 이름의 원본·fallback body·능력치를 유지한다. 명시한 하피/좀비 대상만 원본 SHA·경로·표시 설정과 실제 source override가 일치할 때 공유할 수 있으며, 다른 body까지 비교를 완화하지 않았다. 실제 Main에서도 `flying`/`undead` 선택을 확인했다.

두 번째 묶음의 Main headless **4종/3,457개**, OpenGL **4종/3,856개**, 실패 0개다. 8방향 실제 AI 추적·공격과 5동작 프레임·지면 접촉·피격·사망·바닥 드랍·수동 습득을 확인했다. 관련 Python **33개**도 통과했다. 9종 전체를 묶음당 모드별 한 엔진으로 검사했고, 한 리소스의 전체 자세 캡처를 같은 묶음에서 중복하지 않았다. 최초 OpenGL 시도는 X11 연결 권한으로 게임 시작 전에 종료됐으며, 진단을 보존하고 표시 연결이 가능한 실행에서 통과했다. [검증·보존 범위](evidence/pr100-direction-fix/original-based/batch16/validation-summary.json), [실제 Main 240초 발췌](evidence/pr100-direction-fix/original-based/batch16/main-batch.mp4), [재현 명령](evidence/pr100-direction-fix/original-based/batch16/replay.txt).

**오크 마법사는 2회 연속 방향 검토 불합격으로 추가 생성을 중단했다.** 두 번째 초안은 인접 몸체가 프레임에 들어가는 문제도 있다. 완료 수량에 넣지 않았고 원본/불합격 PNG와 정확한 프롬프트·실패 원인을 [미완료 기록](evidence/pr100-direction-fix/original-based/batch16/orc-mage-blocked/authoring_blocker.json)에 보존했다. 런타임 에셋으로 잘못 취급하지 않도록 해당 초안은 증거 폴더에 둔다. 사용자가 정한 반복 오류 중단 기준에 따라 현재 묶음 검증·저장을 마치고 인계한다. 다음 세션에서는 같은 전체 시트 재생성을 반복하지 말고 **독립 8방향 회전표부터 검토**한 뒤 동작을 만든다.

첫 푸시 `62ad60a`의 [Android CI](https://github.com/zoog136-hash/-/actions/runs/38520075224)는 빌드·독립 검사·업로드까지 성공했다. **81개 compiled SpriteFrames·3,664트랙·14,952재생 슬롯·319개 PNG 임포트**, SHA·캔버스·ZIP CRC·ARM64·서명·16KB 정렬을 검사했다. APK **867,837,879 bytes**, SHA-256 **`b2d1d2b484a23d7be728fe5665083d1a137b66798b6ec07150a55c311bfa579f`**. [APK 산출물](https://github.com/zoog136-hash/-/actions/runs/38520075224/artifacts/11873753237) · [다운로드한 진단과 범위](evidence/pr100-direction-fix/original-based/batch16/previous-commit-android/scope.json). 이 결과에 마지막 2개 디자인을 포함하지 않는다. **현재 83개 리소스의 정확한 푸시 커밋 CI·Android 결과는 별도로 확인하며, 실제 Android 기기 실행은 미검증**이다.

재개 순서는 PR #100의 최신 head/보존 커밋 확인 → 해당 head의 CI 실패 job만 확인 → 오크 방향표와 기존 6개 시트의 프레임 밖 79픽셀 귀속 검토 → 남은 143종 중 다음 5~10종 선택이다. 알비노 악어는 계속 미연결이며 이전 초안 ZIP도 유지한다. 기존 2D 런타임·원본·정상 PNG/TRES를 보존했고 새 PR이나 main 병합은 수행하지 않았다.

마감 확인에서 첫 커밋의 애니메이션 CI가 기존 아시타지오의 출처 단언에서 실패한 것을 발견했다. 재사용 도구가 새 별칭의 `target_references`만 만들면서 기존 별칭을 그 목록에서 누락했다. 모든 기존 연결의 실제 원본 SHA·표시 설정을 먼저 검증하고 전체 출처 목록을 채우도록 수정했다. **아시타지오·오만한 아시타지오·하피·풍룡의 둥지 하피 4종의 실제 Main headless 3,886개**, linker Python **9개**, 전체 리소스의 출처 목록 완전성 검사를 통과했다. PNG/TRES·production profile 바이트는 그대로다. 기존 검사 단언을 약화하지 않았다. [실패 원인·수정·부분 회귀](evidence/pr100-direction-fix/original-based/batch16/ci-reference-fix/summary.json). 이미 알려진 오류가 있는 이 세션의 미종료 CI만 취소하고, 이 수정이 포함된 최종 푸시 커밋에서 전체 회귀·애니메이션·Android를 다시 확인한다. 진행 중 검사를 성공으로 기록하지 않는다.

## 이번 세션 첫 묶음 · batch15 기록

GitHub PR #100의 실제 head `feature/twilight-animation-20261013`이 보존 커밋 **`6067ec1e74fbb7a3ae469caf8f75b5ea9e294b6b`**와 정확히 일치하고 작업 트리가 깨끗한 상태에서 이어서 진행했다. 이전 346/498 연결과 미완료 152종, 원본 참조 222건, 이전 PNG/TRES 및 미완성 ZIP을 확인했다. 새 PR·main 병합·기존 기록 삭제 없이 같은 브랜치를 유지한다.

현재 **351/498종 연결**, **147종 미완료**다. 변신 **136/180**(44 미완료), 일반 몬스터 **180/258**(78), 보스 **35/60**(25). [현재 미완료 ID](evidence/pr100-direction-fix/original-based/coverage/missing-native-sources.json)와 5,880행 방향표는 성공한 Main 증거를 붙여 다시 생성했다.

- **잔혹한 아시타지오**: 기존 아시타지오 원본 두 파일의 SHA·크기·표시 설정이 같아 기존 모션을 재사용했다. 기존 PNG/TRES 바이트를 변경하지 않았다.
- **라미아·왜곡의 라미아**, **에바 왕국 수중정령·수룡의 둥지 심해정령**: 기존 참조 두 디자인에서 각 104자세(8방향 × 대기2·이동3·공격3·피격2·사망3)를 새로 제작했다. 208개 실제 고유 자세 추가, 총 **81개 native 리소스·45개 원본 기반 디자인·4,632개 고유 자세**다. 원본 애니메이션을 회수한 것으로 표현하지 않는다.
- 공통 방향·원점·프레임 처리와 기존 Main 회귀를 먼저 확인했다. 이미 수정된 Flare 방향 매핑과 정상 런타임은 유지했다. 새 임포트가 프레임 밖의 가시 조각을 조용히 버리지 못하도록 사전 검사를 추가했고, 단일 시트의 256 초과 캔버스에도 기존 정규화 메타데이터를 기록한다. 기존 256 캔버스 출력은 바이트 일치를 검사했다.
- 5종을 한 엔진 프로세스에서 순차 실행하도록 QA를 추가했다. 각 이름은 새 실제 `Main.tscn`에서 원래 능력치·AI·맵·사거리·전투·드랍을 사용한다. 생성된 테스트 저장 파일은 대상별로 보존하며 기존 사용자 저장이 있으면 실행을 거부한다.

공식 **Godot 4.7.2**, Main headless **5종/6,194개**, OpenGL **5종/6,450개**, 모두 실패 0개다. 8방향 실제 추적·공격, 전체 5동작 프레임·발 위치, 피격·사망 종료·바닥 드랍·수동 습득을 확인했다. 수중정령 두 이름은 원래 마법 사거리에서 실제 투사체까지 확인했다. 최초 QA가 근접용 시작 거리를 사용해 정령의 추적 검사가 실패했으며, 기존 마법 QA를 선택하도록 수정한 전후 기록을 보존했다. 게임 사거리나 AI는 바꾸지 않았다.

기존 Main OpenGL **7,740개**, 방향 **1,362개**, 캔버스 **640개**, native 회귀 **35,742개**, 관련 Python **26개**가 통과했다. [원시 결과·보존 해시·범위](evidence/pr100-direction-fix/original-based/batch15/validation-summary.json), [실제 Main 화면 240초 발췌](evidence/pr100-direction-fix/original-based/batch15/main-batch.mp4), [캡처 목록](evidence/pr100-direction-fix/original-based/batch15/capture-inventory.json)을 저장한다. 영상은 전체 5종 실행이나 성능 측정을 대신하지 않는다. 새 미채택 그림도 [초안 ZIP](evidence/pr100-direction-fix/original-based/batch15/rejected-generated-drafts.zip)에 보존했다.

기존 6개 시트에서 오래된 프레임 영역 밖 가시 픽셀 79개를 찾았으나 손상 여부는 아직 화면별 판정 전이다. 임의로 자르거나 기존 정상 외형을 다시 생성하지 않았다. 알비노 악어는 계속 미연결이다. **현재 81개 리소스의 정확한 커밋 CI·Android 내보내기는 푸시 후 확인 예정이며, Android 기기 실행은 미검증**이다. 다음 묶음은 원본·표시 설정을 대조한 5~10종을 연결하고 같은 Main 검증을 거친다.

## 아래는 보존 커밋 6067ec1까지의 이전 세션 기록

기존 `feature/twilight-animation-20261013` / `8ea63b3f036b91a801730ae101a1bfd7c0524b99`에서 이어서 수정했다. 이 보고서는 전체 외형 제작 완료를 뜻하지 않는다. 최종 저장 커밋은 이 문서를 포함하는 [PR #100](https://github.com/zoog136-hash/-/pull/100)의 HEAD에서 확인한다. 새 PR이나 main 병합을 수행하지 않았다.


## 진행분 안전 저장 마감

사용자의 작업 중단·안전 저장 요청에 따라 범위를 고정했다. 요청 전에 이미 연결한 **다이어울프·샤벨 타이거·바실리스크 3외형/일반 몬스터 4종**만 최소 검사·수정으로 마감했다. 새 외형 제작·악어 연결·전체 게임 테스트·Android 내보내기·CI 재실행은 시작하지 않았다. 기존 PR 브랜치를 유지하며 원본·미완성 파일·백업·이전 APK를 삭제하거나 되돌리지 않았다.

세 외형은 각각 **96개 실제 자세**(8방향 × 대기2·이동3·공격3·피격2·사망2), 합계288개를 사용한다. 실제 Main headless/OpenGL **최종8회 모두 실패0개**로 4종 각각의8방향 추적·공격, 피격·사망 종료, 바닥 드랍·수동 습득을 확인했다. 지역 타이거는 두 실제 원본 파일의 SHA/크기와 표시 설정이 동일해 리소스를 공유하지만, 각 원본 경로·참조를 독립적으로 보존하고 두 이름을 별도로 실제 전투 검사했다. [최종 Main 기록](evidence/pr100-direction-fix/original-based/batch14-safe-close/final-main-validation.json).

경로가 다른 타이거 별칭에 대해 QA가 기본 개체 파일을 기대하던 오류만 최소 수정했다. QA는 대상별 `target_references`를 선택하고 원본 SHA 및 실제 경로 단언을 유지한다. 변경된 production profile은 정확히4개이며 기존 게임 전투·AI·맵 코드는 바꾸지 않았다. 원본222건·이전 에셋 SHA 유지, Godot 임포트/부팅, 원본 공유·실제 프레임 검사14개, 캔버스640개가 통과했다. 살아 있는80자세/외형의 단일 배율은 기존86/78/78px 높이 제한을 유지한다.

최종 연결 수는 **변신136/180·일반 몬스터175/258·보스35/60**이다. **미완료152종(44/83/25)**을 그대로 기록한다. 79개 native 리소스·43개 신규 원본 기반 디자인·4,424개 실제 고유 자세, 최종 Main 보고서148개와 전체 방향표5,880행을 보존했다. 현재79개 리소스의 Android 빌드, Android 기기 실행 및 최종 커밋의 전체 CI는 미검증이다.

알비노 악어는 연결·완료 처리하지 않았다. 최신 초안과 불합격 시트 **12개** 및 제작 기록은 [미완성/불합격 초안 ZIP](evidence/pr100-direction-fix/original-based/batch14-safe-close/unfinished-and-rejected-drafts.zip)에 보존했다. 압축 파일은 **17,413,095 bytes**, SHA-256 `08bc243787488cfa1213f3eba5c4571b7e51151a0913494cfecc1d18036f9886`이며 CRC/개별 PNG SHA를 확인했다. 원본 참조 이미지는 복제하지 않았다. 선택된 나머지6개 생성 PNG는 native 경로에 바이트 그대로 저장한다. [보존 목록](evidence/pr100-direction-fix/original-based/batch14-safe-close/draft-preservation.json). 안전 저장 후 추가 작업을 종료한다.

## 상하 방향 오류

Godot의 화면 좌표 계산은 정상이다. `+Y`는 아래이고 게임 방향은 `E, SE, S, SW, W, NW, N, NE`다. 기존 변환기가 Flare 원본 방향을 `W, SW, S, SE, E, NE, N, NW`로 잘못 해석했다. 실제 원본 순서는 **`W, NW, N, NE, E, SE, S, SW`**이며 게임 방향에 대한 원본 인덱스는 **`[4,5,6,7,0,1,2,3]`**이다.

- 기존 **36개 SpriteFrames / 1,864개 트랙**의 이름과 출처 매핑을 수정했다. 대기·이동·공격·발사·시전·특수·피격·사망 모두 같은 기준을 따른다.
- 기존 **233개 PNG의 바이트·SHA-256, AtlasTexture 영역, 프레임 순서·시간·루프는 보존**했다. 상하 이미지 반전이나 음수 Y 스케일을 사용하지 않는다.
- `tools/build_open_sprite_sample.gd`, 36개 `provenance.json`, 독립 픽셀 기준과 회귀 검사를 함께 수정했다. 이전 방향 승인 기록의 잘못된 결론은 [독립 원인 분석](evidence/pr100-direction-fix/DIRECTION_CAUSE.md)에서 명시적으로 정정했다.
- `scripts/animation/animation_profile.gd::projectile_offset`와 `scripts/player.gd::combat_projectile_origin`은 8방향 무기의 발사점을 실제 조준 방향으로 옮긴다. 몸통의 높이와 조준 벡터를 구분하며 기존 좌우 발사점은 유지한다.

[원본 엔진 근거·전체 외형 접촉 시트](evidence/pr100-direction-fix/DIRECTION_CAUSE.md), [PNG 보존 및 TRES 변경 해시](evidence/pr100-direction-fix/resource-mapping-audit.json).

## 연결 수 및 미완료 외형

| 분류 | 실제 8방향 연속 프레임 연결 | 전체 | 미완료 |
|---|---:|---:|---:|
| 영웅 이상 변신 | 136 | 180 | 44 |
| 일반 몬스터 | 175 | 258 | 83 |
| 보스 | 35 | 60 | 25 |
| 기본 외형 | 4 | 4 | 0 |

기존 34개 확장 공용 외형과 기사·해골 표본 2개를 보존했다. `class:1/2/3`은 기존 지팡이·활·단검 외형에 연결한다. 후속 제작으로 늑대인간·고스트·여성 사신·오우거·라바 골렘·아이스 골렘·코카트리스·사이클롭스·경비병(창) 대장·서큐버스·하피·라이칸스로프·버그베어·샌드 웜·남성 사신·아이언 골렘·지역 구울·도마뱀·크랩맨·아시타지오·경비병(창)그린·경비병(창)·경비병(창)레드·알비노 개구리·파이어 에그·혼 켈베로스·불사의 머미 로드·불신의 시어·살라흐·본 드래곤·킹버그베어·에틴·고대 펭귄·판·알비노 자이언트 크랩·크라켄·눈사람·에티·아이스 맨·스콜피온·다이어울프·샤벨 타이거·바실리스크 **43개 외형**을 각각의 기존 이미지에서 새로 그렸다. 37개는 각 104자세(8방향 × 대기 2·이동 3·공격 3·피격 2·사망 3), 남성 사신은 실제 이동 2프레임, 아시타지오·에틴·다이어울프·샤벨 타이거·바실리스크는 실제 사망 2프레임을 포함한 각 96자세로 합계 **4,424개 고유 자세**다. 총 **79개 리소스**를 사용한다. 원본과 표시 설정이 이미 동일한 지역 개체만 공유하고 각 이름으로 Main 전투를 별도로 검사했다. 새 그림 43개가 변신 10종·일반 몬스터 56종·보스 4종에 적용됐다. 원본과 기존 모션을 덮어쓰지 않는다.

고정된 공개 소스의 377개 애니메이션 정의와 현재 로컬 자료를 확인했지만, 나머지 외형에 맞는 날개·마물·동물·특수 의상·창·총·이도류·클로·체인소드·낫 등의 8방향 원본은 확보하지 못했다. 서로 다른 몸체를 무리하게 대체하지 않았다. **남은 44/83/25종, 총 152종은 원본 기반 제작·연결·검증이 미완료**다. [현재 ID·사유 목록](evidence/pr100-direction-fix/original-based/coverage/missing-native-sources.json). 기존 54/139/29종 조사표는 이전 검증 증거로 보존했다.

전체 413개 변신, 318개 몬스터/보스, 4개 기본 외형의 **735개 ID × 8방향 = 5,880행** [검증표](evidence/pr100-direction-fix/original-based/coverage/all-identities-eight-directions.csv)를 자동 생성했다. 실제 RGBA 고유 프레임과 재생 슬롯 수를 구분한다. `source_metadata_only`, `actual_gameplay=not_run`은 전수 화면 승인이 아니라는 뜻이다. 성공한 실제 Main 보고서를 명시한 행만 `recorded_Main_sample`로 표시하며 해당 증거 경로를 함께 기록한다. 같은 리소스를 쓰더라도 실행하지 않은 다른 이름은 자동 승격하지 않는다. 실제 플레이한 표본은 별도 [Main 실행 기록](evidence/pr100-direction-fix/gameplay.json)으로 제공한다.

## 실제 TWILIGHT 검증

공식 Godot **4.7.2**, 실제 `Main.tscn`, 기존 직업 선택·아이템 장착·아덴 필드·HUD 명령·전투·AI·바닥 드랍·수동 습득을 사용했다. QA는 유효한 필드 위치에 배우를 배치하고 배경 몬스터를 잠시 정지하며 사용자 저장과 분리된 데이터 디렉터리를 사용한다. 별도 게임이나 프리뷰를 만들지 않았다.

- 검, 활, 지팡이의 기본 외형과 호환되는 실제 변신 `131/135/137`에서 각각 8방향 입력 이동·대기·공격/시전 **48사례**, 지팡이 일반 공격 **16사례**를 검사한다. 투사체 생성·진행 방향, 실제 피해 1회, 접촉 프레임·타격 시점, 같은 방향 대기 복귀, 외형 왕복을 확인한다. headless 전체 검사 **7,703개**, 실제 OpenGL 전체 검사 **7,618개**와 112개 Main 화면 캡처도 통과했다. JSON의 검사 수는 마지막 보고서 저장 확인 1개를 제외하며, 최종 수는 함께 저장한 stdout 로그에서 확인한다.
- 기존 해골 근위병의 실제 AI 추적·공격 8방향, 글루디오의 지배자의 기존 beam 경고·스킬·피해 8방향, 피격·사망·드랍·아이템 습득을 확인한다.
- 아덴 흑장로와 데스나이트에는 누락된 기존 엔진의 beam/cone 설정과 보스 메타데이터를 보완했다. 원작 고유 기술로 검증한 설정은 아니며 `local_adaptation_not_verified_original_skill`로 기록했다. 실제 Main의 16방향 경고·접촉·효과·복귀·중단·사망 검사 **164개**와 전체 60보스 presentation **713개**가 통과했다.
- 수정 방향 검사 **1,362개**, native 확장 **35,742개**가 통과했다. 실제 프레임·8방향·필수 동작·공격 접촉·해시·발 캔버스·캐시 생존을 검사한다. 이는 모든 이름의 개별 디자인·모든 무기 조합·모든 고유 보스 기술 화면 승인과 다르다.
- Godot 전체 임포트 및 Main 부팅은 통과했다. 최초 네트워크 제한 실행의 editor 소켓 오류를 별도 보존했고, 소켓 접근이 가능한 재실행에서는 parse/resource 오류 없이 종료했다.

[검](evidence/pr100-direction-fix/gameplay-video/sword.mp4) · [활](evidence/pr100-direction-fix/gameplay-video/bow.mp4) · [지팡이](evidence/pr100-direction-fix/gameplay-video/staff.mp4)는 실제 Main 화면 녹화다. 30FPS 원본을 H.264 20FPS로 압축한 검토용 영상이며 GPU 성능 측정으로 사용하지 않는다. 영상의 표본은 3개 변신과 드레이크이며, 방향별 공격 전수 확인은 Main 테스트와 화면 캡처를 함께 사용한다. [글루디오 보스의 8방향 beam 영상](evidence/pr100-direction-fix/gameplay-video/boss.mp4)은 실제 Main의 별도 보스 범위 **1,909개** 검사와 연결되며 전체 무기 검사를 대신하지 않는다. [실행 절차](evidence/pr100-direction-fix/gameplay-replay.txt)와 [실제 표본 80행 방향 검증표](evidence/pr100-direction-fix/gameplay-direction-verification.csv)를 제공한다.

## Android

안전 저장한 현재 **79개 리소스의 Android 내보내기는 미실행**이다. 사용자 요청에 따라 이번 마감에서 새 내보내기나 전체 CI를 실행하지 않았다. `c6e7da6`에서 성공 종료한 Android CI는 이전 68개 리소스와 사망 이펙트 수정 범위이며, 아래 로컬 APK는 `1afa922`까지의 65개 리소스에 해당한다. 서로 다른 커밋의 검증 범위를 혼동하지 않는다. [검증 범위](evidence/pr100-direction-fix/original-based/batch11/android-scope.json).

`c6e7da6`의 Android CI는 **빌드·독립 검사·APK 업로드까지 성공 종료**했다. 68개 compiled SpriteFrames·3,144트랙·13,624재생 슬롯·292개 PNG 임포트, 원본 SHA·캔버스·ZIP CRC·ARM64·v2/v3 서명·16KB 정렬을 검증했다. APK는 **834,295,857 bytes**, SHA-256 **`26a1c178c17ddd9fc39672d04216b6fb371ecb5a1d87392de87d92db059385a4`**다. [정확한 커밋의 APK 산출물](https://github.com/zoog136-hash/-/actions/runs/38508664942/artifacts/11870481432) · [CI 검사 원문](evidence/pr100-direction-fix/original-based/batch13/previous-commit-android/android.json). 916,420 bytes 진단 ZIP을 내려받아 CRC/SHA와 검사 결과를 확인했으며, APK 본체를 이 작업 공간에 다시 내려받은 결과로 주장하지 않는다. 현재 79개 리소스의 검증과 실제 기기 실행은 여전히 미완료다.

최근 로컬 Godot 4.7.2 디버그 ARM64 APK에는 65개 compiled SpriteFrames, 3,024개 트랙, 13,320개 재생 슬롯과 286개 PNG 임포트가 들어 있다. ZIP CRC, ARM64 구성, v2/v3 서명, 16KB 라이브러리 정렬, 실제 `.ctex`와 원본 임포트 해시, JSON/출처 메타데이터·캔버스 일치를 검사했다. 재생 슬롯 수를 고유 자세 수로 보고하지 않는다.

최신 APK 크기는 **827,862,502 bytes**, SHA-256은 **`6f684e0d30aad26ebeeb91b2d8f4a6365cded804bf470d30881b5d7a5b10e818`**다. [최신 APK 검사 결과](evidence/pr100-direction-fix/original-based/batch10/android/android.json). 방향 매핑만 고친 초기 771,837,680 bytes APK의 [이전 검사 결과](evidence/pr100-direction-fix/android/summary.json)는 별도로 보존했다.

**Android 기기 실행은 미검증**이다. 기기 연결이 없고 로컬 adb가 읽기 전용 사용자 홈에서 기기 검색을 완료하지 못했다. APK 내보내기 및 독립 검증과 실제 기기 실행을 구분한다. APK는 대용량 Git 리소스로 추가하지 않으며 같은 PR의 Android CI 산출물로 전달한다.

## CI 및 재현

이번 안전 마감의 최종 커밋은 **전체 CI 미검증**이다. 사용자 요청에 따라 새 workflow를 수동 실행하지 않았다. 이전 `c6e7da6`의 관찰 시점 `2026-10-14T05:08:33.424815+00:00`에는 29 workflow 중 19개 성공/10개 진행 중이며, 50 job 중 27개 성공/23개 진행 중이었다. 완료되지 않은 검사를 성공으로 표시하지 않는다. [정확한 이전 커밋의 관찰](evidence/pr100-direction-fix/original-based/batch14-safe-close/previous-commit-ci-observation.json). 이전 Windows 사망 집중 회귀 및 Android APK 빌드/검사/업로드는 성공 종료했다.

최근 종료한 `c19b53a`는 **29 workflow 중 27 성공/2 취소**, **46 job 중 43 성공/2 취소/1 실패**다. 취소된 workflow 내부의 Windows 실패를 별도로 집계한다. 두 취소는 Linux 45분·통합 40분 한도였고, Windows의 실패는 창 대장 변신 사망 프레임 누락이었다. 아래 후속 수정은 로컬 회귀까지 통과했으며 새 커밋의 Windows/전체 CI 성공 종료는 아직 확인 전이다. [정확한 종료 상태](evidence/pr100-direction-fix/original-based/batch11/ci/c19b53a-terminal.json).

시작 커밋의 CI 실패는 지역 레벨의 오래된 기대값, 실제 속도 보정을 무시한 스킬 쿨다운 기대값, 숨겨진 UI 바로가기 검사, 유지된 아이콘 연결 검사, 이동 캐시 서명, 보스 메타데이터·특수 설정, 밀집 스폰 후보 부족이었다. 해당 기능의 실제 계약을 확인하며 고쳤다. 밀집 스폰은 24마리·38px 간격·220px 반경과 보호 지형을 유지하고 실제 격자 후보를 선택한다. 지역 레벨·쿨다운·UI 검사는 실제 값·경계·불변성·신호 연결을 더 정확하게 검증한다.

최종 전체 로컬 회귀 및 PR HEAD CI 결과는 전달 시점의 실제 완료 상태를 기록한다. 실행 중인 CI를 성공으로 간주하지 않는다.

첫 푸시 `93df8ee`의 29개 workflow는 실제 종료까지 확인했으며 **19 성공 / 10 실패**였다. Android와 애니메이션 presentation은 통과했다. 성공한 APK의 [CI 산출물](https://github.com/zoog136-hash/-/actions/runs/38368109928/artifacts/11798237157)은 PR merge context `e3d0fb1`에서 생성되어 로컬 디버그 서명 APK와 해시가 다르다. [첫 푸시 결과](evidence/pr100-direction-fix/ci-followup/first-pushed-head-ci.json)를 최종 수정 후 CI와 혼동하지 않는다.

후속 실패 원인을 확인하여 두 아덴 보스 설정을 생성기에 반영했다. 생성기를 2회 실행해 승인된 카탈로그와 byte 일치를 확인했다. 스폰 검사는 **9,694개 / 0 실패**였으나 runner에 필요한 성공 marker가 없어 실패로 분류되던 문제를 고쳤다. 125개 실제 스킬 학습의 **1,689개** 검사는 약 **195초**에 통과하여 해당 검사에만 540초 제한을 부여했다. 로컬에 선택적 L1J 원본/CI fixture 전체가 없으면 세 검사는 명시적 SKIP이며, 일부 파일만 있는 불완전 설치는 계속 실패한다. 원본 에셋 확보나 화면 승인을 의미하지 않는다.

지도 캡처는 현재 오만 1층에 없는 tomb 대신 기존 stairs를 사용하고, 모든 저장 시 실제 map ID를 확인한다. 정적 검토 위치의 포탈은 그 검사 중에만 대기시켜 다른 지도를 잘못 저장하지 않도록 했다. 실제 OpenGL에서 기존 목표 **37장**과 4개 실제 이동·전투 표본 모두 통과했다. [검사 결과·해시](evidence/pr100-direction-fix/ci-followup/capture-regions-result.json), [실제 오만 1층 화면](evidence/pr100-direction-fix/ci-followup/oman_01-landmark.png).

드랍 검사는 실제 직업 선택을 거친 뒤 실행하고, 맵 재로딩으로 다시 생성된 주변 몬스터를 고정 위치 GUI 검사 전에 정리한다. 해당 구간에만 플레이어 물리를 정지하며 실제 걷기·보스 처치·AUTO 습득 구간에는 물리를 사용한다. 기존 단언은 모두 유지했다. 실제 전달 파일이 headless **167개 / 33.8초**, OpenGL **167개 / 48.1초**로 통과했다. 게임 런타임 변경은 없으며 엔진 결함이 확인됐다고 주장하지 않는다. [검사 범위와 전후 증거](evidence/pr100-direction-fix/ground-ci-fix/fixture-isolation.json).

## 원본 기반 제작 진행 상황

사용자 후속 지시에 따라 처음 미완료였던 222종의 입력 이미지를 [대응표](../../data/animation_authoring_sources.json)로 고정했다. 153개 서로 다른 파일/atlas 영역이며, 54개 카탈로그 이미지, 87개 기존 등록 몬스터 이미지, 81개 기존 프로젝트 atlas 연결이다. **프로젝트 atlas를 검증된 외부 원작 이미지라고 표시하지 않는다.** 각 대상의 실루엣·팔레트·얼굴·장비·무기를 확인하고 원본 바이트를 그대로 유지한다. 이 입력 목록은 완료 목록이 아니다.

늑대인간은 `assets/l1j/verified/monsters/5030.png`, 고스트는 기존 같은 종 연결 이미지 `assets/external_l1j/monsters/1318.png`를 바탕으로 제작했다. 별도 PNG 3개(4,686,902 bytes), 실제 208자세를 추가했고 반복 정지 프레임을 새 동작으로 세지 않았다. 원본 기반 새 그림이며 회수된 원작 애니메이션이 아니다. 방향 순서는 이 새 시트 자체의 `E,SE,S,SW,W,NW,N,NE` 메타데이터를 사용한다.

서로 다른 해상도로 제작된 고스트 동작은 AtlasTexture의 비례 캔버스와 `actor_motion.gd`의 명시적 메타데이터 처리로 발 위치와 표시 크기를 유지한다. 원본/새 시트 픽셀을 재샘플링하지 않는다. 기존 리소스는 이 메타데이터가 없어 기존 크기를 유지한다. Sprite2D와 AnimatedSprite2D의 8방향·상태 전환·반복 적용 **640개 검사**와 기존 native 확장 **35,742개 검사**가 통과했다.

실제 Main에서 늑대인간 headless **942개**, OpenGL 녹화 실행 **951개**, 고스트 headless **1,083개**, OpenGL **1,196개** 검사를 통과했다. 8방향 실제 추적/공격, 피격, 사망, 기존 확률 드랍, 수동 습득을 확인했다. 고스트의 기존 HP는 50으로 기본 캐릭터의 첫 공격에 죽으므로, 피격 모션 확인에는 실제 `take_damage(1)` 경로의 비치명 피해를 먼저 발생시킨다. 그 뒤 실제 무기로 처치하며 전투 능력치와 드랍 표는 바꾸지 않는다. 프레임별 수동 표본 검토는 AI 전투 증거와 별도로 기록한다.

[실제 Main 늑대인간 영상](evidence/pr100-direction-fix/original-based/werewolf-main.mp4), [범위·원본 보존·산출물 해시](evidence/pr100-direction-fix/original-based/preservation-and-scope.json), [고스트 실제 Main 기록](evidence/pr100-direction-fix/original-based/original_based_ghost_gameplay_test-opengl.json)을 보존했다. 제작 중 발견한 프레임 겹침, 불투명 배경, 중복 낫 초안은 적용 수치에서 제외했다. 이 문단의 2개 외형은 `15c71f5`까지의 저장 내역이며, 현재 수치는 맨 위 표와 최신 제작 묶음에서 확인한다.

새 2개 외형을 포함한 APK도 빌드 및 독립 검사에 통과했다. 38개 compiled SpriteFrames, 1,944개 트랙, 10,528개 재생 슬롯, 236개 PNG 임포트와 캔버스 메타데이터가 일치한다. APK는 774,993,177 bytes, SHA-256 `b582568218bcf9083f592e43de52a3635e7fbdb2d926a91bc6fede3502ea4e52`다. [검사 결과](evidence/pr100-direction-fix/original-based/android/android.json). 실제 Android 기기 실행은 여전히 미검증이다. 빌드 후 adb의 읽기 전용 홈 디렉터리 오류를 빌드 실패나 기기 실행 성공과 혼동하지 않는다.

`e66e861`의 CI는 실제 종료 기준 **28 workflow 성공, 1 취소**다. 취소된 Windows 회귀는 마지막 검사들에 도달한 뒤 35분 작업 제한에 걸렸으며, 현재 변경에서 45분으로 늘렸다. 개별 검사 제한과 모든 단언은 유지한다. [실제 종료 결과](evidence/pr100-direction-fix/original-based/e66-ci-summary.json). 이 후속 변경의 CI는 푸시한 정확한 HEAD에서 다시 종료까지 확인해야 한다.

## 여성 사신·오우거와 같은 원본의 지역 개체 추가

`신화-사신(여)`는 기존 카탈로그 이미지 `e090d7a50d6f7a23fe55576c.png`, 오우거는 기존 `16145.png`를 기준으로 제작했다. 원본의 얼굴·의상·무기·색상을 보존하며, 각 104개 실제 포즈를 별도 PNG로 연결했다. 중복 낫·접촉한 프레임·잘못된 행 수의 후보는 제외했다. 당시 창 경비병 후보는 집계하지 않았으며, 아래 세 번째 제작 묶음의 수정 시트로 별도 검증했다.

고스트/글루디오 던전 유령/지옥의 고스트는 기존 `1318.png`, 오우거/기란 평원 오우거/잊혀진 섬 고대오우거는 기존 `16145.png`를 이미 공유한다. 기존 `MonsterArt.material_for`와 `MonsterVisual`에서 사용하지 않는 폴백 색·장비·폭 메타데이터만 공유 비교에서 제외하고, **원본 경로·SHA·종 연결·몸체·표시 높이·공격 형태·모션 설정은 일치해야 한다.** 서로 다른 이미지나 프로젝트 atlas의 장식을 같은 외형으로 대체하지 않는다. 각 대상의 이전 설정을 출처 메타데이터에 보존했다.

여성 사신은 실제 사신 직업·배틀 사이드·변신 장착으로 8방향 이동/대기/공격, 타격 시점, 변신 왕복, 피격과 사망/부활을 검사했다. 피격과 치명 독 피해는 명시적인 production 콜백 입력이며 AI가 사신을 죽인 시험으로 표시하지 않는다. 사망 잔상에도 서로 다른 시트 해상도의 캔버스를 정규화하도록 `scripts/animation/combat_vfx.gd`를 수정했다. 기존 리소스의 잔상 크기·전투 판정은 유지한다.

| 실제 Main 대상 | headless 검사 | OpenGL 검사 |
|---|---:|---:|
| 여성 사신 | 1,516 | 1,535 |
| 오우거 | 1,202 | 1,317 |
| 글루디오 던전 유령 | 1,005 | 1,030 |
| 지옥의 고스트 | 1,005 | 1,014 |
| 기란 평원 오우거 | 1,044 | 1,069 |
| 잊혀진 섬 고대오우거 | 1,126 | 1,135 |

모두 실패 0개다. 지역 개체 검사는 원래 HP·방어·회피·전투 공식을 유지한다. 105레벨 고대 오우거는 훈련용 무기의 30회 한도로 처치되지 않아, 기존 도감의 진명황의 집행검을 정상 장착 경로로 사용했다. 높은 HP 표본의 시도 한도만 늘렸으며 HP를 낮추거나 명중을 강제하지 않았다. 각 실행의 실제 무기·시도 수·드랍·수동 습득은 [검증 결과](evidence/pr100-direction-fix/original-based/expansion-validation.json)와 원시 로그에 기록했다. 저장 확인 1개는 JSON보다 stdout 합계에 포함된다.

추가 검사: 원본/고유 포즈/공유 제한 Python 6개, 검증표의 실패 보고서·미실행 별칭 승격 방지 5개, 기존 native 35,742개, 캔버스 640개, hit feedback 58개 및 VFX 3,000회 스트레스가 통과했다. Godot 전체 임포트와 실제 Main OpenGL 기동도 통과했다. [원본 보존·새 파일 해시](evidence/pr100-direction-fix/original-based/preservation-and-scope.json), [사신 북쪽](evidence/pr100-direction-fix/original-based/original_based_reaper_gameplay_test-authored-N-idle-0.png), [사신 남쪽](evidence/pr100-direction-fix/original-based/original_based_reaper_gameplay_test-authored-S-idle-0.png), [오우거 북쪽](evidence/pr100-direction-fix/original-based/original_based_ogre_gameplay_test-authored-N-idle-0.png).

`bc9dddc`까지의 APK는 **778,717,948 bytes**, SHA-256 **`578d72f67cd3b5b9f2c8bd1a8b0e0af0247c4bc1c8dc924f95b04aeb6311489e`**다. 40개 compiled SpriteFrames·2,024개 트랙·10,736개 재생 슬롯·239개 PNG 임포트 및 SHA·캔버스, ARM64·서명·16KB 정렬·ZIP CRC가 통과했다. [이전 APK 검증](evidence/pr100-direction-fix/original-based/android-expanded/android.json). 실제 Android 기기 실행은 미검증이며, APK 빌드 성공으로 대체하지 않는다.

`15c71f5`는 자동 CI가 등록되지 않아 기존 브랜치의 검증 workflow 29개를 명시적으로 실행했다. 실제 종료 결과는 27 성공·1 실패·1 취소다. `bc9dddc`에서 별도로 실행한 관련 5개 workflow는 2 성공·3 실패로 종료했다. 아래 수정과 최종 HEAD의 CI를 이전 실행과 구분한다.

## 골렘·코카트리스·사이클롭스·창 대장 추가

이번 묶음은 기존 `15738.png`의 라바 골렘 2종, `10358.png`의 아이스 골렘, `14169.png`의 코카트리스 4종, `5683.png`의 사이클롭스, 카탈로그 `4954db6f65010804b3185b7a.png`의 경비병(창) 대장이다. **원본 5개 디자인에서 새 520자세를 제작하여 9종을 연결**했다. 원본 팔레트·얼굴·몸체·장비를 유지했고 상하·좌우를 별도로 그렸다. 코카트리스의 남쪽 접촉이 오른쪽으로 돌아간 후보는 수정했으며, 무기가 이웃 프레임에 닿은 사이클롭스·창 대장 후보는 다시 제작했다. 픽셀 중복·잘림·안전한 프레임 영역 검사도 통과했다.

| 실제 Main 대상 | headless 검사 | OpenGL 검사 |
|---|---:|---:|
| 라바 골렘 | 1,284 | 1,397 |
| 아이스 골렘 | 996 | 1,077 |
| 화룡의 둥지 라바 골렘 | 1,044 | 1,053 |
| 코카트리스 | 956 | 1,117 |
| 기란 평원 코카트리스 | 1,020 | 1,013 |
| 잊혀진 섬 고대코카트리스 | 1,086 | 1,095 |
| 왜곡의 코카트리스 | 844 | 837 |
| 사이클롭스 | 1,204 | 1,302 |
| 경비병(창) 대장 | 1,528 | 1,553 |

모두 실패 0개다. 몬스터는 각 이름별 8방향 실제 AI 추적·공격, 정상 장착 무기로 처치, 원래 확률 드랍, 수동 습득을 검사했다. 코카트리스는 HP 880을 유지한 채 30회 공격 한도를 초과하므로 검사 시도 한도를 200회로 통일했다. 낮은 HP 표본은 처치 즉시 루프를 끝내며 전투 공식을 바꾸지 않는다. 창 대장은 기사 직업에서 기존 크림슨 랜스를 장착하고 변신 176을 적용하여 8방향 타격·변신 왕복·피격·사망/부활을 검사했다. 사망 시험의 들어오는 피해는 기존 사신 시험처럼 명시적인 production 콜백 입력이며 AI 공격으로 표기하지 않는다. [실행 기록 및 검사 수](evidence/pr100-direction-fix/original-based/batch3/validation-summary.json).

원본 참조 222건의 SHA-256과 이전에 추적하던 에셋은 모두 유지됐다. 새 리소스를 Git에 등록한 뒤 735개 ID × 8방향 검증표를 다시 생성했다. 새 제작 리소스 9개, 기존 리소스 36개, 총 45개이며 누락 경로·프레임 무결성 오류는 0개다. 원본/공유/포즈 Python 6개, 검증표 Python 5개, 기존 native 35,742개와 캔버스 640개 검사가 통과했다. 기존 사신과 늑대인간의 Main 회귀도 별도로 통과했다.

이전 묶음의 로컬 APK는 **786,426,179 bytes**, SHA-256 **`4f43f77b4198ee645f676dcdbe6272b666b23074cbcb3c61066e7f9c053d07b6`**다. compiled SpriteFrames 45개·트랙 2,224개·재생 슬롯 11,256개·PNG 임포트 246개, ARM64·서명·16KB 정렬·ZIP CRC·원본 SHA·캔버스가 통과했다. [APK 검사 결과](evidence/pr100-direction-fix/original-based/batch3/android/android.json). Android 실제 기기 실행은 미검증이다.

이전 CI 실패 세 가지를 다음과 같이 수정했다.

- 아덴 고정 시작점은 몬스터와 1,000px 이상 떨어져 빠른 렌더러에서 180프레임이 접근 도중 끝났다. 실제 스폰된 몬스터 근처의 통행·시야가 유효한 지점으로 검사 시작점을 선택한다. 로컬 37장 캡처와 4개 필드 활성 전투가 종료 코드 0으로 끝났다.
- 군중 검사 종료 후 남은 독·출혈이 새 피해 숫자 VFX를 생성했다. 표본 사이에서 상태 효과도 정리한다. 실제 독·출혈 경로의 수정 전 실패를 재현했고 수정 후 재검사와 32/96/192마리 × 사냥/보스의 6개 OpenGL 표본이 모두 통과했다. 전투 중 실제 상태 효과는 그대로 검사한다.
- L1J 합성 CI는 늑대인간 원본을 별도 `_ci_fixture` 경로로 교체하므로 원본 경로 단언과 충돌했다. 원본 SHA를 항상 검사하면서 명시적으로 선언된 합성 경로와 해당 SHA도 확인한다. 실제 원본 경로와 분리된 동일 TWILIGHT 프로젝트의 합성 경로에서 모두 통과했다. **합성 결과는 원본 화면 검증표에 포함할 수 없도록 거부한다.**

원본 기반 17종의 Main 검사를 CI의 네 작업으로 나눴으며 기존 표본과 단언을 유지했다. [수정 전 CI 종료 결과](evidence/pr100-direction-fix/original-based/batch3/ci-before-fixes/bc9-ci-summary.json)는 성공으로 바꾸지 않았다. 이 문서 저장 후 푸시된 HEAD의 실제 종료 결과는 PR #100의 Checks와 본문에 기록한다. 이 묶음 시점에는 **205종 제작과 Android 실기기 실행이 미완료**였다.

`8d2e403a685290dc082573b57b2a0f203f9e8a43`의 CI는 **29개 workflow / 36개 job 모두 성공**으로 종료했다. [실제 종료 상태](evidence/pr100-direction-fix/original-based/batch4/previous-commit-ci.json). 아래 후속 커밋의 CI 결과와 구분한다.

## 서큐버스·하피·라이칸스로프 추가

기존 원본 `1112.png`의 서큐버스 7종, `1024.png`의 하피 2종, `4820.png`의 라이칸스로프 2종을 각각 원본 기반으로 제작한 3개 디자인·312자세에 연결했다. 몸체 메타데이터가 다른 블루 하피는 동일 이미지로 교체하지 않았다. 원본 참조 222건의 SHA와 기존 추적 에셋은 그대로이며, 11개 이름 각각에서 headless와 실제 OpenGL Main의 8방향 AI 추적·공격·피격·사망·원래 드랍·수동 습득을 확인했다. [22개 실행 기록](evidence/pr100-direction-fix/original-based/batch4/validation-summary.json). `fdffcd9` 시점의 합계는 **변신 128/180, 일반 몬스터 145/258, 보스 31/60**, 당시 남은 대상은 **194종**이었다.

서큐버스는 실제 마법 사거리와 투사체를 유지한다. 근접 몬스터용 시작점 대신 각 방향에 통행·시야가 확보된 실제 지형을 선택하고, 실제 카메라에 시전자와 플레이어가 함께 들어오도록 검사 확대율을 조정했다. 7종 × 8방향에서 실제 마법 투사체의 이동 벡터·접촉 종류와 기존 타격 콜백을 확인했다. HP 1,919인 지룡서큐버스는 초반 검으로 200회 후 HP 217이 남았으므로, 기존 고레벨 장비 검사와 같이 실제 DB 무기를 정상 장착해 재검사했다. 몬스터 HP·방어력·명중 공식을 변경하지 않았다.

원거리 필드 검사에서 발견한 검격 이펙트 오류도 수정했다. `impact_visuals.gd`가 큰 월드 좌표를 얇은 초승달 다각형의 정점에 직접 더하면 부동소수점 오차로 삼각분할이 실패했다. 동일 1,600개 표본에서 기존 방식은 7개 실패, 로컬 좌표는 0개 실패였다. 도형을 원점 근처에서 만들고 기존 위치로 캔버스를 이동하여 모양·방향·접촉 위치를 보존했다. 8방향·4개 크기·100개 진행도 검사와 기존 스트레스를 포함한 **3,258개 검사**, 실제 Main 검·활·지팡이 회귀 **headless 7,687 / OpenGL 7,302개**가 모두 통과했다. 검증에는 기본/변신 48사례와 지팡이 일반 공격 16사례, 일반 몬스터·보스 전투가 포함된다.

Godot 전체 임포트와 실제 Main 기동이 통과했다. `fdffcd9`의 APK는 **790,048,921 bytes**, SHA-256 **`eb8d0d38d89accc98d8cad5c85ef09e94ce9d0d9e32960d4769756fd831a57c5`**다. compiled SpriteFrames **48개**, 트랙 **2,344개**, 재생 슬롯 **11,568개**, PNG 임포트 **249개**, ARM64·v2/v3 서명·16KB 정렬·ZIP CRC·원본 SHA·캔버스가 통과했다. [APK 검사 결과](evidence/pr100-direction-fix/original-based/batch4/android/android.json). **Android 실제 기기 실행은 미검증**이며 재생 슬롯 수를 고유 자세 수로 사용하지 않는다. 샌드 웜·버그베어의 다음 제작 후보는 당시 커밋과 완료 수에 포함하지 않았다.

## 작업 복구와 버그베어·샌드 웜·남성 사신 추가

원격 턴 중단 후 `/workspace/TWILIGHT`의 기존 브랜치와 PR #100의 HEAD가 모두 `fdffcd9c5cd572ea7cc79ea5548c337a6d50377e`임을 확인했다. 미커밋 19개 파일, binary patch, 제작 recipe를 별도 보관하고 백업 안의 바이트와 SHA를 검증했다. 강제 초기화·브랜치 변경·미커밋 삭제·원본 덮어쓰기는 하지 않았다. [복구 결과](evidence/pr100-direction-fix/original-based/batch5/recovery-result.json), [보존 파일 해시](evidence/pr100-direction-fix/original-based/batch5/recovery-backup-manifest.json). 백업 자체의 `/workspace` 경로는 해당 Work 환경의 로컬 경로이며 외부 배포 링크로 표시하지 않는다.

사용자가 제공한 오류 화면에서 원격 턴의 파일 URL 다운로드가 upstream HTTP 503으로 실패하고, 바깥 응답이 `400 / invalid_request_error / invalid_value / param=url`임을 확인했다. 화면에는 요청 URL과 파일명이 없어 특정 서버·파일·장애 원인을 확정할 수 없다. 서비스 복구나 만료 URL 갱신 후 재시도할 수 있지만, 식별되지 않은 요청을 실제 재시도했다고 보고하지 않는다. [오류 문구와 복구 판단](evidence/pr100-direction-fix/original-based/batch5/recovery-regression/download-diagnosis.json). 휴대전화 화면 전체는 로컬에만 보존했다.

별도로 확인된 GitHub Godot release 다운로드 HTTP 500은 게임 검사 전 발생했고, [동일 CI의 두 번째 실행](https://github.com/zoog136-hash/-/actions/runs/38410431010)은 2026-10-13 14:39:16 UTC에 성공했다. `fdffcd9`의 **29 workflow / 39 job 모두 성공**으로 종료했다. [확인한 실제 종료 상태](evidence/pr100-direction-fix/original-based/batch5/previous-commit-ci.json). 두 HTTP 오류를 같은 원인으로 단정하지 않는다. 복구된 이미지·엔진·검증 로그가 온전하여 입력 파일을 다시 다운로드하지 않고 미완료 단계부터 재개했다.

버그베어는 기존 `45223.png`의 몸체·빨간 허리옷·가시 곤봉, 남성 사신은 변신 258의 `0c6685aea67140a668a2e435.png`에 있는 검은 금장 갑옷·청록 장식·낫을 바탕으로 제작했다. 샌드 웜은 현재 게임의 `assets/monsters/original/atlas_3.png` 15번 영역에 있는 마디진 몸통·붉은 이빨 입·모래 받침을 유지했다. **샌드 웜의 프로젝트 원본을 검증된 외부 원작 이미지라고 표시하지 않는다.** 원본과 영역을 실제 production portrait 경로에서도 대조했다.

버그베어와 샌드 웜은 각 104자세, 남성 사신은 실제 96자세로 이번에 **304개의 서로 다른 포즈**를 연결했다. 남성 사신 출력은 이동이 2프레임이므로 `movement_fps`를 실제 프레임 수 / 기존 이동 주기 0.48초로 계산하도록 importer를 수정했다. 3번째 이동 프레임을 복제하지 않았으며, 다른 3프레임 외형의 속도는 같다. 각 방향의 전면·측면·후면과 피격·쓰러짐·최종 사망 자세를 검사했다.

| 실제 Main 대상 | headless 검사 | OpenGL 검사 |
|---|---:|---:|
| 버그베어 | 997 | 1,110 |
| 샌드 웜 | 2,845 | 2,966 |
| 남성 사신 | 1,500 | 1,427 |

모두 실패 0개다. 샌드 웜은 일반 추적·공격 8방향과 별도로 기존 nova AI의 경고·공격 유지·효과 방향·실제 피해·대기 복귀·효과 종료·중단을 8방향 검사했다. 보스의 HP 3,200과 기존 공격 패턴은 유지했다. nova는 기존 `local_adaptation_not_verified_original_skill`이며 원작 고유 기술을 복원했다는 의미가 아니다. 정상 장착 무기로 처치한 뒤 실제 드랍·수동 습득도 통과했다. 남성 사신은 실제 직업·배틀 사이드·변신 장착/해제·입력 공격과 피격/사망/부활을 확인했다. 들어오는 피격·치명 독 피해의 production 콜백 검사는 AI 전투와 별도로 표시한다.

[6개 실행 기록](evidence/pr100-direction-fix/original-based/batch5/validation-summary.json), [샌드 웜 Main 녹화](evidence/pr100-direction-fix/original-based/batch5/sand-worm-main.mp4), [남성 사신 Main 녹화](evidence/pr100-direction-fix/original-based/batch5/reaper-male-main.mp4)를 저장했다. 영상은 실제 게임 실행 앞부분을 압축한 검토 자료이며 이후 프레임별 자세 표본을 포함할 수 있다. 전투·자세 표본·피격 입력은 JSON에서 구분하며, 녹화가 전체 검사를 담았다고 주장하지 않는다.

원본 참조 222건의 SHA, 기존 에셋, 35,742개 native 검사와 640개 캔버스 검사, Python 11개 검사, Godot 임포트가 통과했다. 735개 ID × 8방향 검증표를 새 3종의 실제 Main 기록으로 갱신하고, 원본 기반 31종의 CI를 8개 작업으로 연결했다. 현재 **변신 129/180·일반 몬스터 146/258·보스 32/60**, 나머지 **191종의 제작·연결·검증은 미완료**다. 이 변경을 푸시한 정확한 HEAD의 CI 종료 상태는 PR #100 본문과 Checks에서 별도로 확인한다.

새 3종을 포함한 APK는 **798,517,984 bytes**, SHA-256 **`3045017f67a1e51ae1a687b6624fb30396fd9e43abea2c10700e4ea1f5ad506d`**다. compiled SpriteFrames **51개**, 트랙 **2,464개**, 재생 슬롯 **11,872개**, PNG 임포트 **255개**, ARM64·v2/v3 서명·16KB 정렬·ZIP CRC·원본 SHA·캔버스가 통과했다. [실제 APK 검사 결과](evidence/pr100-direction-fix/original-based/batch5/android/android.json). **Android 실제 기기 실행은 미검증**이다. 원래 미커밋 파일 19개는 복구 백업과 여전히 byte 일치하며, [별도 보존 확인](evidence/pr100-direction-fix/original-based/batch5/recovered-files-preserved.json)을 남겼다.

## 복구 후 전체 카탈로그 검사 보정

복구 파일 19개는 `67a45d4eb3c85dce454346326e6be9b364cec4e3`으로 기존 PR 브랜치에 저장했다. 이후 전체 회귀 검사에서 남성 사신의 2프레임 걷기를 0번과 2번 시점으로 비교해 같은 프레임을 다시 읽는 검사 오류를 발견했다. `full_visual_manifest_test.gd`, `capture_all_catalog_motion.gd`, `capture_full_catalog.gd`에서 인접한 실제 자세를 비교하도록 수정했다. Main 캡처는 기존 atlas의 `twilight_visual_key` 외에 native SpriteFrames의 **장착된 profile ID와 실제 리소스 경로가 모두 일치**하는지도 확인한다. 게임 동작이나 PNG를 바꾸거나 중복 프레임을 추가하지 않았다.

수정 후 전체 manifest 검사와 실제 Main의 정상 장착 경로를 통한 **변신 413·인형 166·성물 144, 총 723개 외형 / 실패 0건**을 확인했다. 각 외형의 서로 다른 두 실제 프레임과 OpenGL 픽셀 해시를 검사했다. 별도의 기존 production renderer 검사도 723개 모두 통과했다. 이 검사는 두 자세의 연결·표시 증거이며, 723종 모두의 8방향 전 동작 완성이나 수동 아트 승인을 의미하지 않는다. 기존 Main 보고서의 `views_available`는 옛 atlas 메타데이터이므로 native 방향 수로 사용하지 않는다. [검사 전후 로그·실행 결과·원본 보존](evidence/pr100-direction-fix/original-based/batch5/recovery-regression/summary.json).

`67a45d4`의 [Android CI](https://github.com/zoog136-hash/-/actions/runs/38477049871)는 성공했다. [APK 산출물](https://github.com/zoog136-hash/-/actions/runs/38477049871/artifacts/11857060267)은 798,517,984 bytes, SHA-256 `80b00268d2b829e72329acf25af6ba64a8213657cfb62e3695bbd811d7d5d94a`이며 51개 compiled SpriteFrames / 2,464트랙 / 11,872재생 슬롯을 포함한다. CI 서명본과 앞의 로컬 서명본은 해시가 다르다. 실제 기기 실행은 미검증이다. 전체 로컬 회귀와 수정 후 정확한 HEAD의 CI 종료 결과는 PR 본문에서 별도로 확인한다.

## 아이언 골렘·지역 구울·도마뱀: 원본 기반 6종 추가

기존 이미지 `2147.png`의 아이언 골렘, `15772.png`의 구울, `15649.png`의 도마뱀을 각각 기준으로 새 8방향 시트를 제작했다. 철제 몸체와 주먹, 구울의 마른 체형·상처·허리 천, 도마뱀의 청색 몸체·붉은 등돌기·긴 꼬리를 유지했다. 새 3개 디자인은 각 104개 고유 자세, 합계 **312개 실제 자세**이며 같은 원본과 실제 표시 설정을 이미 공유하는 아래 6종에만 적용했다. 기존 기본 구울 연결은 그대로 유지했다. 원본 참조 222건의 SHA와 이전에 추적되던 에셋의 바이트가 모두 보존됐다.

| 실제 Main 대상 | headless 검사 | OpenGL 검사 |
|---|---:|---:|
| 아이언 골렘 | 869 | 999 |
| 지옥의 아이언골렘 | 807 | 816 |
| 글루디오 던전 구울 | 1,085 | 1,199 |
| 불사의 구울 | 767 | 776 |
| 도마뱀 | 1,005 | 1,071 |
| 알비노 도마뱀 | 927 | 936 |

12회 모두 실패 0개다. 실제 Main에서 8방향 AI 추적·공격, 피격·사망 종료, 기존 확률 드랍·수동 습득을 검사했다. 능력치·전투 공식·드랍 표는 유지했다. [실행 기록과 범위](evidence/pr100-direction-fix/original-based/batch6/validation-summary.json), [아이언 골렘 영상](evidence/pr100-direction-fix/original-based/batch6/iron-golem-main.mp4), [구울 영상](evidence/pr100-direction-fix/original-based/batch6/ghoul-main.mp4), [도마뱀 영상](evidence/pr100-direction-fix/original-based/batch6/lizard-main.mp4)을 저장했다. 영상은 실제 Main 실행 앞부분 90초이며 전투 이후 명시적 자세 검사를 포함할 수 있다. 각 영상이 전체 테스트를 담거나 Android 성능을 증명하지 않는다.

검토 중 바위가 자세 표본을 가리는 점을 발견했다. `original_based_pose_review_helper.gd`는 실제 AI·전투 검사 이후의 명시적 자세 검사에서만 주변의 걸을 수 있는 빈 위치를 찾는다. 실제 전경 오브젝트 경계를 확인하며 지형을 숨기거나 수정하지 않는다. 도마뱀은 중앙 대기 자세 기준 배율에서 긴 N/S 몸체가 기존 86px 표시 높이를 넘었다. importer의 선택적 `max_living_frame` 메타데이터로 **모든 방향·상태에 동일한 배율 0.661538**을 적용했다. PNG와 프레임 수는 그대로이고, 앞·뒤 방향에서 이름표와 몸체가 겹치지 않는 것을 다시 확인했다. 다른 외형의 기본 배율 계산은 유지한다. [검토 후 수정과 제외 후보](evidence/pr100-direction-fix/original-based/batch6/review-corrections.json).

Godot 4.7.2 임포트·실제 Main 실행, 원본/공유/고유 자세 및 검증표 Python 12개, native 35,742개, 캔버스 640개 검사가 통과했다. 검증표에는 54개 리소스와 성공한 Main 보고서 75개를 연결했다. 이전 복구 작업의 전체 로컬 회귀 원시 결과는 **169개 중 162 성공·1 실패·6 SKIP**으로 보존했다. 그 1건은 위의 2프레임 걷기 검사 오류이며 수정 후 별도 재검사에 통과해 합산 확인은 **163 성공·6 SKIP·미해결 실패 0**이다. 원래 전체 실행의 종료 코드를 성공으로 바꾸지 않았다. [원시 결과와 재검사 구분](evidence/pr100-direction-fix/original-based/batch6/recovered-project-regression/combined-results.json). 직전 저장 커밋 `4d90a94`의 CI는 실제 종료 기준 **29개 workflow / 40개 job 모두 성공**했다. 새 6종을 포함한 후속 커밋의 CI와는 별개이며 그 결과는 PR #100 본문에서 정확한 SHA와 함께 갱신한다.

최종 도마뱀 배율까지 포함한 로컬 Android APK는 **805,442,831 bytes**, SHA-256 **`fc443e74a31192b2cac44de548444f8a5cb864462eba81b9237e09be69c3beb4`**다. compiled SpriteFrames **54개**, 트랙 **2,584개**, 재생 슬롯 **12,184개**, PNG 임포트 **261개**, ARM64·v2/v3 서명·16KB 정렬·ZIP CRC·원본 SHA·캔버스 검사에 통과했다. [최종 APK 검사](evidence/pr100-direction-fix/original-based/batch6/android/android.json). **Android 실제 기기 실행은 미검증**이다. 배율 수정 전 APK와 실패한 제작 후보는 완료 증거에서 제외했다. 현재 연결 수는 **변신 129/180·일반 몬스터 152/258·보스 32/60**, 미완료는 **185종**이다.

## 크랩맨·아시타지오·녹색 창 경비병: 원본 기반 5종 추가

크랩맨은 기존 `1610.png`의 가느다란 갑각 몸체와 집게, 아시타지오는 `16150.png`의 검은 뿔·불꽃 팔·짧은 다리, 경비병(창)그린은 `87117dbb872151681c4f8566.png`의 강철 투구·흰색/녹색 의상·단일 창을 기준으로 제작했다. 각 원본 이미지는 그대로 보존했다. 크랩맨과 녹색 창 경비병은 각 104자세, 아시타지오는 실제 사망 2프레임을 포함한 96자세로 **304개 고유 자세**를 추가했다. 없는 사망 프레임을 반복해 3개로 보고하지 않는다. 기존 원본·표시 설정이 일치하는 크랩맨 2종과 아시타지오 2종, 변신 `167`만 연결했다.

| 실제 Main 대상 | headless 검사 | OpenGL 검사 |
|---|---:|---:|
| 크랩맨 | 925 | 1,007 |
| 에바 왕국 크랩맨 | 1,085 | 1,094 |
| 아시타지오 | 1,069 | 1,175 |
| 오만한 아시타지오 | 879 | 888 |
| 경비병(창)그린 | 1,594 | 1,579 |

10회 모두 실패 0개다. 몬스터는 실제 Main의 8방향 추적·공격·피격·사망·바닥 드랍·수동 습득을 검사했다. 경비병은 기존 기사 직업과 크림슨 랜스 장착, 8방향 입력·공격 접촉·1회 타격·같은 방향 대기 복귀·변신 왕복을 검사했다. 경비병의 피격·치명 독 피해·부활은 명시적 production 콜백 입력이며 AI 처치 표본과 구분한다. 전투 능력치·드랍 표·보스 시스템은 바꾸지 않았다. [실행 기록](evidence/pr100-direction-fix/original-based/batch7/validation-summary.json), [크랩맨 영상](evidence/pr100-direction-fix/original-based/batch7/crabman-main.mp4), [아시타지오 영상](evidence/pr100-direction-fix/original-based/batch7/asitagio-main.mp4), [경비병 영상](evidence/pr100-direction-fix/original-based/batch7/spear-guard-green-main.mp4)을 보존했다. 영상은 실제 Main의 앞부분 90초이며 전체 검사나 Android 실행을 대신하지 않는다.

긴 창 공격은 8방향을 물리적인 행, 공격 3단계를 열로 배치한 별도 시트를 사용한다. `tools/import_original_based_motion.py`는 `directions_axis` 메타데이터와 자세별 발 기준점을 읽어 프레임 인덱스를 정규화한다. 이미지 회전·상하 반전·픽셀 재배치는 없다. 392px 대기 캔버스와 224px 공격 캔버스를 비례 정규화해 실제 Main의 남쪽·북쪽 공격에서 몸체 크기와 창 끝 방향을 확인했다. 잘못된 창 방향, 겹친 프레임, 행 수 오류의 후보는 적용하지 않았다.

Godot 임포트·Main 실행, Python 14개, native 35,742개, 캔버스 640개 검사가 통과했다. 처음에는 존재하지 않는 캔버스 테스트 파일명을 실행해 실패했으며, 실제 `original_based_canvas_test.gd`로 고쳐 통과했다. [실패 명령과 정정 기록](evidence/pr100-direction-fix/original-based/batch7/canvas-invocation-correction.json)을 보존하며 게임 결함으로 분류하지 않는다. 57개 리소스와 실제 Main 보고서 85개를 5,880행 검증표에 연결했다. 원본 참조 222건의 SHA는 일치하고 기존 추적 에셋은 변경하지 않았다.

이번 5종을 포함한 APK는 **811,954,278 bytes**, SHA-256 **`ea5219e072b2df2d403cb3cc9b86b37d3c30162e0cc9a8f161d184815f2082fc`**다. compiled SpriteFrames **57개**, 트랙 **2,704개**, 재생 슬롯 **12,488개**, PNG 임포트 **268개**, ARM64·v2/v3 서명·16KB 정렬·ZIP CRC·원본 SHA·캔버스 검사가 통과했다. [APK 검사](evidence/pr100-direction-fix/original-based/batch7/android/android.json). **Android 실제 기기 실행은 미검증**이다. 현재 적용 수는 **변신 130/180·일반 몬스터 156/258·보스 32/60**, 미완료는 **180종**이다. 같은 PR 브랜치의 정확한 푸시 SHA와 CI 종료 결과는 PR 본문에서 갱신한다.

직전 `8bce4dd` CI는 실제 종료 기준 **28개 workflow 성공·1개 취소**였다. Windows 전체 회귀는 `world_regions_test`까지 166개 PASS·실패 0개를 출력한 뒤 45분 job 제한으로 마지막 검사 중 취소됐다. 완료로 처리하지 않는다. Windows 전체 job만 60분으로 조정하고 Linux의 45분·개별 테스트 제한·모든 단언은 유지했다. [정확한 종료 결과](evidence/pr100-direction-fix/original-based/batch7/8bce4dd-ci-terminal.json), [원인·정정](evidence/pr100-direction-fix/original-based/batch7/windows-ci-time-budget.json). 새 커밋의 전체 CI 종료 확인은 별도로 필요하다.

## 기본·빨간 창 경비병: 원본 기반 변신 2종 추가

변신 `2`와 `110`의 기존 원본 `1b99b161b4ebedb6c86c2f16.png`, `9ad7673e0bc7551d5fef799b.png`를 각각 기준으로 제작했다. 남색/자주색과 빨간색 의상, 흰 겉옷·강철 투구·갈색 장화·단일 창을 각각 유지하며 녹색 경비병의 PNG를 공유하지 않는다. 두 외형은 각 104개, 합계 **208개 고유 자세**를 추가했다. 이동·피격 시트에서 다른 행에 닿는 창 끝을 발견해 간격을 다시 제작했고, 첫 임포트의 필수 검토 필드 누락도 별도 기록 후 바로잡았다. 이전 후보·불완전 실행은 완료 근거로 사용하지 않는다.

| 실제 Main 대상 | headless 검사 | OpenGL 검사 |
|---|---:|---:|
| 경비병(창), 변신 2 | 1,606 | 1,603 |
| 경비병(창)레드, 변신 110 | 1,594 | 1,631 |
| 기존 경비병(창)그린 회귀 | 이전 증거 유지 | 1,495 |

실제 기사 직업과 크림슨 랜스로 8방향 입력·대기·이동·공격, 접촉 시점·1회 타격·대기 복귀·변신 장착/해제 왕복을 검사했다. 새 두 외형은 headless/OpenGL 모두 각 8방향 사망에서 세 자세와 정상 종료를 확인했다. 들어오는 피격과 치명 독 피해는 기존 production 콜백을 제어 입력한 검사다. AI가 플레이어를 처치한 표본으로 보고하지 않는다. [최종 실행 기록](evidence/pr100-direction-fix/original-based/batch8/validation-summary.json), [기본 창 경비병 영상](evidence/pr100-direction-fix/original-based/batch8/spear-guard-main.mp4), [빨간 창 경비병 영상](evidence/pr100-direction-fix/original-based/batch8/spear-guard-red-main.mp4). 영상은 실제 Main 앞부분 90초이며 이후의 모든 검사를 담지는 않는다.

실제 화면 검토에서 공격 중 몸체가 커지는 후보를 제외했다. PNG를 변경하지 않고 공격의 가상 캔버스를 각각 352/416px로 보정하고, 창 끝 대신 두 장화 사이를 발 기준점으로 사용했다. 남쪽 대기 대비 공격의 머리부터 발까지의 높이는 각각 약 0.97/1.02배이며 실제 Main의 N/S 접촉·평상시·사망을 다시 확인했다. [몸체 비율 근거](evidence/pr100-direction-fix/original-based/batch8/body-scale-review.json). 독립 회귀 검사는 이전의 20% 이상 확대를 검출한다.

빨간 경비병의 첫 수정 후 OpenGL 실행에서는 PNG를 저장하는 동안 사망 중간 자세를 놓쳐 E/W/NE가 `[0,2]`로 관측됐다. 원래 실패 기록을 보존했다. `tests/original_based_reaper_gameplay_test.gd`는 화면을 실제 렌더 시 메모리에 담고 PNG 압축·저장을 사망 시계 종료 뒤에 수행하도록 고쳤다. **게임의 사망 시간·프레임·시계와 세 자세를 요구하는 단언은 유지**한다. 새 두 외형의 재검사와 기존 녹색 경비병의 실제 OpenGL 회귀에서 모두 `[0,1,2]`를 확인했다. [이전 실패와 수정 범위](evidence/pr100-direction-fix/original-based/batch8/capture-clock-correction.json).

Godot 임포트·Main 실행, Python **16개**, 기존 native **35,742개**, 캔버스 **640개** 검사가 통과했다. 기존 원본 참조 222건과 이전 추적 에셋을 보존했고, 59개 리소스 및 Main 보고서 90개를 5,880행 검증표에 연결했다. APK는 **814,168,400 bytes**, SHA-256 **`c4757bb29b6a7bd5a6a93fc6cba3743b46d4179115ea3d69da146300b6225e16`**다. **59개 SpriteFrames·2,784트랙·12,696재생 슬롯·274 PNG 임포트**, 원본 SHA·캔버스·CRC·ARM64·서명·16KB 정렬을 검증했다. [APK 검사](evidence/pr100-direction-fix/original-based/batch8/android/android.json). Android 실기기 실행은 미검증이다. 현재 적용 수는 **변신 132/180·일반 몬스터 156/258·보스 32/60**, 미완료는 **178종**이다. 정확한 새 커밋의 CI 종료 상태는 PR 본문과 Checks에서 별도로 확인한다.


## 개구리·파이어 에그·혼 켈베로스: 원본 기반 일반 몬스터 6종 추가

기존 `13290.png`, `1820.png`, `16154.png`를 각각 기준으로 3개 외형·312개 고유 자세를 제작했다. 개구리는 실제 원본의 붉은 얼굴·청록색 눈·큰 녹색 잎·작은 갈색 도구를 유지했다. 이름을 근거로 흰색 개구리로 바꾸지 않는다. 파이어 에그는 원본의 노란색/주황색 불꽃이며 얼굴·껍질·팔다리를 추가하지 않았다. 본래 회전 대칭에 가까운 불꽃이므로 방향별 기울기·방출 자세와 실제 마법 투사체로 방향을 검사한다. 혼 켈베로스는 검은 몸·원래 머리 형태·등의 연결된 불꽃을 유지한다. 원본과 실제 표시 설정이 일치하는 각 지역 개체 2종씩만 연결했다.

| 실제 Main 대상 | headless 검사 | OpenGL 검사 |
|---|---:|---:|
| 알비노 개구리 | 927 | 1,073 |
| 알비노 뿔 개구리 | 927 | 968 |
| 파이어 에그 | 1,432 | 1,546 |
| 공포의 파이어 에그 | 1,354 | 1,363 |
| 혼 켈베로스 | 1,390 | 1,486 |
| 잔혹한 혼 켈베로스 | 1,482 | 1,523 |

12회 모두 실패 0개다. 실제 Main의 8방향 추적·공격 접촉·대기 복귀, 실제 무기로 피격·사망·바닥 드랍·수동 습득을 검사했다. 104자세의 화면 샘플은 실제 전투 검사와 별도로 표시한다. 파이어 에그·혼 켈베로스 4종은 원래 마법 사거리와 공격 유형을 유지하며 실제 투사체의 8방향 이동·도착 타격을 확인했다. 공통 화면 검사 위치 보정의 회귀로 기존 서큐버스도 실제 OpenGL **1,638개** 검사를 통과했다. 전투 수치·드랍 표·보스 시스템은 바꾸지 않았다. [최종 실행 기록](evidence/pr100-direction-fix/original-based/batch9/validation-summary.json).

첫 후보는 기능 검사를 통과했지만 불꽃 등 일부 방향의 전체 높이가 이름표 영역에 닿았다. 기존 표시 높이 안에 모든 살아 있는 자세가 들어가도록 외형별 단일 배율을 적용했다. PNG 바이트·가로세로 비율·프레임 시간·방향별 크기는 바꾸지 않았다. 독립 검사는 실제 알파 픽셀을 읽어 80개 살아 있는 자세의 높이를 전수 측정한다. 수정 전 기록과 화면을 [별도로 보존](evidence/pr100-direction-fix/original-based/batch9/before-scale-review/qualification.json)했고 수정 후 Main 검사를 다시 실행했다. [배율·PNG 보존 근거](evidence/pr100-direction-fix/original-based/batch9/living-height-review.json). 새 마법 개체에서 드러난 테스트 음성 표본 오류는 원래 공격 유형과 반대 유형을 사용하도록 바로잡았으며 엄격한 외형 구별 단언은 유지한다.

Godot 임포트·Main 실행, Python **16개**, 기존 native **35,742개**, 캔버스 **640개** 검사가 통과했다. 기존 원본 참조 222건과 추적 에셋의 바이트를 보존했다. 62개 리소스와 Main 보고서 103개를 5,880행 검증표에 연결했다. [개구리 영상](evidence/pr100-direction-fix/original-based/batch9/albino-frog-main.mp4), [파이어 에그 영상](evidence/pr100-direction-fix/original-based/batch9/fire-egg-main.mp4), [혼 켈베로스 영상](evidence/pr100-direction-fix/original-based/batch9/horn-cerberus-main.mp4)은 실제 Main 앞부분 90초이며 전체 검사나 Android 실기기 실행을 대신하지 않는다.

APK는 **819,155,883 bytes**, SHA-256 **`4aa732f816d9dec9e87cf77b6322d23e0c9971ca2c915b6d667e19c1523d89ae`**다. **62개 SpriteFrames·2,904트랙·13,008재생 슬롯·280 PNG 임포트**, 원본 SHA·캔버스·CRC·ARM64·서명·16KB 정렬을 검증했다. [APK 검사](evidence/pr100-direction-fix/original-based/batch9/android/android.json). Android 실기기 실행은 미검증이다. 현재 적용 수는 **변신 132/180·일반 몬스터 162/258·보스 32/60**, 미완료는 **172종**이다.

앞선 `d25863d` CI는 실제 종료 기준 **29개 workflow·44개 job 모두 성공**이다. Windows 전체 회귀도 60분 제한 안에 49분 23초로 완료되어 이전 45분 취소 문제의 수정 결과를 확인했다. [정확한 종료 결과](evidence/pr100-direction-fix/original-based/batch9/d25863d-ci-terminal.json). 이는 이번 새 커밋의 CI 결과와 구분하며 새 HEAD의 종료 상태는 PR에서 갱신한다. PR #100의 main 충돌 표시는 남아 있으며 다른 PR을 임의로 가져오거나 main에 병합하지 않았다.



## 머미 로드·시어·살라흐: 기존 프로젝트 이미지 기반 보스 3종 추가

기존 `assets/monsters/original/atlas_3.png`의 서로 다른 세 셀을 각각 기준으로 3개 외형·312개 고유 자세를 제작했다. 머미 로드의 붕대·금색 왕관·청색/금색 장식·굽은 검, 시어의 큰 붉은 눈·입·눈자루, 살라흐의 뿔 달린 해골·갈색/붉은 천·긴 곡날 무기를 유지했다. 북쪽은 얼굴을 숨긴 뒷모습이며 남쪽은 전면이다. 이는 기존 TWILIGHT 프로젝트 그림을 기준으로 한 제작이며 외부 원작 리소스나 원작 고유 스킬의 검증을 뜻하지 않는다.

| 실제 Main 보스 | 기존 특수 패턴 | headless 검사 | OpenGL 검사 |
|---|---|---:|---:|
| 불사의 머미 로드 | nova 광역 공격 | 2,262 | 2,384 |
| 불신의 시어 | beam 직선 마법 | 2,831 | 2,953 |
| 살라흐 | summon 소환 | 2,430 | 2,552 |

6회 모두 실패 0개다. 실제 Main의 8방향 일반 공격과 8방향 기존 보스 특수 패턴에서 경고 방향·애니메이션 유지·실제 발동 시점·타격/효과 영역·대기 복귀·효과 종료·중단 처리를 검사했다. 시어는 원래 사거리의 실제 마법 투사체도 8방향 확인했다. 살라흐는 매 방향에서 기존 FieldPopulation이 실제 하수인 2마리씩 소환하는 것을 확인했다. 소환 후 하수인은 보스 효과를 분리 관찰하기 위해 정지시켰으므로 하수인 전투 완료로 보고하지 않는다. 세 보스 모두 실제 장비로 피격·사망·바닥 드랍·수동 습득까지 통과했다. [최종 실행 기록](evidence/pr100-direction-fix/original-based/batch10/validation-summary.json).

첫 headless 검사에서는 일반 몬스터의 200회 공격 제한에 도달해 각각 10,367/8,298/16,095 HP가 남았고 사망·드랍 단언이 실패했다. 그 기록을 보존했다. 보스의 HP·방어력·장비 피해를 유지하면서 이 세 보스 QA에만 최대 768회의 실제 공격을 허용했다. 최종 headless에서는 머미 로드 330회, 시어 289회, 살라흐 466회로 처치했다. 새 보스 CI 두 그룹만 실행 한도를 450초로 지정했고 기존 그룹은 300초를 유지한다. [이전 실패와 수정 범위](evidence/pr100-direction-fix/original-based/batch10/boss-fight-budget-correction.json). 게임 전투 코드를 바꾸거나 HP를 직접 0으로 만들지 않았다.

소환형 보스에 직접 피해를 요구하던 검증표 집계 오류도 수정했다. 소환형은 실제 생성 수·경고·효과·직접 피해 0회를 요구하고, 피해형 보스의 타격 요구는 유지한다. [수정과 부정 사례 검사](evidence/pr100-direction-fix/original-based/batch10/summon-audit-correction.json).

머미 로드 첫 시트의 겹친 프레임은 제외하고 다시 제작했다. 최종 세 외형은 서로 다른 시트 해상도를 가상 캔버스로 정규화하고, 방향·상태가 바뀌어도 단일 배율을 사용한다. 모든 살아 있는 자세가 기존 표시 높이 안에 들어가며 원본 PNG·기존 에셋·보스 능력치·스킬 설정을 보존했다. 각 보스의 Main N/S 공격·대기·사망 및 실제 스킬 화면을 검토했다.

Godot 임포트·Main 실행, Python **17개**, 기존 native **35,742개**, 캔버스 **640개** 검사가 통과했다. 원본 참조 222건과 이전 추적 에셋을 보존했고, 65개 리소스 및 Main 보고서 109개를 5,880행 검증표에 연결했다. [머미 로드 영상](evidence/pr100-direction-fix/original-based/batch10/mummy-lord-main.mp4), [시어 영상](evidence/pr100-direction-fix/original-based/batch10/seer-boss-main.mp4), [살라흐 영상](evidence/pr100-direction-fix/original-based/batch10/salah-main.mp4)은 실제 Main 앞부분 90초이며 전체 검사나 Android 실기기 실행을 대신하지 않는다.

APK는 **827,862,502 bytes**, SHA-256 **`6f684e0d30aad26ebeeb91b2d8f4a6365cded804bf470d30881b5d7a5b10e818`**다. **65개 SpriteFrames·3,024트랙·13,320재생 슬롯·286 PNG 임포트**, 원본 SHA·캔버스·CRC·ARM64·서명·16KB 정렬을 검증했다. [APK 검사](evidence/pr100-direction-fix/original-based/batch10/android/android.json). Android 실기기 실행은 미검증이다. 현재 적용 수는 **변신 132/180·일반 몬스터 162/258·보스 35/60**, 미완료는 **169종**이다. 정확한 푸시 SHA의 CI는 진행 중 상태와 성공 종료를 구분해 PR 본문과 Checks에서 갱신한다.



## 본 드래곤·킹버그베어·에틴 5종과 실제 사망 이펙트 시간 수정

기존 몬스터 원본 `16835.png`, `15742.png`, `12983.png`에서 각각 본 드래곤·킹버그베어·에틴을 제작했다. 본 드래곤의 해골·뼈 날개·긴 꼬리, 킹버그베어의 원래 체형·푸른 회색 손잡이의 무기, 에틴의 두 머리·원래 매듭진 곤봉을 유지했다. 기존 원본과 표시 설정이 같은 본 드래곤 지역 개체 세 이름만 공유한다. 에틴은 실제 제작된 사망 2프레임을 그대로 사용해 96자세이며, 나머지 두 외형은 104자세씩, 합계 **304개 고유 자세**다.

실제 Main에서 용의 계곡 본 드래곤·불멸의 본 드래곤·지옥의 본 드래곤·킹버그베어·에틴을 각 이름으로 headless와 OpenGL 실행했다. **10회 모두 실패 0개**로 8방향 추적·대기·공격·실제 타격·복귀, 피격·사망·바닥 드랍·수동 습득을 통과했다. 본 드래곤은 원래 마법 사거리와 실제 투사체의 진행·도착 타격을 검사했다. N 뒷모습/S 전면, 실제 공격과 납작한 사망 자세를 Main 화면에서 검토했고, 살아 있는 80자세의 알파 높이가 외형별 기존 표시 한도 안에 들어간다. [Main 검사](evidence/pr100-direction-fix/original-based/batch11/validation-summary.json) · [본 드래곤 영상](evidence/pr100-direction-fix/original-based/batch11/bone-dragon-main.mp4) · [킹버그베어 영상](evidence/pr100-direction-fix/original-based/batch11/king-bugbear-main.mp4) · [에틴 영상](evidence/pr100-direction-fix/original-based/batch11/ettin-main.mp4). 영상은 실제 Main 앞부분 90초다.

`c19b53a` Windows에서는 창 대장 변신의 이동·공격 8방향이 모두 통과했지만 사망 프레임 검사가 실패했다. 셸의 artifact 다운로드는 프록시 HTTP 403으로 막혔으나 GitHub 커넥터에서 받은 ZIP 166,302 bytes의 CRC와 SHA를 검증해 정확한 실패 로그를 복구했다. 최초 사용자 첨부의 upstream HTTP 503과는 별개의 다운로드 경로다.

검사를 VFX의 실제 process/render 갱신 시점에 맞추자 로컬 Main에서도 창 대장 NE `[1,2]`, 붉은 경비병 E/SE/NW `[0,2]`, S `[1,2]` 누락을 재현했다. 원인은 `scripts/animation/combat_vfx.gd`가 원본 트랙의 **0.65초 재생을 고정 0.4초로 압축**한 것이다. 새 구현은 프레임 duration의 합과 SpriteFrames 속도를 사용한다. 보통 외형의 기존 0.8초 이펙트 수명은 유지하며, 더 긴 트랙은 전체 모션과 0.15초 마지막 자세 유지 시간을 확보한다. 원본 이미지·전투 피해·공격 시점·부활 규칙은 바꾸지 않았다.

독립 0.14초 렌더 간격 검사는 수정 전 세 단언이 실패했고 수정 후 통과했다. 가중 프레임·긴 트랙·이펙트 종료와 풀 반환도 검증했다. 창 대장·붉은 창 경비병·여성 사신의 headless 3회 및 창 두 외형의 실제 OpenGL 2회, **최종 Main 회귀 5회 모두 통과**했다. 각 방향에서 `[0,1,2]` 세 자세, 실제 시각·발 위치·크기·종료·부활 단언을 유지했고 PNG는 재생 종료 후 저장한다. 이전 실패와 전체 로그를 보존한다. [원인과 수정 범위](evidence/pr100-direction-fix/original-based/batch11/death-timing-correction.json) · [최종 회귀](evidence/pr100-direction-fix/original-based/batch11/death-timing-validation.json).

Python 원본 모션/검증표 17개와 실행기 20개, 기존 native 35,742개, VFX·피격 3,258개·authored-state 102개·전투 lifecycle 158개·캔버스 640개 검사가 통과했다. 원본 참조 222건과 기존 추적 에셋을 보존했다. **68개 리소스, 실제 Main 보고서 124개, 방향별 5,880행**을 연결했다. 적용 수는 **변신 132/180·일반 몬스터 167/258·보스 35/60**, 미완료는 **164종**이다.

시간 제한 취소도 성공으로 처리하지 않았다. 기존 전체 Linux job 35~45분/Windows 51분의 측정과 추가 보스 전투 시간을 반영해 전체 검사 job 한도를 Linux 75분/Windows 90분으로 조정했다. 일반 개별 검사 제한은 유지하고 실제 보스 3종만 최소 450초를 사용한다. Windows 사망 회귀를 전체 검사 전에 실행하며, 임시 저장 삭제 후에도 실제 JSON 보고서를 보존하고 실패 내용은 일반 job 로그에도 남긴다. 새 정확한 푸시 SHA의 CI 및 Android 내보내기 결과는 종료 후 별도 확정한다. Android 실기기 실행은 미검증이다.


## 고대 펭귄·판·알비노 자이언트 크랩·크라켄 변신 추가

각각의 기존 카탈로그 원본 이미지에서 네 외형을 별도로 제작했다. 고대 펭귄의 푸른 깃·흰 수염/가슴, 판의 네 발 몸체·뿔·긴 창, 알비노 자이언트 크랩 원본의 실제 붉은 등껍질·집게, 크라켄의 청록색/금색 인체형 몸체·연결된 촉수를 유지했다. 원본과 생성 PNG를 덮어쓰거나 상하 반전하지 않았다. 판은 서로 다른 실제 40개 대기/이동·24개 창 공격·40개 피격/사망 자세를 연결했으며, 네 외형 합계 **416개 고유 자세**다. 판의 잘못된 최초 공격/이동 초안은 제외했다.

최종 headless 4회와 OpenGL 4회가 모두 통과했다. 실제 직업 선택·장비·변신 명령·8방향 입력 이동·대기·공격 접촉 프레임·정확한 피해 1회·대기 복귀·변신 해제/재적용을 확인했다. 방향별 실제 피격과 사망 3자세, 이펙트 위치/크기/종료, 부활 후 변신 유지도 통과했다. 들어오는 피해는 기존 피격/독 콜백을 제어 호출한 범위이며 몬스터 AI 공격 표본으로 세지 않는다. [최종 Main 검사](evidence/pr100-direction-fix/original-based/batch12/validation-summary.json).

판은 기사/크림슨 랜스, 나머지 세 자연형 변신은 다크엘프/강철 크로우의 실제 전투 경로로 검사했다. 원래 신체 공격을 유지하며 그림에 임의의 장비를 추가하지 않았다. 이 네 표본만으로 모든 검·활·지팡이 조합을 검증했다고 주장하지 않는다. 기존 세 무기의 전용 8방향 검사는 앞 절의 증거를 보존했다.

판의 첫 화면에서는 정상적인 전경 바위가 창 끝을 가렸다. 게임이나 지형을 바꾸지 않고 QA의 자세 검토 위치만 가까운 이동 가능 지역으로 옮겨, 창 전체와 앞/뒤 방향 및 사망을 다시 확인했다. 이전 통과 로그와 가려진 화면도 보존하며 검증표에서는 최종 두 실행만 집계한다. [검토 위치 변경 범위](evidence/pr100-direction-fix/original-based/batch12/pan-before-review-position/scope.json). 네 외형의 모든 살아 있는 80자세가 기존 100px 표시 한도 안에 들어가고, 방향/상태에 따른 몸체 배율 변경을 사용하지 않는다.

Godot 임포트·실제 Main, Python **18개**, 기존 native **35,742개**, 캔버스 **640개** 검사가 통과했다. 원본 참조 222건의 SHA와 기존 에셋을 보존했다. **72개 리소스·Main 보고서 132개·5,880행 방향 검증표**를 기록했다. 현재 연결 수는 **변신 136/180·일반 몬스터 167/258·보스 35/60**, 남은 대상은 **160종(44/91/25)**이다.

[고대 펭귄](evidence/pr100-direction-fix/original-based/batch12/ancient-penguin-main.mp4) · [판](evidence/pr100-direction-fix/original-based/batch12/pan-main.mp4) · [알비노 자이언트 크랩](evidence/pr100-direction-fix/original-based/batch12/albino-giant-crab-main.mp4) · [크라켄](evidence/pr100-direction-fix/original-based/batch12/kraken-transform-main.mp4) 영상은 각각 실제 Main의 앞부분 90초다. 현재 72개 리소스의 Android 내보내기와 정확한 HEAD CI 종료는 아직 확인 전이며 실제 Android 기기 실행도 미검증이다.


## 눈사람·에티·아이스 맨·스콜피온 추가

기존 원본 `15639.png`, `10355.png`, `2158.png`, `15648.png`를 각각 기준으로 네 외형·**416개 고유 자세**를 제작했다. 눈사람의 세 눈덩이·붉은 모자·나뭇가지, 에티의 굽은 체형·흰 긴 털, 아이스 맨의 푸른 얼음 면과 팔다리, 스콜피온의 보라/갈색 몸체·밝은 집게·마디 꼬리를 유지한다. 각 외형은 8방향 × 대기2·이동3·공격3·피격2·사망3의 실제 프레임을 사용한다.

실제 Main의 headless4회/OpenGL4회, **8회 모두 실패0개**로 끝났다. 방향별 실제 추적·공격·피해·같은 방향 대기 복귀, 피격·사망 종료·바닥 드랍·수동 습득을 확인했다. 기존 HP·공격·방어·맵·드랍 표는 보존했다. [실제 실행 기록](evidence/pr100-direction-fix/original-based/batch13/validation-summary.json). 네 외형 모두 북쪽 뒷모습·남쪽 전면/공격·최종 사망 자세를 실제 게임 지형 위에서 검토했다. 아이스 맨 시트 뷰어의 강한 청록색 표시는 대부분 알파1~3/255인 RGB이며, 원본 픽셀을 손대지 않고 실제 게임의 투명 표시를 확인했다.

네 외형마다 살아 있는80개 자세가 기존86/86/86/78px 높이 범위에 들어가며, 전 방향·동작에 단일 배율을 사용한다. 원본 참조222건과 이전 추적 에셋의 SHA를 보존했다. Godot 임포트·Main 실행, Python18개, 기존 native35,742개, 캔버스640개 검사가 통과했다.

이 묶음까지 **변신136/180·일반 몬스터171/258·보스35/60**, 미완료는 **156종(44/87/25)**이다. **76개 리소스·실제 Main 최종 기록140개·방향 검증표5,880행**을 연결했다. [눈사람](evidence/pr100-direction-fix/original-based/batch13/snowman-main.mp4) · [에티](evidence/pr100-direction-fix/original-based/batch13/yeti-main.mp4) · [아이스 맨](evidence/pr100-direction-fix/original-based/batch13/ice-man-main.mp4) · [스콜피온](evidence/pr100-direction-fix/original-based/batch13/scorpion-main.mp4)은 실제 Main 앞부분90초 영상이다. 현재76개 리소스의 Android 내보내기와 정확한 푸시 커밋의 CI 성공 종료, Android 실기기 실행은 아직 확인하지 않았다.


```sh
python3 tools/check_resource_integrity.py --root .
godot --headless --editor --path . --import --quit
godot --headless --path . --quit-after 120
godot --headless --path . --script res://tests/eight_direction_animation_test.gd
godot --headless --path . --script res://tests/native_animation_expansion_test.gd
godot --headless --path . --script res://tests/pr100_direction_gameplay_test.gd
godot --headless --path . --script res://tests/aden_boss_special_test.gd
python3 tests/eight_direction_coverage_audit_test.py
python3 tools/audit_eight_direction_coverage.py --root . --output-dir direction-audit
python3 tools/test_project.py --godot /path/to/Godot_v4.7.2-stable_linux.x86_64 --logs test-results
python3 tools/verify_android_animation_export.py --apk /path/to/TWILIGHT.apk --godot /path/to/godot --android-sdk /path/to/android-sdk --output android-validation
```

소프트웨어 화면 캡처는 Xvfb 등 실제 OpenGL 디스플레이와 `LIBGL_ALWAYS_SOFTWARE=1`을 사용한다. `TWILIGHT_PR100_CAPTURE_DIR`는 실제 Main 방향 검사 화면의 저장 위치, `TWILIGHT_PR100_SECTION=boss`는 기존 보스만 검사하는 선택적 녹화 범위다. 생략하면 전체 검사를 실행한다. 사용자 저장을 보존하려면 각 검사에 별도의 `XDG_DATA_HOME`, `XDG_CONFIG_HOME`, `XDG_CACHE_HOME`을 지정한다.
