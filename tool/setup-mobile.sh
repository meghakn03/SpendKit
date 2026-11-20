#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

if [[ ! -d android || ! -d ios ]]; then
  # Generate in isolation so Flutter cannot modify the application source.
  scaffold="$(mktemp -d)"
  trap 'rm -rf "$scaffold"' EXIT
  flutter create --no-pub --platforms=android,ios --org dev.spendkit \
    --project-name spendkit "$scaffold"
  for platform in android ios; do
    if [[ ! -d "$platform" ]]; then
      cp -R "$scaffold/$platform" "$platform"
    fi
  done
  if [[ ! -f .metadata ]]; then
    cp "$scaffold/.metadata" .metadata
  fi
fi
python3 tool/configure-mobile.py
