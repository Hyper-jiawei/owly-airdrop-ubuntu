# Owly AirDrop for Ubuntu

在 **iPhone 与 Ubuntu 之间使用 AirDrop**，带组件化桌面 UI。

本项目把 [t4t5/owly](https://github.com/t4t5/owly)（MIT 协议，让 Linux 支持 Apple AWDL/AirDrop 协议）与一套为 Ubuntu 新设计的桌面组件打包在一起，提供**一键安装的 deb 包**和**完整源码**，欢迎二次开发。

## 功能

- **快速设置开关**：GNOME 面板里的「AirDrop 接收」开关，一键启停接收，副标题实时显示就绪状态（`已停止` / `启动中…` / `已就绪 → ~/下载` / `正在停止…`），开启时自动染蓝；
- **自动接收**：打开开关即自动接受 iPhone 发来的文件，默认保存到 `~/Downloads`，无需盯终端；
- **图形界面**：`Owly AirDrop` 应用可修改保存目录、切换弹窗确认、选择文件并搜索附近设备投送（20 秒超时）；
- **开关与 GUI 协作**：开关运行时 GUI 自动进入"仅设置"模式，不抢端口；改目录自动重启开关的接收端；
- **自定义图标**：应用与状态栏统一使用 AirDrop 风格图标；
- **进程自清理**：关闭开关或 GUI 窗口自动归还无线网卡、恢复 Wi-Fi。

## 系统要求

- Ubuntu 24.04（GNOME Shell 46；其他版本未测试）
- 受支持的无线网卡（Intel AX210/AX200/AX201/AX211 等 `iwlwifi`，或 MediaTek MT7925、Realtek RTL8852CE 等，详见 `owly/hardware/`）
- Intel 网卡为 exclusive 模式：**接收期间 Wi-Fi 会断开**，停止后自动恢复；如需边上网边接收，请加一块受支持的 USB 网卡
- iPhone 端 AirDrop 需设为「所有人，10 分钟」

## 安装

```bash
sudo apt install ./owly-airdrop-ubuntu_0.1.0_amd64.deb
```

启用快速设置开关（一次性）：

```bash
gnome-extensions enable owly-airdrop@hyper-jiawei.github.com
```

然后**注销重登**，或按 `Alt+F2` 输入 `r` 回车重启 Shell。之后右上角快速设置面板底部出现「AirDrop 接收」开关。

## 使用

1. 打开面板开关 → 副标题变为 `已就绪 → ~/下载` 后，iPhone（AirDrop 设为「所有人，10 分钟」）即可搜到本电脑并直接发送，**自动接受**；
2. 关闭开关 → 自动归还网卡、恢复 Wi-Fi；
3. 需要改目录或发文件：点开关右侧 `>` 箭头，菜单里有「打开 Owly AirDrop 设置…」「发送文件…」；
4. 纯命令行也可用：`owly-ctl start|stop|status`、`owly doctor`、`owly radio up`、`owly receive --dir ~/Downloads --accept`。

更多排查与硬件说明见 [docs/使用说明.md](docs/使用说明.md)。

## 从源码构建 deb

```bash
./build-deb.sh
# 产物：dist/owly-airdrop-ubuntu_0.1.0_amd64.deb
```

- 有 `cargo`（Rust ≥ 1.88）时自动从 `owly/` 源码编译 `owly` 与 `owlyd`；
- 没有 cargo 时回退使用系统已安装的 owly 二进制。

## 二次开发

```
owly-airdrop-ubuntu/
├── owly/                      # 原仓库完整源码（t4t5/owly，MIT）
│   ├── crates/                # Rust 工作区：owlyd / owly-cli / owly-radio / owly-awdl / owly-airdrop
│   └── packaging/             # systemd / D-Bus / polkit / NetworkManager 配置
├── src/
│   ├── owly-gui.py            # GTK3 图形界面（收发、设置、单实例、退出清理）
│   ├── owly-ctl.py            # 无头控制器：start/stop/status（ready/starting/external/stopped）
│   ├── extension/             # GNOME Shell 46 快速设置扩展（QuickMenuToggle + SystemIndicator）
│   ├── icons/                 # 应用图标与状态栏符号图标（SVG）
│   └── owly-airdrop.desktop   # 桌面启动项
├── packaging/debian/          # control / postinst / prerm / postrm
├── docs/使用说明.md
└── build-deb.sh               # 一键打包
```

- **GUI / 控制器**：纯 Python（PyGObject），改完直接 `python3 src/owly-gui.py` 运行调试；
- **扩展**：改 `src/extension/*/extension.js` 后，安装到 `~/.local/share/gnome-shell/extensions/` 并重启 Shell（`Alt+F2` → `r`）生效；
- **Rust 底层**：参考 `owly/README.md` 与 `owly/docs/`，`cargo build --release --locked -p owlyd -p owly-cli`；
- 日志：`~/.local/state/owly-gui.log`、`journalctl -u owlyd -f`。

## 致谢与许可

- 无线协议与守护进程：[t4t5/owly](https://github.com/t4t5/owly)（MIT，Copyright (c) 2026 T4T5）
- Ubuntu 桌面组件（GUI / 控制器 / 扩展 / 图标 / 打包）：Hyper-jiawei

整体以 [MIT](LICENSE) 发布，可自由修改与再分发，保留版权声明即可。
