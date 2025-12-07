import Cocoa
import ApplicationServices

class InputMonitor {
    enum MonitorMode {
        case keyboard
        case mouse
    }

    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var currentMode: MonitorMode?
    private var localEventMonitor: Any?
    private var globalEventMonitor: Any?
    private var frozenMouseLocation: CGPoint?

    func startMonitoring(mode: MonitorMode) {
        stopMonitoring()
        currentMode = mode

        let eventMask: CGEventMask
        switch mode {
        case .keyboard:
            let mask1: CGEventMask = 1 << CGEventType.keyDown.rawValue
            let mask2: CGEventMask = 1 << CGEventType.keyUp.rawValue
            let mask3: CGEventMask = 1 << CGEventType.flagsChanged.rawValue
            // Add system-defined events to capture F1-F12 special functions (brightness, volume, etc.)
            let mask4: CGEventMask = 1 << CGEventType(rawValue: 14)!.rawValue  // NSEventTypeSystemDefined
            eventMask = mask1 | mask2 | mask3 | mask4
        case .mouse:
            let mask1: CGEventMask = 1 << CGEventType.leftMouseDown.rawValue
            let mask2: CGEventMask = 1 << CGEventType.leftMouseUp.rawValue
            let mask3: CGEventMask = 1 << CGEventType.rightMouseDown.rawValue
            let mask4: CGEventMask = 1 << CGEventType.rightMouseUp.rawValue
            let mask5: CGEventMask = 1 << CGEventType.mouseMoved.rawValue
            let mask6: CGEventMask = 1 << CGEventType.leftMouseDragged.rawValue
            let mask7: CGEventMask = 1 << CGEventType.rightMouseDragged.rawValue
            let mask8: CGEventMask = 1 << CGEventType.scrollWheel.rawValue
            let mask9: CGEventMask = 1 << CGEventType.otherMouseDown.rawValue
            let mask10: CGEventMask = 1 << CGEventType.otherMouseUp.rawValue
            eventMask = mask1 | mask2 | mask3 | mask4 | mask5 | mask6 | mask7 | mask8 | mask9 | mask10
        }

        let callback: CGEventTapCallBack = { proxy, type, event, refcon in
            let monitor = Unmanaged<InputMonitor>.fromOpaque(refcon!).takeUnretainedValue()
            return monitor.handleEvent(proxy: proxy, type: type, event: event)
        }

        let selfPtr = Unmanaged.passUnretained(self).toOpaque()

        guard let tap = CGEvent.tapCreate(
            tap: .cghidEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: eventMask,
            callback: callback,
            userInfo: selfPtr
        ) else {
            print("Failed to create event tap")
            return
        }

        eventTap = tap
        runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)

        if mode == .keyboard {
            setupNSEventMonitoring()
        } else if mode == .mouse {
            let mouseLocation = CGEvent(source: nil)?.location ?? CGPoint.zero
            frozenMouseLocation = mouseLocation
        }
    }

    private func setupNSEventMonitoring() {
        // Block regular keyboard events
        localEventMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .keyUp, .flagsChanged]) { event in
            print("Local NSEvent - keyCode: \(event.keyCode), characters: \(event.characters ?? "nil")")
            return nil
        }

        globalEventMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.keyDown, .keyUp, .flagsChanged]) { event in
            print("Global NSEvent - keyCode: \(event.keyCode)")
        }
    }

    func stopMonitoring() {
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
            if let source = runLoopSource {
                CFRunLoopRemoveSource(CFRunLoopGetCurrent(), source, .commonModes)
            }
            eventTap = nil
            runLoopSource = nil
        }

        if let monitor = localEventMonitor {
            NSEvent.removeMonitor(monitor)
            localEventMonitor = nil
        }

        if let monitor = globalEventMonitor {
            NSEvent.removeMonitor(monitor)
            globalEventMonitor = nil
        }

        frozenMouseLocation = nil
        currentMode = nil
    }

    private func handleEvent(proxy: CGEventTapProxy, type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        guard let mode = currentMode else {
            return Unmanaged.passUnretained(event)
        }

        switch type {
        case .tapDisabledByTimeout, .tapDisabledByUserInput:
            if let tap = eventTap {
                CGEvent.tapEnable(tap: tap, enable: true)
            }
            return Unmanaged.passUnretained(event)
        default:
            break
        }

        switch mode {
        case .keyboard:
            if type == .keyDown || type == .keyUp || type == .flagsChanged {
                let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
                print("Blocking keyboard event - type: \(type.rawValue), keyCode: \(keyCode)")
                return nil
            }
            // Block system-defined events (brightness, volume, media keys, etc.)
            if type.rawValue == 14 {  // NSEventTypeSystemDefined
                print("Blocking system-defined event (special function key)")
                return nil
            }
        case .mouse:
            if isMouseEvent(type) {
                if let frozenLocation = frozenMouseLocation {
                    if type == .mouseMoved || type == .leftMouseDragged || type == .rightMouseDragged {
                        CGWarpMouseCursorPosition(frozenLocation)
                    }
                }
                return nil
            }
        }

        return Unmanaged.passUnretained(event)
    }

    private func isMouseEvent(_ type: CGEventType) -> Bool {
        switch type {
        case .leftMouseDown, .leftMouseUp, .rightMouseDown, .rightMouseUp,
             .mouseMoved, .leftMouseDragged, .rightMouseDragged,
             .scrollWheel, .otherMouseDown, .otherMouseUp:
            return true
        default:
            return false
        }
    }
}
