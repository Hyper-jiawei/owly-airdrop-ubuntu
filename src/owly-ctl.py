#!/usr/bin/env python3
"""Owly AirDrop 无头控制器（供 GNOME 快速设置开关调用）

用法：
    owly-ctl.py start    启动 radio + 接收端（自动接受，保存到配置目录）
    owly-ctl.py stop     停止接收端并归还 radio
    owly-ctl.py status   打印 state: ready|starting|external|stopped 与 dir:

接收目录读取 ~/.config/owly-gui/config.json 的 dir（与图形工具共用），
缺省为 ~/Downloads。日志写入 ~/.local/state/owly-gui.log。
"""

import argparse
import json
import os
import signal
import subprocess
import sys
import threading
import time
from pathlib import Path

CONFIG_PATH = Path.home() / ".config" / "owly-gui" / "config.json"
LOG_FILE = Path.home() / ".local" / "state" / "owly-gui.log"
DEFAULT_DIR = str(Path.home() / "Downloads")

_run_dir = Path(f"/run/user/{os.getuid()}")
PID_FILE = _run_dir / "owly-ctl.pid" if _run_dir.is_dir() else Path.home() / ".local" / "state" / "owly-ctl.pid"


def log(msg: str) -> None:
    line = f"[{time.strftime('%H:%M:%S')}] ctl: {msg}\n"
    try:
        LOG_FILE.parent.mkdir(parents=True, exist_ok=True)
        with LOG_FILE.open("a", encoding="utf-8") as f:
            f.write(line)
    except Exception:
        pass


def config_dir() -> str:
    try:
        data = json.loads(CONFIG_PATH.read_text(encoding="utf-8"))
        d = str(data.get("dir") or "").strip()
        if d:
            return d
    except Exception:
        pass
    return DEFAULT_DIR


def awdl_up() -> bool:
    try:
        return subprocess.run(
            ["ip", "link", "show", "awdl0"],
            capture_output=True, check=False, timeout=3,
        ).returncode == 0
    except Exception:
        return False


def port_8771_listening() -> bool:
    try:
        out = subprocess.run(
            ["ss", "-ltn"], capture_output=True, text=True, check=False, timeout=3,
        ).stdout
        return ":8771" in out
    except Exception:
        return False


def ctl_pid() -> int | None:
    try:
        pid = int(PID_FILE.read_text(encoding="utf-8").strip())
        os.kill(pid, 0)
        return pid
    except Exception:
        return None


def current_state() -> tuple[str, str]:
    """返回 (state, dir)。

    state 取值：
      ready     控制器运行中且 radio + 接收端都已就绪（可接收）
      starting  控制器运行中但尚未就绪（启动中或停止中的过渡态）
      external  控制器未运行，但 8771 已有监听（图形窗口或其他接收端）
      stopped   完全停止
    """
    d = config_dir()
    if ctl_pid() is not None:
        if awdl_up() and port_8771_listening():
            return ("ready", d)
        return ("starting", d)
    if port_8771_listening():
        return ("external", d)
    return ("stopped", d)


def print_state() -> None:
    s, d = current_state()
    print(f"state: {s}")
    print(f"dir: {d}")


def spawn_logged(cmd: list[str]) -> subprocess.Popen:
    log("+ " + " ".join(cmd))
    return subprocess.Popen(
        cmd,
        stdin=subprocess.DEVNULL,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        text=True,
        bufsize=1,
        errors="replace",
    )


def pump(proc: subprocess.Popen, tag: str, skip_peers: bool = False) -> None:
    def run() -> None:
        assert proc.stdout is not None
        for line in proc.stdout:
            line = line.rstrip()
            if not line:
                continue
            if skip_peers and line.startswith("peers:"):
                continue
            log(f"{tag}: {line}")

    threading.Thread(target=run, daemon=True).start()


def wait_until(pred, timeout: float, stop) -> bool:
    deadline = time.time() + timeout
    while time.time() < deadline and not stop[0]:
        if pred():
            return True
        time.sleep(0.3)
    return pred()


def cleanup(procs, started_radio: bool) -> None:
    for p in procs:
        if p and p.poll() is None:
            try:
                p.send_signal(signal.SIGINT)
            except Exception:
                pass
    for p in procs:
        if p and p.poll() is None:
            try:
                p.wait(timeout=8)
            except Exception:
                try:
                    p.kill()
                except Exception:
                    pass
    if started_radio:
        log("radio 已归还")
    try:
        PID_FILE.unlink(missing_ok=True)
    except Exception:
        pass


def cmd_start() -> int:
    if ctl_pid() is not None:
        print_state()
        return 0
    if port_8771_listening():
        log("8771 已有监听（可能是 Owly AirDrop 窗口），不重复启动")
        print_state()
        return 0

    PID_FILE.write_text(str(os.getpid()), encoding="utf-8")
    stop = [False]

    def on_term(sig, frm):
        stop[0] = True

    signal.signal(signal.SIGTERM, on_term)
    signal.signal(signal.SIGINT, on_term)

    radio = None
    recv = None
    started_radio = False
    try:
        if not awdl_up():
            radio = spawn_logged(["owly", "radio", "up"])
            started_radio = True
            pump(radio, "radio", skip_peers=True)
            if not wait_until(awdl_up, 25.0, stop):
                log("radio 启动超时")
                if radio.poll() is None:
                    radio.terminate()
                return 1
            log("radio 已就绪（awdl0）")

        d = config_dir()
        Path(d).mkdir(parents=True, exist_ok=True)
        recv = spawn_logged(["owly", "receive", "--dir", d, "--accept"])
        pump(recv, "receive")

        deadline = time.time() + 3.0
        while time.time() < deadline and not stop[0]:
            if recv.poll() is not None:
                log(f"接收端启动失败（code={recv.returncode}）")
                return 1
            time.sleep(0.2)
        if stop[0]:
            return 0

        log(f"接收模式运行中 → {d}（自动接受）")
        print("state: ready")
        print(f"dir: {d}")
        sys.stdout.flush()

        procs = [p for p in (radio, recv) if p]
        while not stop[0]:
            time.sleep(0.5)
            if any(p.poll() is not None for p in procs):
                log("子进程意外退出，停止服务")
                break
        return 0
    finally:
        cleanup([recv, radio], started_radio)
        log("已停止")


def cmd_stop() -> int:
    pid = ctl_pid()
    if pid is not None:
        log("收到停止请求")
        try:
            os.kill(pid, signal.SIGTERM)
        except Exception:
            pass
        for _ in range(80):
            try:
                os.kill(pid, 0)
            except ProcessLookupError:
                break
            time.sleep(0.25)
        else:
            try:
                os.kill(pid, signal.SIGKILL)
            except Exception:
                pass
            try:
                PID_FILE.unlink(missing_ok=True)
            except Exception:
                pass
    print("state: stopped")
    return 0


def cmd_status() -> int:
    print_state()
    return 0


def main() -> int:
    parser = argparse.ArgumentParser(description="Owly AirDrop 无头控制器")
    parser.add_argument("cmd", choices=["start", "stop", "status"])
    args = parser.parse_args()
    return {"start": cmd_start, "stop": cmd_stop, "status": cmd_status}[args.cmd]()


if __name__ == "__main__":
    sys.exit(main())
