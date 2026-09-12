import Foundation

/// Одне місце в розкладці, якому можна призначити клавішу:
/// або кнопка, або один із чотирьох напрямків стіка.
enum Slot: Hashable, Identifiable {
    case button(String)
    case stick(side: String, direction: String)   // side: "L" / "R"

    var id: String {
        switch self {
        case .button(let name):
            return name
        case .stick(let side, let direction):
            return "\(side).\(direction)"
        }
    }

    /// Підпис у вікні. Для кнопок показуємо і Xbox-, і PlayStation-позначення,
    /// бо GameController віддає їх під однією назвою.
    var title: String {
        switch self {
        case .button(let name):
            return Slot.titles[name] ?? name
        case .stick(_, let direction):
            return Slot.directionTitles[direction] ?? direction
        }
    }

    private static let titles: [String: String] = [
        "a": "A / ✕",
        "b": "B / ○",
        "x": "X / □",
        "y": "Y / △",
        "lb": "LB / L1",
        "rb": "RB / R1",
        "lt": "LT / L2",
        "rt": "RT / R2",
        "up": "Хрестовина ↑",
        "down": "Хрестовина ↓",
        "left": "Хрестовина ←",
        "right": "Хрестовина →",
        "menu": "Menu / Options",
        "options": "View / Share",
        "home": "Home / PS",
        "l3": "Натиснення лівого стіка",
        "r3": "Натиснення правого стіка",
    ]

    private static let directionTitles: [String: String] = [
        "up": "↑ вгору",
        "down": "↓ вниз",
        "left": "← вліво",
        "right": "→ вправо",
    ]

    static let stickDirections = ["up", "down", "left", "right"]
}
