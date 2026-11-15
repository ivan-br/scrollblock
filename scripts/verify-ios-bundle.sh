#!/usr/bin/env bash
set -euo pipefail
APP_PATH="${1:?Pass the built .app path}"
test -f "$APP_PATH/main.jsbundle"
test -f "$APP_PATH/Assets.car"
EXECUTABLE="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleExecutable' "$APP_PATH/Info.plist")"
test -x "$APP_PATH/$EXECUTABLE"
EXTENSION_PATH="$APP_PATH/PlugIns/ScrollblockTunnel.appex"
test -d "$EXTENSION_PATH"
test -f "$APP_PATH/rules.json"
test -f "$EXTENSION_PATH/rules.json"
cmp "$APP_PATH/rules.json" "$EXTENSION_PATH/rules.json"
EXTENSION_EXECUTABLE="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleExecutable' "$EXTENSION_PATH/Info.plist")"
test -x "$EXTENSION_PATH/$EXTENSION_EXECUTABLE"
test "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$EXTENSION_PATH/Info.plist")" = "com.softdev.scrollblock.tunnel"
test "$(/usr/libexec/PlistBuddy -c 'Print :NSExtension:NSExtensionPointIdentifier' "$EXTENSION_PATH/Info.plist")" = "com.apple.networkextension.packet-tunnel"
test "$(/usr/libexec/PlistBuddy -c 'Print :MinimumOSVersion' "$EXTENSION_PATH/Info.plist")" = "18.0"
test "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$EXTENSION_PATH/Info.plist")" = "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$APP_PATH/Info.plist")"
/usr/bin/plutil -convert json -o - "$APP_PATH/Info.plist" | node -e '
let text = "";
process.stdin.on("data", part => text += part);
process.stdin.on("end", () => {
  const plist = JSON.parse(text);
  if (plist.MinimumOSVersion !== "18.0") throw new Error("Expected iOS 18.0 deployment target");
  const schemes = (plist.CFBundleURLTypes || []).flatMap(item => item.CFBundleURLSchemes || []);
  if (plist.CFBundleDisplayName !== "Scrollblock" || plist.CFBundleIdentifier !== "com.softdev.scrollblock" || !schemes.includes("scrollblock")) {
    console.error("Incorrect display name, bundle identifier or Router URL scheme.");
    process.exit(1);
  }
});'
echo "Verified Scrollblock executable, assets, JavaScript and URL scheme."
