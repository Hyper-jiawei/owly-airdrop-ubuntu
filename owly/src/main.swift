import Cocoa
import IOKit
import IOKit.pwr_mgt
import IOKit.ps
import SwiftUI

// MARK: - Localization

enum Language: String, CaseIterable {
    case english = "en"
    case chinese = "zh"

    var displayName: String {
        switch self {
        case .english: return "English"
        case .chinese: return "中文"
        }
    }

    var next: Language {
        self == .chinese ? .english : .chinese
    }
}

/// All user-facing strings keyed by `Language`. Every property returns the
/// string for the currently selected language (persisted in UserDefaults).
///
/// Add new strings as static computed properties; keep the en / zh values
/// aligned so nothing falls out of sync.
struct L10n {
    static var current: Language {
        get {
            guard let raw = UserDefaults.standard.string(forKey: "appLanguage"),
                  let lang = Language(rawValue: raw) else { return .chinese }
            return lang
        }
        set { UserDefaults.standard.set(newValue.rawValue, forKey: "appLanguage") }
    }

    // MARK: Mode names

    static var modeOff: String { current == .chinese ? "关闭" : "Off" }
    static var modeIdle: String { current == .chinese ? "熄屏不睡（屏幕照常熄）" : "Prevent Idle Sleep (screen sleeps)" }
    static var modeStrong: String { current == .chinese ? "强力模式（合盖也不睡）" : "Strong Mode (no lid sleep)" }

    static var statusOff: String { current == .chinese ? "当前：关闭" : "Current: Off" }
    static var statusIdle: String { current == .chinese ? "当前：熄屏不睡" : "Current: Prevent Idle Sleep" }
    static var statusStrong: String { current == .chinese ? "当前：强力模式（合盖也不睡）" : "Current: Strong Mode" }

    // MARK: Menu

    static var notAuthorizedSuffix: String { current == .chinese ? " — 未授权" : " — Not Authorized" }
    static var menuAutostart: String { current == .chinese ? "开机自启" : "Launch at Login" }
    static var menuResetAuth: String { current == .chinese ? "撤销强力模式授权…" : "Revoke Strong Mode Authorization…" }
    static var menuAbout: String { current == .chinese ? "关于 / 状态详情…" : "About / Status Details…" }
    static var menuDiagnostics: String { current == .chinese ? "诊断信息…" : "Diagnostics…" }
    static var menuQuit: String { current == .chinese ? "退出" : "Quit" }
    static var menuLanguage: String { current == .chinese ? "Language / 语言" : "Language / 语言" }

    // MARK: Alerts – common

    static var okButton: String { current == .chinese ? "好" : "OK" }
    static var cancel: String { current == .chinese ? "取消" : "Cancel" }

    // MARK: Alerts – strong mode

    static var strongModeAlertTitle: String { current == .chinese ? "启用强力模式（合盖也不睡）" : "Enable Strong Mode (no lid sleep)" }
    static var strongModeAlertInfo: String {
        current == .chinese
            ? """
            强力模式需要一次性管理员授权，之后切换永久免密。

            点击「立即授权」会弹出 macOS 原生的管理员对话框，输入登录密码即可。

            授权范围被严格限制为：
              • pmset -a disablesleep 0
              • pmset -a disablesleep 1

            不会获得其他任何 root 权限。
            """
            : """
            Strong Mode requires a one-time admin authorization; after that, switching is permanently password-free.

            Click "Authorize" to open the native macOS admin dialog — just enter your login password.

            The authorization is strictly limited to:
              • pmset -a disablesleep 0
              • pmset -a disablesleep 1

            No other root privileges are granted.
            """
    }
    static var authorizeButton: String { current == .chinese ? "立即授权…" : "Authorize…" }
    static var installFailedTitle: String { current == .chinese ? "授权安装失败" : "Authorization Failed" }
    static var installFailedMessage: String {
        current == .chinese
            ? """
            请尝试改用命令行：

              cd ~/a-idea/owly
              ./scripts/enable-lid-lock.sh

            技术细节：
            """
            : """
            Try the command line instead:

              cd ~/a-idea/owly
              ./scripts/enable-lid-lock.sh

            Details:
            """
    }

    // MARK: Alerts – reset auth

    static var resetAuthAlertTitle: String { current == .chinese ? "撤销强力模式授权？" : "Revoke Strong Mode Authorization?" }
    static var resetAuthAlertInfo: String {
        current == .chinese
            ? "会删除 /etc/sudoers.d/owly（以及任何遗留的旧版本 sudoers 文件）并把 disablesleep 复位为 0。需要再次输入管理员密码。"
            : "This will remove /etc/sudoers.d/owly (and any legacy sudoers files) and reset disablesleep to 0. Admin password required."
    }
    static var revokeButton: String { current == .chinese ? "撤销授权" : "Revoke" }
    static var revokeFailedTitle: String { current == .chinese ? "撤销失败" : "Revoke Failed" }

    // MARK: Alerts – switch failed

    static var switchFailedTitle: String { current == .chinese ? "切换失败" : "Switch Failed" }
    static var idleSwitchFailed: String { current == .chinese ? "IOKit 拒绝创建电源 assertion。" : "IOKit refused to create power assertion." }
    static var strongSwitchFailed: String { current == .chinese ? "执行 sudo pmset 失败。请检查 sudoers 配置。" : "sudo pmset failed. Check sudoers configuration." }

    // MARK: Alerts – autostart

    static var autostartFailedTitle: String { current == .chinese ? "切换开机自启失败" : "Failed to Toggle Launch at Login" }
    static var autostartEnabledTitle: String { current == .chinese ? "开机自启已启用" : "Launch at Login Enabled" }
    static var autostartEnabledInfo: String {
        current == .chinese
            ? "下次开机或注销重新登录时，App 会自动启动。\n\n当前正在运行的实例不会受影响。"
            : "The app will launch automatically on next login or reboot.\n\nThe currently running instance is unaffected."
    }

    // MARK: About view

    static var aboutTitle: String { "Owly" }
    static var aboutSubtitle: String { current == .chinese ? "菜单栏防睡眠工具" : "Menu Bar Anti-Sleep Tool" }
    static var aboutCurrentMode: String { current == .chinese ? "当前模式" : "Current Mode" }
    static var aboutStrongAuth: String { current == .chinese ? "强力模式授权" : "Strong Mode Authorization" }
    static var authorized: String { current == .chinese ? "已授权" : "Authorized" }
    static var notAuthorized: String { current == .chinese ? "未授权" : "Not Authorized" }
    static var aboutAutostart: String { current == .chinese ? "开机自启" : "Launch at Login" }
    static var configured: String { current == .chinese ? "已配置" : "Configured" }
    static var notConfigured: String { current == .chinese ? "未配置" : "Not Configured" }
    static var modeDescription: String { current == .chinese ? "模式说明" : "Modes" }
    static var modeOffSummary: String { current == .chinese ? "系统按默认电源策略走。" : "System follows default power policy." }
    static var modeIdleTitle: String { current == .chinese ? "熄屏不睡（≈ caffeinate -i）" : "Prevent Idle Sleep (≈ caffeinate -i)" }
    static var modeIdleSummary: String {
        current == .chinese
            ? "屏幕到时间照常熄灭省电，但系统不会因空闲而睡，任务继续跑。合盖仍会触发系统级睡眠。"
            : "Screen sleeps as scheduled, but the system won't idle-sleep — your tasks keep running. Closing the lid still triggers system sleep."
    }
    static var modeStrongTitle: String { current == .chinese ? "强力模式（pmset disablesleep=1）" : "Strong Mode (pmset disablesleep=1)" }
    static var modeStrongSummary: String {
        current == .chinese
            ? "系统级硬开关，连合盖都不睡（强力模式是熄屏不睡的超集）。"
            : "System-level hard switch — prevents sleep even when the lid is closed (superset of Prevent Idle Sleep)."
    }
    static var autoResetNote: String {
        current == .chinese
            ? "App 退出时会自动复位 disablesleep=0，避免遗留状态。"
            : "disablesleep=0 is automatically reset when the app exits, preventing stale state."
    }

