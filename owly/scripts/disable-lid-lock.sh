#!/usr/bin/env bash
set -euo pipefail

SUDOERS_PATHS=(
    "/etc/sudoers.d/owly"
    "/etc/sudoers.d/caffeinatetoggle"
    "/etc/sudoers.d/com.user.caffeinatetoggle"
)

echo "==> Resetting disablesleep to 0"
if ! sudo -n /usr/bin/pmset -a disablesleep 0 2>/dev/null; then
    sudo /usr/bin/pmset -a disablesleep 0 || true
fi

echo "==> Removing sudoers entries"
removed=0
for f in "${SUDOERS_PATHS[@]}"; do
    if sudo test -e "$f"; then
        sudo rm -f "$f"
        echo "    removed $f"
        removed=1
    fi
done
if [ "$removed" -eq 0 ]; then
    echo "    (no entry to remove)"
fi

echo ""
echo "✅ 强力模式已关闭。"
