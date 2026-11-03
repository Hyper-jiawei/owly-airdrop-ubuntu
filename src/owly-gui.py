#!/usr/bin/env python3
"""Owly AirDrop 图形界面（本机终极版）

功能：
- 启动后自动进入接收模式（自动接受，保存到指定目录）
- 可选接收目录、可选弹窗确认
- 发送：选择文件 -> 搜索附近设备（20 秒）-> 点击设备投送（20 秒超时）
- 自动管理 radio（退出时归还 Wi-Fi）

用法：
    ./owly-gui.py                 # 完整模式
    ./owly-gui.py --no-radio      # 不启动 radio（调试用）
    ./owly-gui.py --dir ~/下载    # 指定初始目录
"""

import argparse
import json
import os
import queue
import re
import signal
import subprocess
import sys
import threading
import time
from pathlib import Path

import gi

gi.require_version("Gtk", "3.0")
from gi.repository import Gtk, GLib, Gdk

APP_NAME = "Owly AirDrop"
AWDL_IFACE = "awdl0"
BROWSE_SECONDS = 20
SEND_SECONDS = 20
CONFIRM_TIMEOUT_MS = 14000  # owly receive 自身 15 秒超时，留 1 秒余量
CONFIG_PATH = Path.home() / ".config" / "owly-gui" / "config.json"
LOG_FILE = Path.home() / ".local" / "state" / "owly-gui.log"
DEFAULT_DIR = str(Path.home() / "Downloads")
CTL_PATH = Path(__file__).resolve().parent / "owly-ctl.py"

_run_dir = Path(f"/run/user/{os.getuid()}")
LOCK_PATH = _run_dir / "owly-gui.lock" if _run_dir.is_dir() else Path.home() / ".local" / "state" / "owly-gui.lock"


def acquire_lock() -> bool:
    try:
        if LOCK_PATH.exists():
            try:
                pid = int(LOCK_PATH.read_text(encoding="utf-8").strip() or "0")
                os.kill(pid, 0)
                return False
            except (ValueError, ProcessLookupError):
                pass
            except PermissionError:
                return False
            LOCK_PATH.unlink(missing_ok=True)
        LOCK_PATH.write_text(str(os.getpid()), encoding="utf-8")
        return True
    except Exception:
        return True


def release_lock() -> None:
    try:
        if LOCK_PATH.exists() and LOCK_PATH.read_text(encoding="utf-8").strip() == str(os.getpid()):
            LOCK_PATH.unlink(missing_ok=True)
    except Exception:
        pass

DEV_LINE = re.compile(r'^\s*(\S+)\s+"((?:[^"\\]|\\.)*)"\s*\((\S+)\)\s*$')


def unescape(s: str) -> str:
    out = []
    i = 0
    while i < len(s):
        if s[i] == "\\" and i + 1 < len(s):
            out.append(s[i + 1])
            i += 2
        else:
            out.append(s[i])
            i += 1
    return "".join(out)


def notify(summary: str, body: str = "", urgency: str = "normal") -> None:
    try:
        subprocess.run(
            ["notify-send", "-a", APP_NAME, "-u", urgency,
             "-i", "owly-airdrop", summary, body],
            check=False, timeout=5,
        )
    except Exception:
        pass


def awdl_up() -> bool:
    try:
        return subprocess.run(
            ["ip", "link", "show", AWDL_IFACE],
            capture_output=True, check=False, timeout=3,
        ).returncode == 0
    except Exception:
        return False


def ctl_state() -> str:
    """返回快速设置开关控制器的状态：ready|starting|external|stopped|unknown"""
    try:
        out = subprocess.run(
            ["python3", str(CTL_PATH), "status"],
            capture_output=True, text=True, check=False, timeout=5,
        ).stdout
        m = re.search(r"^state: (\w+)$", out, re.M)
        return m.group(1) if m else "unknown"
    except Exception:
        return "unknown"


class Config:
    def __init__(self, path: Path = CONFIG_PATH):
        self.path = path
        self.dir = DEFAULT_DIR
        self.confirm = False
        self.load()

    def load(self) -> None:
        try:
            data = json.loads(self.path.read_text(encoding="utf-8"))
            self.dir = str(data.get("dir", DEFAULT_DIR))
            self.confirm = bool(data.get("confirm", False))
        except Exception:
            pass
        if not self.dir:
            self.dir = DEFAULT_DIR

    def save(self) -> None:
        try:
            self.path.parent.mkdir(parents=True, exist_ok=True)
            self.path.write_text(
                json.dumps({"dir": self.dir, "confirm": self.confirm},
                           ensure_ascii=False, indent=2),
                encoding="utf-8",
            )
        except Exception:
            pass