    // MARK: Diagnostics view

    static var diagTitle: String { current == .chinese ? "诊断信息" : "Diagnostics" }
    static var diagSubtitle: String { current == .chinese ? "实时读取的 App 与系统状态" : "Real-time App & System State" }
    static var diagCurrentMode: String { current == .chinese ? "当前模式（内存）" : "Current Mode (in memory)" }
    static var diagIOKit: String { "IOKit assertion" }
    static var diagPmset: String { "pmset disablesleep" }
    static var diagSudoers: String { current == .chinese ? "强力模式 sudoers" : "Strong Mode sudoers" }
    static var active: String { "active" }
    static var inactive: String { "inactive" }
    static var noSleep: String { "1 (no sleep)" }
    static var defaultValue: String { "0 (default)" }
    static var sudoersOk: String { "OK (passwordless sudo)" }
    static var sudoersNotActive: String { current == .chinese ? "sudoers 未生效" : "sudoers not active" }
    static var sudoersFix: String {
        current == .chinese
            ? "修复：菜单点击「强力模式」会自动弹出原生授权对话框，或运行命令行脚本 `scripts/enable-lid-lock.sh`"
            : "Fix: Click \"Strong Mode\" in the menu for the native auth dialog, or run `scripts/enable-lid-lock.sh`"
    }
    static var processInfo: String { current == .chinese ? "进程信息" : "Process Info" }
    static var pid: String { "PID" }
    static var bundle: String { "Bundle" }

    // MARK: Unplug alert

    static var unpluggedTitle: String { current == .chinese ? "电源拔了" : "Power Unplugged" }
    static var unpluggedCurrently: String {
        current == .chinese ? "当前是「熄屏不睡」" : "Currently: Prevent Idle Sleep"
    }
    static var unpluggedBody: String {
        current == .chinese
            ? "合盖会触发系统睡眠 — 任务/agent 会被打断。要切到「强力模式」吗？"
            : "Closing the lid will trigger system sleep — tasks/agents will be interrupted. Switch to Strong Mode?"
    }
    static var switchToStrong: String { current == .chinese ? "切到强力模式" : "Switch to Strong Mode" }
    static var keepCurrent: String { current == .chinese ? "保持当前" : "Keep Current" }

    // MARK: RowHealth help

    static var healthOk: String { current == .chinese ? "符合当前模式的预期" : "Matches expected state" }
    static var healthNa: String { current == .chinese ? "当前模式不使用此机制" : "Not used in current mode" }
    static var healthWarn: String { current == .chinese ? "状态与当前模式不一致" : "State inconsistent with current mode" }

    // MARK: Auth prompts (AppleScript dialogs)

    static var sudoersInstallPrompt: String {
        current == .chinese
            ? "Owly 想要启用「强力模式」。\n\n会安装一份 sudoers 规则到 /etc/sudoers.d/owly，只授权以下两条精确命令免密执行（不会获得任何其他 root 权限）：\n\n  pmset -a disablesleep 0\n  pmset -a disablesleep 1"
            : "Owly wants to enable Strong Mode.\n\nA sudoers rule will be installed at /etc/sudoers.d/owly, authorizing only these two exact commands without a password (no other root privileges are granted):\n\n  pmset -a disablesleep 0\n  pmset -a disablesleep 1"
    }
    static var sudoersUninstallPrompt: String {
        current == .chinese
            ? "Owly 想要撤销「强力模式」授权，并把 disablesleep 复位为 0。"
            : "Owly wants to revoke Strong Mode authorization and reset disablesleep to 0."
    }
}

// MARK: - Mode

enum CaffeinateMode: Int {
    case off = 0
    case idle = 1
    case strong = 2

    var menuTitle: String {
        switch self {
        case .off:    return L10n.modeOff
        case .idle:   return L10n.modeIdle
        case .strong: return L10n.modeStrong
        }
    }

    var statusLine: String {
        switch self {
        case .off:    return L10n.statusOff
        case .idle:   return L10n.statusIdle
        case .strong: return L10n.statusStrong
        }
    }

    /// SF Symbol used in the SwiftUI About / Diagnostics dialogs (where
    /// the bigger canvas can comfortably show a generic icon). The menu
    /// bar uses a hand-drawn owl glyph instead — see `MenubarOwl`.
    var iconSymbol: String {
        switch self {
        case .off:    return "moon.zzz.fill"
        case .idle:   return "eye.fill"
        case .strong: return "bolt.fill"
        }
    }
}

// MARK: - Menubar owl glyph

