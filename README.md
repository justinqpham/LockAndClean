# LockAndClean

A macOS menu bar app that lets you lock keyboard or mouse input so you can safely clean your computer.

## Features

- **Menu Bar App** - Sits in your macOS menu bar with dynamic lock/unlock icon and launch animation
- **Keyboard Lock** - Disables all keyboard input including:
  - Regular keys and modifier keys
  - Function keys (F1-F12, Esc)
  - Special function keys (brightness, volume, Mission Control, media controls)
- **Mouse/Trackpad Lock** - Completely freezes mouse cursor and disables all clicks/scrolling
- **Visual Feedback** - Polished popovers with native macOS design showing lock status
- **Customizable Unlock Hotkey** - Set any key combination as your unlock hotkey
- **Default Hotkey** - Double Shift press (works when no custom hotkey is set)
- **Dual Unlock Methods** - Unlock via hotkey or click the Unlock button (keyboard mode only)
- **System Notifications** - Get notified when input is locked/unlocked with current hotkey
- **Launch Animation** - Welcome popover and icon bounce animation on app launch

## Building in Xcode

1. Open `LockAndClean.xcodeproj` in Xcode
2. The project is already configured with your development team
3. Build and run the project (Cmd+R)
4. The app will appear in your menu bar with a lock icon

## Required Permissions

The app requires **Accessibility Permission** to monitor and block keyboard/mouse input.

When you first run the app:
1. macOS will prompt you to grant Accessibility permission
2. Go to **System Settings** > **Privacy & Security** > **Accessibility**
3. Enable **LockAndClean** in the list

Without this permission, the app cannot block input.

## How to Use

1. **When Unlocked** - The menu bar shows an open lock icon
2. Click the menu bar icon and choose:
   - **Lock Keyboard** - Disables all keyboard input (mouse still works)
   - **Lock Mouse/Trackpad** - Freezes cursor and disables all mouse input
   - **Unlock Hotkey** - Configure a custom unlock hotkey (default: Double Shift)
3. **When Locked** - The menu bar icon changes to a closed lock and a persistent popover appears showing:
   - For keyboard lock: "Keyboard Locked" with an Unlock button
   - For mouse lock: "Mouse Locked" with instructions to press your configured hotkey
4. Clean your computer safely while input is disabled
5. To unlock:
   - Press your configured hotkey (default: **Double Shift**)
   - Or click the **Unlock** button in the popover (keyboard mode only)

### Setting a Custom Hotkey

1. Click the menu bar icon
2. Select "Unlock Hotkey: [current hotkey]"
3. A window will appear - click in the recorder field
4. Press any key combination (e.g., Cmd+K, Shift+Esc, or even just Shift)
5. The app will check for conflicts with system shortcuts
6. Click "Confirm" to save your hotkey

## Technical Details

- **Minimum macOS**: 13.0 (Ventura)
- **Architecture**: Universal Binary (Apple Silicon + Intel)
- **Code Signing**: Automatic signing with your development team
- **Sandbox**: Disabled (required for accessibility features)

## Project Structure

- `LockAndCleanApp.swift` - Main app entry point
- `AppDelegate.swift` - Menu bar UI, popovers, animations, and app logic
- `InputMonitor.swift` - Low-level input blocking using CGEvent and NSEvent APIs
- `HotkeyManager.swift` - Hotkey detection and management with persistence
- `HotkeyConfigView.swift` - SwiftUI interface for configuring custom hotkeys
- `Assets.xcassets` - App icon and resources

## How It Works

### Keyboard Locking
- Uses both CGEvent tap and NSEvent monitors to capture all keyboard events
- Blocks regular keys, function keys (F1-F12), Escape, and modifier keys
- Blocks system-defined events (brightness, volume, Mission Control, media controls)
- Returns `nil` for all keyboard events to prevent them from being processed
- HID event tap (`.cghidEventTap`) ensures comprehensive coverage of all keyboard input

### Mouse Locking
- Captures current mouse position when lock is activated
- Uses CGEvent tap to intercept all mouse events (clicks, scrolling, movement)
- Calls `CGWarpMouseCursorPosition()` to reset cursor to frozen position on movement
- Blocks all mouse button events and scroll wheel events

### Unlock Mechanism
- HotkeyManager monitors for both `flagsChanged` and `keyDown` events
- Supports custom hotkeys (regular keys, modifier combinations, or modifier-only)
- Default: Tracks double-press timing for Shift key (within 0.5 seconds)
- Works independently of input locking to ensure unlock is always available
- Hotkey settings are persisted using UserDefaults

### Custom Hotkey System
- Interactive hotkey recorder using NSView with event monitoring
- Real-time conflict detection with common macOS shortcuts
- Supports modifier-only hotkeys (e.g., just Shift or Command)
- Supports key combinations (e.g., Cmd+K, Shift+Esc)
- Displays hotkeys using macOS symbols (⌘ ⌥ ⌃ ⇧)

## App Icon

The app uses a custom icon from `appIcon.png`, automatically resized to all required macOS app icon sizes (16x16 to 1024x1024).

## Notes

- The app runs in the background (LSUIElement = true, doesn't appear in the Dock)
- Only one input type can be locked at a time
- Menu bar icon dynamically changes between open lock (unlocked) and closed lock (locked)
- Launch animation: Icon bounce + welcome popover on first launch
- Persistent popover provides clear visual feedback of lock status
- Popovers use native macOS design with proper system fonts and colors
- Notifications require user permission on first run
- App Sandbox is disabled to allow CGEvent tap functionality
- Custom hotkeys are saved and restored between app launches
