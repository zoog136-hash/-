#!/usr/bin/env bash
# Emit one GitHub ::error:: annotation per log file with its first failure
# lines. Job logs and artifacts can be unreachable from review tooling, while
# check-run annotations stay readable. Usage: ci_failure_annotation.sh TITLE FILE...
title="$1"; shift
for file in "$@"; do
  [ -f "$file" ] || continue
  lines=$(grep -E 'SCRIPT ERROR|ERROR:|_FAIL|FAIL:|FAILED|TIMEOUT|Traceback|AssertionError|Error\b|at: .*res://' "$file" \
    | grep -vE '\| reimport \||ADDING:' | awk '!seen[$0]++' | head -n 14)
  [ -n "$lines" ] || lines=$(tail -n 6 "$file")
  detail=$(printf '%s' "$lines" | tr -d '\r' | sed 's/\x1b\[[0-9;]*m//g' | paste -sd'|' - | sed 's/|/ | /g' | cut -c1-1800)
  detail=${detail//%/%25}
  echo "::error title=${title} $(basename "$file")::${detail:-no output}"
done
exit 0