class OwlyApp:
    def __init__(self, no_radio: bool = False, initial_dir: str | None = None):
        self.q: queue.Queue = queue.Queue()
        self.radio_proc: subprocess.Popen | None = None
        self.recv_proc: subprocess.Popen | None = None
        self.no_radio = no_radio
        self.quitting = False
        self.radio_attempts = 0
        self.radio_starting = False
        self.browse_running = False
        self.browse_proc = None
        self.send_running = False
        self.device_rows: list[Gtk.ListBoxRow] = []

        self.config = Config()
        if initial_dir:
            self.config.dir = initial_dir
        self.recv_ready = False
        self.ctl_managed = False

        self._build_ui()
        self._load_dir_entry()
        GLib.timeout_add(150, self._drain_queue)
        GLib.timeout_add(600, self._startup)

    # ---------- UI ----------

    def _build_ui(self) -> None:
        self.win = Gtk.Window(title=APP_NAME)
        self.win.set_default_size(760, 560)
        self.win.set_icon_name("owly-airdrop")
        self.win.connect("delete-event", self._on_close)

        hb = Gtk.HeaderBar()
        hb.set_show_close_button(True)
        hb.set_title(APP_NAME)
        self.header_subtitle = Gtk.Label(label="正在启动…")
        self.header_subtitle.get_style_context().add_class("dim-label")
        hb.set_custom_title(self.header_subtitle)
        self.win.set_titlebar(hb)

        self.notebook = Gtk.Notebook()
        self.win.add(self.notebook)

        outer = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=0)
        self.notebook.append_page(outer, Gtk.Label(label="  接收  "))
        outer.pack_start(self._build_receive_page(), True, True, 0)

        self.notebook.append_page(self._build_send_page(), Gtk.Label(label="  发送  "))

        self.log_view = Gtk.TextView()
        self.log_view.set_editable(False)
        self.log_view.set_cursor_visible(False)
        self.log_view.set_wrap_mode(Gtk.WrapMode.WORD_CHAR)
        log_sw = Gtk.ScrolledWindow()
        log_sw.set_policy(Gtk.PolicyType.AUTOMATIC, Gtk.PolicyType.AUTOMATIC)
        log_sw.add(self.log_view)
        log_sw.set_size_request(-1, 150)
        outer.pack_start(log_sw, False, False, 0)

        self.win.show_all()

    def _build_receive_page(self) -> Gtk.Box:
        page = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=8)
        page.set_margin_top(12)
        page.set_margin_start(12)
        page.set_margin_end(12)

        grid = Gtk.Grid()
        grid.set_column_spacing(8)
        grid.set_row_spacing(8)
        page.pack_start(grid, False, False, 0)

        grid.attach(Gtk.Label(label="保存目录：", xalign=0), 0, 0, 1, 1)
        self.dir_entry = Gtk.Entry()
        self.dir_entry.set_hexpand(True)
        grid.attach(self.dir_entry, 1, 0, 1, 1)
        self.dir_btn = Gtk.Button(label="选择目录…")
        self.dir_btn.connect("clicked", self._choose_dir)
        grid.attach(self.dir_btn, 2, 0, 1, 1)

        self.confirm_check = Gtk.CheckButton(label="收到请求时弹窗确认（默认自动接受）")
        self.confirm_check.set_active(self.config.confirm)
        self.confirm_check.connect("toggled", self._on_confirm_toggled)
        grid.attach(self.confirm_check, 1, 1, 2, 1)

        self.recv_status = Gtk.Label(xalign=0)
        self.recv_status.set_markup('<span color="#888888">等待启动…</span>')
        page.pack_start(self.recv_status, False, False, 0)

        hint = Gtk.Label(
            xalign=0,
            label="提示：iPhone 端请把 AirDrop 设为「所有人，10 分钟」。"
                  "Intel 网卡为 exclusive 模式，接收期间 Wi-Fi 会断开，退出后自动恢复。",
        )
        hint.set_line_wrap(True)
        hint.get_style_context().add_class("dim-label")
        page.pack_start(hint, False, False, 0)

        return page

    def _build_send_page(self) -> Gtk.Box:
        page = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=8)
        page.set_margin_top(12)
        page.set_margin_start(12)
        page.set_margin_end(12)

        grid = Gtk.Grid()
        grid.set_column_spacing(8)
        grid.set_row_spacing(8)
        page.pack_start(grid, False, False, 0)

        grid.attach(Gtk.Label(label="文件：", xalign=0), 0, 0, 1, 1)
        self.file_entry = Gtk.Entry()
        self.file_entry.set_hexpand(True)
        grid.attach(self.file_entry, 1, 0, 1, 1)
        self.file_btn = Gtk.Button(label="选择文件…")
        self.file_btn.connect("clicked", self._choose_file)
        grid.attach(self.file_btn, 2, 0, 1, 1)

        bar = Gtk.Box(spacing=8)
        page.pack_start(bar, False, False, 0)
        self.browse_btn = Gtk.Button(label=f"搜索设备（{BROWSE_SECONDS} 秒）")
        self.browse_btn.connect("clicked", self._on_browse)
        bar.pack_start(self.browse_btn, False, False, 0)
        self.browse_spinner = Gtk.Spinner()
        bar.pack_start(self.browse_spinner, False, False, 0)

        self.send_status = Gtk.Label(xalign=0)
        self.send_status.set_markup('<span color="#888888">未搜索</span>')
        bar.pack_start(self.send_status, False, False, 0)

        self.device_list = Gtk.ListBox()
        self.device_list.set_selection_mode(Gtk.SelectionMode.NONE)
        self.device_list.connect("row-activated", self._on_row_activated)
        self.device_list.set_placeholder(
            Gtk.Label(label="搜索后，附近可投送的设备会显示在这里，点击设备即可发送"))
        dev_sw = Gtk.ScrolledWindow()
        dev_sw.set_policy(Gtk.PolicyType.AUTOMATIC, Gtk.PolicyType.AUTOMATIC)
        dev_sw.add(self.device_list)
        dev_sw.set_vexpand(True)
        page.pack_start(dev_sw, True, True, 0)

        return page

    def _log(self, text: str) -> None:
        line = f"[{time.strftime('%H:%M:%S')}] {text}\n"
        buf = self.log_view.get_buffer()
        buf.insert(buf.get_end_iter(), line, -1)
        buf.place_cursor(buf.get_end_iter())
        self.log_view.scroll_to_iter(buf.get_end_iter(), 0.0, False, 0, 0)
        try:
            LOG_FILE.parent.mkdir(parents=True, exist_ok=True)
            with LOG_FILE.open("a", encoding="utf-8") as f:
                f.write(line)
        except Exception:
            pass

    def _set_header(self, text: str) -> None:
        self.header_subtitle.set_text(text)

    # ---------- 启动 / 关闭 ----------

    def _startup(self) -> bool:
        self._log("Owly AirDrop 启动")
        state = ctl_state()
        if state in ("ready", "starting", "external"):
            self._enter_ctl_managed_mode()
            return False
        if self.no_radio:
            self._log("--no-radio：跳过 radio 管理")
            self._start_receiver()
        elif awdl_up():
            self._log("检测到 awdl0 已存在，复用当前 radio 会话")
            self._start_receiver()
        else:
            self._start_radio()
        return False

    def _enter_ctl_managed_mode(self) -> None:
        """快速设置开关（或其他接收端）正在管理接收，本窗口只做设置和发送。"""
        self.ctl_managed = True
        self._set_header("由快速设置开关管理")
        self._log("检测到接收端已由快速设置开关管理，本窗口仅用于设置与发送")
        self._set_recv_status(
            "接收由快速设置开关管理，本窗口不重复启动接收端。"
            "修改保存目录后会自动重启开关的接收端。", "blue")

    def _start_radio(self) -> None:
        if self.radio_starting or self.quitting:
            return
        self.radio_starting = True
        self.radio_attempts += 1
        self._set_header("正在启动 radio…")
        self._set_recv_status(f"正在启动 radio（第 {self.radio_attempts} 次尝试）…", "orange")
        self._log("启动 owly radio up …")
        try:
            self.radio_proc = subprocess.Popen(
                ["owly", "radio", "up"],
                stdin=subprocess.DEVNULL,
                stdout=subprocess.PIPE,
                stderr=subprocess.STDOUT,
                text=True,
                bufsize=1,
                errors="replace",
            )
        except FileNotFoundError:
            self._set_recv_status("找不到 owly 命令，请确认已安装", "red")
            self.radio_starting = False
            return
        threading.Thread(target=self._pump_radio, daemon=True).start()
        GLib.timeout_add(300, self._poll_awdl)

    def _poll_awdl(self) -> bool:
        if self.quitting:
            self.radio_starting = False
            return False
        if awdl_up():
            self.radio_starting = False
            self.radio_attempts = 0
            self._set_header("radio 已就绪，启动接收端…")
            self._set_recv_status(
                "radio 已启动 · Wi-Fi 已断开（exclusive 模式），退出后恢复", "orange")
            self._log("radio 已就绪（awdl0）")
            self._start_receiver()
            return False
        if self.radio_proc and self.radio_proc.poll() is not None:
            self.radio_starting = False
            self._log("radio 启动失败，2 秒后重试…")
            if self.radio_attempts < 3 and not self.quitting:
                GLib.timeout_add(2000, self._start_radio_retry)
            else:
                self._set_recv_status("radio 启动失败，请查看日志", "red")
                self._show_error("radio 启动失败",
                                 "owly radio up 未能启动。\n"
                                 "请确认 owly 已安装、owlyd 正在运行（systemctl status owlyd），\n"
                                 "并运行 owly doctor 检查网卡状态。")
            return False
        return True

    def _start_radio_retry(self) -> bool:
        self._start_radio()
        return False

    def _start_receiver(self) -> None:
        if self.quitting or self.ctl_managed:
            return
        if self.recv_proc and self.recv_proc.poll() is None:
            return
        self.recv_ready = False
        directory = self.dir_entry.get_text().strip() or DEFAULT_DIR
        Path(directory).mkdir(parents=True, exist_ok=True)
        self.config.dir = directory
        self.config.save()
        cmd = ["owly", "receive", "--dir", directory]
        if not self.confirm_check.get_active():
            cmd.append("--accept")
        self._log(f"启动接收端: {' '.join(cmd)}")
        try:
            self.recv_proc = subprocess.Popen(
                cmd,
                stdin=subprocess.PIPE,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                text=True,
                bufsize=1,
                errors="replace",
            )
        except FileNotFoundError:
            self._set_recv_status("找不到 owly 命令", "red")
            return
        threading.Thread(target=self._pump_receiver, daemon=True).start()
        mode = "自动接受" if not self.confirm_check.get_active() else "弹窗确认"
        self._set_recv_status(f"接收端启动中（{mode}）…", "orange")

    def _restart_receiver(self) -> None:
        if self.ctl_managed:
            self._restart_ctl()
            return
        old = self.recv_proc
        self.recv_proc = None
        if old and old.poll() is None:
            try:
                old.send_signal(signal.SIGINT)
            except Exception:
                pass
            GLib.timeout_add(100, self._wait_old_receiver, old, [50])
        else:
            self._start_receiver()

    def _restart_ctl(self) -> None:
        """由开关管理时，改目录后重启开关的接收端（stop && start，脱离本窗口运行）。"""
        self._log("目录已改，重启快速设置开关的接收端…")
        self._set_recv_status("正在重启开关的接收端…", "orange")
        cmd = f"python3 {CTL_PATH} stop && python3 {CTL_PATH} start"
        try:
            subprocess.Popen(
                ["/bin/sh", "-c", cmd],
                stdin=subprocess.DEVNULL,
                stdout=subprocess.DEVNULL,
                stderr=subprocess.DEVNULL,
                start_new_session=True,
            )
        except Exception as e:
            self._log(f"重启开关接收端失败: {e}")
            self._set_recv_status("重启开关接收端失败，请查看日志", "red")
            return
        GLib.timeout_add(4000, self._after_ctl_restart)

    def _after_ctl_restart(self) -> bool:
        self._set_recv_status(
            "接收由快速设置开关管理（目录已更新，接收端已重启）", "blue")
        return False

    def _wait_old_receiver(self, proc: subprocess.Popen, left: list) -> bool:
        if proc.poll() is None:
            left[0] -= 1
            if left[0] > 0:
                return True
            try:
                proc.kill()
                proc.wait(timeout=2)
            except Exception:
                pass
            self._log("旧接收端未在 5 秒内退出，已强制结束")
        self._start_receiver()
        return False

    def _on_confirm_toggled(self, check: Gtk.CheckButton) -> None:
        self.config.confirm = check.get_active()
        self.config.save()
        if self.ctl_managed:
            self._log("弹窗确认设置已保存（由快速设置开关管理时始终自动接受，此设置仅在窗口独立运行时生效）")
            return
        self._log("弹窗确认已" + ("开启" if check.get_active() else "关闭") + "，重启接收端…")
        self._restart_receiver()

    def _on_close(self, *args) -> bool:
        if self.quitting:
            return True
        self.quitting = True
        self._quit_ticks = 0
        self._set_header("正在退出…")
        if self.ctl_managed:
            self._log("由快速设置开关管理，窗口退出不影响接收")
            self.config.save()
            release_lock()
            Gtk.main_quit()
            return False
        self._log("正在退出，归还 radio、恢复 Wi-Fi …")
        for proc in (self.recv_proc, self.radio_proc):
            if proc and proc.poll() is None:
                try:
                    proc.send_signal(signal.SIGINT)
                except Exception:
                    pass
        GLib.timeout_add(150, self._quit_watch)
        return True

    def _quit_watch(self) -> bool:
        self._quit_ticks += 1
        alive = [p for p in (self.recv_proc, self.radio_proc) if p and p.poll() is None]
        if not alive:
            if self.radio_proc is not None:
                self._log("清理完成，Wi-Fi 即将恢复")
            else:
                self._log("清理完成")
            self.config.save()
            release_lock()
            Gtk.main_quit()
            return False
        if self._quit_ticks == 60:
            self._log("部分进程未在 9 秒内退出，强制结束…")
            for p in alive:
                try:
                    p.kill()
                    p.wait(timeout=2)
                except Exception:
                    pass
        if self._quit_ticks > 75:
            self.config.save()
            release_lock()
            Gtk.main_quit()
            return False
        return True

    # ---------- 接收 ----------

    def _choose_dir(self, btn) -> None:
        dlg = Gtk.FileChooserDialog(
            title="选择接收目录",
            transient_for=self.win,
            action=Gtk.FileChooserAction.SELECT_FOLDER,
        )
        dlg.add_button("取消", Gtk.ResponseType.CANCEL)
        dlg.add_button("选择", Gtk.ResponseType.OK)
        current = self.dir_entry.get_text().strip()
        if current and Path(current).is_dir():
            dlg.set_current_folder(current)
        resp = dlg.run()
        if resp == Gtk.ResponseType.OK:
            path = dlg.get_filename()
            if path:
                self.dir_entry.set_text(path)
                self._log(f"接收目录改为：{path}")
                self._restart_receiver()
        dlg.destroy()

    def _load_dir_entry(self) -> None:
        self.dir_entry.set_text(self.config.dir)
        self.confirm_check.set_active(self.config.confirm)

    # ---------- 发送 ----------

    def _choose_file(self, btn) -> None:
        dlg = Gtk.FileChooserDialog(
            title="选择要发送的文件",
            transient_for=self.win,
            action=Gtk.FileChooserAction.OPEN,
        )
        dlg.add_button("取消", Gtk.ResponseType.CANCEL)
        dlg.add_button("选择", Gtk.ResponseType.OK)
        resp = dlg.run()
        if resp == Gtk.ResponseType.OK:
            path = dlg.get_filename()
            if path:
                self.file_entry.set_text(path)
        dlg.destroy()

    def _on_browse(self, btn) -> None:
        if self.browse_running or self.send_running:
            return
        if not awdl_up():
            self._set_send_status("radio 未启动，无法搜索", "red")
            self._show_error("radio 未启动",
                             "请先等待「接收」页状态变为“接收模式运行中”，\n"
                             "再切换到发送页搜索设备。")
            return
        self.browse_running = True
        self.browse_spinner.start()
        self.browse_btn.set_sensitive(False)
        for row in self.device_rows:
            self.device_list.remove(row)
        self.device_rows.clear()
        self._set_send_status(f"正在搜索附近的设备（最长 {BROWSE_SECONDS} 秒）…", "orange")
        self._log(f"owly browse --seconds {BROWSE_SECONDS}")
        try:
            proc = subprocess.Popen(
                ["owly", "browse", "--seconds", str(BROWSE_SECONDS)],
                stdin=subprocess.DEVNULL,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                text=True,
                bufsize=1,
                errors="replace",
            )
        except FileNotFoundError:
            self.browse_running = False
            self.browse_spinner.stop()
            self.browse_btn.set_sensitive(True)
            return
        self.browse_proc = proc
        threading.Thread(target=self._pump_browse, args=(proc,), daemon=True).start()

    def _on_row_activated(self, listbox, row) -> None:
        self._on_device_clicked(row, getattr(row, "device", None))

    def _on_device_clicked(self, btn, device) -> None:
        if device is None:
            return
        if self.send_running:
            self._log("已有发送在进行，忽略本次点击")
            return
        path = self.file_entry.get_text().strip()
        if not path or not Path(path).is_file():
            self._set_send_status("请先选择要发送的文件", "red")
            return
        if self.browse_running:
            self._log("已点击设备，结束搜索并发送…")
            self.browse_running = False
            self.browse_spinner.stop()
            self.browse_btn.set_sensitive(True)
            if self.browse_proc and self.browse_proc.poll() is None:
                try:
                    self.browse_proc.terminate()
                except Exception:
                    pass
            self.browse_proc = None
        name = device["name"]
        self._log(f"点击设备：{name}")
        self.send_running = True
        for row in self.device_rows:
            row.set_sensitive(False)
        self._set_send_status(f"正在发送到 {name} …（最长 {SEND_SECONDS} 秒）", "orange")
        self._log(f"owly send --to {name!r} --seconds {SEND_SECONDS} {path}")
        try:
            proc = subprocess.Popen(
                ["owly", "send", "--to", name, "--seconds", str(SEND_SECONDS), path],
                stdin=subprocess.DEVNULL,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                text=True,
                bufsize=1,
                errors="replace",
            )
        except FileNotFoundError:
            self.send_running = False
            self._reset_device_rows()
            return
        threading.Thread(target=self._pump_send, args=(proc, name), daemon=True).start()

    def _reset_device_rows(self) -> None:
        for row in self.device_rows:
            row.set_sensitive(True)

    # ---------- 子进程输出 ----------

    def _pump_radio(self) -> None:
        assert self.radio_proc and self.radio_proc.stdout
        for line in self.radio_proc.stdout:
            self.q.put(("log", f"radio: {line.rstrip()}"))
        self.q.put(("radio_exit", self.radio_proc.returncode))

    def _pump_receiver(self) -> None:
        proc = self.recv_proc
        assert proc and proc.stdout and proc.stderr
        pending: list[str] = []
        err_buf = ""
        try:
            while True:
                import select as _select
                readable, _, _ = _select.select([proc.stdout, proc.stderr], [], [], 0.3)
                for fd in readable:
                    try:
                        raw = os.read(fd.fileno(), 4096)
                    except Exception:
                        raw = b""
                    if not raw:
                        self.q.put(("recv_exit", proc.returncode))
                        return
                    text = raw.decode("utf-8", errors="replace")
                    if fd is proc.stdout:
                        out_buf = text
                        for line in out_buf.split("\n"):
                            line = line.strip()
                            if line:
                                self.q.put(("saved", line))
                    else:
                        err_buf += text
                        while "\n" in err_buf:
                            line, err_buf = err_buf.split("\n", 1)
                            line = line.rstrip()
                            if not line:
                                continue
                            self.q.put(("log", f"receive: {line}"))
                            if "receiving as" in line:
                                self.q.put(("recv_ready", line))
                            if "wants to send" in line or line.startswith("  "):
                                pending.append(line)
                        if "accept? [y/N]" in err_buf:
                            err_buf = ""
                            self.q.put(("prompt", "\n".join(pending[-8:]).strip()))
                            pending.clear()
        except Exception:
            self.q.put(("recv_exit", proc.returncode if proc.poll() is not None else -1))

    def _pump_browse(self, proc: subprocess.Popen) -> None:
        assert proc.stdout and proc.stderr
        threads = []
        def read_stdout():
            for line in proc.stdout:
                line = line.rstrip()
                if not line:
                    continue
                m = DEV_LINE.match(line)
                if m:
                    self.q.put(("dev", {"instance": m.group(1),
                                        "name": unescape(m.group(2)),
                                        "addr": m.group(3)}))
                else:
                    self.q.put(("log", f"browse: {line}"))
        def read_stderr():
            for line in proc.stderr:
                line = line.rstrip()
                if line:
                    self.q.put(("log", f"browse: {line}"))
        t1 = threading.Thread(target=read_stdout, daemon=True)
        t2 = threading.Thread(target=read_stderr, daemon=True)
        t1.start(); t2.start()
        t1.join(); t2.join()
        proc.wait()
        self.q.put(("browse_done", proc.returncode))

    def _pump_send(self, proc: subprocess.Popen, name: str) -> None:
        assert proc.stdout and proc.stderr
        threads = []
        def read_stdout():
            for line in proc.stdout:
                self.q.put(("send_result", (name, line.strip())))
        def read_stderr():
            for line in proc.stderr:
                line = line.rstrip()
                if line:
                    self.q.put(("log", f"send: {line}"))
        t1 = threading.Thread(target=read_stdout, daemon=True)
        t2 = threading.Thread(target=read_stderr, daemon=True)
        t1.start(); t2.start()
        t1.join(); t2.join()
        proc.wait()
        self.q.put(("send_done", name))

    # ---------- 主循环事件 ----------

    def _drain_queue(self) -> bool:
        if self.quitting:
            return False
        try:
            while True:
                kind, payload = self.q.get_nowait()
                self._handle_event(kind, payload)
        except queue.Empty:
            pass
        return True

    def _handle_event(self, kind: str, payload) -> None:
        if kind == "log":
            self._log(payload)
        elif kind == "radio_exit":
            if not self.quitting and not self.radio_starting:
                self._set_recv_status("radio 已停止", "red")
                self._log(f"radio 进程退出（code={payload}），2 秒后重试…")
                GLib.timeout_add(2000, self._start_radio_retry)
        elif kind == "recv_exit":
            if not self.quitting:
                if self.recv_ready:
                    self._set_recv_status("接收端已停止", "red")
                    self._set_header("接收端已停止")
                else:
                    self._set_recv_status(
                        "接收端启动失败（端口 8771 可能被占用），请查看日志", "red")
                    self._set_header("接收端启动失败")
                    self._show_error("接收端启动失败",
                                     "owly receive 未能开始监听。\n"
                                     "常见原因：上一个接收端还没退出，8771 端口被占用。\n"
                                     "请查看底部日志，或退出本工具后重开。")
                self._log("接收端进程退出")
        elif kind == "recv_ready":
            self.recv_ready = True
            mode = "自动接受" if not self.confirm_check.get_active() else "弹窗确认"
            directory = self.dir_entry.get_text().strip() or DEFAULT_DIR
            self._set_recv_status(f"接收模式运行中（{mode}）→ {directory}", "green")
            self._set_header("接收模式运行中")
            notify("Owly 正在接收", f"保存目录：{directory}\niPhone 请选「所有人，10 分钟」")
        elif kind == "saved":
            self._log(f"已接收：{payload}")
            notify("已接收文件", str(payload))
        elif kind == "prompt":
            self._on_receive_prompt(payload)
        elif kind == "dev":
            self._add_device_row(payload)
        elif kind == "browse_done":
            self.browse_running = False
            self.browse_proc = None
            self.browse_spinner.stop()
            self.browse_btn.set_sensitive(True)
            if self.send_running:
                return
            count = len(self.device_rows)
            if count:
                self._set_send_status(f"搜索完成：找到 {count} 个设备，点击设备发送", "green")
            else:
                self._set_send_status(
                    "未找到设备。确认 iPhone 已解锁且 AirDrop 设为「所有人，10 分钟」，再试一次", "red")
                self._log("browse 结束：未找到设备")
        elif kind == "send_result":
            name, line = payload
            self._log(f"send → {name}: {line}")
            if line.startswith("delivered"):
                self._set_send_status(f"已发送到 {name}", "green")
                notify("发送成功", f"文件已发送到 {name}")
            elif line.startswith("declined"):
                self._set_send_status(f"{name} 拒绝了接收", "red")
                notify("对方已拒绝", name, "critical")
            elif line.startswith("failed"):
                self._set_send_status(f"发送失败：{line}", "red")
                notify("发送失败", line, "critical")
        elif kind == "send_done":
            self.send_running = False
            self._reset_device_rows()

    def _add_device_row(self, dev: dict) -> None:
        name = dev["name"] or dev["instance"]
        row = Gtk.ListBoxRow()
        row.set_activatable(True)
        row.device = dev
        box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=2)
        box.set_margin_top(8)
        box.set_margin_bottom(8)
        box.set_margin_start(8)
        box.set_margin_end(8)
        title = Gtk.Label(xalign=0)
        title.set_markup(f"<b>{GLib.markup_escape_text(name)}</b>")
        box.pack_start(title, False, False, 0)
        sub = Gtk.Label(xalign=0, label=f"{dev['instance']}  {dev['addr']}")
        sub.get_style_context().add_class("dim-label")
        box.pack_start(sub, False, False, 0)
        row.add(box)
        row.show_all()
        self.device_list.add(row)
        self.device_rows.append(row)
        self._log(f"发现设备：{name} ({dev['instance']})")

    def _on_receive_prompt(self, details: str) -> None:
        if not details:
            details = "收到一个 AirDrop 发送请求"
        self._log(f"收到请求：{details}")
        dlg = Gtk.MessageDialog(
            transient_for=self.win,
            modal=True,
            message_type=Gtk.MessageType.QUESTION,
            buttons=Gtk.ButtonsType.YES_NO,
            text="收到 AirDrop 请求，是否接受？",
        )
        dlg.format_secondary_text(details)
        dlg.set_default_response(Gtk.ResponseType.NO)
        dlg.add_button("拒绝", Gtk.ResponseType.NO)
        dlg.add_button("接受", Gtk.ResponseType.YES)
        answered = [False]

        def answer(resp: int) -> None:
            if answered[0]:
                return
            answered[0] = True
            dlg.destroy()
            ans = "y" if resp == Gtk.ResponseType.YES else "n"
            if self.recv_proc and self.recv_proc.stdin:
                try:
                    self.recv_proc.stdin.write(ans + "\n")
                    self.recv_proc.stdin.flush()
                    self._log(f"已应答：{ans}")
                except Exception as e:
                    self._log(f"写入应答失败：{e}")
            if ans == "y":
                notify("已接受", "正在接收文件…")
            else:
                notify("已拒绝", "已拒绝该请求")

        dlg.connect("response", lambda d, r: answer(r))

        def auto_decline() -> bool:
            if not answered[0]:
                answer(Gtk.ResponseType.NO)
            return False

        GLib.timeout_add(CONFIRM_TIMEOUT_MS, auto_decline)
        dlg.show_all()

    # ---------- 工具 ----------

    def _set_recv_status(self, text: str, color: str) -> None:
        self._set_label(self.recv_status, text, color)

    def _set_send_status(self, text: str, color: str) -> None:
        self._set_label(self.send_status, text, color)

    @staticmethod
    def _set_label(label: Gtk.Label, text: str, color: str) -> None:
        label.set_markup(f'<span color="{color}">{GLib.markup_escape_text(text)}</span>')

    def _show_error(self, title: str, text: str) -> None:
        dlg = Gtk.MessageDialog(
            transient_for=self.win,
            modal=True,
            message_type=Gtk.MessageType.ERROR,
            buttons=Gtk.ButtonsType.OK,
            text=title,
        )
        dlg.format_secondary_text(text)
        dlg.connect("response", lambda d, r: d.destroy())
        dlg.show_all()


def main() -> int:
    parser = argparse.ArgumentParser(description=APP_NAME)
    parser.add_argument("--no-radio", action="store_true", help="不管理 radio（调试用）")
    parser.add_argument("--dir", default=None, help="初始接收目录")
    parser.add_argument("--send", action="store_true", help="直接打开发送页")
    args = parser.parse_args()

    if not acquire_lock():
        notify("Owly AirDrop 已经在运行",
               "请切换到已打开的 Owly AirDrop 窗口。\n（重复启动会占用 8771 端口，导致接收失败）",
               "critical")
        return 0

    app = OwlyApp(no_radio=args.no_radio, initial_dir=args.dir)
    if args.send:
        app.notebook.set_current_page(1)

    def on_term(*_):
        try:
            app._on_close()
        except Exception:
            release_lock()
            Gtk.main_quit()

    signal.signal(signal.SIGTERM, on_term)
    Gtk.main()
    return 0


if __name__ == "__main__":
    sys.exit(main())