/// Hand-drawn owl head rendered as an alpha-only template image, suitable
/// for an `NSStatusItem` button. Matches the App icon's character: ear
/// tufts, an outline head, and three expressions:
///   - off:    closed eyes (^^) plus a "Z" drifting in the corner
///   - idle:   open eyes (round dots) — Owly on watch
///   - strong: open eyes plus a small starburst around each eye
///
/// The image is `isTemplate = true`, so macOS auto-tints it to match the
/// menu bar theme (white in dark mode, black in light mode).
enum MenubarOwl {
    /// Returns a square template image for the given mode. Default 22pt
    /// matches the menu bar; pass a larger size for in-window rendering
    /// (the geometry scales uniformly).
    static func image(for mode: CaffeinateMode, size: CGFloat = 22) -> NSImage {
        let img = NSImage(size: NSSize(width: size, height: size))
        img.lockFocus()
        defer { img.unlockFocus() }

        // All geometry below is authored in the 22pt design space and
        // then scaled into the target canvas via this affine transform,
        // so call sites can request any pixel size and stroke widths /
        // distances scale together.
        let scale = size / 22
        let xform = NSAffineTransform()
        xform.scaleX(by: scale, yBy: scale)
        xform.concat()

        // Geometry tuned for a 22pt render (design space).
        let cx: CGFloat = 11
        let cy: CGFloat = 11
        let headW: CGFloat = 15
        let headH: CGFloat = 17
        let outlineWidth: CGFloat = 1.4

        NSColor.black.setFill()
        NSColor.black.setStroke()

        // 1. Head outline (stroke-only so the menu bar shows through and
        //    the silhouette doesn't dominate at small sizes).
        let headRect = NSRect(
            x: cx - headW / 2,
            y: cy - headH / 2,
            width: headW,
            height: headH
        )
        let headPath = NSBezierPath(ovalIn: headRect)
        headPath.lineWidth = outlineWidth
        headPath.stroke()

        // 2. Ear tufts (filled triangles, tips poking above the head)
        let earBaseY: CGFloat = cy + headH / 2 - 1.5
        let earTipY: CGFloat = cy + headH / 2 + 1.8
        let earOffset: CGFloat = 4.2
        let earBaseHalf: CGFloat = 1.3
        for sign: CGFloat in [-1, 1] {
            let earCx = cx + sign * earOffset
            let triangle = NSBezierPath()
            triangle.move(to: NSPoint(x: earCx - earBaseHalf, y: earBaseY))
            triangle.line(to: NSPoint(x: earCx + earBaseHalf, y: earBaseY))
            triangle.line(to: NSPoint(x: earCx, y: earTipY))
            triangle.close()
            triangle.fill()
        }

        // 3. Eyes (state-dependent)
        let eyeOffset: CGFloat = 3.4
        let eyeY: CGFloat = cy + 1.2
        let eyeR: CGFloat = 1.5

        switch mode {
        case .off:
            // Closed eyes: two upward arcs ("^^") drawn as round-cap strokes.
            for sign: CGFloat in [-1, 1] {
                let eyeCx = cx + sign * eyeOffset
                let arc = NSBezierPath()
                arc.lineWidth = 1.2
                arc.lineCapStyle = .round
                arc.appendArc(
                    withCenter: NSPoint(x: eyeCx, y: eyeY - 0.2),
                    radius: eyeR + 0.4,
                    startAngle: 25,
                    endAngle: 155
                )
                arc.stroke()
            }
            // Sleeping "Z" in the upper-right corner — three short strokes
            // forming a Z shape. Indicates "off duty". Coordinates are in
            // 22pt design space (top-right corner is (22, 22)).
            let zCx: CGFloat = 22 - 3.3
            let zCy: CGFloat = 22 - 3.3
            let zHalf: CGFloat = 1.7
            let z = NSBezierPath()
            z.lineWidth = 1.0
            z.lineCapStyle = .round
            z.lineJoinStyle = .round
            z.move(to: NSPoint(x: zCx - zHalf, y: zCy + zHalf))
            z.line(to: NSPoint(x: zCx + zHalf, y: zCy + zHalf))
            z.line(to: NSPoint(x: zCx - zHalf, y: zCy - zHalf))
            z.line(to: NSPoint(x: zCx + zHalf, y: zCy - zHalf))
            z.stroke()

        case .idle:
            // Open eyes: two filled dots (the pupils, against the head's
            // empty interior — read as round eyes at 22pt).
            for sign: CGFloat in [-1, 1] {
                let eyeCx = cx + sign * eyeOffset
                NSBezierPath(ovalIn: NSRect(
                    x: eyeCx - eyeR,
                    y: eyeY - eyeR,
                    width: eyeR * 2,
                    height: eyeR * 2
                )).fill()
            }

        case .strong:
            // Open eyes + small starburst around each.
            for sign: CGFloat in [-1, 1] {
                let eyeCx = cx + sign * eyeOffset
                NSBezierPath(ovalIn: NSRect(
                    x: eyeCx - eyeR,
                    y: eyeY - eyeR,
                    width: eyeR * 2,
                    height: eyeR * 2
                )).fill()

                // 3 short outward rays per eye (outer side only)
                let angles: [CGFloat] = sign > 0
                    ? [-35, 5, 45]      // right eye: SE, E-up, NE
                    : [135, 175, 215]   // left eye: NW, W, SW (mirror)
                for deg in angles {
                    let rad = deg * .pi / 180
                    let rayInner: CGFloat = eyeR + 0.5
                    let rayOuter: CGFloat = eyeR + 2.0
                    let dx = cos(rad)
                    let dy = sin(rad)
                    let ray = NSBezierPath()
                    ray.lineWidth = 0.9
                    ray.lineCapStyle = .round
                    ray.move(to: NSPoint(
                        x: eyeCx + dx * rayInner,
                        y: eyeY + dy * rayInner
                    ))
                    ray.line(to: NSPoint(
                        x: eyeCx + dx * rayOuter,
                        y: eyeY + dy * rayOuter
                    ))
                    ray.stroke()
                }
            }
        }

        // 4. Beak (tiny triangle pointing down, between/below the eyes)
        let beakTopY: CGFloat = cy - 2.0
        let beakTipY: CGFloat = beakTopY - 1.6
        let beakHalfW: CGFloat = 0.85
        let beak = NSBezierPath()
        beak.move(to: NSPoint(x: cx - beakHalfW, y: beakTopY))
        beak.line(to: NSPoint(x: cx + beakHalfW, y: beakTopY))
        beak.line(to: NSPoint(x: cx, y: beakTipY))
        beak.close()
        beak.fill()

        img.isTemplate = true
        return img
    }
}

// MARK: - Idle assertion (≈ caffeinate -i)

final class IdleSleepAssertion {
    private var assertionID: IOPMAssertionID = 0
    private(set) var isActive: Bool = false

    @discardableResult
    func enable() -> Bool {
        guard !isActive else { return true }
        let reason = "Owly: prevent idle sleep" as CFString
        let result = IOPMAssertionCreateWithName(
            kIOPMAssertPreventUserIdleSystemSleep as CFString,
            IOPMAssertionLevel(kIOPMAssertionLevelOn),
            reason,
            &assertionID
        )
        if result == kIOReturnSuccess {
            isActive = true
            return true
        }
        return false
    }

    func disable() {
        guard isActive else { return }
        IOPMAssertionRelease(assertionID)
        assertionID = 0
        isActive = false
    }
}

// MARK: - System-wide sleep lock (`pmset -a disablesleep`)

enum SudoersInstallResult {
    case success
    case userCancelled
    case failed(String)
}

enum LidSleepLock {
    static let pmsetPath = "/usr/bin/pmset"
    static let sudoPath = "/usr/bin/sudo"
    static let sudoersPath = "/etc/sudoers.d/owly"

    /// Legacy filenames from earlier names of this project. Cleaned up
    /// whenever we install or uninstall sudoers, so users upgrading from
    /// the old "CaffeinateToggle" don't end up with multiple sudoers files.
    static let sudoersLegacyPaths = [
        "/etc/sudoers.d/caffeinatetoggle",
        "/etc/sudoers.d/com.user.caffeinatetoggle",
    ]

    /// Whether passwordless `pmset -a disablesleep` is wired up.
    ///
    /// Implementation: pure stat — we just check if the sudoers file we
    /// would have installed is present. We deliberately do NOT probe by
    /// running `sudo -n pmset ...` here, because that command has a side
    /// effect (it actually flips disablesleep to 0) and `isAuthorized` is
    /// called many times per UI refresh. Earlier versions did probe, which
    /// caused strong mode to silently get reset to 0 on every menu redraw.
    static func isAuthorized() -> Bool {
        let allPaths = [sudoersPath] + sudoersLegacyPaths
        return allPaths.contains { FileManager.default.fileExists(atPath: $0) }
    }

    /// Human-readable diagnostic explaining why authorization is missing.
    ///
    /// IMPORTANT: must remain side-effect free. The diagnostics window
    /// builds this string every time it's opened, and an earlier version
    /// fell back to running `sudo pmset -a disablesleep 0` to surface the
    /// real exit code — which silently flipped strong mode off whenever
    /// the user opened the diagnostics window. Stay file-system only.
    static func authorizationFailureReason() -> String {
        let allPaths = [sudoersPath] + sudoersLegacyPaths
        let found = allPaths.filter { FileManager.default.fileExists(atPath: $0) }
        if found.isEmpty {
            return "no sudoers file at \(sudoersPath) (or any legacy path)"
        }
        return "sudoers file present at \(found.joined(separator: ", ")) — file may have been tampered with or the rules don't match the expected `\(pmsetPath) -a disablesleep 0|1` pattern"
    }

    @discardableResult
    static func setEnabled(_ enabled: Bool) -> Bool {
        runSudoPmset(value: enabled ? "1" : "0").exitCode == 0
    }

    /// Triggers macOS's native admin authorization dialog, then installs a
    /// sudoers entry granting passwordless execution of the two exact pmset
    /// commands we use. Also cleans up the legacy filename.
    static func installSudoersInteractively() -> SudoersInstallResult {
        let username = NSUserName()
        let sudoersContent = """
        # Owly — passwordless toggle of system-wide sleep lock.
        # Installed by the menu bar app via osascript admin authorization.
        \(username) ALL=(root) NOPASSWD: \(pmsetPath) -a disablesleep 0
        \(username) ALL=(root) NOPASSWD: \(pmsetPath) -a disablesleep 1
        """
        let base64 = Data(sudoersContent.utf8).base64EncodedString()
        let legacyCleanup = sudoersLegacyPaths.map { "/bin/rm -f \($0)" }.joined(separator: "\n")

        // Run as one shell command via `do shell script with administrator
        // privileges`. base64-encoded payload avoids any shell-quoting surprises.
        let shellCommand = """
        set -e
        TMP=$(/usr/bin/mktemp -t owly.sudoers)
        /bin/echo '\(base64)' | /usr/bin/base64 -D > "$TMP"
        /usr/sbin/visudo -c -f "$TMP" >/dev/null
        /usr/bin/install -m 0440 -o root -g wheel "$TMP" \(sudoersPath)
        \(legacyCleanup)
        /bin/rm -f "$TMP"
        """

        return runWithAdminPrivileges(
            shell: shellCommand,
            prompt: L10n.sudoersInstallPrompt
        )
    }

