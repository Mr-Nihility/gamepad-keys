import Foundation
import GameController

/// Прив'язує один контролер до розкладки.
///
/// GameController нормалізує назви: на DualSense `a` — це Хрестик, `b` — Кружечок,
/// `x` — Квадрат, `y` — Трикутник.
final class Mapper {
    private let pad: GCExtendedGamepad
    private let sender: InputSender

    /// Повідомляє вікно, яку кнопку зараз тримають — для «живих» індикаторів.
    /// Викликається на головній черзі.
    var onActivity: ((Slot, Bool) -> Void)?

    /// Напрямки стіка, які зараз вважаються натиснутими. Окремо від `stickHeld`,
    /// бо напрямок може бути відхилений, але без призначеної клавіші — і про
    /// нього все одно треба повідомити індикатор рівно один раз.
    private var stickWanted: [String: Set<String>] = ["L": [], "R": []]
    private var stickHeld: [String: [String: Action]] = ["L": [:], "R": [:]]

    /// Усі кнопки, які можна вказати в конфігу.
    static let buttonNames = [
        "a", "b", "x", "y",
        "lb", "rb", "lt", "rt",
        "up", "down", "left", "right",
        "menu", "options", "home", "l3", "r3",
    ]

    init(pad: GCExtendedGamepad, sender: InputSender) {
        self.pad = pad
        self.sender = sender
    }

    /// Застосувати профіль. Можна викликати повторно — стара прив'язка знімається.
    ///
    /// Обробники вішаються на ВСІ кнопки, навіть непризначені: інакше в вікні
    /// не було б видно, яка кнопка зараз натиснута.
    func apply(_ profile: Profile) {
        reset()

        var bound = 0
        var missing: [String] = []

        for name in Mapper.buttonNames {
            guard let input = input(named: name) else {
                missing.append(name)
                continue
            }
            let slot = Slot.button(name)
            let action = profile.buttons[name].flatMap { Action($0) }
            if action != nil { bound += 1 }

            input.pressedChangedHandler = { [weak self] _, _, pressed in
                guard let self else { return }
                DispatchQueue.main.async { self.onActivity?(slot, pressed) }

                if let action {
                    log("🎮 \(name) \(pressed ? "↓" : "↑") → \(action.title)")
                    if pressed { self.sender.press(action) } else { self.sender.release(action) }
                } else if pressed {
                    log("🎮 \(name) ↓ (не призначено)")
                }
            }
        }

        bind(pad.leftThumbstick, profile.leftStick, side: "L")
        bind(pad.rightThumbstick, profile.rightStick, side: "R")

        log("профіль «\(profile.name)» застосовано: \(bound) призначень"
            + (missing.isEmpty ? "" : ", контролер не має: \(missing.joined(separator: ", "))"))
    }

    /// Зняти всі обробники і відпустити все, що тримається.
    func reset() {
        for name in Mapper.buttonNames {
            input(named: name)?.pressedChangedHandler = nil
        }
        pad.leftThumbstick.valueChangedHandler = nil
        pad.rightThumbstick.valueChangedHandler = nil
        sender.mouse.setVelocity(x: 0, y: 0, speed: MouseSender.defaultSpeed)

        for side in Array(stickHeld.keys) {
            for combo in (stickHeld[side] ?? [:]).values { sender.release(combo) }
            stickHeld[side] = [:]
            stickWanted[side] = []
        }
    }

    // MARK: - Внутрішнє

    private func input(named name: String) -> GCControllerButtonInput? {
        switch name {
        case "a":       return pad.buttonA
        case "b":       return pad.buttonB
        case "x":       return pad.buttonX
        case "y":       return pad.buttonY
        case "lb":      return pad.leftShoulder
        case "rb":      return pad.rightShoulder
        case "lt":      return pad.leftTrigger
        case "rt":      return pad.rightTrigger
        case "up":      return pad.dpad.up
        case "down":    return pad.dpad.down
        case "left":    return pad.dpad.left
        case "right":   return pad.dpad.right
        case "menu":    return pad.buttonMenu
        case "options": return pad.buttonOptions
        case "home":    return pad.buttonHome
        case "l3":      return pad.leftThumbstickButton
        case "r3":      return pad.rightThumbstickButton
        default:        return nil
        }
    }

