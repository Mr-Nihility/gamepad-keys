import CoreGraphics
import Foundation

/// Рух курсора і кнопки миші.
///
/// Курсор рухається окремим таймером, а не за подіями стіка: стік повідомляє
/// лише напрямок і силу відхилення, а швидкість має бути рівною незалежно від
/// того, як часто контролер шле оновлення.
final class MouseSender {

    /// Пікселів за секунду при повному відхиленні стіка.
    static let defaultSpeed: Double = 900

    private let source = CGEventSource(stateID: .hidSystemState)
    private let lock = NSLock()

    private var held: Set<MouseButton> = []
    private var velocity = CGVector(dx: 0, dy: 0)
    private var speed = CGFloat(MouseSender.defaultSpeed)
    private var remainder = CGVector(dx: 0, dy: 0)
    private var timer: DispatchSourceTimer?

    private static let tickRate = 120.0

    var isPaused = false {
        didSet { if isPaused { releaseAll() } }
    }

    // MARK: - Рух

    /// `x` і `y` — уже з врахованою мертвою зоною, в діапазоні -1…1.
    /// `y` додатний угору (як віддає GameController).
    func setVelocity(x: Float, y: Float, speed: Double) {
        lock.lock()
        self.speed = CGFloat(speed)
        // На екрані вісь Y спрямована вниз, у контролера — вгору.
        velocity = CGVector(dx: CGFloat(x), dy: CGFloat(-y))
        let isMoving = velocity.dx != 0 || velocity.dy != 0
        lock.unlock()

        if isMoving { startTimer() } else { stopTimer() }
    }

    private func startTimer() {
        lock.lock()
        defer { lock.unlock() }
        guard timer == nil else { return }

        let source = DispatchSource.makeTimerSource(queue: .main)
        source.schedule(deadline: .now(), repeating: 1 / MouseSender.tickRate)
        source.setEventHandler { [weak self] in self?.tick() }
        source.resume()
        timer = source
    }

    private func stopTimer() {
        lock.lock()
        defer { lock.unlock() }
        timer?.cancel()
        timer = nil
        remainder = .zero
    }

    private func tick() {
        lock.lock()
        let velocity = self.velocity
        let speed = self.speed
        let held = self.held
        lock.unlock()

        guard isPaused == false else { return }

        let dt = CGFloat(1 / MouseSender.tickRate)
        // Квадратична крива: біля центру курсор повзе (зручно цілитись),
        // до краю розганяється до повної швидкості.
        func curve(_ value: CGFloat) -> CGFloat {
            (value < 0 ? -1 : 1) * value * value
        }

        lock.lock()
        let dx = curve(velocity.dx) * speed * dt + remainder.dx
        let dy = curve(velocity.dy) * speed * dt + remainder.dy
        let stepX = dx.rounded(.towardZero)
        let stepY = dy.rounded(.towardZero)
        // Дробову частину переносимо на наступний кадр, інакше повільний рух
        // округлявся б до нуля і курсор просто стояв би.
        remainder = CGVector(dx: dx - stepX, dy: dy - stepY)
        lock.unlock()

        guard stepX != 0 || stepY != 0 else { return }
        guard let current = CGEvent(source: nil)?.location else { return }

        let target = CGPoint(x: current.x + stepX, y: current.y + stepY)
        let dragging = held.first
        let type: CGEventType
        switch dragging {
        case .left:   type = .leftMouseDragged
        case .right:  type = .rightMouseDragged
        case .middle: type = .otherMouseDragged
        case nil:     type = .mouseMoved
        }

        guard let event = CGEvent(mouseEventSource: source,
                                  mouseType: type,
                                  mouseCursorPosition: target,
                                  mouseButton: MouseSender.cgButton(dragging ?? .left))
        else { return }

        // Ігри з захопленням курсора (Pointer Lock у браузері) читають саме
        // ці поля, а не абсолютну позицію.
        event.setIntegerValueField(.mouseEventDeltaX, value: Int64(stepX))
        event.setIntegerValueField(.mouseEventDeltaY, value: Int64(stepY))
        event.post(tap: .cghidEventTap)
    }

    // MARK: - Кнопки

    func press(_ button: MouseButton) {
        lock.lock()
        let alreadyHeld = held.contains(button) || isPaused
        if !alreadyHeld { held.insert(button) }
        lock.unlock()

        guard !alreadyHeld else { return }
        post(button, down: true)
    }

    func release(_ button: MouseButton) {
        lock.lock()
        let wasHeld = held.remove(button) != nil
        lock.unlock()

        guard wasHeld else { return }
        post(button, down: false)
    }

    func releaseAll() {
        lock.lock()
        let buttons = held
        held.removeAll()
        lock.unlock()

        for button in buttons { post(button, down: false) }
    }

    private func post(_ button: MouseButton, down: Bool) {
        guard let location = CGEvent(source: nil)?.location else { return }

        let type: CGEventType
        switch (button, down) {
        case (.left, true):    type = .leftMouseDown
        case (.left, false):   type = .leftMouseUp
        case (.right, true):   type = .rightMouseDown
        case (.right, false):  type = .rightMouseUp
        case (.middle, true):  type = .otherMouseDown
        case (.middle, false): type = .otherMouseUp
        }

        guard let event = CGEvent(mouseEventSource: source,
                                  mouseType: type,
                                  mouseCursorPosition: location,
                                  mouseButton: MouseSender.cgButton(button))
        else { return }

        event.setIntegerValueField(.mouseEventClickState, value: 1)
        event.post(tap: .cghidEventTap)
        log("🖱  \(button.title) \(down ? "↓" : "↑")")
    }

    private static func cgButton(_ button: MouseButton) -> CGMouseButton {
        switch button {
        case .left:   return .left
        case .right:  return .right
        case .middle: return .center
        }
    }
}