    /// Removes the sudoers entry (including any legacy filenames from
    /// earlier project names). Triggers a separate admin authorization.
    static func uninstallSudoersInteractively() -> SudoersInstallResult {
        let allPaths = ([sudoersPath] + sudoersLegacyPaths)
            .map { "/bin/rm -f \($0)" }
            .joined(separator: "\n")
        let shellCommand = """
        \(allPaths)
        /usr/bin/pmset -a disablesleep 0 || true
        """
        return runWithAdminPrivileges(
            shell: shellCommand,
            prompt: L10n.sudoersUninstallPrompt
        )
    }

    private static func runWithAdminPrivileges(shell: String, prompt: String) -> SudoersInstallResult {
        let escapedShell = shell
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
        let escapedPrompt = prompt
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")

        let source = """
        do shell script "\(escapedShell)" with administrator privileges with prompt "\(escapedPrompt)"
        """

        guard let script = NSAppleScript(source: source) else {
            return .failed("Failed to construct AppleScript")
        }

        var errorInfo: NSDictionary?
        _ = script.executeAndReturnError(&errorInfo)

        if let error = errorInfo {
            let errNum = (error[NSAppleScript.errorNumber] as? Int) ?? 0
            // -128 = userCanceledErr (user clicked Cancel in the auth dialog)
            if errNum == -128 {
                return .userCancelled
            }
            let msg = (error[NSAppleScript.errorMessage] as? String)
                ?? error.description
            return .failed("errno=\(errNum)  \(msg)")
        }
        return .success
    }

    static func isCurrentlyEnabled() -> Bool {
        for args in [["-g"], ["-g", "custom"]] {
            let task = Process()
            task.executableURL = URL(fileURLWithPath: pmsetPath)
            task.arguments = args
            let pipe = Pipe()
            task.standardOutput = pipe
            task.standardError = Pipe()
            do {
                try task.run()
                task.waitUntilExit()
            } catch {
                continue
            }
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            guard let output = String(data: data, encoding: .utf8) else { continue }

            for line in output.split(separator: "\n") {
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                let keyMatch =
                    trimmed.hasPrefix("disablesleep") ||
                    trimmed.hasPrefix("SleepDisabled")
                guard keyMatch else { continue }

                let parts = trimmed
                    .split { $0 == " " || $0 == "\t" }
                    .filter { !$0.isEmpty }
                if parts.count >= 2, let value = Int(parts[1]), value != 0 {
                    return true
                }
            }
        }
        return false
    }

    private static func runSudoPmset(value: String) -> (exitCode: Int32, stderr: String) {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: sudoPath)
        task.arguments = ["-n", pmsetPath, "-a", "disablesleep", value]
        let outPipe = Pipe()
        let errPipe = Pipe()
        task.standardOutput = outPipe
        task.standardError = errPipe
        do {
            try task.run()
            task.waitUntilExit()
        } catch {
            return (1, "spawn failed: \(error)")
        }
        let stderr = String(
            data: errPipe.fileHandleForReading.readDataToEndOfFile(),
            encoding: .utf8
        ) ?? ""
        return (task.terminationStatus, stderr)
    }
}

// MARK: - Power source monitor

/// Watches macOS power source state via the IOPS framework. Fires
/// `onPowerUnplugged` exactly once per AC → battery transition. Used to
/// nudge the user toward strong-mode if they yank the adapter while a
/// long-running task is in flight (a common precursor to "I'll just close
/// the lid for a sec…" disasters).
final class PowerSourceMonitor {
    private var runLoopSource: CFRunLoopSource?
    private var lastIsOnAC: Bool?

    /// Called on the main thread on every AC → battery transition.
    /// Stays silent for the initial state and for AC ↔ AC noise.
    var onPowerUnplugged: (() -> Void)?

    func start() {
        guard runLoopSource == nil else { return }
        let info = Unmanaged.passUnretained(self).toOpaque()
        let callback: IOPowerSourceCallbackType = { context in
            guard let context = context else { return }
            let monitor = Unmanaged<PowerSourceMonitor>
                .fromOpaque(context)
                .takeUnretainedValue()
            DispatchQueue.main.async { monitor.handleChange() }
        }

        guard let unmanagedSource = IOPSNotificationCreateRunLoopSource(callback, info)
        else { return }
        let source = unmanagedSource.takeRetainedValue()
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .defaultMode)
        runLoopSource = source

        // Seed last-known state so the first real transition is detectable.
        lastIsOnAC = Self.isOnAC()
    }

    func stop() {
        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .defaultMode)
        }
        runLoopSource = nil
    }

    func currentlyOnAC() -> Bool { Self.isOnAC() }

    private func handleChange() {
        let now = Self.isOnAC()
        let prev = lastIsOnAC
        lastIsOnAC = now
        if prev == true && now == false {
            onPowerUnplugged?()
        }
    }

    /// Returns true if any reported power source is currently AC-powered.
    /// Desktops without a battery report AC and never transition, which is
    /// fine — they'll never trigger `onPowerUnplugged`.
    private static func isOnAC() -> Bool {
        guard let blob = IOPSCopyPowerSourcesInfo()?.takeRetainedValue() else {
            return false
        }
        guard let list = IOPSCopyPowerSourcesList(blob)?.takeRetainedValue()
                as? [CFTypeRef]
        else { return false }
        for source in list {
            guard let desc = IOPSGetPowerSourceDescription(blob, source)?
                    .takeUnretainedValue() as? [String: Any]
            else { continue }
            if let state = desc[kIOPSPowerSourceStateKey as String] as? String,
               state == (kIOPSACPowerValue as String) {
                return true
            }
        }
        return false
    }
}

// MARK: - LaunchAgent helpers

enum LaunchAgent {
    static let label = "com.aarontaken.owly"

    /// Plist labels used by older versions of this project. We delete these
    /// during uninstall so users upgrading from the original "CaffeinateToggle"
    /// don't end up with stale launchd registrations.
    static let legacyLabels = ["com.user.caffeinatetoggle"]

    static var plistURL: URL {
        FileManager.default
            .homeDirectoryForCurrentUser
            .appendingPathComponent("Library/LaunchAgents/\(label).plist")
    }

    static var isInstalled: Bool {
        FileManager.default.fileExists(atPath: plistURL.path)
    }

    /// Writes ~/Library/LaunchAgents/<label>.plist pointing at the currently
    /// running executable. Does NOT call `launchctl` — the agent will be
    /// auto-loaded by macOS at the next login.
    ///
    /// Why no `launchctl load`: it would either spawn a *second* instance of
    /// the app (if RunAtLoad triggers while we're already running), or, if
    /// our current process is already managed by launchd, conflict with the
    /// existing service. Pure file-write semantics match what users expect
    /// from a "Launch at login" toggle.
    static func install() throws {
        let executablePath = Bundle.main.executablePath
            ?? Bundle.main.bundlePath + "/Contents/MacOS/Owly"

        let plist = """
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
        <plist version="1.0">
        <dict>
            <key>Label</key>
            <string>\(label)</string>
            <key>ProgramArguments</key>
            <array>
                <string>\(executablePath)</string>
            </array>
            <key>RunAtLoad</key>
            <true/>
            <key>KeepAlive</key>
            <false/>
            <key>ProcessType</key>
            <string>Interactive</string>
            <key>StandardOutPath</key>
            <string>/tmp/\(label).out.log</string>
            <key>StandardErrorPath</key>
            <string>/tmp/\(label).err.log</string>
        </dict>
        </plist>
        """

        try FileManager.default.createDirectory(
            at: plistURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try plist.write(to: plistURL, atomically: true, encoding: .utf8)
    }

    /// Removes the plist. Does NOT call `launchctl unload` — that would send
    /// SIGTERM to the currently running process if it was launched by
    /// launchd, killing the app the user is interacting with.
    ///
    /// The agent's launchd registration (if any) survives until logout. That
    /// is fine: the app is still running normally; only the auto-launch on
    /// next login is disabled, which is the user's intent.
    static func uninstall() throws {
        if FileManager.default.fileExists(atPath: plistURL.path) {
            try FileManager.default.removeItem(at: plistURL)
        }
        // Best-effort cleanup of legacy plist names from earlier versions.
        let agentsDir = FileManager.default
            .homeDirectoryForCurrentUser
            .appendingPathComponent("Library/LaunchAgents")
        for legacyLabel in legacyLabels {
            let legacyURL = agentsDir.appendingPathComponent("\(legacyLabel).plist")
            try? FileManager.default.removeItem(at: legacyURL)
        }
    }
}

// MARK: - App delegate

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private static let modeKey = "currentMode"

