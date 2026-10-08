#!/bin/zsh
set -euo pipefail
root=${0:A:h}
app="$root/AIMicro Host.app"
mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources/Helper" "$app/Contents/Resources/Server" "$root/../.build/mac-host/module-cache"
swiftc -module-cache-path "$root/../.build/mac-host/module-cache" "$root/Helper/main.swift" -o "$app/Contents/Resources/Helper/MicroRemoteAX"
swiftc -parse-as-library -module-cache-path "$root/../.build/mac-host/module-cache" "$root/App/"*.swift -o "$app/Contents/MacOS/MicroRemoteHost"
if [[ -f "$root/Server/server.py" ]]; then cp -R "$root/Server/." "$app/Contents/Resources/Server/"; fi
cat > "$app/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?><!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd"><plist version="1.0"><dict><key>CFBundleIdentifier</key><string>de.aimicro.host</string><key>CFBundleName</key><string>AIMicro Host</string><key>CFBundleExecutable</key><string>MicroRemoteHost</string><key>CFBundlePackageType</key><string>APPL</string><key>CFBundleShortVersionString</key><string>0.1.0</string><key>LSMinimumSystemVersion</key><string>15.0</string><key>NSAppleEventsUsageDescription</key><string>AIMicro liest und wählt vorhandene Terminal-Tabs, um nachgewiesene Claude-Code-Sitzungen von deinem iPhone zu steuern.</string><key>NSHighResolutionCapable</key><true/></dict></plist>
PLIST
codesign --force --deep --sign - "$app"
