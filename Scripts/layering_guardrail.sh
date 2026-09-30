#!/usr/bin/env bash
set -euo pipefail

ROOT="${SRCROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
FAIL=0

echo "==> Layering guardrail (ARCH-9)"

while IFS= read -r -d '' file; do
  if grep -qE '^\s*import (SwiftUI|GRDB|Supabase)' "$file"; then
    echo "FAIL: Core must not import SwiftUI/GRDB/Supabase: $file"
    FAIL=1
  fi
done < <(find "$ROOT/Packages/TagReportingCore/Sources" -name '*.swift' -print0)

while IFS= read -r -d '' file; do
  if grep -qE '^\s*import Supabase' "$file"; then
    echo "FAIL: Features must not import Supabase directly: $file"
    FAIL=1
  fi
done < <(find "$ROOT/LooseTagReporter/Features" -name '*.swift' -print0 2>/dev/null)

echo "==> Silent-app audio lint"

while IFS= read -r -d '' file; do
  # Ban audio playback APIs only — AVFoundation/VisionKit are required for the tag scanner.
  if grep -qE 'import AudioToolbox|AudioServicesPlaySystemSound|AVAudioPlayer|AVAudioSession' "$file"; then
    echo "FAIL: Audio API forbidden (silent app constraint): $file"
    FAIL=1
  fi
done < <(find "$ROOT/LooseTagReporter" "$ROOT/Packages/TagReportingCore/Sources" -name '*.swift' -print0)

if [[ "$FAIL" -ne 0 ]]; then
  exit 1
fi

echo "Guardrails passed."