    private var statusItem: NSStatusItem!
    private let assertion = IdleSleepAssertion()
    private var currentMode: CaffeinateMode = .off

    private var headerItem: NSMenuItem!
    private var modeItems: [CaffeinateMode: NSMenuItem] = [:]
    private var autostartItem: NSMenuItem!
    private var resetAuthItem: NSMenuItem!
    private var languageItem: NSMenuItem!
    private var languageSubmenu: NSMenu!

    private let powerMonitor = PowerSourceMonitor()
    private let unplugPopover = UnplugAlertPopover()

    /// Language at last menu build — used to detect changes that require
    /// a full menu rebuild.
    private var lastLanguage: Language?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Bail out if another instance is already running (prevents accidental
        // double-launch when launchd starts one and the user double-clicks
        // another, or vice versa).
        if let bid = Bundle.main.bundleIdentifier {
            let myPID = ProcessInfo.processInfo.processIdentifier
            let others = NSRunningApplication
                .runningApplications(withBundleIdentifier: bid)
                .filter { $0.processIdentifier != myPID }
            if !others.isEmpty {
                NSLog("Owly: another instance is already running, exiting.")
                NSApp.terminate(nil)
                return
            }
        }

        // Recover from a possible crash that left disablesleep=1 behind.
        if LidSleepLock.isAuthorized() && LidSleepLock.isCurrentlyEnabled() {
            LidSleepLock.setEnabled(false)
        }

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        let menu = buildMenu()
        menu.delegate = self
        statusItem.menu = menu
        lastLanguage = L10n.current

        // Restore the mode from last session.
        let savedRaw = UserDefaults.standard.integer(forKey: Self.modeKey)
        let saved = CaffeinateMode(rawValue: savedRaw) ?? .off
        applyMode(saved, persist: false)

        // Watch for AC → battery transitions. If the user yanks the
        // adapter while we're NOT in strong mode, surface a quiet
        // suggestion under the menu bar icon.
        powerMonitor.onPowerUnplugged = { [weak self] in
            self?.handlePowerUnplugged()
        }
        powerMonitor.start()
    }

    func applicationWillTerminate(_ notification: Notification) {
        if currentMode == .strong {
            LidSleepLock.setEnabled(false)
        }
        assertion.disable()
        powerMonitor.stop()
    }

    // MARK: Power-source change handler

    private func handlePowerUnplugged() {
        // Already covering for clamshell sleep — no need to nag.
        guard currentMode != .strong else { return }
        // No status-bar button means the menu bar isn't visible
        // (rare — e.g. setup flake). Fail quietly.
        guard let button = statusItem.button else { return }

        unplugPopover.show(from: button) { [weak self] in
            guard let self else { return }
            // If the user already had sudoers authorized, this is a no-op
            // password-wise; otherwise applyMode will trigger the native
            // admin dialog through the normal strong-mode pathway.
            self.applyMode(.strong, persist: true)
        }
    }

    func menuWillOpen(_ menu: NSMenu) {
        // If language changed since last build, rebuild the entire menu.
        if L10n.current != lastLanguage {
            rebuildMenu()
        }
        refreshUI()
    }

    // MARK: Build / rebuild menu

    private func rebuildMenu() {
        let menu = buildMenu()
        menu.delegate = self
        statusItem.menu = menu
        lastLanguage = L10n.current
    }

    private func buildMenu() -> NSMenu {
        let menu = NSMenu()

        headerItem = NSMenuItem(title: "", action: nil, keyEquivalent: "")
        headerItem.isEnabled = false
        menu.addItem(headerItem)
        menu.addItem(.separator())

        for (i, mode) in [CaffeinateMode.off, .idle, .strong].enumerated() {
            let item = NSMenuItem(
                title: mode.menuTitle,
                action: #selector(modeMenuItemClicked(_:)),
                keyEquivalent: "\(i)"
            )
            item.target = self
            item.tag = mode.rawValue
            menu.addItem(item)
            modeItems[mode] = item
        }

        menu.addItem(.separator())

        autostartItem = NSMenuItem(
            title: L10n.menuAutostart,
            action: #selector(toggleAutostart),
            keyEquivalent: ""
        )
        autostartItem.target = self
        menu.addItem(autostartItem)

        resetAuthItem = NSMenuItem(
            title: L10n.menuResetAuth,
            action: #selector(resetAuthorizationClicked),
            keyEquivalent: ""
        )
        resetAuthItem.target = self
        menu.addItem(resetAuthItem)

        let aboutItem = NSMenuItem(
            title: L10n.menuAbout,
            action: #selector(showAbout),
            keyEquivalent: ""
        )
        aboutItem.target = self
        menu.addItem(aboutItem)

        let diagnosticsItem = NSMenuItem(
            title: L10n.menuDiagnostics,
            action: #selector(showDiagnostics),
            keyEquivalent: ""
        )
        diagnosticsItem.target = self
        menu.addItem(diagnosticsItem)

        // Language submenu
        languageSubmenu = NSMenu()
        languageItem = NSMenuItem(title: L10n.menuLanguage, action: nil, keyEquivalent: "")
        menu.addItem(languageItem)
        menu.setSubmenu(languageSubmenu, for: languageItem)

        rebuildLanguageSubmenu()

        menu.addItem(.separator())

        let quitItem = NSMenuItem(
            title: L10n.menuQuit,
            action: #selector(NSApp.terminate(_:)),
            keyEquivalent: "q"
        )
        menu.addItem(quitItem)

        return menu
    }

    private func rebuildLanguageSubmenu() {
        languageSubmenu.removeAllItems()
        languageItem.title = L10n.menuLanguage
        for lang in Language.allCases {
            let item = NSMenuItem(
                title: lang.displayName,
                action: #selector(languageMenuItemClicked(_:)),
                keyEquivalent: ""
            )
            item.target = self
            item.state = (lang == L10n.current) ? .on : .off
            item.representedObject = lang
            languageSubmenu.addItem(item)
        }
    }

    @objc private func languageMenuItemClicked(_ sender: NSMenuItem) {
        guard let lang = sender.representedObject as? Language else { return }
        L10n.current = lang
        rebuildMenu()
        refreshUI()
    }

    // MARK: Mode handling

    @objc private func modeMenuItemClicked(_ sender: NSMenuItem) {
        guard let mode = CaffeinateMode(rawValue: sender.tag) else { return }
        applyMode(mode, persist: true)
    }

