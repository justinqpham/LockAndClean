import SwiftUI
import Carbon

struct HotkeyConfigView: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var viewModel = HotkeyConfigViewModel()

    var onConfirm: (HotkeyConfig) -> Void

    var body: some View {
        VStack(spacing: 20) {
            Text("Set Unlock Hotkey")
                .font(.title2)
                .fontWeight(.semibold)

            Text("Press any key combination to set as unlock hotkey")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            HotkeyRecorderView(viewModel: viewModel)

            if let conflict = viewModel.conflictDescription {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                    Text(conflict)
                        .font(.caption)
                        .foregroundColor(.orange)
                }
                .padding(.horizontal)
            }

            HStack(spacing: 12) {
                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)

                Button("Confirm") {
                    if let config = viewModel.currentHotkey, !viewModel.hasConflict {
                        onConfirm(config)
                        dismiss()
                    }
                }
                .keyboardShortcut(.defaultAction)
                .disabled(viewModel.currentHotkey == nil || viewModel.hasConflict)
            }
        }
        .padding(24)
        .frame(width: 400, height: 250)
    }
}

struct HotkeyRecorderView: NSViewRepresentable {
    @ObservedObject var viewModel: HotkeyConfigViewModel

    func makeNSView(context: Context) -> HotkeyRecorderNSView {
        let view = HotkeyRecorderNSView()
        view.onHotkeyChanged = { config in
            viewModel.setHotkey(config)
        }
        return view
    }

    func updateNSView(_ nsView: HotkeyRecorderNSView, context: Context) {
        nsView.hotkeyConfig = viewModel.currentHotkey
    }
}

class HotkeyRecorderNSView: NSView {
    var onHotkeyChanged: ((HotkeyConfig) -> Void)?
    var hotkeyConfig: HotkeyConfig? {
        didSet {
            needsDisplay = true
        }
    }

    private var eventMonitor: Any?
    private var isMonitoring = false

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupView()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupView()
    }

    private func setupView() {
        wantsLayer = true
        layer?.cornerRadius = 8
        layer?.borderWidth = 2
        layer?.borderColor = NSColor.controlAccentColor.cgColor
        layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor
    }

    override var acceptsFirstResponder: Bool { true }

    override func becomeFirstResponder() -> Bool {
        layer?.borderColor = NSColor.controlAccentColor.cgColor
        startMonitoring()
        return super.becomeFirstResponder()
    }

    override func resignFirstResponder() -> Bool {
        layer?.borderColor = NSColor.separatorColor.cgColor
        stopMonitoring()
        return super.resignFirstResponder()
    }

    override func mouseDown(with event: NSEvent) {
        window?.makeFirstResponder(self)
    }

    private func startMonitoring() {
        guard !isMonitoring else { return }
        isMonitoring = true

        eventMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .flagsChanged]) { [weak self] event in
            self?.handleKeyEvent(event)
            return nil
        }
    }

    private func stopMonitoring() {
        guard isMonitoring else { return }
        isMonitoring = false

        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
            eventMonitor = nil
        }
    }

    private func handleKeyEvent(_ event: NSEvent) {
        let modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)

        if event.type == .keyDown {
            let keyCode = event.keyCode
            let config = HotkeyConfig(
                keyCode: keyCode,
                modifiers: modifiers,
                characters: event.charactersIgnoringModifiers ?? ""
            )
            onHotkeyChanged?(config)
        } else if event.type == .flagsChanged {
            // Allow modifier-only hotkeys (like Shift, Command, etc.)
            if !modifiers.isEmpty {
                // Use a special keyCode of 0 for modifier-only hotkeys
                let config = HotkeyConfig(
                    keyCode: 0,
                    modifiers: modifiers,
                    characters: ""
                )
                onHotkeyChanged?(config)
            }
        }
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        let text: String
        if let config = hotkeyConfig {
            text = config.displayString
        } else {
            text = "Click here and press a key..."
        }

        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 16, weight: .medium),
            .foregroundColor: NSColor.labelColor
        ]

        let attributedString = NSAttributedString(string: text, attributes: attributes)
        let textSize = attributedString.size()
        let textRect = NSRect(
            x: (bounds.width - textSize.width) / 2,
            y: (bounds.height - textSize.height) / 2,
            width: textSize.width,
            height: textSize.height
        )

        attributedString.draw(in: textRect)
    }

    override var intrinsicContentSize: NSSize {
        return NSSize(width: 300, height: 60)
    }

    deinit {
        stopMonitoring()
    }
}

class HotkeyConfigViewModel: ObservableObject {
    @Published var currentHotkey: HotkeyConfig?
    @Published var conflictDescription: String?
    @Published var hasConflict: Bool = false

    func setHotkey(_ config: HotkeyConfig) {
        currentHotkey = config
        checkForConflicts(config)
    }

