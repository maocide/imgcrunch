#!/usr/bin/env bash
# ==============================================================================
# IMGCRUNCH // Desktop Installation Script
# Installs imgcrunch as a native Linux desktop application with icons and MIME types.
# ==============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALL_PREFIX="${HOME}/.local"
APP_DIR="${INSTALL_PREFIX}/share/imgcrunch"
BIN_DIR="${INSTALL_PREFIX}/bin"
DESKTOP_DIR="${INSTALL_PREFIX}/share/applications"
ICONS_BASE="${INSTALL_PREFIX}/share/icons/hicolor"

usage() {
    cat <<EOF
IMGCRUNCH Installer
Usage: ./install.sh [OPTIONS]

Options:
  --clean          Clean Flutter and Rust build caches before building (cargo clean + flutter clean)
  --skip-build     Skip running 'flutter build linux --release' (use existing bundle)
  --no-default     Do not register imgcrunch as the default system image viewer
  --uninstall      Remove imgcrunch from ~/.local (binary, icons, desktop entry)
  -h, --help       Show this help message
EOF
    exit 0
}

uninstall_app() {
    echo ">> Removing IMGCRUNCH from ${INSTALL_PREFIX}..."
    rm -rf "${APP_DIR}"
    rm -f "${BIN_DIR}/imgcrunch"
    rm -f "${DESKTOP_DIR}/imgcrunch.desktop"

    for size in 16 24 32 48 64 128 256 512; do
        rm -f "${ICONS_BASE}/${size}x${size}/apps/imgcrunch.png"
    done

    echo ">> Updating desktop and icon caches..."
    update-desktop-database "${DESKTOP_DIR}" 2>/dev/null || true
    gtk-update-icon-cache -q -f -t "${ICONS_BASE}" 2>/dev/null || true

    echo "✓ IMGCRUNCH has been cleanly uninstalled."
    exit 0
}

CLEAN_BUILD=0
SKIP_BUILD=0
SET_DEFAULT=1

while [[ $# -gt 0 ]]; do
    case "$1" in
        --clean)
            CLEAN_BUILD=1
            shift
            ;;
        --skip-build)
            SKIP_BUILD=1
            shift
            ;;
        --no-default)
            SET_DEFAULT=0
            shift
            ;;
        --uninstall)
            uninstall_app
            ;;
        -h|--help)
            usage
            ;;
        *)
            echo "Unknown option: $1"
            usage
            ;;
    esac
done

echo "=================================================="
echo "   IMGCRUNCH // Linux Desktop Installer           "
echo "=================================================="

# 0. Clean build caches if requested
if [[ ${CLEAN_BUILD} -eq 1 ]]; then
    echo ">> [0/5] Purging Flutter and Rust build caches..."
    cd "${SCRIPT_DIR}"
    if command -v cargo &>/dev/null && [[ -f "rust/Cargo.toml" ]]; then
        cargo clean --manifest-path rust/Cargo.toml
    fi
    flutter clean
    flutter pub get
fi

# 1. Build release bundle if needed
BUNDLE_DIR="${SCRIPT_DIR}/build/linux/x64/release/bundle"

if [[ ${SKIP_BUILD} -eq 0 ]]; then
    echo ">> [1/5] Building release bundle with Flutter & Rust..."
    cd "${SCRIPT_DIR}"
    flutter build linux --release
else
    echo ">> [1/5] Skipping build (using existing bundle in ${BUNDLE_DIR})..."
fi

if [[ ! -d "${BUNDLE_DIR}" ]]; then
    echo "Error: Bundle not found at ${BUNDLE_DIR}."
    echo "Please run without --skip-build to compile first."
    exit 1
fi

# 2. Install application bundle
echo ">> [2/5] Installing application bundle to ${APP_DIR}..."
mkdir -p "${APP_DIR}" "${BIN_DIR}"
rm -rf "${APP_DIR:?}"/*
cp -r "${BUNDLE_DIR}"/* "${APP_DIR}/"

# 3. Create symlink in ~/.local/bin
echo ">> [3/5] Linking binary into ${BIN_DIR}/imgcrunch..."
ln -sf "${APP_DIR}/imgcrunch" "${BIN_DIR}/imgcrunch"

# 4. Install icons & desktop file
echo ">> [4/5] Installing hicolor icon set and desktop entry..."
for size in 16 24 32 48 64 128 256 512; do
    icon_src="${SCRIPT_DIR}/assets/icons/hicolor/${size}x${size}/apps/imgcrunch.png"
    if [[ -f "${icon_src}" ]]; then
        icon_dest="${ICONS_BASE}/${size}x${size}/apps"
        mkdir -p "${icon_dest}"
        cp "${icon_src}" "${icon_dest}/imgcrunch.png"
    fi
done

mkdir -p "${DESKTOP_DIR}"
cp "${SCRIPT_DIR}/linux/imgcrunch.desktop" "${DESKTOP_DIR}/imgcrunch.desktop"

# Refresh system desktop & icon databases
update-desktop-database "${DESKTOP_DIR}" 2>/dev/null || true
gtk-update-icon-cache -q -f -t "${ICONS_BASE}" 2>/dev/null || true

# 5. Register MIME types if requested
echo ">> [5/5] Configuring MIME types..."
if [[ ${SET_DEFAULT} -eq 1 ]] && command -v xdg-mime >/dev/null 2>&1; then
    echo "   Registering IMGCRUNCH as default system viewer for common image formats..."
    xdg-mime default imgcrunch.desktop image/png image/jpeg image/jpg image/webp image/gif image/bmp image/tiff
fi

echo ""
echo "=================================================="
echo "✓ IMGCRUNCH installed successfully!"
echo "=================================================="
echo "  Binary:      ${BIN_DIR}/imgcrunch"
echo "  Desktop App: ${DESKTOP_DIR}/imgcrunch.desktop"
echo "  Launcher:    Available in your application menu"
echo ""

# Check if ~/.local/bin is in PATH
if [[ ":$PATH:" != *":${BIN_DIR}:"* ]]; then
    echo "Notice: ${BIN_DIR} is not in your current PATH."
    echo "To launch 'imgcrunch' directly from terminal anywhere, add this to your ~/.bashrc or ~/.zshrc:"
    echo "   export PATH=\"\$HOME/.local/bin:\$PATH\""
    echo ""
fi

echo "To uninstall anytime, simply run: ./install.sh --uninstall"
echo "Happy Crunching! 💾⚡"
