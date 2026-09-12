# GamepadKeys

**Control your keyboard and mouse with a gamepad on macOS.**

GamepadKeys lives in the menu bar and turns controller buttons and stick movements
into system keyboard and mouse events. Use it with browser games that lack Gamepad
API support or apps designed for keyboard input.

Built with Swift and AppKit. No third-party packages or kernel drivers.
The app interface is currently in Ukrainian.

## Features

- Map controller buttons to keys, shortcuts such as `cmd+shift+a`, and mouse buttons.
- Use sticks for WASD, arrow keys, or cursor movement with adjustable speed and dead zones.
- Repeat held inputs approximately 10 times per second, enabled separately for each profile.
- Create, duplicate, and switch profiles with automatic saving.
- Receive input in the background, with activity indicators and an event log.
- Send mouse movement deltas for browser games using Pointer Lock.
- Optionally launch at login.

## Requirements

- macOS 13 or later.
- Command Line Tools: `xcode-select --install`.
- A gamepad recognized by macOS through `GameController` as an extended gamepad.
- **Accessibility** permission to send input to other apps.

A full Xcode installation is not required. Button availability depends on the
controller and macOS; compatibility with every game is not guaranteed.

## Quick start

```sh
git clone https://github.com/Mr-Nihility/gamepad-keys.git
cd gamepad-keys/gamepad-keys
make run
```

`make run` builds the app, installs it at `/Applications/GamepadKeys.app`, and
launches it. Reinstalling stops any currently running instance.

1. Connect your gamepad via Bluetooth or USB.
2. Open **System Settings → Privacy & Security → Accessibility** and grant GamepadKeys access.
3. Click the gamepad icon in the menu bar → **«Розкладка…»** (Mapping).
4. Click a key assignment and press the desired key. Use the **⌄** menu to assign a mouse button.
5. Switch to your game or another app and try the controls.

The default mapping uses the left stick for WASD, the right stick for the cursor,
and `A` for Space. Enable **«Повторювати при утриманні»** (Repeat while held) for
repeated input. With this option disabled, a mapped key stays down until you
release the controller button.

### Signing after a rebuild

Launch the copy in `/Applications`: the app's path and signing identity affect
Accessibility permission. Without a stable signature, you may need to remove the
app from the permission list with **−** and add it again with **+** after rebuilding.

Optionally run `make cert`, then `make install`, to use a stable local signature.
`make cert` creates a self-signed certificate and adds it to your login Keychain;
macOS may prompt for your password.

## Development and testing

Run all commands from the nested `gamepad-keys/` directory:

| Command | Purpose |
| --- | --- |
| `swift build` | Build for development |
| `make app` | Create a release bundle at `.build/GamepadKeys.app` |
| `make install` | Build and install in `/Applications` |
| `make run` | Install and launch |
| `make test` | Check input repeat and configuration compatibility |
| `make icon` | Generate the app icon |
| `make clean` | Remove build output |

Tests intercept events before they reach macOS and leave your configuration and
log files untouched. To check actual input, open
[`test-keys.html`](gamepad-keys/test-keys.html) in a browser and use your gamepad.

## Configuration and troubleshooting

- Configuration: `~/.config/gamepad-keys/config.json`.
- Log: `~/.config/gamepad-keys/log.txt`, overwritten on launch.
- **«Тест клавіші»** (Test key) in the mapping window sends Space to check permission without a gamepad.

Quit the app before editing its configuration manually so automatic saving does
not overwrite your changes. See the [user guide in Ukrainian](gamepad-keys/README.md)
for profile settings, button names, and the JSON format.

## Contributing

Bug reports and pull requests are welcome.

1. Fork the repository and create a branch for your change.
2. Follow the [repository guidelines](AGENTS.md) and existing Swift style.
3. Run `make test` and `swift build`; check input changes with a gamepad.
4. Describe the problem, your change, and verification results in the PR. Include screenshots for UI changes.

When [reporting a bug](https://github.com/Mr-Nihility/gamepad-keys/issues), include
your macOS version, controller model, connection method, reproduction steps, and
a relevant log excerpt. Review logs before posting: they contain button presses
and key assignments.

App source lives in `gamepad-keys/Sources/GamepadKeys/`, checks in
`gamepad-keys/Tests/`, and the icon generator in `gamepad-keys/Tools/`.

## License

A `LICENSE` file has not been added yet; the project license has not been selected.
