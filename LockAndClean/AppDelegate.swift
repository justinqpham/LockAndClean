import Cocoa
import SwiftUI
import UserNotifications

class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    var statusItem: NSStatusItem?
    var inputMonitor: InputMonitor?
    var hotkeyManager: HotkeyManager?
    var lockPopover: NSPopover?
    var hotkeyWindow: NSWindow?

    enum LockMode {
        case none
        case keyboard
        case mouse
    }

    var currentLockMode: LockMode = .none

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupMenuBar()
        setupNotifications()
        inputMonitor = InputMonitor()
        hotkeyManager = HotkeyManager()
        hotkeyManager?.onHotkeyTriggered = { [weak self] in
            self?.unlockInput()
        }
        checkAccessibilityPermissions()

        // Show launch animation and welcome popover
        showLaunchAnimation()
    }

    func setupNotifications() {
        let center = UNUserNotificationCenter.current()
        center.requestAuthorization(options: [.alert, .sound]) { granted, error in
            if let error = error {
                print("Notification authorization error: \(error)")
            }
        }
    }

    func setupMenuBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        updateMenuBarIcon()
        updateMenu()
    }

    func updateMenuBarIcon() {
        if let button = statusItem?.button {
            let config = NSImage.SymbolConfiguration(pointSize: 14, weight: .regular)
            let iconName = currentLockMode == .none ? "lock.open.fill" : "lock.fill"
            let image = NSImage(systemSymbolName: iconName, accessibilityDescription: "Lock and Clean")
            button.image = image?.withSymbolConfiguration(config)
        }
    }

    func updateMenu() {
        let menu = NSMenu()

        let statusText: String
        switch currentLockMode {
        case .none:
            statusText = "Status: Unlocked"
        case .keyboard:
            statusText = "Status: Keyboard Locked"
        case .mouse:
            statusText = "Status: Mouse Locked"
        }

        let statusItem = NSMenuItem(title: statusText, action: nil, keyEquivalent: "")
        statusItem.isEnabled = false
        menu.addItem(statusItem)

        menu.addItem(NSMenuItem.separator())

        if currentLockMode == .none {
            menu.addItem(NSMenuItem(title: "Lock Keyboard", action: #selector(lockKeyboard), keyEquivalent: "k"))
            menu.addItem(NSMenuItem(title: "Lock Mouse/Trackpad", action: #selector(lockMouse), keyEquivalent: "m"))
        } else {
            menu.addItem(NSMenuItem(title: "Unlock", action: #selector(unlockInput), keyEquivalent: "u"))
        }

        menu.addItem(NSMenuItem.separator())

        let hotkeyItem = NSMenuItem(title: "Unlock Hotkey: \(hotkeyManager?.getHotkeyDescription() ?? "Space")", action: #selector(showHotkeySettings), keyEquivalent: "")
        menu.addItem(hotkeyItem)

        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(quitApp), keyEquivalent: "q"))

        self.statusItem?.menu = menu
    }

    @objc func lockKeyboard() {
        currentLockMode = .keyboard
        inputMonitor?.startMonitoring(mode: .keyboard)
        updateMenuBarIcon()
        updateMenu()
        showLockPopover()
        let hotkeyDesc = hotkeyManager?.getHotkeyDescription() ?? "Space"
        showNotification(title: "Keyboard Locked", message: "Press \(hotkeyDesc) to unlock")
    }

    @objc func lockMouse() {
        currentLockMode = .mouse
        inputMonitor?.startMonitoring(mode: .mouse)
        updateMenuBarIcon()
        updateMenu()
        showLockPopover()
        let hotkeyDesc = hotkeyManager?.getHotkeyDescription() ?? "Space"
        showNotification(title: "Mouse Locked", message: "Press \(hotkeyDesc) to unlock")
    }

    @objc func unlockInput() {
        inputMonitor?.stopMonitoring()
        currentLockMode = .none
        updateMenuBarIcon()
        updateMenu()
        hideLockPopover()
        showNotification(title: "Unlocked", message: "Input is now enabled")
    }

    func showLockPopover() {
        guard let button = statusItem?.button else { return }

        // Activate the application to ensure the popover window becomes active
        NSApp.activate(ignoringOtherApps: true)

        let popover = NSPopover()
        popover.contentSize = NSSize(width: 240, height: 120)
        popover.behavior = .applicationDefined
        let hotkeyDescription = hotkeyManager?.getHotkeyDescription() ?? "Space"
        popover.contentViewController = NSHostingController(rootView: LockPopoverView(
            lockMode: currentLockMode,
            hotkeyDescription: hotkeyDescription,
            unlockAction: { [weak self] in
                self?.unlockInput()
            }
        ))

        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        lockPopover = popover

        // Make the popover window active after it's shown
        DispatchQueue.main.async { [weak self] in
            if let window = self?.lockPopover?.contentViewController?.view.window {
                window.makeKeyAndOrderFront(nil)
                NSApp.activate(ignoringOtherApps: true)
            }
        }
    }

    func hideLockPopover() {
        lockPopover?.close()
        lockPopover = nil
    }

    func showLaunchAnimation() {
        guard let button = statusItem?.button else { return }

        // Bounce animation for the menu bar icon
        let animation = CAKeyframeAnimation(keyPath: "transform.scale")
        animation.values = [1.0, 1.3, 0.9, 1.1, 1.0]
        animation.keyTimes = [0, 0.25, 0.5, 0.75, 1.0]
        animation.duration = 0.5
        animation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        button.layer?.add(animation, forKey: "bounce")

        // Show welcome popover briefly
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            self?.showWelcomePopover()
        }
    }

    func showWelcomePopover() {
        guard let button = statusItem?.button else { return }

        let popover = NSPopover()
        popover.contentSize = NSSize(width: 180, height: 60)
        popover.behavior = .applicationDefined
        popover.contentViewController = NSHostingController(rootView: WelcomePopoverView())

        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)

        // Auto-dismiss after 0.5 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            popover.close()
        }
    }

    @objc func showHotkeySettings() {
        if let existingWindow = hotkeyWindow {
            existingWindow.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 400, height: 250),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "Hotkey Settings"
        window.center()
        window.isReleasedWhenClosed = false
        window.delegate = self

        let hotkeyView = HotkeyConfigView { [weak self] config in
            self?.hotkeyManager?.setCustomHotkey(config)
            self?.updateMenu()
            self?.hotkeyWindow?.close()
            self?.hotkeyWindow = nil
        }

        window.contentView = NSHostingView(rootView: hotkeyView)
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        hotkeyWindow = window
    }

    func windowWillClose(_ notification: Notification) {
        if let window = notification.object as? NSWindow, window == hotkeyWindow {
            hotkeyWindow = nil
        }
    }

    @objc func quitApp() {
        inputMonitor?.stopMonitoring()
        NSApplication.shared.terminate(nil)
    }

    func checkAccessibilityPermissions() {
        let options: NSDictionary = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
        let accessEnabled = AXIsProcessTrustedWithOptions(options)

        if !accessEnabled {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                let alert = NSAlert()
                alert.messageText = "Accessibility Permission Required"
                alert.informativeText = "LockAndClean needs Accessibility permission to monitor and block input. Please grant permission in System Settings > Privacy & Security > Accessibility."
                alert.alertStyle = .warning
                alert.addButton(withTitle: "OK")
                alert.runModal()
            }
        }
    }

    func showNotification(title: String, message: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = message
        content.sound = .default

        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Notification error: \(error)")
            }
        }
    }
}

