#!/usr/bin/env bash
set -euo pipefail

# Local release script: builds with local Xcode, uploads to GitHub Release, updates Homebrew cask.
# Usage: ./release.sh v0.2.0

ROOT_DIR="$(cd "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/.." && pwd)"
cd "$ROOT_DIR"

if [[ $# -lt 1 ]]; then
  echo "Usage: $0 <tag>  (e.g. $0 v0.2.0)"
  exit 1
fi

TAG="$1"
VERSION="${TAG#v}"
APP_NAME="AgentBar"

echo "==> Building ${APP_NAME} ${TAG}..."
"$ROOT_DIR/Scripts/build_app.sh"

echo "==> Packaging zip..."
ditto -c -k --keepParent .build/AgentBar.app AgentBar-macos.zip

echo "==> Packaging dmg..."
hdiutil create \
  -volname "$APP_NAME" \
  -srcfolder .build/AgentBar.app \
  -ov \
  -format UDZO \
  AgentBar-macos.dmg

echo "==> Uploading to GitHub Release ${TAG}..."
gh release upload "$TAG" \
  AgentBar-macos.zip \
  AgentBar-macos.dmg \
  --clobber

echo "==> Updating Homebrew cask..."
ZIP_URL="https://github.com/varenyzc1/agentbar/releases/download/${TAG}/AgentBar-macos.zip"
SHA256="$(curl -fL "$ZIP_URL" | shasum -a 256 | awk '{print $1}')"

git clone "https://github.com/varenyzc1/homebrew-agentbar.git" /tmp/agentbar-tap 2>/dev/null || true
cd /tmp/agentbar-tap && git pull
perl -0pi -e "s/version \"[^\"]+\"/version \"${VERSION}\"/" Casks/agentbar.rb
perl -0pi -e "s/sha256 \"[0-9a-f]+\"/sha256 \"${SHA256}\"/" Casks/agentbar.rb
git config user.name "varenyzc"
git config user.email "varenyzc@users.noreply.github.com"
git add Casks/agentbar.rb
git diff --cached --quiet || git commit -m "brew: update agentbar to ${VERSION}"
git push origin main
rm -rf /tmp/agentbar-tap

echo ""
echo "==> Done!"
echo "    Release: https://github.com/varenyzc1/agentbar/releases/tag/${TAG}"
echo "    Users can now run: brew update && brew upgrade --cask agentbar"
