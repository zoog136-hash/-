#!/usr/bin/env bash
# Local authenticated extraction, then the base-768 manual compatibility reader.
set -euo pipefail
stage='prerequisites'
trap 'code=$?; printf "LOCAL BOOTSTRAP: stage=%s exit=%s.\n" "$stage" "$code" >&2' EXIT
for executable in python3 git curl; do
  command -v "$executable" >/dev/null || { printf 'Missing prerequisite: %s\n' "$executable" >&2; exit 1; }
done
# No pkg/rclone, Drive configuration, storage authorization or original download.
extractor_ref="${TWILIGHT_EXTRACTOR_REF:-}"
if [[ ! "$extractor_ref" =~ ^[0-9a-f]{40}$ ]]; then
  printf 'An explicit published TWILIGHT_EXTRACTOR_REF commit is required.\n' >&2
  exit 1
fi
installer_ref='768dd49388c99b8c9e87df9a07d1adbffd6f6fa6'
source_base="$HOME/.cache/twilight-manual-extractor-source"
mkdir -p "$source_base"
source_dir="$(mktemp -d "$source_base/source-$extractor_ref-XXXXXX")"
stage='download-public-helpers'
curl --proto '=https' --proto-redir '=https' -fL --retry 2 \
  -o "$source_dir/manual_resource_extract.py" \
  "https://raw.githubusercontent.com/zoog136-hash/-/$extractor_ref/tools/android/manual_resource_extract.py"
for source_file in install_private_sources.py manual_resource_install.py private_drive_transport.py private_source_bootstrap.gd; do
  source_ref="$installer_ref"
  # The original private index keeps its base-768 contract. Only the two
  # explicit manual-verification compatibility modules come from this helper
  # revision; source pins, resources and the original runtime guards stay intact.
  case "$source_file" in install_private_sources.py|manual_resource_install.py) source_ref="$extractor_ref" ;; esac
  curl --proto '=https' --proto-redir '=https' -fL --retry 2 \
    -o "$source_dir/$source_file" \
    "https://raw.githubusercontent.com/zoog136-hash/-/$source_ref/tools/android/$source_file"
done
stage='verify-local-zip-set-and-extract'
printf 'Verify all exact local ZIP names and hashes before extraction; then add minimal GitHub code using the pinned original manual installer. No Drive or original downloads.\n' >&2
python3 "$source_dir/manual_resource_extract.py" "$@"
stage='finished'