    /// Shows a confirmation alert, then triggers macOS's native admin dialog
    /// to install the sudoers entry. Returns true if installation succeeded
    /// and the caller should continue switching to .strong mode.
    private func promptInstallSudoersAndRetry() -> Bool {
        let alert = NSAlert()
        alert.messageText = L10n.strongModeAlertTitle
        alert.informativeText = L10n.strongModeAlertInfo
        alert.alertStyle = .informational
        alert.addButton(withTitle: L10n.authorizeButton)
        alert.addButton(withTitle: L10n.cancel)

        NSApp.activate(ignoringOtherApps: true)
        let response = alert.runModal()
        guard response == .alertFirstButtonReturn else { return false }

        let result = LidSleepLock.installSudoersInteractively()
        switch result {
        case .success:
            return true
        case .userCancelled:
            return false
        case .failed(let detail):
            presentAlert(
                title: L10n.installFailedTitle,
                message: L10n.installFailedMessage + detail
            )
            return false
        }
    }

    @objc private func resetAuthorizationClicked() {
        let alert = NSAlert()
        alert.messageText = L10n.resetAuthAlertTitle
        alert.informativeText = L10n.resetAuthAlertInfo
        alert.alertStyle = .warning
        alert.addButton(withTitle: L10n.revokeButton)
        alert.addButton(withTitle: L10n.cancel)

        NSApp.activate(ignoringOtherApps: true)
        guard alert.runModal() == .alertFirstButtonReturn else { return }

        let result = LidSleepLock.uninstallSudoersInteractively()
        switch result {
        case .success:
            // If we were in strong mode, fall back to off.
            if currentMode == .strong {
                applyMode(.off, persist: true)
            }
            refreshUI()
        case .userCancelled:
            break
        case .failed(let detail):
            presentAlert(title: L10n.revokeFailedTitle, message: detail)
        }
    }

    /// Switches into `target` mode: cleanly tears down whatever the current
    /// mode owns, then sets up the new mode's side-effects.
    private func applyMode(_ target: CaffeinateMode, persist: Bool) {
        if target == .strong && !LidSleepLock.isAuthorized() {
            // Try to install sudoers interactively (one-time, native auth dialog).
            let proceed = promptInstallSudoersAndRetry()
            if !proceed { return }
            // After installation, fall through and continue applying mode.
        }

        // Tear down current mode.
        switch currentMode {
        case .idle:   assertion.disable()
        case .strong: LidSleepLock.setEnabled(false)
        case .off:    break
        }

        // Apply target mode.
        switch target {
        case .idle:
            if !assertion.enable() {
                presentAlert(
                    title: L10n.switchFailedTitle,
                    message: L10n.idleSwitchFailed
                )
                currentMode = .off
                refreshUI()
                return
            }
        case .strong:
            if !LidSleepLock.setEnabled(true) {
                presentAlert(
                    title: L10n.switchFailedTitle,
                    message: L10n.strongSwitchFailed
                )
                currentMode = .off
                refreshUI()
                return
            }
        case .off:
            break
        }

        currentMode = target
        if persist {
            UserDefaults.standard.set(target.rawValue, forKey: Self.modeKey)
        }
        refreshUI()
    }

    // MARK: UI refresh

    private func refreshUI() {
        if let button = statusItem.button {
            // Hand-drawn owl glyph (auto-tinted by macOS to match the menu
            // bar theme via `isTemplate = true`). Each mode = a different
            // owl expression: closed eyes / open eyes / open + starburst.
            button.image = MenubarOwl.image(for: currentMode)
        }

        headerItem.title = currentMode.statusLine

        for (mode, item) in modeItems {
            item.state = (mode == currentMode) ? .on : .off
            if mode == .strong && !LidSleepLock.isAuthorized() {
                item.title = "\(mode.menuTitle)\(L10n.notAuthorizedSuffix)"
            } else {
                item.title = mode.menuTitle
            }
        }

        autostartItem.state = LaunchAgent.isInstalled ? .on : .off
        resetAuthItem.isHidden = !LidSleepLock.isAuthorized()
    }

    // MARK: Other actions

    @objc private func toggleAutostart() {
        let wasInstalled = LaunchAgent.isInstalled
        do {
            if wasInstalled {
                try LaunchAgent.uninstall()
            } else {
                try LaunchAgent.install()
            }
        } catch {
            presentAlert(
                title: L10n.autostartFailedTitle,
                message: "\(error)"
            )
            refreshUI()
            return
        }

        // Subtle, non-intrusive feedback only the first time the user toggles
        // it on, so they understand "next login" semantics.
        let key = "shownAutostartHint"
        if !wasInstalled && !UserDefaults.standard.bool(forKey: key) {
            UserDefaults.standard.set(true, forKey: key)
            presentAlert(
                title: L10n.autostartEnabledTitle,
                message: L10n.autostartEnabledInfo
            )
        }

        refreshUI()
    }

    private var infoWindowController: NSWindowController?

    @objc private func showAbout() {
        let snapshot = AppSnapshot(
            currentMode: currentMode,
            lidAuthorized: LidSleepLock.isAuthorized(),
            autostartConfigured: LaunchAgent.isInstalled,
            idleAssertionActive: assertion.isActive,
            disablesleepActive: LidSleepLock.isCurrentlyEnabled(),
            lidAuthFailureReason: LidSleepLock.authorizationFailureReason(),
            bundlePath: Bundle.main.bundlePath,
            pid: ProcessInfo.processInfo.processIdentifier
        )
        showInfoWindow(content: AnyView(AboutView(snapshot: snapshot)), title: L10n.aboutTitle)
    }

    @objc private func showDiagnostics() {
        let snapshot = AppSnapshot(
            currentMode: currentMode,
            lidAuthorized: LidSleepLock.isAuthorized(),
            autostartConfigured: LaunchAgent.isInstalled,
            idleAssertionActive: assertion.isActive,
            disablesleepActive: LidSleepLock.isCurrentlyEnabled(),
            lidAuthFailureReason: LidSleepLock.authorizationFailureReason(),
            bundlePath: Bundle.main.bundlePath,
            pid: ProcessInfo.processInfo.processIdentifier
        )
        showInfoWindow(content: AnyView(DiagnosticsView(snapshot: snapshot)), title: L10n.diagTitle)
    }

    private func showInfoWindow(content: AnyView, title: String) {
        // Reuse existing window if open, just swap content.
        if let controller = infoWindowController, let window = controller.window {
            window.title = title
            window.contentView = NSHostingView(rootView: content)
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let hostingView = NSHostingView(rootView: content)
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 520, height: 600),
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.title = title
        window.titlebarAppearsTransparent = true
        window.isMovableByWindowBackground = true
        window.contentView = hostingView
        window.center()
        window.isReleasedWhenClosed = false

        let controller = NSWindowController(window: window)
        infoWindowController = controller

        controller.showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func presentAlert(title: String, message: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.alertStyle = .informational
        alert.addButton(withTitle: L10n.okButton)
        NSApp.activate(ignoringOtherApps: true)
        alert.runModal()
    }
}

// MARK: - SwiftUI snapshot

struct AppSnapshot {
    let currentMode: CaffeinateMode
    let lidAuthorized: Bool
    let autostartConfigured: Bool
    let idleAssertionActive: Bool
    let disablesleepActive: Bool
    let lidAuthFailureReason: String
    let bundlePath: String
    let pid: Int32
}

// MARK: - SwiftUI shared building blocks

struct InfoCardHeader: View {
    let title: String
    let subtitle: String
    /// SF Symbol fallback. Used only when `useAppIcon` is false. Kept
    /// around so other panels (alerts, popovers) can still use a plain
    /// glyph header without dragging in the full app icon.
    let symbol: String
    let tint: Color
    /// When true, the leading badge renders the actual Owly app icon
    /// (the hand-drawn owl) instead of `symbol`. Used by About and
    /// Diagnostics so those panels carry Owly's visual identity rather
    /// than a generic SF Symbol.
    let useAppIcon: Bool

    init(
        title: String,
        subtitle: String,
        symbol: String,
        tint: Color,
        useAppIcon: Bool = false
    ) {
        self.title = title
        self.subtitle = subtitle
        self.symbol = symbol
        self.tint = tint
        self.useAppIcon = useAppIcon
    }

