#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

if ! command -v flutter >/dev/null 2>&1; then
  printf '%s\n' 'Install Flutter 3.50.1 and add flutter to your PATH before starting SpendKit.' >&2
  exit 127
fi

exec flutter run -d chrome
