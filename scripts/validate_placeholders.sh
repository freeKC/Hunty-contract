#!/usr/bin/env bash
# validate_placeholders.sh — Check config/contracts.*.json for placeholder values
#
# Exits with status 1 if any JSON config contains a placeholder value
# (a string starting with "replace-with-"), preventing accidental deployment
# of unconfigured contract configs.
#
# Usage: scripts/validate_placeholders.sh [config-file ...]
#
# With no arguments, every config/contracts.*.json file is checked. With
# file arguments, only those files are checked. deploy_contracts.sh passes
# the config it has just written, because the committed configs of the
# environments that were not deployed still hold placeholders.

set -euo pipefail

CONFIG_DIR="config"
HAS_ERROR=0

if [ "$#" -gt 0 ]; then
  FILES=("$@")
  for file in "${FILES[@]}"; do
    if [ ! -f "$file" ]; then
      echo "ERROR: $file does not exist" >&2
      HAS_ERROR=1
    fi
  done
else
  FILES=("$CONFIG_DIR"/contracts.*.json)
fi

if command -v jq &>/dev/null; then
  # Use jq for thorough recursive check
  for file in "${FILES[@]}"; do
    [ -f "$file" ] || continue
    placeholders=$(jq '[paths(scalars) as $p | getpath($p) | select(type == "string" and startswith("replace-with-"))] | length' "$file")
    if [ "$placeholders" -gt 0 ]; then
      echo "ERROR: $file contains placeholder values:" >&2
      jq '[paths(scalars) as $p | {path: ($p | join(".")), value: getpath($p)} | select(.value | type == "string" and startswith("replace-with-"))]' "$file" >&2
      HAS_ERROR=1
    else
      echo "OK: $file — no placeholders found"
    fi
  done
else
  # Fallback: grep-based check
  for file in "${FILES[@]}"; do
    [ -f "$file" ] || continue
    if grep -q '"replace-with-' "$file"; then
      echo "ERROR: $file contains placeholder values (replace-with-...)" >&2
      grep -n '"replace-with-' "$file" >&2
      HAS_ERROR=1
    else
      echo "OK: $file — no placeholders found"
    fi
  done
fi

exit "$HAS_ERROR"
