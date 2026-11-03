#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."
PROJECT_ROOT="$(pwd)"

APP_NAME="Owly"
APP_BUNDLE="build/$APP_NAME.app"
INSTALL_DIR="/Applications"
LABEL="com.aarontaken.owly"
PLIST_PATH="$HOME/Library/LaunchAgents/$LABEL.plist"

# ENABLE_LID:
#   auto - if stdin is a TTY, prompt; otherwise skip
#   yes  - install sudoers without prompt (still needs sudo password)
#   no   - skip sudoers installation
ENABLE_LID="auto"

while [[ $# -gt 0 ]]; do
    case "$1" in
        --with-lid-lock) ENABLE_LID="yes"; shift ;;
        --no-lid-lock)   ENABLE_LID="no";  shift ;;
        -h|--help)
            cat <<USAGE
Usage: $0 [--with-lid-lock | --no-lid-lock]

  --with-lid-lock   Install sudoers entry to enable "lid lock" feature
                    (requires sudo password).
  --no-lid-lock     Skip sudoers installation. You can enable later via
                    the menu bar (will trigger a native admin dialog) or
                    via scripts/enable-lid-lock.sh.
  (default)         Prompt interactively if running in a TTY, otherwise skip.
USAGE
            exit 0 ;;
        *) echo "Unknown option: $1" >&2; exit 2 ;;
    esac
done

if [ ! -d "$APP_BUNDLE" ]; then
    echo "❌ App not built. Run scripts/build.sh first." >&2
    exit 1
fi

echo "==> Installing to $INSTALL_DIR/$APP_NAME.app"
rm -rf "$INSTALL_DIR/$APP_NAME.app"
cp -R "$APP_BUNDLE" "$INSTALL_DIR/"

echo "==> Writing LaunchAgent: $PLIST_PATH"
mkdir -p "$(dirname "$PLIST_PATH")"
cat > "$PLIST_PATH" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>$LABEL</string>
    <key>ProgramArguments</key>
    <array>
        <string>$INSTALL_DIR/$APP_NAME.app/Contents/MacOS/$APP_NAME</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <false/>
    <key>ProcessType</key>
    <string>Interactive</string>
    <key>StandardOutPath</key>
    <string>/tmp/$LABEL.out.log</string>
    <key>StandardErrorPath</key>
    <string>/tmp/$LABEL.err.log</string>
</dict>
</plist>
EOF

if [[ "$ENABLE_LID" == "auto" ]]; then
    if [[ -t 0 ]]; then
        echo ""
        echo "==> 「合盖也不睡」强力模式"
        echo "    需要 sudoers 授权，让菜单栏点击就能免密切换。"
        echo "    授权范围被严格限制为以下两条精确命令："
        echo "        /usr/bin/pmset -a disablesleep 0"
        echo "        /usr/bin/pmset -a disablesleep 1"
        echo ""
        read -r -p "    现在启用？[Y/n] " enable_lid
        enable_lid="${enable_lid:-Y}"
        ENABLE_LID=$([[ "$enable_lid" =~ ^[Yy]$ ]] && echo yes || echo no)
    else
        ENABLE_LID="no"
        echo ""
        echo "==> 非交互模式：跳过强力模式 sudoers 安装"
        echo "    需要时菜单栏点击「强力模式」会自动弹出原生授权对话框；"
        echo "    或终端运行 scripts/enable-lid-lock.sh。"
    fi
fi

if [[ "$ENABLE_LID" == "yes" ]]; then
    "$PROJECT_ROOT/scripts/enable-lid-lock.sh"
fi

echo ""
echo "==> Loading LaunchAgent"
launchctl unload "$PLIST_PATH" 2>/dev/null || true
launchctl load "$PLIST_PATH"

echo ""
echo "✅ Installed and started."
echo "   App:          $INSTALL_DIR/$APP_NAME.app"
echo "   LaunchAgent:  $PLIST_PATH"
echo "   菜单栏现在应该出现一个图标，点击切换防睡眠。"
