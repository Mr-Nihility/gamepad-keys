import Foundation

enum StickMode: String, Codable {
    case keys      // чотири напрямки → чотири клавіші
    case mouse     // рух курсора
}

/// Розкладка стіка.
/// `deadzone` — наскільки треба відхилити стік, щоб він почав діяти (0…1).
/// `speed` — пікселів за секунду при повному відхиленні, лише для режиму миші.
struct StickConfig: Codable, Equatable {
    var mode: StickMode?
    var up: String?
    var down: String?
    var left: String?
    var right: String?
    var deadzone: Double?
    var speed: Double?
}

/// Одна розкладка. Ідентифікується назвою — так JSON лишається читабельним,
/// без службових UUID.
struct Profile: Codable, Identifiable, Equatable {
    var name: String
    var buttons: [String: String] = [:]
    var repeatEnabled = false
    var leftStick: StickConfig?
    var rightStick: StickConfig?

    var id: String { name }   // обчислювана властивість — у JSON не потрапляє
}

struct Config: Codable, Equatable {
    var profiles: [Profile]
    var activeProfile: String?

    var activeIndex: Int {
        profiles.firstIndex { $0.name == activeProfile } ?? 0
    }

    var active: Profile {
        profiles.isEmpty ? Profile(name: "Основний") : profiles[activeIndex]
    }

    // MARK: - Файл

    static let url = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent(".config/gamepad-keys/config.json")

    static func loadOrCreateDefault() -> Config {
        guard let data = try? Data(contentsOf: url) else {
            starter.save()
            return starter
        }
        do {
            var loaded = try JSONDecoder().decode(Config.self, from: data)
            if loaded.profiles.isEmpty { loaded.profiles = starter.profiles }
            return loaded
        } catch {
            NSLog("gamepad-keys: конфіг не читається (\(error)) — беру типовий")
            return starter
        }
    }

    func save() {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try? FileManager.default.createDirectory(
            at: Config.url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try? encoder.encode(self).write(to: Config.url)
    }

    /// Стартова розкладка: стіки на WASD і стрілки.
    static let starter = Config(
        profiles: [
            Profile(
                name: "Основний",
                buttons: [
                    "a": "space",
                    "b": "escape",
                    "x": "e",
                    "y": "f",
                    "lb": "q",
                    "rb": "r",
                    "lt": "shift",
                    "rt": "return",
                    "up": "1",
                    "down": "2",
                    "left": "3",
                    "right": "4",
                    "l3": "f",
                    "r3": "mouse:left",
                ],
                leftStick: StickConfig(mode: .keys, up: "w", down: "s", left: "a", right: "d",
                                       deadzone: 0.5),
                // Мертва зона для миші менша: інакше повільне прицілювання неможливе.
                rightStick: StickConfig(mode: .mouse, deadzone: 0.12,
                                        speed: MouseSender.defaultSpeed)
            )
        ],
        activeProfile: "Основний"
    )
}

// Розбір винесений в extension навмисне: якби `init(from:)` стояв у тілі структури,
// Swift прибрав би згенерований memberwise-ініціалізатор.
extension Profile {
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        name = try container.decodeIfPresent(String.self, forKey: .name) ?? "Основний"
        repeatEnabled = try container.decodeIfPresent(Bool.self, forKey: .repeatEnabled) ?? false
        buttons = try container.decodeIfPresent([String: String].self, forKey: .buttons) ?? [:]
        leftStick = try container.decodeIfPresent(StickConfig.self, forKey: .leftStick)
        rightStick = try container.decodeIfPresent(StickConfig.self, forKey: .rightStick)
    }
}

extension Config {
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        if let list = try container.decodeIfPresent([Profile].self, forKey: .profiles), !list.isEmpty {
            profiles = list
        } else {
            // Старий формат (без профілів): розкладка лежала прямо в корені файлу.
            var migrated = try Profile(from: decoder)
            migrated.name = "Основний"
            profiles = [migrated]
        }
        activeProfile = try container.decodeIfPresent(String.self, forKey: .activeProfile)
    }
}
