import AppKit
import ApplicationServices
import Foundation
import GameController
import ServiceManagement

/// Уся змінна частина програми в одному місці. Усі зміни відбуваються на
/// головній черзі — і сповіщення GameController, і монітор клавіатури приходять саме туди.
///
/// Інтерфейс підписується двома окремими замиканнями: `onChange` — коли треба
/// перебудувати вікно, `onActivity` — коли змінилось лише підсвічування кнопок
/// (це буває часто, і повна перебудова там зайва).
final class AppState {

    private(set) var config: Config
    private(set) var activeControls: Set<Slot> = []
    private(set) var controllerName: String?
    private(set) var controllerDetail: String?
    private(set) var capturingSlot: Slot?

    /// Чи приходила хоч одна подія з контролера. Якщо контролер підключений,
    /// а подій нема — це майже завжди означає, що ввід до нас не доходить,
    /// а не що розкладка порожня.
    private(set) var sawInput = false

    var onChange: (() -> Void)?
    var onActivity: (() -> Void)?

    var hasPermission: Bool { AXIsProcessTrusted() }

    var launchAtLogin: Bool {
        get { SMAppService.mainApp.status == .enabled }
        set {
            do {
                if newValue {
                    try SMAppService.mainApp.register()
                } else {
                    try SMAppService.mainApp.unregister()
                }
            } catch {
                // Працює лише для зібраного .app — із «голого» бінарника кидає помилку.
                NSLog("gamepad-keys: автозапуск недоступний (\(error))")
            }
        }
    }

    private let sender = InputSender()
    private let keyCapture = KeyCapture()
    private var mappers: [Mapper] = []
    private var permissionTimer: Timer?
    private var lastPermission = false