    private func bind(_ stick: GCControllerDirectionPad, _ config: StickConfig?, side: String) {
        let deadzone = Float(config?.deadzone ?? 0.5)

        if config?.mode == .mouse {
            bindMouse(stick, deadzone: deadzone,
                      speed: config?.speed ?? MouseSender.defaultSpeed, side: side)
            return
        }

        let actions: [String: Action] = [
            "up": config?.up, "down": config?.down,
            "left": config?.left, "right": config?.right,
        ].compactMapValues { text in text.flatMap { Action($0) } }

        // Гістерезис: увійти в напрямок важче, ніж із нього вийти. Без цього стік,
        // застиглий рівно на межі, сипле down/up десятки разів на секунду.
        let release = deadzone * 0.7

        stick.valueChangedHandler = { [weak self] _, x, y in
            guard let self else { return }
            let previous = self.stickWanted[side] ?? []

            func isActive(_ direction: String, _ value: Float) -> Bool {
                value > (previous.contains(direction) ? release : deadzone)
            }

            var wanted = Set<String>()
            if isActive("up", y)     { wanted.insert("up") }
            if isActive("down", -y)  { wanted.insert("down") }
            if isActive("left", -x)  { wanted.insert("left") }
            if isActive("right", x)  { wanted.insert("right") }

            self.updateStick(side: side, wanted: wanted, actions: actions)
        }
    }

    /// Режим миші: стік не «натискає напрямки», а задає швидкість курсора.
    private func bindMouse(_ stick: GCControllerDirectionPad,
                           deadzone: Float, speed: Double, side: String) {
        stick.valueChangedHandler = { [weak self] _, x, y in
            guard let self else { return }

            // Перерахунок так, щоб одразу за мертвою зоною швидкість була нульова
            // і наростала плавно, а не стрибком.
            func shaped(_ value: Float) -> Float {
                let magnitude = abs(value)
                guard magnitude > deadzone else { return 0 }
                return (value < 0 ? -1 : 1) * (magnitude - deadzone) / (1 - deadzone)
            }

            let vx = shaped(x)
            let vy = shaped(y)
            self.sender.mouse.setVelocity(x: vx, y: vy, speed: speed)

            // Індикатори у вікні лишаються живими і в цьому режимі.
            var wanted = Set<String>()
            if vy > 0 { wanted.insert("up") }
            if vy < 0 { wanted.insert("down") }
            if vx < 0 { wanted.insert("left") }
            if vx > 0 { wanted.insert("right") }
            self.reportStick(side: side, wanted: wanted)
        }
    }

    private func updateStick(side: String, wanted: Set<String>, actions: [String: Action]) {
        let previous = stickWanted[side] ?? []
        // Стік шле подію на кожен мікрорух — реагуємо лише на перетин мертвої зони.
        guard wanted != previous else { return }

        var held = stickHeld[side] ?? [:]

        for direction in previous.subtracting(wanted) {
            if let action = held[direction] {
                log("🕹 \(side).\(direction) ↑ → \(action.title)")
                sender.release(action)
                held[direction] = nil
            }
        }
        for direction in wanted.subtracting(previous) {
            if let action = actions[direction] {
                log("🕹 \(side).\(direction) ↓ → \(action.title)")
                sender.press(action)
                held[direction] = action
            } else {
                log("🕹 \(side).\(direction) ↓ (не призначено)")
            }
        }

        stickHeld[side] = held
        reportStick(side: side, wanted: wanted)
    }

    /// Оновити індикатори у вікні, повідомляючи лише про справжні зміни.
    private func reportStick(side: String, wanted: Set<String>) {
        let previous = stickWanted[side] ?? []
        guard wanted != previous else { return }
        stickWanted[side] = wanted

        let changes = previous.subtracting(wanted).map { (Slot.stick(side: side, direction: $0), false) }
            + wanted.subtracting(previous).map { (Slot.stick(side: side, direction: $0), true) }
        DispatchQueue.main.async { [weak self] in
            for (slot, isActive) in changes { self?.onActivity?(slot, isActive) }
        }
    }
}
