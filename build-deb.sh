#!/usr/bin/env bash
# 构建 owly-airdrop-ubuntu 的 deb 安装包
#
# owly/owlyd 二进制：优先用 cargo 从 vendored 源码构建（需要 Rust 1.88+）；
# 没有 cargo 时回退到系统已安装的 owly 二进制（本包开发时基于官方 0.4.2）。
set -euo pipefail

PKG=owly-airdrop-ubuntu
VER=0.1.0
ARCH=amd64
UUID='owly-airdrop@hyper-jiawei.github.com'

ROOT="$(cd "$(dirname "$0")" && pwd)"
STAGE="$ROOT/build/${PKG}_${VER}_${ARCH}"
OUT="$ROOT/dist"

if command -v cargo >/dev/null 2>&1; then
    echo ">> 从源码构建 owly / owlyd"
    (cd "$ROOT/owly" && cargo build --release --locked -p owlyd -p owly-cli)
    OWLY_BIN="$ROOT/owly/target/release/owly"
    OWLYD_BIN="$ROOT/owly/target/release/owlyd"
else
    echo ">> 未找到 cargo，使用系统已安装的 owly 二进制"
    echo "   （安装 Rust 1.88+ 后重跑本脚本即可从源码构建）"
    OWLY_BIN=/usr/bin/owly
    OWLYD_BIN=/usr/lib/owly/owlyd
    [[ -x $OWLY_BIN && -x $OWLYD_BIN ]] || { echo "错误：系统未安装 owly，且没有 cargo"; exit 1; }
fi

rm -rf "$STAGE"
mkdir -p "$STAGE/DEBIAN" "$OUT"

install -m 0644 "$ROOT/packaging/debian/control"  "$STAGE/DEBIAN/control"
install -m 0755 "$ROOT/packaging/debian/postinst" "$STAGE/DEBIAN/postinst"
install -m 0755 "$ROOT/packaging/debian/prerm"    "$STAGE/DEBIAN/prerm"
install -m 0755 "$ROOT/packaging/debian/postrm"   "$STAGE/DEBIAN/postrm"

# 二进制
install -Dm0755 "$OWLY_BIN"  "$STAGE/usr/bin/owly"
install -Dm0755 "$OWLYD_BIN" "$STAGE/usr/lib/owly/owlyd"

# UI 组件（GUI 与控制器），/usr/bin 下为符号链接
install -Dm0755 "$ROOT/src/owly-gui.py" "$STAGE/usr/lib/owly-airdrop/owly-gui.py"
install -Dm0755 "$ROOT/src/owly-ctl.py" "$STAGE/usr/lib/owly-airdrop/owly-ctl.py"
mkdir -p "$STAGE/usr/bin"
ln -s ../lib/owly-airdrop/owly-gui.py "$STAGE/usr/bin/owly-gui"
ln -s ../lib/owly-airdrop/owly-ctl.py "$STAGE/usr/bin/owly-ctl"

# 系统配置（来自原仓库 packaging/）
P="$ROOT/owly/packaging"
install -Dm0644 "$P/90-owly-unmanaged.conf"  "$STAGE/usr/lib/NetworkManager/conf.d/90-owly-unmanaged.conf"
install -Dm0644 "$P/10-owly-awdl0.link"      "$STAGE/usr/lib/systemd/network/10-owly-awdl0.link"
install -Dm0644 "$P/owlyd.service"           "$STAGE/usr/lib/systemd/system/owlyd.service"
install -Dm0644 "$P/io.github.t4t5.Owly.service" "$STAGE/usr/share/dbus-1/system-services/io.github.t4t5.Owly.service"
install -Dm0644 "$P/io.github.t4t5.Owly.conf"    "$STAGE/usr/share/dbus-1/system.d/io.github.t4t5.Owly.conf"
install -Dm0644 "$P/io.github.t4t5.Owly.policy"  "$STAGE/usr/share/polkit-1/actions/io.github.t4t5.Owly.policy"

# GNOME Shell 扩展
install -Dm0644 "$ROOT/src/extension/$UUID/metadata.json" "$STAGE/usr/share/gnome-shell/extensions/$UUID/metadata.json"
install -Dm0644 "$ROOT/src/extension/$UUID/extension.js"  "$STAGE/usr/share/gnome-shell/extensions/$UUID/extension.js"

# 图标与桌面启动项
install -Dm0644 "$ROOT/src/icons/owly-airdrop.svg"          "$STAGE/usr/share/icons/hicolor/scalable/apps/owly-airdrop.svg"
install -Dm0644 "$ROOT/src/icons/owly-airdrop-symbolic.svg" "$STAGE/usr/share/icons/hicolor/scalable/status/owly-airdrop-symbolic.svg"
install -Dm0644 "$ROOT/src/owly-airdrop.desktop"            "$STAGE/usr/share/applications/owly-airdrop.desktop"

# 文档
install -Dm0644 "$ROOT/README.md"      "$STAGE/usr/share/doc/$PKG/README.md"
install -Dm0644 "$ROOT/owly/LICENSE"   "$STAGE/usr/share/doc/$PKG/LICENSE"
install -Dm0644 "$ROOT/docs/使用说明.md" "$STAGE/usr/share/doc/$PKG/使用说明.md"

dpkg-deb --root-owner-group --build "$STAGE" "$OUT/${PKG}_${VER}_${ARCH}.deb"
echo ">> 构建完成: $OUT/${PKG}_${VER}_${ARCH}.deb"
