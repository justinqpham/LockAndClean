# LockAndClean

A macOS menu bar app that lets you lock keyboard or mouse input so you can safely clean your computer.

## Features

- **Menu Bar App** - Sits in your macOS menu bar with dynamic lock/unlock icon
- **Keyboard Lock** - Disables all keyboard input including function keys (F1-F12, Esc)
- **Mouse/Trackpad Lock** - Completely freezes mouse cursor and disables all clicks/scrolling
- **Visual Feedback** - Persistent popover shows lock status with unlock instructions
- **Quick Unlock Hotkey** - Press Shift key twice quickly to unlock
- **Dual Unlock Methods** - Unlock via hotkey or click the Unlock button (keyboard mode only)
- **System Notifications** - Get notified when input is locked/unlocked

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
3. **When Locked** - The menu bar icon changes to a closed lock and a persistent popover appears showing:
   - For keyboard lock: "Keyboard Locked" with an Unlock button
   - For mouse lock: "Mouse Locked" with instructions to press Shift twice
4. Clean your computer safely while input is disabled
5. To unlock:
   - Press **Shift** key twice quickly (works for both modes)
   - Or click the **Unlock** button in the popover (keyboard mode only)

## Technical Details

- **Minimum macOS**: 13.0 (Ventura)
- **Architecture**: Universal Binary (Apple Silicon + Intel)
- **Code Signing**: Automatic signing with your development team
- **Sandbox**: Disabled (required for accessibility features)

## Project Structure

- `LockAndCleanApp.swift` - Main app entry point
- `AppDelegate.swift` - Menu bar UI, popover, and app logic
- `InputMonitor.swift` - Low-level input blocking using CGEvent and NSEvent APIs
- `HotkeyManager.swift` - Double Shift hotkey detection
- `Assets.xcassets` - App icon and resources

## How It Works

### Keyboard Locking
- Uses both CGEvent tap and NSEvent monitors to capture all keyboard events
- Blocks regular keys, function keys (F1-F12), Escape, and modifier keys
- Returns `nil` for all keyboard events to prevent them from being processed
- HID event tap ensures comprehensive coverage of all keyboard input

### Mouse Locking
- Captures current mouse position when lock is activated
- Uses CGEvent tap to intercept all mouse events (clicks, scrolling, movement)
- Calls `CGWarpMouseCursorPosition()` to reset cursor to frozen position on movement
- Blocks all mouse button events and scroll wheel events

### Unlock Mechanism
- HotkeyManager monitors for flagsChanged events to detect Shift key presses
- Tracks double-press timing (within 0.5 seconds)
- Works independently of input locking to ensure unlock is always available

## App Icon

The app uses a custom icon from `appIcon.png`, automatically resized to all required macOS app icon sizes (16x16 to 1024x1024).

## Notes

- The app runs in the background (LSUIElement = true, doesn't appear in the Dock)
- Only one input type can be locked at a time
- Menu bar icon dynamically changes between open lock (unlocked) and closed lock (locked)
- Persistent popover provides clear visual feedback of lock status
- Notifications require user permission on first run
- App Sandbox is disabled to allow CGEvent tap functionality