    var body: some View {
        HStack(spacing: 14) {
            if useAppIcon, let icon = NSApp.applicationIconImage {
                Image(nsImage: icon)
                    .resizable()
                    .interpolation(.high)
                    .frame(width: 56, height: 56)
            } else {
                ZStack {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(tint.opacity(0.18))
                        .frame(width: 56, height: 56)
                    Image(systemName: symbol)
                        .font(.system(size: 28, weight: .semibold))
                        .foregroundStyle(tint)
                }
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 18, weight: .bold))
                Text(subtitle)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
    }
}

/// Health classification for a single diagnostic row.
///
/// `ok`  — the underlying mechanism is in the state we'd expect for the
///         current app mode (e.g. IOKit assertion = active in idle mode).
/// `na`  — the mechanism doesn't apply to the current mode (e.g. IOKit
///         assertion in strong mode, where pmset disablesleep is doing
///         the work instead). The value isn't a problem, just irrelevant.
/// `warn` — actual inconsistency (e.g. user is in strong mode but
///         disablesleep is 0, meaning the lid-close protection isn't
///         really in force).
enum RowHealth {
    case ok
    case na
    case warn

    fileprivate var symbol: String {
        switch self {
        case .ok:   return "checkmark.circle.fill"
        case .na:   return "minus.circle.fill"
        case .warn: return "exclamationmark.triangle.fill"
        }
    }

    fileprivate var tint: Color {
        switch self {
        case .ok:   return .green
        case .na:   return .secondary
        case .warn: return .orange
        }
    }
}

struct StatusRow: View {
    let symbol: String
    /// When non-nil, the leading icon renders the Owly glyph for that
    /// mode (sleeping / open / alert) instead of the SF Symbol — used
    /// by the "current mode" row to match the menu-bar icon language.
    let leadingMode: CaffeinateMode?
    let label: String
    let value: String
    let highlighted: Bool
    /// Optional health indicator drawn on the trailing edge. `nil` hides
    /// it (used by the About panel, where rows aren't health-checked).
    let health: RowHealth?

    init(
        symbol: String,
        leadingMode: CaffeinateMode? = nil,
        label: String,
        value: String,
        highlighted: Bool,
        health: RowHealth? = nil
    ) {
        self.symbol = symbol
        self.leadingMode = leadingMode
        self.label = label
        self.value = value
        self.highlighted = highlighted
        self.health = health
    }

    var body: some View {
        HStack(spacing: 10) {
            if let leadingMode {
                Image(nsImage: MenubarOwl.image(for: leadingMode, size: 18))
                    .renderingMode(.template)
                    .frame(width: 18, height: 18)
                    .foregroundStyle(highlighted ? Color.accentColor : Color.secondary)
            } else {
                Image(systemName: symbol)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(highlighted ? Color.accentColor : Color.secondary)
                    .frame(width: 18)
            }
            Text(label)
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
            Spacer(minLength: 12)
            Text(value)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(
                    health == .na
                        ? .secondary
                        : (highlighted ? .primary : .secondary)
                )
            if let health {
                Image(systemName: health.symbol)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(health.tint)
                    .frame(width: 14)
                    .help(healthHelp(health))
            }
        }
    }

    private func healthHelp(_ h: RowHealth) -> String {
        switch h {
        case .ok:   return L10n.healthOk
        case .na:   return L10n.healthNa
        case .warn: return L10n.healthWarn
        }
    }
}

struct ModeBlurb: View {
    /// SF Symbol fallback (kept for back-compat). Used only when `mode`
    /// is `nil`. Pass a `mode` to render the matching Owly glyph instead.
    let symbol: String
    /// When non-nil, the leading badge renders the hand-drawn Owly
    /// expression for that mode (sleeping / open eyes / alert) instead
    /// of the SF Symbol — matching the menu-bar icon language.
    let mode: CaffeinateMode?
    let title: String
    let summary: String
    let highlighted: Bool

    init(
        symbol: String,
        mode: CaffeinateMode? = nil,
        title: String,
        summary: String,
        highlighted: Bool
    ) {
        self.symbol = symbol
        self.mode = mode
        self.title = title
        self.summary = summary
        self.highlighted = highlighted
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            if let mode {
                // Reuse the menu-bar owl glyph at a larger size so this
                // panel speaks the same visual language as the icon in
                // the status bar. The image is a template, so the
                // foregroundStyle below tints it.
                Image(nsImage: MenubarOwl.image(for: mode, size: 26))
                    .renderingMode(.template)
                    .frame(width: 26, height: 26)
                    .foregroundStyle(highlighted ? Color.accentColor : Color.secondary)
            } else {
                Image(systemName: symbol)
                    .font(.system(size: 16, weight: .semibold))
                    .frame(width: 22)
                    .foregroundStyle(highlighted ? Color.accentColor : Color.secondary)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                Text(summary)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(highlighted ? Color.accentColor.opacity(0.10) : Color.gray.opacity(0.08))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(highlighted ? Color.accentColor.opacity(0.35) : Color.clear, lineWidth: 1)
        )
    }
}

// MARK: - Unplug-alert popover

/// Tiny SwiftUI card shown under the menu bar icon when the user yanks
/// the power adapter while NOT in strong mode. Goal: low-friction nudge,
/// not a system notification, not a modal dialog.
private struct UnplugAlertView: View {
    let onSwitchToStrong: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Image(systemName: "powerplug.fill")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(Color.orange)
                    .symbolRenderingMode(.hierarchical)
                VStack(alignment: .leading, spacing: 2) {
                    Text(L10n.unpluggedTitle)
                        .font(.system(size: 13, weight: .semibold))
                    Text(L10n.unpluggedCurrently)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
            }

            Text(L10n.unpluggedBody)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 8) {
                Button(action: onSwitchToStrong) {
                    HStack(spacing: 5) {
                        Image(systemName: "bolt.fill")
                        Text(L10n.switchToStrong).font(.system(size: 12, weight: .medium))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 2)
                }
                .keyboardShortcut(.defaultAction)
                .controlSize(.regular)

                Button(action: onDismiss) {
                    Text(L10n.keepCurrent).font(.system(size: 12))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 2)
                }
                .controlSize(.regular)
            }
        }
        .padding(14)
        .frame(width: 296)
    }
}

/// Manages the lifecycle of the unplug-alert NSPopover anchored under the
/// status item.
final class UnplugAlertPopover {
    /// Auto-dismiss the popover after this many seconds of no interaction.
    private static let autoDismissSeconds: TimeInterval = 12

    private var popover: NSPopover?
    private var hideTimer: Timer?

    /// Show the popover anchored under the given status-bar button.
    /// `onSwitchToStrong` is invoked on the main thread when the user taps
    /// the primary CTA. The popover is dismissed automatically afterward.
    ///
    /// If a popover is already on screen, this call is a no-op (so we
    /// don't stack two cards on top of each other).
    func show(
        from button: NSStatusBarButton,
        onSwitchToStrong: @escaping () -> Void
    ) {
        if popover != nil { return }

        let p = NSPopover()
        p.behavior = .transient
        p.animates = true
        let view = UnplugAlertView(
            onSwitchToStrong: { [weak self] in
                onSwitchToStrong()
                self?.dismiss()
            },
            onDismiss: { [weak self] in self?.dismiss() }
        )
        p.contentViewController = NSHostingController(rootView: view)
        p.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        popover = p

        hideTimer?.invalidate()
        hideTimer = Timer.scheduledTimer(
            withTimeInterval: Self.autoDismissSeconds,
            repeats: false
        ) { [weak self] _ in
            self?.dismiss()
        }
    }

    func dismiss() {
        hideTimer?.invalidate()
        hideTimer = nil
        popover?.performClose(nil)
        popover = nil
    }
}

// MARK: - About view

struct AboutView: View {
    let snapshot: AppSnapshot

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                InfoCardHeader(
                    title: L10n.aboutTitle,
                    subtitle: L10n.aboutSubtitle,
                    symbol: "powersleep",
                    tint: .accentColor,
                    useAppIcon: true
                )

