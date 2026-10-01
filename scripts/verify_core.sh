#!/bin/zsh
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
WORK_DIR="$PROJECT_ROOT/.build/core-verification"
mkdir -p "$WORK_DIR/module-cache"

swiftc \
  -module-cache-path "$WORK_DIR/module-cache" \
  "$PROJECT_ROOT/Sources/CoverLetterFiller/Models.swift" \
  "$PROJECT_ROOT/Sources/CoverLetterFiller/DocxTemplateService.swift" \
  "$PROJECT_ROOT/scripts/verify_core.swift" \
  -o "$WORK_DIR/verify-core"

if [[ $# -eq 1 ]]; then
  "$WORK_DIR/verify-core" "$1"
else
  "$WORK_DIR/verify-core"
fi
