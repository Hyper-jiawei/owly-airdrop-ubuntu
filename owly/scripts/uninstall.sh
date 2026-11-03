#!/usr/bin/env bash
set -euo pipefail

APP_NAME="Owly"
INSTALL_DIR="/Applications"
LABEL="com.aarontaken.owly"
PLIST_PATH="$HOME/Library/LaunchAgents/$LABEL.plist"

# Legacy paths/labels from earlier versions of this project.
LEGACY_LABELS=("com.user.caffeinatetoggle")
LEGACY_APP_NAMES=("CaffeinateToggle")
SUDOERS_PATHS=(
    "/etc/sudoers.d/owly"
    "/etc/sudoers.d/caffeinatetoggle"
    "/etc/sudoers.d/com.user.caffeinatetoggle"
)

echo "==> Unloading LaunchAgent"
if [ -f "$PLIST_PATH" ]; then
    launchctl unload "$PLIST_PATH" 2>/dev/null || true
    rm -f "$PLIST_PATH"
    echo "    removed $PLIST_PATH"
fi
for legacy in "${LEGACY_LABELS[@]}"; do
    legacy_plist="$HOME/Library/LaunchAgents/$legacy.plist"
    if [ -f "$legacy_plist" ]; then
        launchctl unload "$legacy_plist" 2>/dev/null || true
        rm -f "$legacy_plist"
        echo "    removed $legacy_plist (legacy)"
    fi
done

echo "==> Killing running process"
pkill -x "$APP_NAME" 2>/dev/null || true
for legacy in "${LEGACY_APP_NAMES[@]}"; do
    pkill -x "$legacy" 2>/dev/null || true
done

echo "==> Resetting disablesleep just in case"
if ! sudo -n /usr/bin/pmset -a disablesleep 0 2>/dev/null; then
    sudo /usr/bin/pmset -a disablesleep 0 || true
fi

echo "==> Removing sudoers entries (if any)"
removed=0
for f in "${SUDOERS_PATHS[@]}"; do
    if sudo test -e "$f"; then
        sudo rm -f "$f"
        echo "    removed $f"
        removed=1
    fi
done
if [ "$removed" -eq 0 ]; then
    echo "    (no sudoers entry)"
fi

echo "==> Removing app bundle"
if [ -d "$INSTALL_DIR/$APP_NAME.app" ]; then
    rm -rf "$INSTALL_DIR/$APP_NAME.app"
    echo "    removed $INSTALL_DIR/$APP_NAME.app"
fi
for legacy in "${LEGACY_APP_NAMES[@]}"; do
    if [ -d "$INSTALL_DIR/$legacy.app" ]; then
        rm -rf "$INSTALL_DIR/$legacy.app"
        echo "    removed $INSTALL_DIR/$legacy.app (legacy)"
    fi
done

echo ""
echo "✅ Uninstalled."
