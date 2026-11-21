#!/bin/zsh
# Builds "Check Updates.app" (Apple Silicon + Intel) and a zip to share.
set -e
cd "$(dirname "$0")"
APP="build.noindex/Check Updates.app"
rm -rf build.noindex && mkdir -p "$APP/Contents/MacOS"
for arch in arm64 x86_64; do
  xcrun swiftc -O -parse-as-library -target $arch-apple-macos13.0 main.swift -o build.noindex/CheckUpdates-$arch
done
lipo -create build.noindex/CheckUpdates-* -output "$APP/Contents/MacOS/CheckUpdates"
rm build.noindex/CheckUpdates-*
mkdir -p "$APP/Contents/Resources" && cp AppIcon.icns "$APP/Contents/Resources/"
cat > "$APP/Contents/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>CFBundleName</key><string>Check Updates</string>
  <key>CFBundleIdentifier</key><string>com.armanalis.checkupdates</string>
  <key>CFBundleExecutable</key><string>CheckUpdates</string>
  <key>CFBundleIconFile</key><string>AppIcon</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>1.1</string>
  <key>CFBundleVersion</key><string>2</string>
  <key>LSMinimumSystemVersion</key><string>13.0</string>
  <key>NSHighResolutionCapable</key><true/>
</dict></plist>
EOF
xattr -cr "$APP"
codesign --force -s - "$APP"
(cd build.noindex && ditto -c -k --keepParent "Check Updates.app" CheckUpdates.zip)
cp build.noindex/CheckUpdates.zip website/public/CheckUpdates.zip
echo "Built: $APP, build.noindex/CheckUpdates.zip and website/public/CheckUpdates.zip"
