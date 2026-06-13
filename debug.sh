#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_NAME="AgentBar"
APP_DIR="$ROOT_DIR/.build/${APP_NAME}.app"

echo "Building ${APP_NAME}..."
"$ROOT_DIR/build.sh" >/tmp/agentbar-build.log
cat /tmp/agentbar-build.log

if pgrep -x "$APP_NAME" >/dev/null; then
  echo "Stopping existing ${APP_NAME}..."
  osascript -e 'tell application "AgentBar" to quit' >/dev/null 2>&1 || true
  sleep 0.8
fi

echo "Opening ${APP_DIR}..."
open "$APP_DIR"

echo "Done. Check the macOS menu bar for ${APP_NAME}."
