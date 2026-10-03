#!/bin/bash
# Compila MirrorBar.app (requiere Xcode Command Line Tools: xcode-select --install)
set -e; cd "$(dirname "$0")"
mkdir -p MirrorBar.app/Contents/MacOS
cat > MirrorBar.app/Contents/Info.plist <<P
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleName</key><string>MirrorBar</string><key>CFBundleIdentifier</key><string>com.joelveloz.mirrorbar</string>
<key>CFBundleExecutable</key><string>MirrorBar</string><key>CFBundleVersion</key><string>1.0</string>
<key>CFBundleIconFile</key><string>AppIcon</string><key>LSUIElement</key><true/><key>LSMinimumSystemVersion</key><string>12.0</string>
</dict></plist>
P
# ícono desde icon.svg
mkdir -p MirrorBar.app/Contents/Resources
qlmanage -t -s 1024 -o /tmp icon.svg >/dev/null 2>&1; I=/tmp/MirrorBar.iconset; rm -rf $I; mkdir $I
for s in 16 32 128 256 512; do sips -z $s $s /tmp/icon.svg.png --out $I/icon_${s}x${s}.png >/dev/null; sips -z $((s*2)) $((s*2)) /tmp/icon.svg.png --out $I/icon_${s}x${s}@2x.png >/dev/null; done
iconutil -c icns $I -o MirrorBar.app/Contents/Resources/AppIcon.icns
swiftc -O main.swift -o MirrorBar.app/Contents/MacOS/MirrorBar
codesign --force -s - MirrorBar.app
echo "✅ MirrorBar.app listo"
