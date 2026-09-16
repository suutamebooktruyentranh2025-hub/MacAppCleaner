#!/usr/bin/env bash
set -e

# Script đóng gói MacAppCleaner thành ứng dụng macOS (.app) độc lập
PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$PROJECT_ROOT"

APP_NAME="MacAppCleaner"
BUILD_DIR="$PROJECT_ROOT/build"
BUNDLE_DIR="$BUILD_DIR/$APP_NAME.app"
CONTENTS_DIR="$BUNDLE_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"

echo "🔨 [1/4] Đang biên dịch bản Release..."
swift build -c release

RELEASE_BIN="$PROJECT_ROOT/.build/arm64-apple-macosx/release/$APP_NAME"
if [ ! -f "$RELEASE_BIN" ]; then
    # Fallback nếu architecture khác
    RELEASE_BIN="$(swift build -c release --show-bin-path)/$APP_NAME"
fi

echo "📦 [2/4] Đang khởi tạo cấu trúc macOS App Bundle ($BUNDLE_DIR)..."
rm -rf "$BUNDLE_DIR"
mkdir -p "$MACOS_DIR"
mkdir -p "$RESOURCES_DIR"

# Copy binary vào thư mục Contents/MacOS
cp "$RELEASE_BIN" "$MACOS_DIR/$APP_NAME"
chmod +x "$MACOS_DIR/$APP_NAME"

# Sao chép AppIcon vào Resources
if [ ! -f "$PROJECT_ROOT/Sources/MacAppCleaner/Resources/AppIcon.icns" ]; then
    echo "🎨 Đang tạo bộ icon AppIcon..."
    swift "$PROJECT_ROOT/scripts/generate-app-icon.swift"
fi
cp "$PROJECT_ROOT/Sources/MacAppCleaner/Resources/AppIcon.icns" "$RESOURCES_DIR/AppIcon.icns"
if [ -f "$PROJECT_ROOT/Sources/MacAppCleaner/Resources/AppIcon.png" ]; then
    cp "$PROJECT_ROOT/Sources/MacAppCleaner/Resources/AppIcon.png" "$RESOURCES_DIR/AppIcon.png"
fi

echo "📝 [3/4] Đang tạo Info.plist và PkgInfo..."
cat <<EOF > "$CONTENTS_DIR/Info.plist"
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>$APP_NAME</string>
    <key>CFBundleIdentifier</key>
    <string>com.macappcleaner.app</string>
    <key>CFBundleName</key>
    <string>$APP_NAME</string>
    <key>CFBundleDisplayName</key>
    <string>$APP_NAME</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundleIconName</key>
    <string>AppIcon</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSSupportsAutomaticGraphicsSwitching</key>
    <true/>
    <key>LSApplicationCategoryType</key>
    <string>public.app-category.utilities</string>
    <key>NSAppleEventsUsageDescription</key>
    <string>MacAppCleaner cần quyền gửi sự kiện đến Finder để hỗ trợ dọn dẹp và chuyển ứng dụng được bảo vệ vào Thùng Rác.</string>
    <key>NSSystemAdministrationUsageDescription</key>
    <string>MacAppCleaner cần quyền Quản trị viên để gỡ bỏ hoàn toàn ứng dụng và tệp tàn dư được bảo vệ.</string>
    <key>NSFullDiskAccessUsageDescription</key>
    <string>MacAppCleaner cần quyền truy cập toàn bộ đĩa để quét và dọn dẹp các tệp caches, cấu hình và tàn dư ứng dụng.</string>
</dict>
</plist>
EOF

echo "APPL????" > "$CONTENTS_DIR/PkgInfo"

echo "🔏 [4/5] Đang ký mã Ad-hoc với Designated Requirement ổn định..."
codesign --force --deep --sign - --identifier "com.macappcleaner.app" --requirements '=designated => identifier "com.macappcleaner.app"' "$BUNDLE_DIR"

echo "💿 [5/5] Đang tạo tệp cài đặt Disk Image (.dmg) kéo thả..."
"$PROJECT_ROOT/scripts/build-dmg.sh"

echo "✅ Hoàn tất toàn bộ quy trình đóng gói!"
echo "👉 App Bundle: $BUNDLE_DIR"
echo "👉 File cài đặt DMG: $PROJECT_ROOT/build/$APP_NAME.dmg"
echo "Bạn có thể mở tệp cài đặt bằng lệnh: open \"$PROJECT_ROOT/build/$APP_NAME.dmg\""
