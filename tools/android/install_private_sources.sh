#!/usr/bin/env bash
# One entry point for first installation and later updates. No game/tests/CI.
set -euo pipefail

diagnostic_only=false
manual_resources=false
for argument in "$@"; do
  case "$argument" in --diagnose-bundle|--diagnose-bundle=*) diagnostic_only=true ;; esac
  case "$argument" in --manual-*) manual_resources=true ;; esac
done

bootstrap_stage='prerequisites'
# Report only a fixed stage and exit code: tracing commands/arguments can
# expose private paths or authentication input and is deliberately avoided.
trap 'bootstrap_code=$?; if [ "$bootstrap_stage" = complete ] && [ "$bootstrap_code" -eq 0 ]; then printf "BOOTSTRAP FINISHED: Python exit=0. See installer result above.\n" >&2; else printf "BOOTSTRAP STOPPED: stage=%s exit=%s.\n" "$bootstrap_stage" "$bootstrap_code" >&2; fi' EXIT

if ! "$diagnostic_only" && ! "$manual_resources" && command -v pkg >/dev/null 2>&1; then
  pkg install -y python git curl rclone
fi
required_executables=(python3 git curl)
if ! "$manual_resources"; then required_executables+=(rclone); fi
for executable in "${required_executables[@]}"; do
  command -v "$executable" >/dev/null || { echo "Missing prerequisite: $executable" >&2; exit 1; }
done

if ! "$diagnostic_only" && ! "$manual_resources" && [ ! -d "$HOME/storage/downloads" ] && command -v termux-setup-storage >/dev/null 2>&1; then
  echo 'Allow Termux shared-storage access in Android, then return here.' >&2
  termux-setup-storage
fi
if ! "$manual_resources" && [ ! -d "$HOME/storage/downloads" ]; then
  echo 'Android Download is unavailable. Allow storage access and rerun the same command.' >&2
  exit 1
fi

bootstrap_stage='resolve-installer'
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
bootstrap_stage='download-helpers'
source_files=(install_private_sources.py private_drive_transport.py private_source_bootstrap.gd)
if "$manual_resources"; then source_files+=(manual_resource_install.py); fi
for source_file in "${source_files[@]}"; do
  curl --proto '=https' --proto-redir '=https' -fL --retry 2 \
    -o "$install_source/$source_file" \
    "https://raw.githubusercontent.com/zoog136-hash/-/$install_sha/tools/android/$source_file"
done

if "$manual_resources"; then
  bootstrap_stage='manual-resource-inputs'
  echo 'Manual helpers downloaded. The existing local resource receipt will be verified without Drive access.' >&2
else
  bootstrap_stage='drive-configuration'
  echo 'Installer helpers downloaded. Checking selected Drive remote.' >&2
fi
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
if ! "$manual_resources" && ! "$use_token"; then
  found_remote=false
  # A process substitution hides the producer's failure status. Check the
  # command itself, while keeping unrelated remote names out of the output.
  if ! configured_remotes="$(rclone listremotes 2>/dev/null)"; then
    echo 'Could not read the local rclone remote list. No credentials were printed; complete the existing local rclone setup before retrying.' >&2
    exit 1
  fi
  while IFS= read -r configured_remote; do
    if [ "$configured_remote" = "$drive_remote:" ]; then found_remote=true; fi
  done <<< "$configured_remotes"
  if ! "$found_remote"; then
    if "$diagnostic_only"; then
      echo 'Diagnostic stopped: the existing selected remote is unavailable. No authorization or configuration flow was started.' >&2
      exit 1
    fi
    echo "Private Drive authorization is required once. In rclone config, create '$drive_remote' as Google Drive with read-only access." >&2
    echo 'Use the normal setup (advanced config: no), complete your browser authorization, save the remote, then quit config. Do not paste tokens or auth URLs into chat.' >&2
    rclone config
  fi
  echo 'A saved remote name is not proof of authentication. The installer first checks access by reading the selected private plan.' >&2
fi

if "$manual_resources"; then
  echo 'Manual resource mode: verify the selected existing folder and retained ZIPs, then add minimal GitHub code. No rclone, Drive plan, source download, extraction or resource copy.' >&2
elif "$diagnostic_only"; then
  echo 'Read-only diagnostic: one pinned bundle metadata/path dry-run. No game-code checkout, source-media download or installation will start.' >&2
else
  echo 'Close Godot before continuing. Code uses packed Git transfer; Drive uses verified ZIP bundles (default two at once).' >&2
fi
bootstrap_stage='python-handoff'
# Keep this supervising shell alive so even a silent Python exit has a
# visible final status. Preserve the Python exit code; do not retry or turn
# failure into success. This launches no additional installation process.
if python3 "$install_source/install_private_sources.py" --remote "$drive_remote" "$@"; then
  bootstrap_stage='complete'
else
  bootstrap_code=$?
  exit "$bootstrap_code"
fi
