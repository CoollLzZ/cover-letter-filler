#!/bin/zsh
set -euo pipefail

if [[ $# -ne 2 ]]; then
  echo "Usage: scripts/verify_end_to_end.sh <cover-letter.docx> <soffice-path>" >&2
  exit 64
fi

PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
WORK_DIR="$PROJECT_ROOT/.build/end-to-end-verification"
mkdir -p "$WORK_DIR/module-cache"

swiftc \
  -D DEBUG \
  -module-cache-path "$WORK_DIR/module-cache" \
  "$PROJECT_ROOT/Sources/CoverLetterFiller/Models.swift" \
  "$PROJECT_ROOT/Sources/CoverLetterFiller/DocxTemplateService.swift" \
  "$PROJECT_ROOT/Sources/CoverLetterFiller/PDFConverter.swift" \
  "$PROJECT_ROOT/scripts/verify_end_to_end.swift" \
  -o "$WORK_DIR/verify-end-to-end"

SOFFICE_PATH="$2" "$WORK_DIR/verify-end-to-end" "$1" "$2"
