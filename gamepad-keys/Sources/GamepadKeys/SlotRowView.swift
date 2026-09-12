import AppKit

/// Один рядок розкладки: індикатор натискання, підпис, кнопка призначення, очищення.
final class SlotRowView: NSView {
    let slot: Slot

    private let dot = NSView()
    private let keyButton = NSButton()
    private let mouseButton = NSPopUpButton()
    private let clearButton = NSButton()
    private let onAssign: () -> Void
    private let onClear: () -> Void
    private let onMouse: (MouseButton) -> Void

    init(slot: Slot,
         onAssign: @escaping () -> Void,
         onMouse: @escaping (MouseButton) -> Void,
         onClear: @escaping () -> Void) {
        self.slot = slot
        self.onAssign = onAssign
        self.onMouse = onMouse
        self.onClear = onClear
        super.init(frame: .zero)

        dot.wantsLayer = true
        dot.layer?.cornerRadius = 4
        dot.layer?.backgroundColor = SlotRowView.idleColor
        dot.translatesAutoresizingMaskIntoConstraints = false
        dot.widthAnchor.constraint(equalToConstant: 8).isActive = true
        dot.heightAnchor.constraint(equalToConstant: 8).isActive = true

        let title = NSTextField(labelWithString: slot.title)
        title.lineBreakMode = .byTruncatingTail

        keyButton.bezelStyle = .rounded
        keyButton.font = .monospacedSystemFont(ofSize: NSFont.systemFontSize, weight: .regular)
        keyButton.target = self
        keyButton.action = #selector(assign)
        keyButton.translatesAutoresizingMaskIntoConstraints = false
        keyButton.widthAnchor.constraint(equalToConstant: 160).isActive = true

        // Кнопки миші не можна «натиснути для запису», бо саме мишею
        // користувач і клацає по цьому вікну. Тому — окреме меню.
        mouseButton.pullsDown = true
        mouseButton.bezelStyle = .rounded
        mouseButton.addItem(withTitle: "")
        for button in MouseButton.allCases {
            let item = NSMenuItem(title: button.title, action: #selector(chooseMouse(_:)),
                                  keyEquivalent: "")
            item.target = self
            item.representedObject = button.rawValue
            mouseButton.menu?.addItem(item)
        }
        mouseButton.toolTip = "Призначити кнопку миші"
        mouseButton.translatesAutoresizingMaskIntoConstraints = false
        mouseButton.widthAnchor.constraint(equalToConstant: 34).isActive = true

        clearButton.bezelStyle = .inline
        clearButton.isBordered = false
        clearButton.image = NSImage(systemSymbolName: "xmark.circle.fill",
                                    accessibilityDescription: "Прибрати призначення")
        clearButton.contentTintColor = .tertiaryLabelColor
        clearButton.target = self
        clearButton.action = #selector(clear)
        clearButton.toolTip = "Прибрати призначення"

        let spacer = NSView()
        spacer.setContentHuggingPriority(.init(1), for: .horizontal)

        let row = NSStackView(views: [dot, title, spacer, keyButton, mouseButton, clearButton])
        row.orientation = .horizontal
        row.alignment = .centerY
        row.spacing = 8
        row.translatesAutoresizingMaskIntoConstraints = false
        addSubview(row)

        NSLayoutConstraint.activate([
            row.leadingAnchor.constraint(equalTo: leadingAnchor),
            row.trailingAnchor.constraint(equalTo: trailingAnchor),
            row.topAnchor.constraint(equalTo: topAnchor),
            row.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
    }

    required init?(coder: NSCoder) { fatalError("не використовується") }

    // MARK: - Оновлення

    func update(key: String?, isCapturing: Bool) {
        keyButton.title = isCapturing ? "натисніть клавішу…" : (key ?? "—")
        keyButton.contentTintColor = isCapturing ? .controlAccentColor : nil
        clearButton.isHidden = key == nil
    }

    func setActive(_ isActive: Bool) {
        dot.layer?.backgroundColor = isActive
            ? NSColor.systemGreen.cgColor
            : SlotRowView.idleColor
    }

    private static let idleColor = NSColor.tertiaryLabelColor.cgColor

    @objc private func assign() { onAssign() }
    @objc private func clear() { onClear() }

    @objc private func chooseMouse(_ sender: NSMenuItem) {
        guard let raw = sender.representedObject as? String,
              let button = MouseButton(rawValue: raw) else { return }
        onMouse(button)
    }
}
