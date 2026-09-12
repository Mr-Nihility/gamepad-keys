import Foundation

enum MouseButton: String, CaseIterable {
    case left, right, middle

    var title: String {
        switch self {
        case .left:   return "ліва миша"
        case .right:  return "права миша"
        case .middle: return "середня миша"
        }
    }
}

/// Те, у що перетворюється кнопка геймпада: клавіша або кнопка миші.
///
/// У конфігу зберігається рядком — клавіші як були ("space", "cmd+w"),
/// кнопки миші з префіксом ("mouse:left").
enum Action: Equatable {
    case key(KeyCombo)
    case mouse(MouseButton)

    init?(_ text: String) {
        if text.hasPrefix("mouse:") {
            guard let button = MouseButton(rawValue: String(text.dropFirst("mouse:".count))) else {
                return nil
            }
            self = .mouse(button)
        } else if let combo = KeyCombo(text) {
            self = .key(combo)
        } else {
            return nil
        }
    }

    /// Запис у конфіг.
    var text: String {
        switch self {
        case .key(let combo):    return combo.text
        case .mouse(let button): return "mouse:\(button.rawValue)"
        }
    }

    /// Підпис у вікні.
    var title: String {
        switch self {
        case .key(let combo):    return combo.text
        case .mouse(let button): return button.title
        }
    }
}
