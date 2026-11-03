/* Owly AirDrop 快速设置开关（GNOME 46，ESM）
 *
 * 开关开启 → 运行 owly-ctl start（radio + 接收端，自动接受）
 * 开关关闭 → 运行 owly-ctl stop（归还 radio、恢复 Wi-Fi）
 * 副标题显示实时就绪状态：已停止 / 启动中… / 已就绪 → 目录 / 正在停止…
 * 菜单里可以打开图形工具做设置或发送文件。
 */

import Gio from 'gi://Gio';
import GLib from 'gi://GLib';
import GObject from 'gi://GObject';

import {Extension} from 'resource:///org/gnome/shell/extensions/extension.js';
import * as Main from 'resource:///org/gnome/shell/ui/main.js';
import * as PopupMenu from 'resource:///org/gnome/shell/ui/popupMenu.js';
import {QuickMenuToggle, SystemIndicator} from 'resource:///org/gnome/shell/ui/quickSettings.js';

const CTL = '/usr/bin/owly-ctl';
const GUI = '/usr/bin/owly-gui';

function spawn(argv) {
    try {
        const proc = Gio.Subprocess.new(
            argv,
            Gio.SubprocessFlags.STDOUT_PIPE | Gio.SubprocessFlags.STDERR_PIPE);
        proc.communicate_utf8_async(null, null, (p, res) => {
            try {
                p.communicate_utf8_finish(res);
            } catch (e) {
                logError(e);
            }
        });
    } catch (e) {
        logError(e);
    }
}

function parseState(out) {
    const m = out.match(/^state: (\w+)/m);
    return m ? m[1] : 'unknown';
}

function parseDir(out) {
    const m = out.match(/^dir: (.+)$/m);
    return m ? m[1].trim() : '';
}

const AirDropToggle = GObject.registerClass(
class AirDropToggle extends QuickMenuToggle {
    _init() {
        super._init({
            title: 'AirDrop 接收',
            subtitle: '已停止',
            iconName: 'owly-airdrop-symbolic',
            toggleMode: true,
        });

        this._dead = false;
        this._watching = false;
        this._watchToken = 0;
        this._watcher = 0;

        this.menu.setHeader('owly-airdrop-symbolic', 'AirDrop 接收', 'iPhone ⇄ 电脑互传');

        const settingsItem = new PopupMenu.PopupMenuItem('打开 Owly AirDrop 设置…');
        settingsItem.connect('activate', () => spawn([GUI]));
        this.menu.addMenuItem(settingsItem);

        const sendItem = new PopupMenu.PopupMenuItem('发送文件…');
        sendItem.connect('activate', () => spawn([GUI, '--send']));
        this.menu.addMenuItem(sendItem);

        this.connect('clicked', () => this._onClicked());
    }

    destroy() {
        this._dead = true;
        this._watching = false;
        if (this._watcher) {
            GLib.source_remove(this._watcher);
            this._watcher = 0;
        }
        super.destroy();
    }

    _onClicked() {
        const target = this.checked;
        this._watchToken += 1;
        this._watching = true;
        this.subtitle = target ? '启动中…' : '正在停止…';
        spawn([CTL, target ? 'start' : 'stop']);
        this._watch(target, 0, this._watchToken);
    }

    _watch(target, attempt, token) {
        if (this._dead || token !== this._watchToken)
            return;
        this._watcher = GLib.timeout_add(GLib.PRIORITY_DEFAULT, 1000, () => {
            this._watcher = 0;
            if (this._dead || token !== this._watchToken)
                return GLib.SOURCE_REMOVE;
            this._status(out => {
                if (this._dead || token !== this._watchToken)
                    return;
                const state = parseState(out);
                if (target) {
                    if (state === 'ready' || state === 'external') {
                        this._watching = false;
                        this._apply(state, parseDir(out));
                    } else if (state === 'stopped' && attempt >= 3) {
                        this._watching = false;
                        this.checked = false;
                        this.subtitle = '启动失败';
                    } else if (attempt >= 20) {
                        this._watching = false;
                        this.refresh();
                    } else {
                        this._watch(target, attempt + 1, token);
                    }
                } else {
                    if (state === 'stopped') {
                        this._watching = false;
                        this._apply(state, parseDir(out));
                    } else if (attempt >= 20) {
                        this._watching = false;
                        this.refresh();
                    } else {
                        this._watch(target, attempt + 1, token);
                    }
                }
            });
            return GLib.SOURCE_REMOVE;
        });
    }

    _shortDir(dir) {
        const home = GLib.get_home_dir();
        if (dir.startsWith(home))
            return '~' + dir.slice(home.length);
        return dir;
    }

    _apply(state, dir) {
        if (state === 'ready') {
            this.checked = true;
            this.subtitle = dir ? `已就绪 → ${this._shortDir(dir)}` : '已就绪';
        } else if (state === 'external') {
            this.checked = true;
            this.subtitle = '由图形窗口管理';
        } else if (state === 'starting') {
            this.checked = true;
            this.subtitle = '启动中…';
        } else {
            this.checked = false;
            this.subtitle = '已停止';
        }
    }

    _status(callback) {
        try {
            const proc = Gio.Subprocess.new(
                [CTL, 'status'],
                Gio.SubprocessFlags.STDOUT_PIPE | Gio.SubprocessFlags.STDERR_PIPE);
            proc.communicate_utf8_async(null, null, (p, res) => {
                try {
                    const [, out] = p.communicate_utf8_finish(res);
                    callback(out);
                } catch (e) {
                    logError(e);
                }
            });
        } catch (e) {
            logError(e);
        }
    }

    refresh() {
        this._status(out => {
            if (this._dead)
                return;
            this._apply(parseState(out), parseDir(out));
        });
    }
});

export default class OwlyQuickToggle extends Extension {
    enable() {
        this._indicator = new SystemIndicator();
        this._toggle = new AirDropToggle();
        this._indicator.quickSettingsItems.push(this._toggle);
        Main.panel.statusArea.quickSettings.addExternalIndicator(this._indicator);

        this._toggle.refresh();
        this._timer = GLib.timeout_add_seconds(GLib.PRIORITY_DEFAULT, 10, () => {
            if (this._toggle && !this._toggle._watching)
                this._toggle.refresh();
            return GLib.SOURCE_CONTINUE;
        });
    }

    disable() {
        if (this._timer) {
            GLib.source_remove(this._timer);
            this._timer = 0;
        }
        if (this._toggle) {
            this._toggle.destroy();
            this._toggle = null;
        }
        if (this._indicator) {
            this._indicator.destroy();
            this._indicator = null;
        }
    }
}
