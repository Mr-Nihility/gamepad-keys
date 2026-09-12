# Repository Guidelines

## Project Structure & Module Organization

`gamepad-keys/` contains GamepadKeys, a macOS 13+ menu-bar application mapping controller input to system keyboard and mouse events. It uses Swift Package Manager and AppKit, with no external package dependencies.

- `Sources/GamepadKeys/`: application state, mapping UI, configuration, and input senders.
- `Tools/make-icon.swift`: generates icon assets into `.build/`.
- `Info.plist`: application bundle metadata.
- `test-keys.html`: manual browser keyboard-event checker.

Read `CLAUDE.md` before changing input handling, configuration, or signing; it documents architectural constraints and known failure modes. See `gamepad-keys/README.md` for setup and usage.

## Build, Test, and Development Commands

Run commands from `gamepad-keys/`. Install macOS Command Line Tools first.

- `swift build`: compile the executable for development.
- `make app`: build the release bundle at `.build/GamepadKeys.app`.
- `make install`: build and replace `/Applications/GamepadKeys.app`, stopping any running instance.
- `make run`: install and launch the application.
- `make icon`: generate the application icon.
- `make cert`: create a local signing certificate; modifies the login Keychain.
- `make clean`: remove generated build output.

Launch the installed application for functional checks; its path and signing identity affect Accessibility permission.

## Coding Style & Naming Conventions

Match existing Swift style: four-space indentation, `UpperCamelCase` types, and `lowerCamelCase` functions and properties. Name source files after their primary type. Keep code comments and existing documentation in Ukrainian. Use AppKit and existing mapping/sender components. No formatter or linter configuration is present.

## Testing Guidelines

There is no automated test target, testing framework, or coverage threshold. Build changed code, then verify affected behavior with a controller and `test-keys.html` in a browser. Check press/release pairs, profile switching, and mouse movement when relevant. Inspect `~/.config/gamepad-keys/log.txt`; it resets on launch. Report hardware checks that could not be performed.

## Commit & Pull Request Guidelines

This checkout has no Git metadata, so commit conventions cannot be verified. Use concise, imperative commit subjects. PRs should describe the behavior change, link relevant issues, list build/manual-check results, and include screenshots for UI changes.

## Configuration Safety

Quit the application before editing `~/.config/gamepad-keys/config.json`; automatic saves can overwrite external edits. Preserve compatibility with legacy configuration files.
