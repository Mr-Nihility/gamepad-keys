import AppKit

/// Вікно розкладки: шапка з профілями, попередження про дозвіл і список слотів.
final class MappingWindowController: NSWindowController, NSWindowDelegate, NSTextFieldDelegate {

    private let state: AppState

    private let profilePopup = NSPopUpButton()
    private let nameField = NSTextField()
    private let repeatCheckbox = NSButton(checkboxWithTitle: "Повторювати при утриманні", target: nil, action: nil)
    private let deleteButton = NSButton()
    private let controllerLabel = NSTextField(labelWithString: "")
    private let permissionBar = NSStackView()
    private let connectionBar = NSStackView()
    private let connectionDot = NSView()
    private let connectionLabel = NSTextField(labelWithString: "")
    private let connectionHint = NSTextField(labelWithString: "")
    private let contentStack = NSStackView()
    private let logView = NSTextView()

    private var rows: [Slot: SlotRowView] = [:]
    private var deadzoneSliders: [String: NSSlider] = [:]
    private var deadzoneLabels: [String: NSTextField] = [:]
    private var speedSliders: [String: NSSlider] = [:]
    private var speedLabels: [String: NSTextField] = [:]
    private var modePopups: [String: NSPopUpButton] = [:]
    /// Рядки напрямків і рядок швидкості ховаються залежно від режиму стіка.
    private var stickDirectionRows: [String: [NSView]] = [:]
    private var speedRows: [String: NSView] = [:]

    init(state: AppState) {
        self.state = state

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 540, height: 660),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Розкладка"
        window.minSize = NSSize(width: 480, height: 420)
        window.center()

