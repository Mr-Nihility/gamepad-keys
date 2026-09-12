import CoreGraphics
import Foundation

/// Один вхід для всього, що програма надсилає в систему.
/// Приховує від `Mapper` різницю між клавіатурою і мишею.
final class InputSender {
    let keyboard: KeySender
    let mouse: MouseSender
    private var repeatTimer: DispatchSourceTimer?
    var repeatEnabled = false {
        didSet { updateRepeatTimer() }
    }

    private func updateRepeatTimer() {
        repeatTimer?.cancel()
        repeatTimer = nil
        guard repeatEnabled, !isPaused else { return }
        let timer = DispatchSource.makeTimerSource(queue: .main)
        timer.schedule(deadline: .now() + 0.1, repeating: 0.1)
        timer.setEventHandler { [weak self] in
            guard let self, self.repeatEnabled, !self.isPaused else { return }
            self.keyboard.repeatHeld()
            self.mouse.repeatHeld()
        }
        timer.resume()
        repeatTimer = timer
    }

    deinit { repeatTimer?.cancel() }

    init(postEvent: @escaping (CGEvent) -> Void = { $0.post(tap: .cghidEventTap) }) {
        keyboard = KeySender(postEvent: postEvent)
        mouse = MouseSender(postEvent: postEvent)
    }

    /// Поки вікно чекає на призначення, вихід глушиться повністю.
    var isPaused = false {
        didSet {
            keyboard.isPaused = isPaused
            mouse.isPaused = isPaused
            updateRepeatTimer()
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
