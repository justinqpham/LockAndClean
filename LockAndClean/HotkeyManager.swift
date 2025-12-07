import Cocoa
import Carbon

class HotkeyManager {
    var onHotkeyTriggered: (() -> Void)?

    private var eventMonitor: Any?
    private var lastShiftPressTime: Date?
    private let doublePressInterval: TimeInterval = 0.5
    private var isShiftCurrentlyPressed = false
    private var shiftPressCount = 0

    init() {
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
    }

    func stopMonitoring() {
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
            eventMonitor = nil
        }
    }

    private func handleFlagsChanged(_ event: NSEvent) {
        let flags = event.modifierFlags
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

    func getHotkeyDescription() -> String {
        return "Double Shift"
    }
}