    init() {
        config = Config.loadOrCreateDefault()
        lastPermission = AXIsProcessTrusted()

        log("запуск, конфіг: \(Config.url.path)")
        log(lastPermission
            ? "дозвіл «Універсальний доступ»: є"
            : "⛔️ дозвіл «Універсальний доступ»: НЕМАЄ")

        // Головне для програми з рядка стану: без цього macOS віддає ввід з
        // геймпада лише застосунку на передньому плані, і ми не отримуємо нічого.
        GCController.shouldMonitorBackgroundEvents = true
        log("фоновий прийом подій увімкнено")

        let center = NotificationCenter.default
        center.addObserver(forName: .GCControllerDidConnect, object: nil, queue: .main) {
            [weak self] _ in
            log("подія: контролер підключено")
            self?.rebuild()
        }
        center.addObserver(forName: .GCControllerDidDisconnect, object: nil, queue: .main) {
            [weak self] _ in
            log("подія: контролер відключено")
            self?.rebuild()
        }

        rebuild()
        GCController.startWirelessControllerDiscovery()

        // Дозвіл користувач видає у Системних налаштуваннях, нас про це ніхто не
        // сповіщає — тому просто періодично перепитуємо.
        permissionTimer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in
            guard let self else { return }
            let granted = AXIsProcessTrusted()
            guard granted != self.lastPermission else { return }
            self.lastPermission = granted
            log(granted ? "✅ дозвіл видано" : "⛔️ дозвіл відкликано")
            self.onChange?()
        }
    }

    /// Надіслати пробіл, щоб перевірити дозвіл окремо від контролера.
    func sendTestKey() {
        guard let combo = KeyCombo("space") else { return }
        log("тест: надсилаю «space»")
        sender.press(.key(combo))
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) { [weak self] in
            self?.sender.release(.key(combo))
        }
    }

    // MARK: - Дозвіл

    func requestPermission() {
        let prompt = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        _ = AXIsProcessTrustedWithOptions([prompt: true] as CFDictionary)
    }

    func openAccessibilitySettings() {
        let url = URL(string:
            "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
        NSWorkspace.shared.open(url)
    }

    // MARK: - Контролери

    private func rebuild() {
        sender.releaseAll()
        mappers.forEach { $0.reset() }
        mappers.removeAll()
        activeControls.removeAll()

        let controllers = GCController.controllers()
        log("знайдено контролерів: \(controllers.count)")
        if controllers.isEmpty {
            // Сповіщення про підключення приходить із затримкою в кілька сотень
            // мілісекунд, тому одразу після запуску список завжди порожній.
            // Скануємо HID лише якщо контролера немає і через дві секунди.
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                guard GCController.controllers().isEmpty else { return }
                HIDScan.report()
            }
        }

        for controller in controllers {
            let name = controller.vendorName ?? "без назви"
            guard let pad = controller.extendedGamepad else {
                // Наприклад, пульт або мікро-геймпад: кнопок, які ми мапимо, там немає.
                log("⚠️ «\(name)» (\(controller.productCategory)) — не розширений геймпад, пропускаю")
                continue
            }
            log("• «\(name)» · \(controller.productCategory) · розширений геймпад")

            let mapper = Mapper(pad: pad, sender: sender)
            mapper.onActivity = { [weak self] slot, isActive in
                guard let self else { return }
                if !self.sawInput {
                    self.sawInput = true
                    log("✅ перша подія з контролера отримана")
                    self.onChange?()
                }
                let before = self.activeControls.count
                if isActive {
                    self.activeControls.insert(slot)
                } else {
                    self.activeControls.remove(slot)
                }
                if self.activeControls.count != before { self.onActivity?() }
            }
            mapper.apply(config.active)
            mappers.append(mapper)
        }

        let connected = controllers.first { $0.extendedGamepad != nil }
        controllerName = connected?.vendorName
        controllerDetail = connected.map { "\($0.productCategory) · розширений геймпад" }
        if connected == nil { sawInput = false }
        onChange?()
    }

    // MARK: - Читання і зміна розкладки

    func key(for slot: Slot) -> String? {
        let profile = config.active
        switch slot {
        case .button(let name):
            return profile.buttons[name]
        case .stick(let side, let direction):
            let stick = side == "L" ? profile.leftStick : profile.rightStick
            switch direction {
            case "up":   return stick?.up
            case "down": return stick?.down
            case "left": return stick?.left
            default:     return stick?.right
            }
        }
    }

    func setKey(_ text: String?, for slot: Slot) {
        var profile = config.active
        switch slot {
        case .button(let name):
            profile.buttons[name] = text
        case .stick(let side, let direction):
            var stick = (side == "L" ? profile.leftStick : profile.rightStick) ?? StickConfig()
            switch direction {
            case "up":   stick.up = text
            case "down": stick.down = text
            case "left": stick.left = text
            default:     stick.right = text
            }
            if side == "L" { profile.leftStick = stick } else { profile.rightStick = stick }
        }
        update(profile)
    }

    /// Підпис призначення у вікні: "space", "ліва миша". Нерозпізнане показуємо
    /// як є з позначкою, щоб зіпсований конфіг не виглядав як порожній слот.
    func actionTitle(for slot: Slot) -> String? {
        guard let text = key(for: slot) else { return nil }
        return Action(text)?.title ?? "\(text) ⁉️"
    }

    // MARK: - Режим стіка

    func stickMode(_ side: String) -> StickMode {
        let profile = config.active
        return (side == "L" ? profile.leftStick?.mode : profile.rightStick?.mode) ?? .keys
    }

    func setStickMode(_ mode: StickMode, side: String) {
        var profile = config.active
        var stick = (side == "L" ? profile.leftStick : profile.rightStick) ?? StickConfig()
        stick.mode = mode
        // Мертві зони в режимах різні за призначенням: для клавіш вона відсікає
        // випадкові дотики, для миші — тремтіння руки при прицілюванні.
        if stick.deadzone == nil { stick.deadzone = mode == .mouse ? 0.12 : 0.5 }
        if mode == .mouse, stick.speed == nil { stick.speed = MouseSender.defaultSpeed }
        if side == "L" { profile.leftStick = stick } else { profile.rightStick = stick }
        update(profile)
    }

    func speed(_ side: String) -> Double {
        let profile = config.active
        return (side == "L" ? profile.leftStick?.speed : profile.rightStick?.speed)
            ?? MouseSender.defaultSpeed
    }

    func setSpeed(_ value: Double, side: String) {
        var profile = config.active
        var stick = (side == "L" ? profile.leftStick : profile.rightStick) ?? StickConfig()
        stick.speed = value
        if side == "L" { profile.leftStick = stick } else { profile.rightStick = stick }
        update(profile)
    }

    func deadzone(_ side: String) -> Double {
        let profile = config.active
        return (side == "L" ? profile.leftStick?.deadzone : profile.rightStick?.deadzone) ?? 0.5
    }

    func setDeadzone(_ value: Double, side: String) {
        var profile = config.active
        var stick = (side == "L" ? profile.leftStick : profile.rightStick) ?? StickConfig()
        stick.deadzone = value
        if side == "L" { profile.leftStick = stick } else { profile.rightStick = stick }
        update(profile)
    }

    // MARK: - Перехоплення клавіші

    func beginCapture(_ slot: Slot) {
        if capturingSlot == slot { cancelCapture(); return }

        capturingSlot = slot
        sender.isPaused = true
        onChange?()

        keyCapture.start { [weak self] combo in
            guard let self else { return }
            if let combo { self.setKey(combo.text, for: slot) }
            self.cancelCapture()
        }
    }

    func cancelCapture() {
        guard capturingSlot != nil || keyCapture.isActive else { return }
        keyCapture.stop()
        capturingSlot = nil
        sender.isPaused = false
        onChange?()
    }

    // MARK: - Профілі

    func activate(_ name: String) {
        guard config.activeProfile != name else { return }
        config.activeProfile = name
        config.save()
        rebuild()
    }

    func addProfile() {
        var name = "Новий профіль"
        var index = 2
        while config.profiles.contains(where: { $0.name == name }) {
            name = "Новий профіль \(index)"
            index += 1
        }
        var copy = config.active
        copy.name = name
        config.profiles.append(copy)
        config.activeProfile = name
        config.save()
        rebuild()
    }

    func deleteActiveProfile() {
        guard config.profiles.count > 1 else { return }
        config.profiles.remove(at: config.activeIndex)
        config.activeProfile = config.profiles.first?.name
        config.save()
        rebuild()
    }

    func renameActiveProfile(to name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, trimmed != config.active.name else { return }
        guard !config.profiles.contains(where: { $0.name == trimmed }) else { return }

        config.profiles[config.activeIndex].name = trimmed
        config.activeProfile = trimmed
        config.save()
        onChange?()
    }

    // MARK: - Запис

    private func update(_ profile: Profile) {
        config.profiles[config.activeIndex] = profile
        config.save()
        mappers.forEach { $0.apply(profile) }
        onChange?()
    }
}
