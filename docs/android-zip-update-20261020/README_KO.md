# TWILIGHT 휴대폰 ZIP 설치본 안전 업데이트

이 문서는 Termux에서 `Download/TWILIGHT_Play/project.godot`을 Godot Android Editor로 실행하는 사용자를 위한 절차입니다.

GitHub의 Download ZIP에는 `.git`이 없으므로 `git pull`, `git reset`, `git clean`으로 업데이트하지 않습니다.

## 업데이트 (한 번에 복사해서 실행)

먼저 Godot 편집기에서 프로젝트 실행을 종료하세요. Termux에서 아래 명령어를 실행합니다.

```bash
pkg install -y python curl
curl -fL --retry 3 -o "$HOME/twilight_update.py" \
  "https://raw.githubusercontent.com/zoog136-hash/-/main/tools/android/termux_update_zip.py" &&
python "$HOME/twilight_update.py" "$HOME/storage/downloads/TWILIGHT_Play"
```

화면에 **Type YES**가 나타나면 `YES`를 입력하세요. 최신 main의 Git 파일 목록과 로컬 내용을 비교하여 필요한 파일만 받습니다. 각 다운로드는 GitHub blob SHA-1으로 검증하며 다운로드 중 실패하면 기존 프로젝트 파일은 변경하지 않습니다.

완료 시 `UPDATE OK:` 메시지가 나옵니다. 이후 Godot Android Editor를 다시 열고 기존 `Download/TWILIGHT_Play/project.godot` 프로젝트를 가져오세요.

- 기존 사용자가 추가한 파일은 자동 삭제하지 않습니다.
- 업데이트로 바뀌는 기존 프로젝트 파일은 `.twilight_update_backup_날짜` 폴더에 보관합니다.
- `.git`, `.godot`, 개인 저장 데이터 `user://`는 변경하지 않습니다.
- 처음 업데이트한 ZIP에만 존재하던 오래된 비추적 파일은 삭제하지 않습니다. 이 때문에 구형 리소스 충돌 가능성은 별도 진단 대상입니다.
- GitHub API 접근/네트워크가 실패하거나 변경 파일의 해시가 다르면 업데이트를 중단합니다.
- **맵 리소스 최신화와 실제 PNG 모드 활성화는 별개입니다.** 알비노·에스카로스 실제 PNG 모드는 현재 명시 실행 옵션을 사용하며, 옛 몬스터 배치를 자동으로 새 이미지로 옮기지 않습니다.

## 실행 실패 시

`UPDATE STOPPED:` 내용을 캡처하세요. 중간에 `git reset --hard`나 `git clean -fd`를 실행하지 마세요. 기존 Godot 사용자 세이브는 게임의 `user://` 영역에 보관됩니다.

## 검증 범위

2026-10-20: 안전 경로 확인, 누락 파일 다운로드와 해시 비교, 백업 보존, 네트워크 오류에서 변경 0, 재실행 시 중복 다운로드 회피의 단위 테스트를 수행했습니다. Android 실제 기기에서 전체 프로젝트 업데이트는 아직 검증하지 않았습니다.
