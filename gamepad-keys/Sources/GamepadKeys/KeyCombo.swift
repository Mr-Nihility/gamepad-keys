import CoreGraphics

/// Одна клавіша (плюс, за бажанням, модифікатори), у яку перетворюється кнопка геймпада.
///
/// Розбирає рядки з конфіга: "w", "space", "left", "cmd+shift+a", "shift".
///
/// Важливо: `CGKeyCode` — це ПОЗИЦІЯ клавіші на клавіатурі, а не символ.
/// 0x0D — це фізичне місце "W" на US-розкладці. Якщо у вас увімкнена українська
/// розкладка, та сама клавіша дасть "ц", але ігри читають саме позицію, тож це
/// зазвичай те, що потрібно.
struct KeyCombo: Equatable {
    let code: CGKeyCode
    let flags: CGEventFlags

    // MARK: - Створення

    init?(_ text: String) {
        let lowered = text.lowercased()

        // "shift" саме по собі — це фізична клавіша-модифікатор, а не модифікатор
        // до чогось іншого.
        if let solo = KeyCombo.soloModifier(named: lowered) {
            self = solo
            return
        }

        var flags: CGEventFlags = []
        var keyName: String?

        for part in lowered.split(separator: "+").map(String.init) {
            switch KeyCombo.canonical(part) {
            case "cmd":   flags.insert(.maskCommand)
            case "shift": flags.insert(.maskShift)
            case "alt":   flags.insert(.maskAlternate)
            case "ctrl":  flags.insert(.maskControl)
            default:      keyName = KeyCombo.canonical(part)
            }
        }

        guard let keyName, let code = KeyCombo.codes[keyName] else { return nil }
        self.code = code
        self.flags = flags
    }

    /// Для перехоплення натискання з клавіатури.
    init?(code: CGKeyCode, flags: CGEventFlags) {
        guard KeyCombo.names[code] != nil else { return nil }
        self.code = code
        self.flags = flags
    }

    private init(code: CGKeyCode, flagsRaw: CGEventFlags) {
        self.code = code
        self.flags = flagsRaw
    }

    // MARK: - Показ і запис у конфіг

    /// "cmd+shift+a" — те, що потрапляє в JSON і що бачить користувач.
    var text: String {
        let base = KeyCombo.names[code] ?? "?"
        if KeyCombo.soloModifierCodes.contains(code) { return base }

        var parts: [String] = []
        if flags.contains(.maskControl)   { parts.append("ctrl") }
        if flags.contains(.maskAlternate) { parts.append("alt") }
        if flags.contains(.maskShift)     { parts.append("shift") }
        if flags.contains(.maskCommand)   { parts.append("cmd") }
        parts.append(base)
        return parts.joined(separator: "+")
    }

    // MARK: - Таблиці

    /// Клавіші-модифікатори як самостійні клавіші.
    /// Прапорець потрібен, щоб браузер бачив `event.shiftKey === true`.
    static let soloModifiers: [String: (CGKeyCode, CGEventFlags)] = [
        "shift":  (0x38, .maskShift),
        "ctrl":   (0x3B, .maskControl),
        "alt":    (0x3A, .maskAlternate),
        "cmd":    (0x37, .maskCommand),
        "rshift": (0x3C, .maskShift),
        "rctrl":  (0x3E, .maskControl),
        "ralt":   (0x3D, .maskAlternate),
    ]

    static let soloModifierCodes: Set<CGKeyCode> = Set(soloModifiers.values.map(\.0))

    static func soloModifier(named name: String) -> KeyCombo? {
        guard let entry = soloModifiers[canonical(name)] else { return nil }
        return KeyCombo(code: entry.0, flagsRaw: entry.1)
    }

    static func soloModifier(forCode code: CGKeyCode) -> KeyCombo? {
        guard let entry = soloModifiers.values.first(where: { $0.0 == code }) else { return nil }
        return KeyCombo(code: entry.0, flagsRaw: entry.1)
    }

    /// Синоніми → канонічна назва. Канонічні назви — єдині, що пишуться в конфіг.
    static let aliases: [String: String] = [
        "esc": "escape", "enter": "return",
        "command": "cmd", "control": "ctrl", "option": "alt",
    ]

    static func canonical(_ name: String) -> String {
        aliases[name] ?? name
    }

    /// Канонічна назва → позиція клавіші (значення з Carbon `kVK_*`).
    /// Кожен код зустрічається рівно один раз, щоб працював зворотний пошук.
    static let codes: [String: CGKeyCode] = [
        // літери
        "a": 0x00, "s": 0x01, "d": 0x02, "f": 0x03, "h": 0x04, "g": 0x05,
        "z": 0x06, "x": 0x07, "c": 0x08, "v": 0x09, "b": 0x0B, "q": 0x0C,
        "w": 0x0D, "e": 0x0E, "r": 0x0F, "y": 0x10, "t": 0x11, "o": 0x1F,
        "u": 0x20, "i": 0x22, "p": 0x23, "l": 0x25, "j": 0x26, "k": 0x28,
        "n": 0x2D, "m": 0x2E,

        // цифри
        "1": 0x12, "2": 0x13, "3": 0x14, "4": 0x15, "5": 0x17,
        "6": 0x16, "7": 0x1A, "8": 0x1C, "9": 0x19, "0": 0x1D,

        // розділові
        "minus": 0x1B, "equal": 0x18, "leftbracket": 0x21, "rightbracket": 0x1E,
        "backslash": 0x2A, "semicolon": 0x29, "quote": 0x27, "comma": 0x2B,
        "period": 0x2F, "slash": 0x2C, "grave": 0x32,

        // керівні
        "return": 0x24, "tab": 0x30, "space": 0x31, "backspace": 0x33,
        "delete": 0x75, "escape": 0x35,
        "home": 0x73, "end": 0x77, "pageup": 0x74, "pagedown": 0x79,

        // стрілки
        "left": 0x7B, "right": 0x7C, "down": 0x7D, "up": 0x7E,

        // функційні
        "f1": 0x7A, "f2": 0x78, "f3": 0x63, "f4": 0x76, "f5": 0x60, "f6": 0x61,
        "f7": 0x62, "f8": 0x64, "f9": 0x65, "f10": 0x6D, "f11": 0x67, "f12": 0x6F,
    ]

    /// Зворотний пошук: позиція → назва. Будується один раз.
    static let names: [CGKeyCode: String] = {
        var result: [CGKeyCode: String] = [:]
        for (name, code) in codes { result[code] = name }
        for (name, entry) in soloModifiers { result[entry.0] = name }
        return result
    }()
}
