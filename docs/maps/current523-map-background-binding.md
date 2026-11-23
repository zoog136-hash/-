# 523 원본 맵 배경 연결 기준

현재 523 정의 아카이브(SHA-256 `d5192c3c735ff95c6b181bf2d4d77448d8b562fdb28dbd43f897fa4eae1f4832`)의 `MapBackgroundView.ID`는 논리 `Land.ID`다. `Land.AssetPath` 숫자나 `Land.BackgroundTypeId`가 아니다. 예를 들어 몽환의 섬은 **Land 22801 → 지형 폴더 303/**이며, 배경 Sky 691 / Cloud 690에 대응한다. 303으로 조회하거나 아덴 Land 4로 조회하면 선언이 없다. 이 아카이브 53개 행은 모두 RenderType 11이며 하늘·구름 역할에 걸쳐 서로 다른 AssetID가 11개다.

`Current523SourceField.source_background_binding()`은 현재 확인된 필드에서 요청 시에만 이 관계를 읽는다. 실제 이미지 경로는 같은 정의의 `AssetType/AssetView`와 설치된 523 이미지 팩 검증을 거친다. 선언이 없거나 올바른 이미지가 없는 경우 다른 자산을 찾거나 픽셀을 만들지 않는다. 맵 진입, 충돌, 카메라와 게임 루프는 바꾸지 않는다.

실제 배경 그리기는 아직 연결하지 않는다. Windows EXE 1.10.22.0의 Land 키 선택과 RenderType 11 분기는 확인했지만, Android/523의 floor-derived need rectangle, 원본 crop 좌표와 구름 타일 합성 및 알파의 동치가 검증되지 않았다. 앞에 아무 하늘이나 붙이거나 모든 화면 뒤를 채우면 이 경계를 무시하게 된다. `draw_ready=false`는 이 보류를 명시하는 값이다.

검사: Godot 4.7.2에서 `TWILIGHT_PATCH523_CONTENT`에 위 원본 ZIP을 지정하고 `--script res://tests/current523_map_background_test.gd`를 실행한다. 로컬 추가 검사는 실제 몽환의 섬 지형 카탈로그와 해시 정합을 확인한 구름 PNG를 사용하되, 하늘 PNG가 없는 불완전한 이미지 쌍은 그리기에 진입할 수 없음을 검사한다. Android 실기기 및 시각 동치 검사는 하지 않았다.
