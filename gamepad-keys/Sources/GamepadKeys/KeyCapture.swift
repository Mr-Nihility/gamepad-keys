import AppKit

/// Ловить наступне натискання клавіші у вікні програми і повертає його як `KeyCombo`.
///
/// Монітор локальний — перехоплює тільки події, адресовані нашому вікну, і
/// «з'їдає» їх (повертає nil), щоб натискання не пішло в поля вводу.
final class KeyCapture {
    private var monitor: Any?

    var isActive: Bool { monitor != nil }

    func start(_ handler: @escaping (KeyCombo?) -> Void) {
        stop()
        monitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .flagsChanged]) {
            [weak self] event in

            if event.type == .flagsChanged {
                // Модифікатор сам по собі: реагуємо лише на натискання, не на відпускання.
                guard let combo = KeyCombo.soloModifier(forCode: event.keyCode),
                      KeyCapture.isPressed(combo, in: event.modifierFlags)
                else { return nil }
                self?.stop()
                handler(combo)
                return nil
            }

            let combo = KeyCombo(code: event.keyCode,
                                 flags: KeyCapture.flags(from: event.modifierFlags))
            self?.stop()
            handler(combo)
            return nil
        }
    }

    func stop() {
        if let monitor { NSEvent.removeMonitor(monitor) }
        monitor = nil
    }

    // MARK: - Перетворення прапорців AppKit → CoreGraphics

    private static func flags(from modifiers: NSEvent.ModifierFlags) -> CGEventFlags {
        var result: CGEventFlags = []
        if modifiers.contains(.command)   { result.insert(.maskCommand) }
        if modifiers.contains(.shift)     { result.insert(.maskShift) }
        if modifiers.contains(.option)    { result.insert(.maskAlternate) }
        if modifiers.contains(.control)   { result.insert(.maskControl) }
        return result
    }

    private static func isPressed(_ combo: KeyCombo, in modifiers: NSEvent.ModifierFlags) -> Bool {
        if combo.flags.contains(.maskCommand)   { return modifiers.contains(.command) }
        if combo.flags.contains(.maskShift)     { return modifiers.contains(.shift) }
        if combo.flags.contains(.maskAlternate) { return modifiers.contains(.option) }
        if combo.flags.contains(.maskControl)   { return modifiers.contains(.control) }
        return false
    }
}
