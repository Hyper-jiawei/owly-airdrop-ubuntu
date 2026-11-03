#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

VERSION="${1:-1.1.3}"
APP_NAME="Owly"
APP_BUNDLE="build/$APP_NAME.app"
DIST_DIR="dist"
ZIP_NAME="${APP_NAME}-v${VERSION}.zip"

echo "==> Building"
./scripts/build.sh

echo ""
echo "==> Preparing distribution"
rm -rf "$DIST_DIR"
mkdir -p "$DIST_DIR"

cp -R "$APP_BUNDLE" "$DIST_DIR/"

# Strip quarantine from the local copy (downstream users still need to do
# the right-click trick because Gatekeeper sets quarantine on download).
xattr -cr "$DIST_DIR/$APP_NAME.app"

cat > "$DIST_DIR/README-给同事.txt" <<'EOF'
Owly — 菜单栏防睡眠工具
========================

安装步骤：

1. 把 Owly.app 拖到「应用程序」文件夹

2. 第一次打开会被 Gatekeeper 拦下（"无法验证开发者"）
   解决：
   - 在「应用程序」里【右键】Owly.app，选「打开」
   - 弹窗里再点「打开」一次，之后双击就直接打开了
   - 或：系统设置 → 隐私与安全性 → 滚到底部点「仍要打开」

3. 启动后菜单栏会出现一个图标。点它就能切换三档：
   - 关闭
   - 熄屏不睡（屏幕照常熄灭省电，但系统/任务不睡）
   - 强力模式（连合盖都不睡，需要一次性管理员授权）

4. 想要开机自启 → 菜单点「开机自启」打勾即可（不需要密码，
   只是写一份 LaunchAgent 到你自己的 ~/Library/LaunchAgents/）

5. 想用强力模式 → 菜单点「强力模式」会弹出 macOS 原生
   管理员对话框，输一次密码后永久免密生效。授权范围被限制为
   仅以下两条精确命令：
     pmset -a disablesleep 0
     pmset -a disablesleep 1
   不会获得其他任何 root 权限。

6. 想撤销 / 卸载 → 菜单底部「撤销强力模式授权…」一键回滚；
   或直接把 .app 拖到废纸篓即可。

什么场景用什么：
- 跑长时间任务（编译、agent、下载）→ 选「熄屏不睡」
  屏幕该熄熄省电、CPU 继续跑，离开十几分钟回来也没事
- 合上盖子带去会议室还想任务继续 → 选「强力模式」
  退出 App 时会自动复位，不会留尾巴
EOF

cd "$DIST_DIR"
rm -f "$ZIP_NAME"
zip -ry "$ZIP_NAME" "$APP_NAME.app" "README-给同事.txt" >/dev/null

echo ""
echo "✅ Distribution package built:"
echo ""
echo "    $(pwd)/$ZIP_NAME"
echo "    $(du -sh "$ZIP_NAME" | awk '{print $1}')"
echo ""
echo "    分发给同事：直接发这个 zip，附上简短说明："
echo "    解压 → 把 Owly.app 拖到「应用程序」"
echo "    → 右键打开（首次绕过 Gatekeeper）→ 菜单栏点开三档随意切。"
