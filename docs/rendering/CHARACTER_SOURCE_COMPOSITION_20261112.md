# 캐릭터 주변 광채·실루엣 조사와 합성 수정

기준 main: `11df08720afdb988884ad1c2b316d937fb7dc64d` (#414 병합).
브랜치: `feature/character-source-alpha-20261112`. 별도 clone에서 작업했다.

## 사진과 정체의 확인 범위

사용자 Library 원본 ID
`libfile_fde3_f-bbf201f61368819194835bebde3ffdb5_a45b800353708191ad5088f9182e6ba5`를
그대로 사용해 `photo-evidence/1001112039.jpg`로 가져왔다. 소비 환경에서 파일 존재,
760,642 bytes, SHA256
`0a961fab64fbe55ee7a6e8631ee10ecec280ac3381239fd465a8acbfa585e4a9`와
Library 식별 메타데이터를 확인하고 실제 픽셀을 열었다. 사진은 수정하거나 커밋하지 않았다.

중앙의 황백색 광채와 검은 실루엣을 확인했다. HUD의 ‘황혼의 사신’은
`hud_v20.gd`의 `황혼의 %s` + `job_class` 표시다. 원본 Class94 사신의 기본
남성 sprite21951 / 여성26213은 확인되지만, 이 문구는 활성 변신 카드·성별의
증거가 아니다. 확보한 기본 사신 프레임은 어두운 복장이므로 사진의 금백색 본체와
동일한 선택이라고 단정하지 않는다.

## 원본과 현재 경로

현재 월드 원본 경로는 `player.gd` → `original_source_preview.gd` →
`current523_source_bank.gd` → `reference_sp2_bank.gd` →
`current523_sp2_decoder.gd` → 무압축 straight RGBA8 ImageTexture다.
원본 SP2 저장 샘플은 alpha255, 빈 coverage는 alpha0으로 해독한다.
이번 수정은 팔레트·coverage·프레임·오프셋·축척·텍스처 바이트를 변경하지 않는다.
카드 UI의 PMA 텍스처 재변환 캐시는 별도 성능 작업 범위이며 수정하지 않았다.

현행523 원문 SPR에는 다음 관계가 있다.

| 본체 | 원문 레이어 |
| --- | --- |
| 남성21951 | shadow21952 |
| 여성26213 | shadow26214, clothes26215_sc(attr8), clothes26216_mu(attr128) |

이 관계는 레이어 존재 선언이다. 실제 파일 가용성 및 사진의 활성 카드와 구분한다.
여성 clothes26215/26216은 선택된523 원본에서 물리 SP2를 찾지 못했다.
508 전체625개 DAT 중523과 동일한622개를 manifest로 대조하고, 변경·추가8개는
현행 SHA1/크기를 검증해 전수 검색했다. 이 사신 clothes를 새로 만들거나 채우지 않는다.
검은 실루엣은 확보한 원본 shadow 픽셀에서도 관찰된다. 이를 삭제하지 않았다.

기존 호환 경로는 attr8에 Godot ADD, attr128에 MIX/alpha0.5,
attr 없는 shadow에 opaque MIX를 적용했다. 보존된 복원 M 클라이언트
1.10.22.0(525)의 P02/P13 정적 자료는 좁은 일반 경로에서 다음을 확인한다.

| 정확한 flags | 복원된 RGB565 수식 | 기존 처리와 차이 |
| --- | --- | --- |
| 1 | 채널별 floor((D+S)/2), G6 보존 | 불투명 검은 덮어쓰기 방지 |
| 8 | D+S-floor(D*S/31), R5/G5/B5 | ADD의 과도한 밝기와 다름 |
| 128 | floor(D*S/31), R5/G5/B5 | half-MIX의 흰 막과 다름 |

screen/multiply는 원시 green bit5를 버린다. 저장 샘플 S=0도 처리하며,
coverage가 없는 픽셀만 건너뛴다. P13 shadow flags는
`(actor.flags & ~0x8000) | 1`이며 shadow 자체 SPR attr를 대신 쓰지 않는다.

## 수정 범위

`source_sp2_compositor.gd`와 `source_sp2_rgb565.gdshader`가 **compatible 모드의
정확한 flags1/8/128**에만 위 수식을 적용한다. strict와 미해석·복합 flags는
기존 정책을 유지한다. shadow는 선택된 실제 body의 flags로 계산한다.
원본 레이어·선택 identity·프레임 clock·저장·전투는 유지한다.

각 Sprite2D의 기존 그리기 위치 바로 앞에서 해당 sprite 사각형만 BackBufferCopy한다.
후속 레이어는 직전 레이어의 결과를 읽으며 copy/material은 재사용한다.
Godot 4.7.2 GLES3/RD가 raw copy.rect를 사용하므로 복사 영역은 화면 좌표로 계산하고
자식 copy의 변환을 상쇄한다. frame_pre_draw에서 카메라 이동·viewport 크기까지
반영하고 빈/화면 밖 영역은 비활성화한다(빈 Rect는 전체 화면 복사 의미라 전달하지 않는다).
pre_draw 연결은 첫 ready가 아닌 매 tree 진입에서 복구해 reparent도 따른다.
스타일이 바뀌면 이전 shader와 copy를 비활성화한다. 기존 attachment 진단에
`recovered_source_compositors`를 추가해 적용 flags·수식 출처를 확인할 수 있다.

이는 **525 복원 정적 수식의 523 호환 적용**이다. 보호된 현행523 EXE에서 같은
SP2 호출 사슬을 직접 복구한 것 또는 Android 원본 렌더 식을 관측한 것이 아니다.
원본 cell depth, effect map, coefficient·복합 flags 및 모든 native 합성 순서는
이번 수정 범위 밖이다. 자체 action으로 독립 재생되는 shadow 자식은 내부 kind가 body라
부모 shadow flags가 이 adapter로 전달되지 않으며 기존 합성이 남는다. 확인한 사신
21952/26214는 자체 action이 없는 inline shadow다. 기존 평탄화된 레이어 순서의
원작 동등성을 주장하지 않는다.

## 원본 근거와 바이트 검증

분석 입력과 원본·진단 PNG는 저장소 밖 개인 작업 폴더에 보존했다.
제3자 이미지나 실행파일을 공개 Git에 추가하지 않았다.

- Library `libfile_31d517205c8c8191b83f35b82fda9676`:
  `LineageM_클라이언트_통합분석_01-30_20261108.zip`, 24,341,756 B,
  SHA256 `c281d4042253f94799ee416f1d56add2b8aceb9343ade93c13e709021f04cc87`.
  P02 `PIXEL_BLEND_FINDINGS_KO.txt` SHA256
  `ca900f3cc1deb6b26ab9aa19cb578bb510876a07a4b589da947e8691b601fe3d`;
  독립 산술 QA `8485babce373ffb1147b4b3450ee862c0eb1eeaab019d9fd3a2b5c51c319b2ad`;
  P13 `REPORT_KO.md` `b6b0dbb66413966c8b2fab1c59a1a61595ef4bffe36167d0673dc776a603332e`.
- 위 수식의 분석 대상 복원 EXE SHA256:
  `9f9c3b9c9a49fb598899b3da308b4776cbbc47cbb98dbe4b4aa368cce519019d`.
- 별도로 실제 현행523 EXE/DLL의 원본 바이트·동봉 provenance를 대조했다.
  EXE `5148b1092c4795e402536896819e8672e5749e41463d8d6a2a8be5c4464a7521`,
  DLL `306798705bb101f46fd8eaafee5e84b291d8b4aca0a6ccf99e9a91dab83fc2c2`.
  EXE는 보호된 .ncg 표면으로 직접 SP2 수식 연결을 얻지 못했다.
  Cocos UI split-alpha shader를 SP2 규칙으로 일반화하지 않았다.
- 원본 선택 SP2 121개: 각각 raw SHA/크기, 표준 Brotli 전체 입력/EOF,
  해독 스트림 SHA와 동봉 스트림의 일치 확인.
- 사신 body/shadow SP2 76개: 개별 원본 SHA/CRC 및 현행523
  `files_info.json.523`의 외부 DAT·SPR SHA1/크기와 대조했다.
  현재 manifest SHA256:
  `fefb29fb8126f106e4d127b59a81459efc576d5a6eab8456b4c4988ae390f4dc`.

## 검증과 한계

- Godot 4.7.2: 정수·정책·coverage·copy 초기화 회귀 22,601 checks, 오류0.
- 동일 shader를 Godot 4.7.2 언어 파서로 검사해 operation int uniform을 확인했다.
  이는 GPU 컴파일·출력 검증과 구분한다.
- 기존 reference SP2 load memo 회귀의 시간 대기를 실제 monotonic/mtime 기준으로
  보강했다. CI에서 SceneTreeTimer 1.1초가 실제834ms만 기다리는 경우를 재현했다.
  관측된 mtime 변경·동일 크기를 확인한 뒤 원래 SHA 거부 검사를 그대로 수행한다.
  보강된 회귀33 checks, 오류0. production 캐시 정책은 변경하지 않았다.
- 기존 reference SP2 공유 회귀 62 checks, 오류0. 원본 texture 공유 key/bytes 유지.
- 실제 선택 SP2 121개: 1,463프레임 / 1,706 checks, 오류0.
- 실제 사신 body/shadow76개: 5,472프레임 / 5,612 checks, 오류0.
- 원본 사신 남녀8방향 shadow CPU 비교: 원래 픽셀·오프셋과 사진의 바닥 crop을
  유지한 계산 결과에서 3,959픽셀 차이. 바닥이 보이는 평균 합성을 확인했다.
- 실제 원본 attr8/128 효과의 ADD/half-MIX 대 screen/multiply CPU 비교도 확인했다.
  이 별도 효과를 사진의 활성 캐릭터라고 주장하지 않는다.
- CPU PNG는 GPU 캡처가 아니다. 로컬 Xorg는 허용된 환경에서 Unix socket을
  만들 수 없어 시작하지 못했다. OpenGL 픽셀·연쇄 레이어·투명 coverage·reset
  검증은 `Source SP2 RGB565 OpenGL pixels` CI에 연결했다. 실제 CI의 초기 실패가
  복사 좌표와 reparent 연결 문제를 잡았으며 수정 후 같은 검사를 재실행한다.
  최종 SHA의 실행·성공 여부는 PR 체크와 실행 로그를 기준으로 확인한다.
- Android 실기기, 사진과 동일한 활성 변신의 재현 및 원작 M 시각 동등성은 미검증이다.
  Android에서 배경 copy 비용과 최종 시각을 추가 확인해야 한다.

저장소 `AGENTS.md`·프로젝트 규칙·리소스 정책을 읽었다. 관련 `.agents/skills`는
이 checkout 및 상위 `.agents`에 없었다. 지침의 옛 `check_resource_integrity.py`는
최신 main에서 제거되어 실행할 수 없었으며, 현재 필수 workflow의
`check_no_legacy_resources.py`와 회귀2건은 통과했다. 옛 자산 또는 외부 원본의
전체 통합·배포 완료를 주장하지 않는다. 일반 세이브와 다른 작업 checkout은 보존했다.
