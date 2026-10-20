# TWILIGHT 지도 데이터 팩 — GitHub 업로드 완료

PR #133에서 사용자 요청으로 지도 팩의 실제 파일을 업로드했습니다. 대형 분할 ZIP을 커넥터에 통째로 전달하는 대신 파일 단위 Git 전송을 사용했습니다. **파일 업로드 완료와 게임 자동 적용 완료는 다릅니다.**

## 포함된 실제 파일

| 위치 | 포함 내용 | 파일 수 |
|---|---|---:|
| `native_png_v5/` | 알비노 1~3구역, 에스카로스 단일 필드, 야히의신전, 발록의 시전 | 210 |
| `oman_v2/` | 오만 1~10층 격자·배치 및 원래 팩의 검증 메타데이터 | 15 |

Native v5는 PNG 203개와 JSON 7개입니다. PNG에는 배경 청크 193개, 전경 1개, overview 6개, 알비노 분할 원본 3개가 포함됩니다. 원래 v5 팩의 210개 파일을 빠짐없이 동일 바이트로 보존했습니다. 거대한 원본 PNG 네 장 자체를 새로 제작하거나 포함한 것으로 주장하지 않습니다.

두 팩의 파일 225개 합계는 **285,296,128바이트**입니다. 기존 오만 ZIP `TWILIGHT-map-remake-private-20261015-v2.zip`도 보존합니다. v5 분할 ZIP 3개는 중복 저장하지 않았으며 그 안의 실제 파일 전체를 추적합니다. 파일별 길이·SHA-256은 `MAP_ASSET_DELIVERY.json`에 있습니다.

## 검증

- 실제 파일 업로드 커밋: `b2b9494cac0e67f4ce2eb2c219900fe2d77ec9d0`.
- 전송 작업: `39366937376`, 다운로드 검증·Git commit/push 성공.
- Native v5 합본 ZIP SHA-256: `2bc0a2463ef7448a8b16b890911175d3da03f2d992dcbcaa18cfd7563c310122`.
- Oman v2 ZIP SHA-256: `9123660429fc06a9e88a3f7719f2121401f53dc57d71e1da543b085caa399708`.
- 세 분할 SHA-256·ZIP CRC·팩 index·맵 manifest·배경/전경/분할 이미지 SHA-256을 대조했습니다.
- 별도 로컬 검증에서 PNG 203개 전부를 끝까지 디코딩했습니다. 실패 0.
- 업로드 후 GitHub에서 조회한 13개 최상위 tree/blob SHA를 로컬 원본으로 계산한 Git 객체 SHA와 비교했습니다. 225개 파일의 경로·내용 전체가 일치했습니다.
- Native 디렉터리 Git tree: `77206029971d154c24d0c946804f803346350ad9`.
- Oman 디렉터리 Git tree: `288ef0fe1c47b53760710d4104e78141f506fb39`.

## 아직 하지 않은 작업

이 PR은 **자료 업로드 단계**입니다. 현재 `native_png_registry.gd`는 환경변수 `TWILIGHT_NATIVE_PNG_PACK` 또는 `user://native_png_maps`를 사용합니다. `external_map_packs/native_png_v5`를 자동 탐색하도록 게임 코드를 변경하지 않았습니다. 기존 알비노·에스카로스 교체는 계속 `--native-png-maps` 명시 모드이며, 기존 몬스터 좌표 이전과 Android 실기 검증은 별도입니다.

오만 자료도 `oman_v2/data/map_remake/private/`에 보관한 상태입니다. 실제 게임의 `data/map_remake/private/` 연결은 별도 설치/통합 단계에서 기존 파일과 해시를 비교하고 처리해야 합니다. 세이브나 기존 팩을 무조건 덮어쓰지 않습니다.

`.gdignore`는 보관용 대형 PNG를 Android 편집기가 불필요하게 자동 임포트하는 것을 막습니다. `.gitattributes`는 해시 검증 대상 JSON의 줄바꿈을 보존합니다. 이 폴더를 APK에 넣었다거나 게임 자동 활성화를 검증한 것으로 해석하지 않습니다.

main과 다른 작업 브랜치는 변경하지 않았습니다. 일회성 전송 workflow와 댓글의 임시 다운로드 경로는 전송 후 제거했습니다. Drive 원본 공유 설정은 바꾸지 않았습니다.
