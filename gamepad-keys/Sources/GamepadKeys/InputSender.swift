import Foundation

/// Один вхід для всього, що програма надсилає в систему.
/// Приховує від `Mapper` різницю між клавіатурою і мишею.
final class InputSender {
    let keyboard = KeySender()
    let mouse = MouseSender()

    /// Поки вікно чекає на призначення, вихід глушиться повністю.
    var isPaused = false {
        didSet {
            keyboard.isPaused = isPaused
            mouse.isPaused = isPaused
        }
    }

    func press(_ action: Action) {
        switch action {
        case .key(let combo):    keyboard.press(combo)
        case .mouse(let button): mouse.press(button)
        }
    }

    func release(_ action: Action) {
        switch action {
        case .key(let combo):    keyboard.release(combo)
        case .mouse(let button): mouse.release(button)
        }
    }

    func releaseAll() {
        keyboard.releaseAll()
        mouse.releaseAll()
        mouse.setVelocity(x: 0, y: 0, speed: MouseSender.defaultSpeed)
    }
}
