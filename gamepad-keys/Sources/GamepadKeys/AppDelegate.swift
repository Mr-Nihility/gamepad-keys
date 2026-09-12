import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {

    private let state = AppState()
    private var statusItem: NSStatusItem?
    private var windowController: MappingWindowController?
    private var testSignal: DispatchSourceSignal?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.button?.image = NSImage(systemSymbolName: "gamecontroller",
                                     accessibilityDescription: "GamepadKeys")
        let menu = NSMenu()
        menu.delegate = self
        item.menu = menu
        statusItem = item

        state.onChange = { [weak self] in
            self?.windowController?.refresh()
            self?.updateStatusIcon()
        }
        state.onActivity = { [weak self] in
            self?.windowController?.refreshIndicators()
        }
        Log.shared.onAppend = { [weak self] in
            self?.windowController?.refreshLog()
        }

        updateStatusIcon()

        // `kill -USR1 (pgrep GamepadKeys)` надсилає тестову клавішу.
        // Зручно перевіряти чужу програму, не забираючи в неї фокус.
        signal(SIGUSR1, SIG_IGN)
        let source = DispatchSource.makeSignalSource(signal: SIGUSR1, queue: .main)
        source.setEventHandler { [weak self] in self?.state.sendTestKey() }
        source.resume()
        testSignal = source

        // Без дозволу програма марна — просимо одразу, ще до відкриття вікна.
        if !state.hasPermission {
            state.requestPermission()
            showWindow()
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        // Інакше клавіша, затиснута в мить виходу, залишиться натиснутою в системі.
        state.cancelCapture()
    }

    private func updateStatusIcon() {
        let name = state.controllerName == nil ? "gamecontroller" : "gamecontroller.fill"
        statusItem?.button?.image = NSImage(systemSymbolName: name,
                                            accessibilityDescription: "GamepadKeys")
    }

    // MARK: - Меню

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()

        let status = NSMenuItem(title: state.controllerName ?? "Контролер не підключений",
                                action: nil, keyEquivalent: "")
        status.isEnabled = false
        menu.addItem(status)
        menu.addItem(.separator())

        for profile in state.config.profiles {
            let item = NSMenuItem(title: profile.name,
                                  action: #selector(selectProfile(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = profile.name
            item.state = profile.name == state.config.active.name ? .on : .off
            menu.addItem(item)
        }
        menu.addItem(.separator())

        let mapping = NSMenuItem(title: "Розкладка…", action: #selector(showWindow), keyEquivalent: ",")
        mapping.target = self
        menu.addItem(mapping)

        let launch = NSMenuItem(title: "Запускати при вході",
                                action: #selector(toggleLaunchAtLogin), keyEquivalent: "")
        launch.target = self
        launch.state = state.launchAtLogin ? .on : .off
        menu.addItem(launch)

        if !state.hasPermission {
            let permission = NSMenuItem(title: "Дати дозвіл «Універсальний доступ»…",
                                        action: #selector(openPermissionSettings), keyEquivalent: "")
            permission.target = self
            menu.addItem(permission)
        }

        menu.addItem(.separator())

        let quit = NSMenuItem(title: "Вийти", action: #selector(NSApplication.terminate(_:)),
                              keyEquivalent: "q")
        menu.addItem(quit)
    }

    // MARK: - Дії

    @objc private func selectProfile(_ sender: NSMenuItem) {
        guard let name = sender.representedObject as? String else { return }
        state.activate(name)
    }

    @objc private func showWindow() {
        if windowController == nil {
            windowController = MappingWindowController(state: state)
        }
        NSApp.activate(ignoringOtherApps: true)
        windowController?.showWindow(nil)
        windowController?.window?.makeKeyAndOrderFront(nil)
        windowController?.refresh()
    }

    @objc private func toggleLaunchAtLogin() {
        state.launchAtLogin.toggle()
    }

    @objc private func openPermissionSettings() {
        state.openAccessibilitySettings()
    }
}