                VStack(alignment: .leading, spacing: 10) {
                    StatusRow(
                        symbol: snapshot.currentMode.iconSymbol,
                        leadingMode: snapshot.currentMode,
                        label: L10n.aboutCurrentMode,
                        value: snapshot.currentMode.menuTitle,
                        highlighted: snapshot.currentMode != .off
                    )
                    Divider()
                    StatusRow(
                        symbol: snapshot.lidAuthorized
                            ? "checkmark.shield.fill"
                            : "exclamationmark.shield",
                        label: L10n.aboutStrongAuth,
                        value: snapshot.lidAuthorized ? L10n.authorized : L10n.notAuthorized,
                        highlighted: snapshot.lidAuthorized,
                        health: snapshot.lidAuthorized
                            ? .ok
                            : (snapshot.currentMode == .strong ? .warn : .na)
                    )
                    Divider()
                    StatusRow(
                        symbol: snapshot.autostartConfigured ? "power.circle.fill" : "power.circle",
                        label: L10n.aboutAutostart,
                        value: snapshot.autostartConfigured ? L10n.configured : L10n.notConfigured,
                        highlighted: snapshot.autostartConfigured,
                        health: snapshot.autostartConfigured ? .ok : .na
                    )
                }
                .padding(14)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color.primary.opacity(0.05))
                )

                VStack(alignment: .leading, spacing: 8) {
                    Text(L10n.modeDescription)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(.secondary)

                    ModeBlurb(
                        symbol: CaffeinateMode.off.iconSymbol,
                        mode: .off,
                        title: L10n.modeOff,
                        summary: L10n.modeOffSummary,
                        highlighted: snapshot.currentMode == .off
                    )

                    ModeBlurb(
                        symbol: CaffeinateMode.idle.iconSymbol,
                        mode: .idle,
                        title: L10n.modeIdleTitle,
                        summary: L10n.modeIdleSummary,
                        highlighted: snapshot.currentMode == .idle
                    )

                    ModeBlurb(
                        symbol: CaffeinateMode.strong.iconSymbol,
                        mode: .strong,
                        title: L10n.modeStrongTitle,
                        summary: L10n.modeStrongSummary,
                        highlighted: snapshot.currentMode == .strong
                    )
                }

                HStack(spacing: 8) {
                    Image(systemName: "info.circle")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                    Text(L10n.autoResetNote)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 4)
            }
            .padding(20)
        }
        .frame(width: 520, height: 600)
        .background(.ultraThickMaterial)
    }
}

// MARK: - Diagnostics view

struct DiagnosticsView: View {
    let snapshot: AppSnapshot

    /// One row in the diagnostics list. `health == nil` hides the trailing
    /// status indicator (used for the "current mode" row, which is fact,
    /// not a checked invariant).
    private struct AssertionRow {
        let label: String
        let value: String
        let symbol: String
        let leadingMode: CaffeinateMode?
        let highlighted: Bool
        let health: RowHealth?

        init(
            label: String,
            value: String,
            symbol: String,
            leadingMode: CaffeinateMode? = nil,
            highlighted: Bool,
            health: RowHealth?
        ) {
            self.label = label
            self.value = value
            self.symbol = symbol
            self.leadingMode = leadingMode
            self.highlighted = highlighted
            self.health = health
        }
    }

    private var assertionRows: [AssertionRow] {
        let mode = snapshot.currentMode

        // IOKit assertion: should be active iff in idle mode. In any
        // other mode it should be inactive — if it's active anyway,
        // that's a stale assertion (warn).
        let iokitHealth: RowHealth = {
            switch mode {
            case .idle:
                return snapshot.idleAssertionActive ? .ok : .warn
            case .strong, .off:
                return snapshot.idleAssertionActive ? .warn : .na
            }
        }()

        // pmset disablesleep: should be 1 iff in strong mode. Anywhere
        // else, 1 means a leaked global sleep lock (warn).
        let pmsetHealth: RowHealth = {
            switch mode {
            case .strong:
                return snapshot.disablesleepActive ? .ok : .warn
            case .idle, .off:
                return snapshot.disablesleepActive ? .warn : .na
            }
        }()

        // Sudoers authorization: required iff currently in strong mode.
        // If the user just hasn't enabled strong mode yet, "未授权" is
        // perfectly fine (na), not a warning.
        let sudoersHealth: RowHealth = {
            if snapshot.lidAuthorized { return .ok }
            return mode == .strong ? .warn : .na
        }()

        return [
            AssertionRow(
                label: L10n.diagCurrentMode,
                value: mode.menuTitle,
                symbol: mode.iconSymbol,
                leadingMode: mode,
                highlighted: mode != .off,
                health: nil
            ),
            AssertionRow(
                label: L10n.diagIOKit,
                value: snapshot.idleAssertionActive ? L10n.active : L10n.inactive,
                symbol: snapshot.idleAssertionActive ? "checkmark.seal.fill" : "circle.dashed",
                highlighted: snapshot.idleAssertionActive,
                health: iokitHealth
            ),
            AssertionRow(
                label: L10n.diagPmset,
                value: snapshot.disablesleepActive ? L10n.noSleep : L10n.defaultValue,
                symbol: snapshot.disablesleepActive ? "lock.shield.fill" : "lock.open",
                highlighted: snapshot.disablesleepActive,
                health: pmsetHealth
            ),
            AssertionRow(
                label: L10n.diagSudoers,
                value: snapshot.lidAuthorized ? L10n.sudoersOk : L10n.notAuthorized,
                symbol: snapshot.lidAuthorized ? "checkmark.shield.fill" : "exclamationmark.triangle.fill",
                highlighted: snapshot.lidAuthorized,
                health: sudoersHealth
            ),
        ]
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                InfoCardHeader(
                    title: L10n.diagTitle,
                    subtitle: L10n.diagSubtitle,
                    symbol: "stethoscope",
                    tint: snapshot.lidAuthorized ? .green : .orange,
                    useAppIcon: true
                )

                VStack(spacing: 10) {
                    ForEach(Array(assertionRows.enumerated()), id: \.offset) { _, row in
                        StatusRow(
                            symbol: row.symbol,
                            leadingMode: row.leadingMode,
                            label: row.label,
                            value: row.value,
                            highlighted: row.highlighted,
                            health: row.health
                        )
                    }
                }
                .padding(14)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color.primary.opacity(0.05))
                )

                if !snapshot.lidAuthorized {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 6) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(.orange)
                            Text(L10n.sudoersNotActive)
                                .font(.system(size: 13, weight: .semibold))
                        }
                        Text(snapshot.lidAuthFailureReason)
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundStyle(.secondary)
                            .textSelection(.enabled)
                            .fixedSize(horizontal: false, vertical: true)
                        Text(L10n.sudoersFix)
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(Color.orange.opacity(0.10))
                    )
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text(L10n.processInfo)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(.secondary)
                    HStack(spacing: 6) {
                        Image(systemName: "number")
                            .foregroundStyle(.secondary)
                        Text(L10n.pid)
                            .foregroundStyle(.secondary)
                        Text("\(snapshot.pid)")
                            .font(.system(.body, design: .monospaced))
                            .textSelection(.enabled)
                    }
                    .font(.system(size: 12))
                    HStack(alignment: .top, spacing: 6) {
                        Image(systemName: "shippingbox")
                            .foregroundStyle(.secondary)
                        Text(L10n.bundle)
                            .foregroundStyle(.secondary)
                        Text(snapshot.bundlePath)
                            .font(.system(.caption, design: .monospaced))
                            .textSelection(.enabled)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .font(.system(size: 12))
                }
            }
            .padding(20)
        }
        .frame(width: 520, height: 540)
        .background(.ultraThickMaterial)
    }
}

// MARK: - Entry point

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