struct LockPopoverView: View {
    let lockMode: AppDelegate.LockMode
    let hotkeyDescription: String
    let unlockAction: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            // Icon and title
            HStack(spacing: 10) {
                Image(systemName: "lock.fill")
                    .font(.system(size: 20))
                    .foregroundColor(.accentColor)

                Text(lockMode == .keyboard ? "Keyboard Locked" : "Mouse Locked")
                    .font(.system(size: 13, weight: .semibold))
            }
            .padding(.top, 4)

            if lockMode == .keyboard {
                // Keyboard mode: Show unlock button
                Button(action: unlockAction) {
                    Text("Unlock")
                        .font(.system(size: 13))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            } else {
                // Mouse mode: Only show hotkey instruction
                VStack(spacing: 6) {
                    Text("To unlock, press")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)

                    Text(hotkeyDescription)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.primary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 4)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(Color(nsColor: .controlBackgroundColor))
                        )
                }
            }
        }
        .frame(width: 240, height: 120)
        .padding(16)
    }
}

struct WelcomePopoverView: View {
    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "lock.open.fill")
                    .font(.system(size: 18))
                    .foregroundColor(.accentColor)

                Text("Lock And Clean!")
                    .font(.system(size: 13, weight: .semibold))
            }
        }
        .frame(width: 180, height: 60)
        .padding(12)
    }
}
