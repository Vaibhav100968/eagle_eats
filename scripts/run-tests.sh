#!/usr/bin/env bash
# Mean Eats — local quality checks
# Usage: ./scripts/run-tests.sh

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

echo "==> Mean Eats QA"
echo ""

# ---------------------------------------------------------------------------
# 1. Python scraper unit tests (no network)
# ---------------------------------------------------------------------------
echo "→ Python scraper tests"
python3 -m unittest discover -s backend/lambda_scraper -p 'test_*.py' -v
echo ""

# ---------------------------------------------------------------------------
# 2. Swift XCTest (optional if Xcode / simulator available)
# ---------------------------------------------------------------------------
if ! command -v xcodegen >/dev/null 2>&1; then
  echo "⚠ xcodegen not found — skipping Swift tests (install: brew install xcodegen)"
  echo ""
  echo "✅ Python suite passed"
  exit 0
fi

if ! command -v xcodebuild >/dev/null 2>&1; then
  echo "⚠ xcodebuild not found — skipping Swift tests"
  echo ""
  echo "✅ Python suite passed"
  exit 0
fi

echo "→ Generating Xcode project"
xcodegen generate

DESTINATION="${MEAN_EATS_TEST_DESTINATION:-platform=iOS Simulator,name=iPhone 16}"

echo "→ Swift unit tests ($DESTINATION)"
set +e
xcodebuild test \
  -project eaglesEats2.xcodeproj \
  -scheme eaglesEats2 \
  -destination "$DESTINATION" \
  -only-testing:MeanEatsTests \
  -quiet
SWIFT_STATUS=$?
set -e

if [[ $SWIFT_STATUS -ne 0 ]]; then
  echo ""
  echo "⚠ Swift tests failed or simulator unavailable (exit $SWIFT_STATUS)."
  echo "  Tip: set MEAN_EATS_TEST_DESTINATION to a simulator you have installed."
  echo "  Python suite still passed."
  exit "$SWIFT_STATUS"
fi

echo ""
echo "✅ All local QA checks passed"
