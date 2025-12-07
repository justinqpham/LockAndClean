import Cocoa
import SwiftUI
import UserNotifications

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem?
    var inputMonitor: InputMonitor?
    var hotkeyManager: HotkeyManager?
    var lockPopover: NSPopover?

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

        let hotkeyItem = NSMenuItem(title: "Unlock Hotkey: \(hotkeyManager?.getHotkeyDescription() ?? "Double Shift")", action: #selector(showHotkeySettings), keyEquivalent: "")
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
        showNotification(title: "Keyboard Locked", message: "Press Shift twice to unlock")
    }

    @objc func lockMouse() {
        currentLockMode = .mouse
        inputMonitor?.startMonitoring(mode: .mouse)
        updateMenuBarIcon()
        updateMenu()
        showLockPopover()
        showNotification(title: "Mouse Locked", message: "Press Shift twice to unlock")
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

        let popover = NSPopover()
        popover.contentSize = NSSize(width: 200, height: 100)
        popover.behavior = .applicationDefined
        popover.contentViewController = NSHostingController(rootView: LockPopoverView(
            lockMode: currentLockMode,
            unlockAction: { [weak self] in
                self?.unlockInput()
            }
        ))

        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        lockPopover = popover
    }

    func hideLockPopover() {
        lockPopover?.close()
        lockPopover = nil
    }

    @objc func showHotkeySettings() {
        let alert = NSAlert()
        alert.messageText = "Hotkey Settings"
        alert.informativeText = "Current unlock hotkey: Double Shift\n\nNote: Hotkey customization coming in future version."
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        alert.runModal()
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
    let unlockAction: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            Text(lockMode == .keyboard ? "Keyboard Locked" : "Mouse Locked")
                .font(.headline)
                .padding(.top, 8)

            if lockMode == .keyboard {
                Button("Unlock") {
                    unlockAction()
                }
                .buttonStyle(.borderedProminent)
            } else {
                Text("Press Shift twice to unlock")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }

            Spacer()
        }
        .frame(width: 200, height: 100)
        .padding()
    }
}
