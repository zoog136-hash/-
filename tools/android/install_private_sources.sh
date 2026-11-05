#!/usr/bin/env bash
# One entry point for first installation and later updates. No game/tests/CI.
set -euo pipefail

if command -v pkg >/dev/null 2>&1; then
  pkg install -y python git curl rclone
fi
for executable in python3 git curl rclone; do
  command -v "$executable" >/dev/null || { echo "Missing prerequisite: $executable" >&2; exit 1; }
done

if [ ! -d "$HOME/storage/downloads" ] && command -v termux-setup-storage >/dev/null 2>&1; then
  echo 'Allow Termux shared-storage access in Android, then return here.'
  termux-setup-storage
fi
if [ ! -d "$HOME/storage/downloads" ]; then
  echo 'Android Download is unavailable. Allow storage access and rerun the same command.' >&2
  exit 1
fi

install_ref="${TWILIGHT_INSTALLER_REF:-feature/android-private-source-bootstrap-20261105}"
if [[ "$install_ref" =~ ^[0-9a-f]{40}$ ]]; then
  install_sha="$install_ref"
else
  install_sha="$(git ls-remote --exit-code https://github.com/zoog136-hash/-.git "refs/heads/$install_ref" | cut -f1)"
fi
if [[ ! "$install_sha" =~ ^[0-9a-f]{40}$ ]]; then
  echo 'Could not pin the installer revision; no installation started.' >&2
  exit 1
fi

install_base="$HOME/.cache/twilight-installer-source"
mkdir -p "$install_base"
install_source="$(mktemp -d "$install_base/source-$install_sha-XXXXXX")"
for source_file in install_private_sources.py private_drive_transport.py private_source_bootstrap.gd; do
  curl --proto '=https' --proto-redir '=https' -fL --retry 2 \
    -o "$install_source/$source_file" \
    "https://raw.githubusercontent.com/zoog136-hash/-/$install_sha/tools/android/$source_file"
done

drive_remote="${TWILIGHT_DRIVE_REMOTE:-twilight-drive}"
use_token=false
remaining=("$@")
for ((i=0; i<${#remaining[@]}; i++)); do
  case "${remaining[$i]}" in
    --token-file|--token-file=*) use_token=true ;;
    --remote) drive_remote="${remaining[$((i+1))]:-}" ;;
    --remote=*) drive_remote="${remaining[$i]#--remote=}" ;;
  esac
done
if ! "$use_token"; then
  found_remote=false
  while IFS= read -r configured_remote; do
    if [ "$configured_remote" = "$drive_remote:" ]; then found_remote=true; fi
  done < <(rclone listremotes)
  if ! "$found_remote"; then
    echo "Private Drive authorization is required once. In rclone config, create '$drive_remote' as Google Drive with read-only access."
    rclone config
  fi
fi

echo 'Close Godot before continuing. Code uses packed Git transfer; Drive uses verified ZIP bundles (default two at once).'
exec python3 "$install_source/install_private_sources.py" --remote "$drive_remote" "$@"
