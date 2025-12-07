import Cocoa
import Carbon

class HotkeyManager {
    var onHotkeyTriggered: (() -> Void)?

    private var eventMonitor: Any?
    private var keyDownMonitor: Any?

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
    }

    private func handleKeyDown(_ event: NSEvent) {
        let modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)

        // Check for custom hotkey first
        if let hotkey = customHotkey {
            if event.keyCode == hotkey.keyCode && modifiers == hotkey.modifiers {
                DispatchQueue.main.async { [weak self] in
                    self?.onHotkeyTriggered?()
                }
            }
            return
        }

        // Default: spacebar (no modifiers)
        if event.keyCode == kVK_Space && modifiers.isEmpty {
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
        return "Space"
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
