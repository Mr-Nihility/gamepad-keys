import ApplicationServices
import CoreGraphics
import Foundation

/// Надсилає системні події клавіатури.
///
/// `.cghidEventTap` вкидає подію на рівні HID — тобто в самий низ, так само як
/// натискання справжньої клавіші. Її бачать усі застосунки, включно з браузером.
///
/// Лічильник `held` потрібен ось для чого: якщо дві кнопки геймпада прив'язані
/// до однієї клавіші, відпускання однієї з них не повинно відпускати клавішу,
/// доки друга ще натиснута.
final class KeySender {
    private var held: [CGKeyCode: (count: Int, flags: CGEventFlags)] = [:]
    private let source = CGEventSource(stateID: .hidSystemState)
    private let lock = NSLock()
    private var warnedAboutPermission = false

    /// Поки вікно чекає на натискання клавіші, вихід треба заглушити —
    /// інакше кнопка геймпада надішле синтетичну клавішу, і програма
    /// перехопить власну ж подію як «призначення».
    var isPaused = false {
        didSet { if isPaused { releaseAll() } }
    }

    func press(_ key: KeyCombo) {
        lock.lock()
        defer { lock.unlock() }
        guard !isPaused else { return }

        let count = (held[key.code]?.count ?? 0) + 1
        held[key.code] = (count, key.flags)
        if count == 1 {
            post(code: key.code, flags: key.flags, down: true)
        }
    }

    func release(_ key: KeyCombo) {
        lock.lock()
        defer { lock.unlock() }

        guard let current = held[key.code] else { return }
        if current.count <= 1 {
            held[key.code] = nil
            post(code: key.code, flags: current.flags, down: false)
        } else {
            held[key.code] = (current.count - 1, current.flags)
        }
    }

    /// Відпустити все — при відключенні контролера, зміні профілю або виході.
    /// Без цього клавіша може «залипнути» назавжди.
    func releaseAll() {
        lock.lock()
        defer { lock.unlock() }

        for (code, current) in held {
            post(code: code, flags: current.flags, down: false)
        }
        held.removeAll()
    }

    private func post(code: CGKeyCode, flags: CGEventFlags, down: Bool) {
        let name = KeyCombo.names[code] ?? String(format: "0x%02X", code)

        if down, !AXIsProcessTrusted() {
            if !warnedAboutPermission {
                warnedAboutPermission = true
                log("⛔️ немає дозволу «Універсальний доступ» — система мовчки відкидає всі події")
            }
        } else if down {
            warnedAboutPermission = false
        }

        guard let event = CGEvent(keyboardEventSource: source, virtualKey: code, keyDown: down) else {
            log("‼️ не вдалось створити подію для «\(name)»")
            return
        }
        event.flags = flags
        event.post(tap: .cghidEventTap)
        log("⌨️  \(name) \(down ? "↓" : "↑")")
    }
}
