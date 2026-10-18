#!/usr/bin/env bash
# Run the EXISTING TWILIGHT Main scene with a locally supplied source PNG pack.
set -eu
if [ "$#" -lt 2 ]; then
    echo "Usage: bash tools/run_png_review.sh PRIVATE_PACK_ROOT OFFICIAL_GODOT_4.7.2 [--png-collision-overlay]" >&2
    exit 2
fi
png_review_root=$(cd "$1" && pwd)
png_review_godot=$2
shift 2
png_review_project=$(cd "$(dirname "$0")/.." && pwd)
png_review_version=$("$png_review_godot" --version)
case "$png_review_version" in
    4.7.2.stable.official.*) ;;
    *) echo "Official Godot 4.7.2 required; found: $png_review_version" >&2; exit 2 ;;
esac
test -f "$png_review_root/map_png/aden_world/manifest.json"
test -f "$png_review_root/topology/index.json"
mkdir -p "$png_review_root/session-data" "$png_review_root/session-config" "$png_review_root/session-cache"
export XDG_DATA_HOME="$png_review_root/session-data"
export XDG_CONFIG_HOME="$png_review_root/session-config"
export XDG_CACHE_HOME="$png_review_root/session-cache"
export TWILIGHT_MAP_PNG_PACK="$png_review_root/map_png"
export TWILIGHT_REMAKE_PACK="$png_review_root/topology"
exec "$png_review_godot" --path "$png_review_project" -- --png-review "$@"
