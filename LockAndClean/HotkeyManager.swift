import Cocoa
import Carbon

class HotkeyManager {
    var onHotkeyTriggered: (() -> Void)?

    private var eventMonitor: Any?
    private var keyDownMonitor: Any?
    private var lastShiftPressTime: Date?
    private let doublePressInterval: TimeInterval = 0.5
    private var isShiftCurrentlyPressed = false
    private var shiftPressCount = 0

    private var customHotkey: HotkeyConfig? {
        didSet {
            saveHotkey()
        }
    }

    init() {
        loadHotkey()
        startMonitoring()
    }

    deinit {
        stopMonitoring()
    }

    func startMonitoring() {
        eventMonitor = NSEvent.addGlobalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
            self?.handleFlagsChanged(event)
        }

        NSEvent.addLocalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
            self?.handleFlagsChanged(event)
            return event
        }

        keyDownMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            self?.handleKeyDown(event)
            return event
        }

        NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            self?.handleKeyDown(event)
        }
    }

    func stopMonitoring() {
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
            eventMonitor = nil
        }

        if let monitor = keyDownMonitor {
            NSEvent.removeMonitor(monitor)
            keyDownMonitor = nil
        }
    }

    private func handleFlagsChanged(_ event: NSEvent) {
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)

        // Check if custom hotkey is a modifier-only hotkey (keyCode == 0)
        if let hotkey = customHotkey, hotkey.keyCode == 0 {
            // For modifier-only hotkeys, trigger when the modifiers match
            if flags == hotkey.modifiers {
                DispatchQueue.main.async { [weak self] in
                    self?.onHotkeyTriggered?()
                }
                return
            }
        }

        // Default double-shift behavior
        let shiftPressed = flags.contains(.shift)

        if shiftPressed && !isShiftCurrentlyPressed {
            let now = Date()

            if let lastPress = lastShiftPressTime,
               now.timeIntervalSince(lastPress) < doublePressInterval {
                shiftPressCount += 1

                if shiftPressCount == 1 {
                    DispatchQueue.main.async { [weak self] in
                        self?.onHotkeyTriggered?()
                    }
                    shiftPressCount = 0
                    lastShiftPressTime = nil
                    return
                }
            } else {
                shiftPressCount = 0
            }

            lastShiftPressTime = now
            isShiftCurrentlyPressed = true

        } else if !shiftPressed && isShiftCurrentlyPressed {
            isShiftCurrentlyPressed = false
        }
    }

    private func handleKeyDown(_ event: NSEvent) {
        guard let hotkey = customHotkey else { return }

        let modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)

        if event.keyCode == hotkey.keyCode && modifiers == hotkey.modifiers {
            DispatchQueue.main.async { [weak self] in
                self?.onHotkeyTriggered?()
            }
        }
    }

    func setCustomHotkey(_ config: HotkeyConfig) {
        customHotkey = config
        stopMonitoring()
        startMonitoring()
    }

    func getHotkeyDescription() -> String {
        if let hotkey = customHotkey {
            return hotkey.displayString
        }
        return "Double Shift"
    }

    private func saveHotkey() {
        if let hotkey = customHotkey {
            if let encoded = try? JSONEncoder().encode(hotkey) {
                UserDefaults.standard.set(encoded, forKey: "customHotkey")
            }
        } else {
            UserDefaults.standard.removeObject(forKey: "customHotkey")
        }
    }

    private func loadHotkey() {
        if let data = UserDefaults.standard.data(forKey: "customHotkey"),
           let hotkey = try? JSONDecoder().decode(HotkeyConfig.self, from: data) {
            customHotkey = hotkey
        }
    }
}
