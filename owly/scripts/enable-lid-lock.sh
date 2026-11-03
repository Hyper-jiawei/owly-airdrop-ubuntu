#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

# IMPORTANT: filename must NOT contain a '.' character — sudo skips any file
# in /etc/sudoers.d/ whose name has a dot or ends with '~' (see sudoers(5)).
SUDOERS_NAME="owly"
SUDOERS_DST="/etc/sudoers.d/$SUDOERS_NAME"

# Legacy filenames from earlier versions of this project. Cleaned up so users
# upgrading don't end up with multiple sudoers files.
SUDOERS_LEGACY=(
    "/etc/sudoers.d/caffeinatetoggle"
    "/etc/sudoers.d/com.user.caffeinatetoggle"
)

TEMPLATE="resources/sudoers.template"

if [ ! -f "$TEMPLATE" ]; then
    echo "❌ Missing $TEMPLATE" >&2
    exit 1
fi

USERNAME="$(id -un)"
TMP_SUDOERS="$(mktemp -t owly.sudoers)"
sed "s|__USER__|$USERNAME|g" "$TEMPLATE" > "$TMP_SUDOERS"

echo "==> Validating rendered sudoers file"
if ! /usr/sbin/visudo -c -f "$TMP_SUDOERS" >/dev/null; then
    echo "❌ sudoers 模板语法校验失败。" >&2
    rm -f "$TMP_SUDOERS"
    exit 1
fi

echo "==> Installing $SUDOERS_DST  (会要求一次管理员密码)"
sudo install -m 0440 -o root -g wheel "$TMP_SUDOERS" "$SUDOERS_DST"
rm -f "$TMP_SUDOERS"

# Clean up any legacy sudoers files left over from earlier project names.
for legacy in "${SUDOERS_LEGACY[@]}"; do
    if sudo test -e "$legacy"; then
        echo "==> Removing legacy file $legacy"
        sudo rm -f "$legacy"
    fi
done

echo ""
echo "==> Verifying passwordless sudo works"
sudo -k  # 清空当前会话的 sudo 凭证缓存,避免缓存让验证假成功
if sudo -n /usr/bin/pmset -a disablesleep 0 >/dev/null 2>&1; then
    echo "    ✓ 验证通过。菜单栏「强力模式」现在可用了。"
    echo "      （已顺手把 disablesleep 重置为 0，避免遗留状态）"
else
    echo "    ⚠️  sudoers 已写入但免密验证失败。可能原因："
    echo "       - sudoers.d 不在 /etc/sudoers 的 includedir 列表里"
    echo "       - 文件名含 . 或 ~ 字符（被 sudo 忽略）"
    echo "       - 系统启用了 tty_tickets / requiretty 严格模式"
    echo "       请检查 /etc/sudoers 中是否包含  @includedir /private/etc/sudoers.d"
    echo "       或运行  sudo -ll  查看实际加载到的规则"
    exit 1
fi

echo ""
echo "✅ 强力模式已启用。"
echo "   关闭：scripts/disable-lid-lock.sh"