    private func checkForConflicts(_ config: HotkeyConfig) {
        let conflicts = HotkeyConflictChecker.checkConflicts(for: config)

        if !conflicts.isEmpty {
            hasConflict = true
            conflictDescription = "Conflict: \(conflicts.joined(separator: ", "))"
        } else {
            hasConflict = false
            conflictDescription = nil
        }
    }
}

struct HotkeyConfig: Codable, Equatable {
    let keyCode: UInt16
    let modifiers: NSEvent.ModifierFlags
    let characters: String

    enum CodingKeys: String, CodingKey {
        case keyCode
        case modifiersRawValue
        case characters
    }

    init(keyCode: UInt16, modifiers: NSEvent.ModifierFlags, characters: String) {
        self.keyCode = keyCode
        self.modifiers = modifiers
        self.characters = characters
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        keyCode = try container.decode(UInt16.self, forKey: .keyCode)
        let rawValue = try container.decode(UInt.self, forKey: .modifiersRawValue)
        modifiers = NSEvent.ModifierFlags(rawValue: rawValue)
        characters = try container.decode(String.self, forKey: .characters)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(keyCode, forKey: .keyCode)
        try container.encode(modifiers.rawValue, forKey: .modifiersRawValue)
        try container.encode(characters, forKey: .characters)
    }

    var displayString: String {
        var parts: [String] = []

        if modifiers.contains(.control) {
            parts.append("⌃")
        }
        if modifiers.contains(.option) {
            parts.append("⌥")
        }
        if modifiers.contains(.shift) {
            parts.append("⇧")
        }
        if modifiers.contains(.command) {
            parts.append("⌘")
        }

        // Only add key string if keyCode is not 0 (modifier-only hotkeys use keyCode 0)
        if keyCode != 0 {
            let keyString = keyCodeToString(keyCode)
            parts.append(keyString)
        }

        return parts.joined()
    }

    private func keyCodeToString(_ keyCode: UInt16) -> String {
        switch Int(keyCode) {
        case kVK_Return: return "↩"
        case kVK_Tab: return "⇥"
        case kVK_Space: return "Space"
        case kVK_Delete: return "⌫"
        case kVK_Escape: return "⎋"
        case kVK_ForwardDelete: return "⌦"
        case kVK_Home: return "↖"
        case kVK_End: return "↘"
        case kVK_PageUp: return "⇞"
        case kVK_PageDown: return "⇟"
        case kVK_LeftArrow: return "←"
        case kVK_RightArrow: return "→"
        case kVK_DownArrow: return "↓"
        case kVK_UpArrow: return "↑"
        case kVK_F1: return "F1"
        case kVK_F2: return "F2"
        case kVK_F3: return "F3"
        case kVK_F4: return "F4"
        case kVK_F5: return "F5"
        case kVK_F6: return "F6"
        case kVK_F7: return "F7"
        case kVK_F8: return "F8"
        case kVK_F9: return "F9"
        case kVK_F10: return "F10"
        case kVK_F11: return "F11"
        case kVK_F12: return "F12"
        case kVK_F13: return "F13"
        case kVK_F14: return "F14"
        case kVK_F15: return "F15"
        case kVK_F16: return "F16"
        case kVK_F17: return "F17"
        case kVK_F18: return "F18"
        case kVK_F19: return "F19"
        case kVK_F20: return "F20"
        default:
            return characters.uppercased()
        }
    }
}

struct HotkeyConflictChecker {
    static func checkConflicts(for config: HotkeyConfig) -> [String] {
        var conflicts: [String] = []

        let commonShortcuts: [(HotkeyConfig, String)] = [
            (HotkeyConfig(keyCode: 0x00, modifiers: [.command], characters: "a"), "Select All"),
            (HotkeyConfig(keyCode: 0x08, modifiers: [.command], characters: "c"), "Copy"),
            (HotkeyConfig(keyCode: 0x09, modifiers: [.command], characters: "v"), "Paste"),
            (HotkeyConfig(keyCode: 0x07, modifiers: [.command], characters: "x"), "Cut"),
            (HotkeyConfig(keyCode: 0x06, modifiers: [.command], characters: "z"), "Undo"),
            (HotkeyConfig(keyCode: 0x10, modifiers: [.command], characters: "w"), "Close Window"),
            (HotkeyConfig(keyCode: 0x0C, modifiers: [.command], characters: "q"), "Quit"),
            (HotkeyConfig(keyCode: 0x31, modifiers: [.command], characters: " "), "Spotlight"),
            (HotkeyConfig(keyCode: 0x30, modifiers: [.command], characters: "\t"), "Switch Apps"),
        ]

        for (shortcut, name) in commonShortcuts {
            if config.keyCode == shortcut.keyCode &&
               config.modifiers == shortcut.modifiers {
                conflicts.append(name)
            }
        }

        return conflicts
    }
}
