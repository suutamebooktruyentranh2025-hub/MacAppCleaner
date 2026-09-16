#!/usr/bin/env bash
set -e

PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$PROJECT_ROOT"

APP_NAME="MacAppCleaner"
BUILD_DIR="$PROJECT_ROOT/build"
BUNDLE_DIR="$BUILD_DIR/$APP_NAME.app"
DMG_PATH="$BUILD_DIR/$APP_NAME.dmg"
DMG_STAGING="$BUILD_DIR/dmg_staging"

# 1. Đảm bảo file .app đã được đóng gói
if [ ! -d "$BUNDLE_DIR" ]; then
    echo "⚠️ Chưa tìm thấy $BUNDLE_DIR, đang chạy build-app.sh..."
    "$PROJECT_ROOT/scripts/build-app.sh"
fi

echo "💿 [1/3] Đang chuẩn bị thư mục đóng gói DMG ($DMG_STAGING)..."
rm -rf "$DMG_STAGING"
mkdir -p "$DMG_STAGING"

# Copy App Bundle vào Staging
cp -R "$BUNDLE_DIR" "$DMG_STAGING/"

# Tạo Symlink trỏ vào thư mục /Applications để người dùng kéo thả
ln -s /Applications "$DMG_STAGING/Applications"

# Cài đặt Volume Icon cho DMG nếu có AppIcon.icns
ICNS_FILE="$PROJECT_ROOT/Sources/MacAppCleaner/Resources/AppIcon.icns"
if [ -f "$ICNS_FILE" ]; then
    cp "$ICNS_FILE" "$DMG_STAGING/.VolumeIcon.icns"
    if command -v SetFile >/dev/null 2>&1; then
        SetFile -c icnC "$DMG_STAGING/.VolumeIcon.icns" 2>/dev/null || true
        SetFile -a C "$DMG_STAGING" 2>/dev/null || true
    fi
fi

echo "🗜️ [2/3] Đang nén thành tệp Disk Image (.dmg) bằng hdiutil..."
rm -f "$DMG_PATH"

# Tạo tệp DMG nén UDZO (chuẩn phân phối macOS)
hdiutil create \
    -volname "$APP_NAME" \
    -srcfolder "$DMG_STAGING" \
    -ov \
    -format UDZO \
    "$DMG_PATH"

# Dọn dẹp thư mục tạm
rm -rf "$DMG_STAGING"
sync
sleep 1

echo "🔍 [3/3] Đang kiểm tra tính toàn vẹn của tệp DMG..."
hdiutil verify "$DMG_PATH"

echo ""
echo "🎉 Hoàn tất đóng gói DMG cài đặt thành công!"
echo "👉 Đường dẫn tệp DMG: $DMG_PATH"
echo "Kích thước: $(du -sh "$DMG_PATH" | cut -f1)"
echo ""
echo "Để mở và thử kéo thả cài đặt, chạy:"
echo "open \"$DMG_PATH\""