        super.init(window: window)
        window.delegate = self
        buildLayout()
        buildRows()
        refresh()
        refreshLog()
    }

    required init?(coder: NSCoder) { fatalError("не використовується") }

    // MARK: - Каркас

    private func buildLayout() {
        profilePopup.target = self
        profilePopup.action = #selector(profileChanged)
        profilePopup.translatesAutoresizingMaskIntoConstraints = false
        profilePopup.widthAnchor.constraint(equalToConstant: 170).isActive = true

        nameField.placeholderString = "назва профілю"
        nameField.delegate = self
        nameField.translatesAutoresizingMaskIntoConstraints = false
        nameField.widthAnchor.constraint(equalToConstant: 150).isActive = true

        let addButton = NSButton(image: NSImage(systemSymbolName: "plus", accessibilityDescription: "Новий профіль")!,
                                 target: self, action: #selector(addProfile))
        addButton.bezelStyle = .rounded
        addButton.toolTip = "Новий профіль — копія поточного"

        deleteButton.image = NSImage(systemSymbolName: "minus", accessibilityDescription: "Видалити профіль")
        deleteButton.bezelStyle = .rounded
        deleteButton.target = self
        deleteButton.action = #selector(deleteProfile)
        deleteButton.toolTip = "Видалити профіль"

        let headerSpacer = NSView()
        headerSpacer.setContentHuggingPriority(.init(1), for: .horizontal)

        controllerLabel.font = .systemFont(ofSize: NSFont.smallSystemFontSize)
        controllerLabel.textColor = .secondaryLabelColor

        let header = NSStackView(views: [profilePopup, nameField, addButton, deleteButton,
                                         headerSpacer, controllerLabel])
        header.orientation = .horizontal
        header.alignment = .centerY
        header.spacing = 8
        header.edgeInsets = NSEdgeInsets(top: 10, left: 12, bottom: 10, right: 12)

        buildPermissionBar()
        buildConnectionBar()

        contentStack.orientation = .vertical
        contentStack.alignment = .leading
        contentStack.spacing = 4
        contentStack.edgeInsets = NSEdgeInsets(top: 8, left: 12, bottom: 12, right: 12)
        contentStack.translatesAutoresizingMaskIntoConstraints = false

        let scroll = NSScrollView()
        scroll.hasVerticalScroller = true
        scroll.drawsBackground = false
        scroll.documentView = contentStack
        scroll.translatesAutoresizingMaskIntoConstraints = false

        // Без цієї прив'язки ширини стек «схлопнеться» по вмісту
        // і рядки не розтягнуться на все вікно.
        contentStack.widthAnchor.constraint(equalTo: scroll.widthAnchor).isActive = true

        let logPanel = buildLogPanel()

        let root = NSStackView(views: [header, permissionBar, connectionBar, scroll, logPanel])
        root.orientation = .vertical
        root.alignment = .leading
        root.spacing = 0
        root.translatesAutoresizingMaskIntoConstraints = false

        let container = NSView()
        container.addSubview(root)
        window?.contentView = container

        NSLayoutConstraint.activate([
            root.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            root.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            root.topAnchor.constraint(equalTo: container.topAnchor),
            root.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            header.widthAnchor.constraint(equalTo: root.widthAnchor),
            permissionBar.widthAnchor.constraint(equalTo: root.widthAnchor),
            connectionBar.widthAnchor.constraint(equalTo: root.widthAnchor),
            scroll.widthAnchor.constraint(equalTo: root.widthAnchor),
            logPanel.widthAnchor.constraint(equalTo: root.widthAnchor),
        ])
    }

    private func buildConnectionBar() {
        connectionDot.wantsLayer = true
        connectionDot.layer?.cornerRadius = 5
        connectionDot.translatesAutoresizingMaskIntoConstraints = false
        connectionDot.widthAnchor.constraint(equalToConstant: 10).isActive = true
        connectionDot.heightAnchor.constraint(equalToConstant: 10).isActive = true

        connectionLabel.font = .systemFont(ofSize: NSFont.systemFontSize, weight: .medium)

        connectionHint.font = .systemFont(ofSize: NSFont.smallSystemFontSize)
        connectionHint.textColor = .secondaryLabelColor

        let spacer = NSView()
        spacer.setContentHuggingPriority(.init(1), for: .horizontal)

        connectionBar.setViews([connectionDot, connectionLabel, connectionHint, spacer], in: .leading)
        connectionBar.orientation = .horizontal
        connectionBar.alignment = .centerY
        connectionBar.spacing = 8
        connectionBar.edgeInsets = NSEdgeInsets(top: 8, left: 12, bottom: 8, right: 12)
        connectionBar.wantsLayer = true
        connectionBar.layer?.backgroundColor = NSColor.textBackgroundColor.cgColor
    }

    private func buildLogPanel() -> NSView {
        let title = NSTextField(labelWithString: "Журнал")
        title.font = .systemFont(ofSize: NSFont.smallSystemFontSize, weight: .semibold)
        title.textColor = .secondaryLabelColor

        let spacer = NSView()
        spacer.setContentHuggingPriority(.init(1), for: .horizontal)

        let test = NSButton(title: "Тест клавіші", target: self, action: #selector(sendTestKey))
        test.bezelStyle = .rounded
        test.toolTip = "Надіслати «space» — перевірка дозволу окремо від контролера"

        let copy = NSButton(title: "Копіювати", target: self, action: #selector(copyLog))
        copy.bezelStyle = .rounded

        let clear = NSButton(title: "Очистити", target: self, action: #selector(clearLog))
        clear.bezelStyle = .rounded

        let toolbar = NSStackView(views: [title, spacer, test, copy, clear])
        toolbar.orientation = .horizontal
        toolbar.alignment = .centerY
        toolbar.spacing = 6
        toolbar.edgeInsets = NSEdgeInsets(top: 6, left: 12, bottom: 4, right: 12)

        logView.isEditable = false
        logView.isSelectable = true
        logView.drawsBackground = true
        logView.backgroundColor = .textBackgroundColor
        logView.font = .monospacedSystemFont(ofSize: 10, weight: .regular)
        logView.isVerticallyResizable = true
        logView.isHorizontallyResizable = false
        logView.autoresizingMask = [.width]
        logView.minSize = .zero
        logView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude,
                                 height: CGFloat.greatestFiniteMagnitude)
        logView.textContainer?.widthTracksTextView = true

        let logScroll = NSScrollView()
        logScroll.hasVerticalScroller = true
        logScroll.borderType = .noBorder
        logScroll.documentView = logView
        logScroll.translatesAutoresizingMaskIntoConstraints = false
        logScroll.heightAnchor.constraint(equalToConstant: 160).isActive = true

        let panel = NSStackView(views: [toolbar, logScroll])
        panel.orientation = .vertical
        panel.alignment = .leading
        panel.spacing = 0

        NSLayoutConstraint.activate([
            toolbar.widthAnchor.constraint(equalTo: panel.widthAnchor),
            logScroll.widthAnchor.constraint(equalTo: panel.widthAnchor),
        ])
        return panel
    }

    private func buildPermissionBar() {
        let icon = NSImageView(image: NSImage(systemSymbolName: "exclamationmark.triangle.fill",
                                              accessibilityDescription: nil)!)
        icon.contentTintColor = .systemOrange

        let text = NSTextField(labelWithString:
            "Немає дозволу «Універсальний доступ» — клавіші не надсилаються.")
        text.font = .systemFont(ofSize: NSFont.smallSystemFontSize)

        let spacer = NSView()
        spacer.setContentHuggingPriority(.init(1), for: .horizontal)

        let open = NSButton(title: "Відкрити налаштування", target: self,
                            action: #selector(openPermissionSettings))
        open.bezelStyle = .rounded

        permissionBar.setViews([icon, text, spacer, open], in: .leading)
        permissionBar.orientation = .horizontal
        permissionBar.alignment = .centerY
        permissionBar.spacing = 8
        permissionBar.edgeInsets = NSEdgeInsets(top: 8, left: 12, bottom: 8, right: 12)
        permissionBar.wantsLayer = true
        permissionBar.layer?.backgroundColor = NSColor.systemOrange.withAlphaComponent(0.12).cgColor
    }

    // MARK: - Рядки

    private func buildRows() {
        repeatCheckbox.target = self
        repeatCheckbox.action = #selector(repeatChanged)
        repeatCheckbox.toolTip = "Повторювати клавіші й кліки миші 10 разів на секунду для поточного профілю"
        contentStack.addArrangedSubview(repeatCheckbox)
        contentStack.addArrangedSubview(sectionHeader("Кнопки"))
        for name in Mapper.buttonNames {
            addRow(for: .button(name))
        }

        for (side, title) in [("L", "Лівий стік"), ("R", "Правий стік")] {
            contentStack.addArrangedSubview(stickHeader(title, side: side))

            var directionRows: [NSView] = []
            for direction in Slot.stickDirections {
                directionRows.append(addRow(for: .stick(side: side, direction: direction)))
            }
            stickDirectionRows[side] = directionRows

            let speed = speedRow(side: side)
            speedRows[side] = speed
            contentStack.addArrangedSubview(speed)

            contentStack.addArrangedSubview(deadzoneRow(side: side))
        }
    }

    @discardableResult
    private func addRow(for slot: Slot) -> SlotRowView {
        let row = SlotRowView(
            slot: slot,
            onAssign: { [weak self] in self?.state.beginCapture(slot) },
            onMouse: { [weak self] button in
                self?.state.setKey(Action.mouse(button).text, for: slot)
            },
            onClear: { [weak self] in self?.state.setKey(nil, for: slot) }
        )
        rows[slot] = row
        contentStack.addArrangedSubview(row)
        row.widthAnchor.constraint(equalTo: contentStack.widthAnchor, constant: -24).isActive = true
        return row
    }

    /// Заголовок секції стіка з перемикачем «клавіші / миша».
    private func stickHeader(_ title: String, side: String) -> NSView {
        let label = NSTextField(labelWithString: title)
        label.font = .systemFont(ofSize: NSFont.smallSystemFontSize, weight: .semibold)
        label.textColor = .secondaryLabelColor

        let popup = NSPopUpButton()
        popup.addItem(withTitle: "клавіші")
        popup.lastItem?.representedObject = StickMode.keys.rawValue
        popup.addItem(withTitle: "миша")
        popup.lastItem?.representedObject = StickMode.mouse.rawValue
        popup.target = self
        popup.action = #selector(modeChanged(_:))
        popup.identifier = NSUserInterfaceItemIdentifier(side)
        popup.translatesAutoresizingMaskIntoConstraints = false
        popup.widthAnchor.constraint(equalToConstant: 110).isActive = true
        modePopups[side] = popup

        let spacer = NSView()
        spacer.setContentHuggingPriority(.init(1), for: .horizontal)

        let row = NSStackView(views: [label, spacer, popup])
        row.orientation = .horizontal
        row.alignment = .centerY
        row.edgeInsets = NSEdgeInsets(top: 12, left: 0, bottom: 2, right: 24)
        return row
    }

    private func speedRow(side: String) -> NSView {
        let label = NSTextField(labelWithString: "Швидкість курсора")
        label.textColor = .secondaryLabelColor

        let slider = NSSlider(value: state.speed(side), minValue: 200, maxValue: 2500,
                              target: self, action: #selector(speedChanged))
        slider.identifier = NSUserInterfaceItemIdentifier(side)
        speedSliders[side] = slider

        let value = NSTextField(labelWithString: "")
        value.font = .monospacedDigitSystemFont(ofSize: NSFont.systemFontSize, weight: .regular)
        value.textColor = .secondaryLabelColor
        value.translatesAutoresizingMaskIntoConstraints = false
        value.widthAnchor.constraint(equalToConstant: 62).isActive = true
        speedLabels[side] = value

        let row = NSStackView(views: [label, slider, value])
        row.orientation = .horizontal
        row.alignment = .centerY
        row.spacing = 8
        row.edgeInsets = NSEdgeInsets(top: 4, left: 18, bottom: 4, right: 0)
        return row
    }

    private func sectionHeader(_ title: String) -> NSView {
        let label = NSTextField(labelWithString: title)
        label.font = .systemFont(ofSize: NSFont.smallSystemFontSize, weight: .semibold)
        label.textColor = .secondaryLabelColor

        let wrapper = NSStackView(views: [label])
        wrapper.orientation = .horizontal
        wrapper.edgeInsets = NSEdgeInsets(top: 12, left: 0, bottom: 2, right: 0)
        return wrapper
    }

    private func deadzoneRow(side: String) -> NSView {
        let label = NSTextField(labelWithString: "Мертва зона")
        label.textColor = .secondaryLabelColor

        let slider = NSSlider(value: state.deadzone(side), minValue: 0.1, maxValue: 0.9,
                              target: self, action: #selector(deadzoneChanged))
        slider.identifier = NSUserInterfaceItemIdentifier(side)
        deadzoneSliders[side] = slider

        let value = NSTextField(labelWithString: String(format: "%.2f", state.deadzone(side)))
        value.font = .monospacedDigitSystemFont(ofSize: NSFont.systemFontSize, weight: .regular)
        value.textColor = .secondaryLabelColor
        value.translatesAutoresizingMaskIntoConstraints = false
        value.widthAnchor.constraint(equalToConstant: 40).isActive = true
        deadzoneLabels[side] = value

        let row = NSStackView(views: [label, slider, value])
        row.orientation = .horizontal
        row.alignment = .centerY
        row.spacing = 8
        row.edgeInsets = NSEdgeInsets(top: 4, left: 18, bottom: 4, right: 0)
        return row
    }

    // MARK: - Оновлення

    /// Повне оновлення: профілі, дозвіл, усі призначення.
    func refresh() {
        repeatCheckbox.state = state.config.active.repeatEnabled ? .on : .off
        profilePopup.removeAllItems()
        for profile in state.config.profiles {
            profilePopup.addItem(withTitle: profile.name)
        }
        profilePopup.selectItem(withTitle: state.config.active.name)
        deleteButton.isEnabled = state.config.profiles.count > 1

        if nameField.currentEditor() == nil {
            nameField.stringValue = state.config.active.name
        }

        controllerLabel.stringValue = state.controllerName ?? "контролер не підключений"
        permissionBar.isHidden = state.hasPermission
        refreshConnection()

        for (slot, row) in rows {
            row.update(key: state.actionTitle(for: slot), isCapturing: state.capturingSlot == slot)
        }
        for (side, slider) in deadzoneSliders {
            slider.doubleValue = state.deadzone(side)
            deadzoneLabels[side]?.stringValue = String(format: "%.2f", state.deadzone(side))
        }
        for (side, slider) in speedSliders {
            slider.doubleValue = state.speed(side)
            speedLabels[side]?.stringValue = String(format: "%.0f px/с", state.speed(side))
        }

        for side in ["L", "R"] {
            let mode = state.stickMode(side)
            modePopups[side]?.selectItem(at: mode == .mouse ? 1 : 0)
            // У режимі миші напрямки не мають сенсу, у режимі клавіш — швидкість.
            stickDirectionRows[side]?.forEach { $0.isHidden = mode == .mouse }
            speedRows[side]?.isHidden = mode != .mouse
        }

        refreshIndicators()
    }

    /// Дешеве оновлення: тільки крапки-індикатори.
    func refreshIndicators() {
        for (slot, row) in rows {
            row.setActive(state.activeControls.contains(slot))
        }
    }

    func refreshLog() {
        logView.string = Log.shared.text
        logView.scrollToEndOfDocument(nil)
    }

    /// Три стани: контролера немає / є, але подій не було / працює.
    private func refreshConnection() {
        guard let name = state.controllerName else {
            connectionDot.layer?.backgroundColor = NSColor.tertiaryLabelColor.cgColor
            connectionLabel.stringValue = "Контролер не підключений"
            connectionHint.stringValue = "підключіть по Bluetooth або кабелю"
            return
        }

        connectionLabel.stringValue = name

        if state.sawInput {
            connectionDot.layer?.backgroundColor = NSColor.systemGreen.cgColor
            connectionHint.stringValue = state.controllerDetail ?? ""
        } else {
            connectionDot.layer?.backgroundColor = NSColor.systemOrange.cgColor
            connectionHint.stringValue = "підключений, але жодної події ще не було — натисніть будь-яку кнопку"
        }
    }

    // MARK: - Дії

    @objc private func repeatChanged() {
        state.setRepeatEnabled(repeatCheckbox.state == .on)
    }

    @objc private func profileChanged() {
        guard let name = profilePopup.titleOfSelectedItem else { return }
        state.activate(name)
    }

    @objc private func addProfile() { state.addProfile() }
    @objc private func sendTestKey() { state.sendTestKey() }
    @objc private func clearLog() { Log.shared.clear() }

    @objc private func copyLog() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(Log.shared.text, forType: .string)
    }

    @objc private func deleteProfile() { state.deleteActiveProfile() }
    @objc private func openPermissionSettings() { state.openAccessibilitySettings() }

    @objc private func deadzoneChanged(_ sender: NSSlider) {
        guard let side = sender.identifier?.rawValue else { return }
        state.setDeadzone(sender.doubleValue, side: side)
    }

    @objc private func speedChanged(_ sender: NSSlider) {
        guard let side = sender.identifier?.rawValue else { return }
        state.setSpeed(sender.doubleValue, side: side)
    }

    @objc private func modeChanged(_ sender: NSPopUpButton) {
        guard let side = sender.identifier?.rawValue,
              let raw = sender.selectedItem?.representedObject as? String,
              let mode = StickMode(rawValue: raw) else { return }
        state.setStickMode(mode, side: side)
    }

    func controlTextDidEndEditing(_ notification: Notification) {
        guard notification.object as? NSTextField === nameField else { return }
        state.renameActiveProfile(to: nameField.stringValue)
        refresh()
    }

    func windowWillClose(_ notification: Notification) {
        state.cancelCapture()
    }
}
