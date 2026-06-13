#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_NAME="AgentBar"
APP_DIR="$ROOT_DIR/.build/${APP_NAME}.app"
DMG_NAME="${1:-AgentBar-macos.dmg}"
DMG_PATH="$ROOT_DIR/$DMG_NAME"
STAGING_DIR="$ROOT_DIR/.build/dmg-staging"
BACKGROUND_PATH="$ROOT_DIR/.build/dmg-background.png"
RW_DMG="$ROOT_DIR/.build/${APP_NAME}-rw.dmg"
APPLICATIONS_ICON="/System/Library/CoreServices/CoreTypes.bundle/Contents/Resources/ApplicationsFolderIcon.icns"

if [[ ! -d "$APP_DIR" ]]; then
  echo "Missing app bundle: $APP_DIR" >&2
  echo "Run ./Scripts/build_app.sh first." >&2
  exit 1
fi

rm -rf "$STAGING_DIR" "$RW_DMG" "$DMG_PATH"
mkdir -p "$STAGING_DIR"

/usr/bin/swift - "$ROOT_DIR/docs/assets/agentbar-icon.png" "$BACKGROUND_PATH" <<'SWIFT'
import AppKit
import Foundation

let arguments = CommandLine.arguments
let iconURL = URL(fileURLWithPath: arguments[1])
let outputURL = URL(fileURLWithPath: arguments[2])
let size = NSSize(width: 640, height: 420)
let image = NSImage(size: size)

image.lockFocus()

let rect = NSRect(origin: .zero, size: size)
NSColor(calibratedRed: 0.955, green: 0.968, blue: 0.978, alpha: 1).setFill()
rect.fill()

let cardRect = NSRect(x: 34, y: 42, width: 572, height: 336)
let cardPath = NSBezierPath(roundedRect: cardRect, xRadius: 24, yRadius: 24)
NSColor(calibratedRed: 0.992, green: 0.996, blue: 1.0, alpha: 1).setFill()
cardPath.fill()
NSColor(calibratedRed: 0.82, green: 0.86, blue: 0.895, alpha: 1).setStroke()
cardPath.lineWidth = 1.4
cardPath.stroke()

if let icon = NSImage(contentsOf: iconURL) {
    icon.draw(in: NSRect(x: 274, y: 280, width: 92, height: 92),
              from: .zero,
              operation: .sourceOver,
              fraction: 1)
}

let paragraph = NSMutableParagraphStyle()
paragraph.alignment = .center

func draw(_ text: String, y: CGFloat, size: CGFloat, weight: NSFont.Weight, color: NSColor) {
    let attributes: [NSAttributedString.Key: Any] = [
        .font: NSFont.systemFont(ofSize: size, weight: weight),
        .foregroundColor: color,
        .paragraphStyle: paragraph
    ]
    text.draw(in: NSRect(x: 60, y: y, width: 520, height: size + 12), withAttributes: attributes)
}

draw("Install AgentBar", y: 244, size: 28, weight: .semibold, color: NSColor(calibratedWhite: 0.05, alpha: 1))
draw("Drag AgentBar into Applications", y: 214, size: 15, weight: .medium, color: NSColor(calibratedWhite: 0.43, alpha: 1))

let arrowAttributes: [NSAttributedString.Key: Any] = [
    .font: NSFont.systemFont(ofSize: 46, weight: .medium),
    .foregroundColor: NSColor(calibratedRed: 0.0, green: 0.48, blue: 0.18, alpha: 1),
    .paragraphStyle: paragraph
]
"→".draw(in: NSRect(x: 274, y: 114, width: 92, height: 60), withAttributes: arrowAttributes)

image.unlockFocus()

guard let tiff = image.tiffRepresentation,
      let bitmap = NSBitmapImageRep(data: tiff),
      let png = bitmap.representation(using: .png, properties: [:]) else {
    fatalError("Could not render DMG background")
}

try png.write(to: outputURL)
SWIFT

hdiutil create \
  -volname "$APP_NAME" \
  -fs HFS+ \
  -fsargs "-c c=64,a=16,e=16" \
  -size 80m \
  -ov \
  "$RW_DMG"

ATTACH_OUTPUT="$(hdiutil attach "$RW_DMG" -readwrite -noverify -noautoopen)"
DEVICE="$(printf '%s\n' "$ATTACH_OUTPUT" | awk '/Apple_HFS/ {print $1; exit}')"
VOLUME="$(printf '%s\n' "$ATTACH_OUTPUT" | awk '/Apple_HFS/ {for (i=3; i<=NF; i++) {printf "%s%s", (i==3 ? "" : " "), $i}; print ""; exit}')"

cleanup() {
  if [[ -n "${DEVICE:-}" ]]; then
    hdiutil detach "$DEVICE" -quiet || true
  fi
}
trap cleanup EXIT

if [[ -d "$VOLUME" ]]; then
  cp -R "$APP_DIR" "$VOLUME/${APP_NAME}.app"
  mkdir -p "$VOLUME/.background"
  cp "$BACKGROUND_PATH" "$VOLUME/.background/background.png"

  osascript <<APPLESCRIPT || true
set volumeAlias to POSIX file "$VOLUME" as alias
set applicationsAlias to POSIX file "/Applications" as alias
tell application "Finder"
  make new alias file to applicationsAlias at volumeAlias with properties {name:"Applications"}
end tell
APPLESCRIPT

  if [[ -f "$APPLICATIONS_ICON" ]] && command -v xxd >/dev/null && command -v Rez >/dev/null && command -v SetFile >/dev/null; then
    {
      echo "data 'icns' (-16455, \"icns\") {"
      xxd -p "$APPLICATIONS_ICON" | sed 's/.*/$"&"/'
      echo "};"
    } > "$STAGING_DIR/ApplicationsIcon.r"
    Rez -append "$STAGING_DIR/ApplicationsIcon.r" -o "$VOLUME/Applications" || true
    SetFile -a C "$VOLUME/Applications" || true
  fi

  osascript <<APPLESCRIPT || true
set volumeAlias to POSIX file "$VOLUME" as alias
set backgroundAlias to POSIX file "$VOLUME/.background/background.png"
tell application "Finder"
  open volumeAlias
  delay 1
  set targetWindow to front Finder window
  set current view of targetWindow to icon view
  set toolbar visible of targetWindow to false
  set statusbar visible of targetWindow to false
  set bounds of targetWindow to {120, 120, 760, 540}
  set theViewOptions to the icon view options of targetWindow
  set arrangement of theViewOptions to not arranged
  set icon size of theViewOptions to 96
  set background picture of theViewOptions to backgroundAlias
  set position of item "${APP_NAME}.app" of targetWindow to {190, 268}
  set position of item "Applications" of targetWindow to {450, 268}
  update volumeAlias without registering applications
  delay 3
  close targetWindow
end tell
APPLESCRIPT

  chflags hidden "$VOLUME/.background" || true

  if [[ ! -f "$VOLUME/.DS_Store" ]]; then
    echo "Warning: Finder did not write .DS_Store; DMG layout may not be preserved." >&2
  fi

  sync
fi

hdiutil detach "$DEVICE" -quiet
DEVICE=""

hdiutil convert "$RW_DMG" \
  -format UDZO \
  -imagekey zlib-level=9 \
  -o "$DMG_PATH" \
  -ov

rm -rf "$STAGING_DIR" "$RW_DMG"
echo "$DMG_PATH"
