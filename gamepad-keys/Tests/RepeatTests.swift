import CoreGraphics
import Foundation

// У перевірках журнал не торкається користувацьких файлів.
func log(_ message: String) {}

@main
struct RepeatTests {
    static func main() throws {
        let json = Data(#"{"profiles":[{"name":"Тест","repeatEnabled":true}]}"#.utf8)
        let config = try JSONDecoder().decode(Config.self, from: json)
        let saved = try JSONSerialization.jsonObject(with: JSONEncoder().encode(config)) as! [String: Any]
        let profile = (saved["profiles"] as! [[String: Any]])[0]
        precondition(profile["repeatEnabled"] as? Bool == true, "Профіль має зберігати ввімкнений повтор")
        var events: [CGEvent] = []
        let sender = InputSender { events.append($0) }
        sender.repeatEnabled = true
        sender.press(Action("space")!)
        RunLoop.main.run(until: Date().addingTimeInterval(0.35))
        precondition(events.filter { $0.type == .keyDown }.count >= 3,
                     "Утримання має надсилати повторні keydown")
        sender.releaseAll()
        events.removeAll()
        sender.press(.mouse(.left))
        RunLoop.main.run(until: Date().addingTimeInterval(0.35))
        sender.release(.mouse(.left))
        precondition(events.map(\.type) == Array(repeating: [CGEventType.leftMouseDown, .leftMouseUp], count: events.count / 2).flatMap { $0 }
                     && events.count >= 6, "Утримання миші має давати завершені повторні кліки")
        events.removeAll()
        sender.press(.mouse(.left))
        sender.press(.mouse(.left))
        sender.release(.mouse(.left))
        precondition(events.map(\.type) == [.leftMouseDown],
                     "Дві прив’язки до миші мають утримувати її до останнього відпускання")
        sender.release(.mouse(.left))
        precondition(events.map(\.type) == [.leftMouseDown, .leftMouseUp])
        for stop in ["release", "releaseAll", "pause", "disable"] {
            events.removeAll()
            sender.isPaused = false
            sender.repeatEnabled = true
            sender.press(Action("shift+space")!)
            sender.press(.mouse(.right))
            RunLoop.main.run(until: Date().addingTimeInterval(0.25))
            let repeats = events.filter { $0.type == .keyDown && $0.getIntegerValueField(.keyboardEventAutorepeat) == 1 }
            precondition(!repeats.isEmpty && repeats.allSatisfy { $0.flags.contains(.maskShift) },
                         "Повтор має зберігати модифікатори та ознаку autorepeat")
            switch stop {
            case "release":
                sender.release(Action("shift+space")!)
                sender.release(.mouse(.right))
            case "releaseAll": sender.releaseAll()
            case "pause": sender.isPaused = true
            default: sender.repeatEnabled = false
            }
            let stoppedCount = events.count
            RunLoop.main.run(until: Date().addingTimeInterval(0.25))
            precondition(events.count == stoppedCount, "Повтор має зупинятися: \(stop)")
            sender.releaseAll()
        }
        events.removeAll()
        sender.isPaused = false
        sender.repeatEnabled = false
        sender.press(Action("space")!)
        RunLoop.main.run(until: Date().addingTimeInterval(0.25))
        sender.release(Action("space")!)
        precondition(events.map(\.type) == [.keyDown, .keyUp], "Без галочки події не повторюються")
        for text in [#"{"buttons":{"a":"space"}}"#,
                     #"{"profiles":[{"name":"Старий","buttons":{"a":"space"}}]}"#] {
            let old = try JSONDecoder().decode(Config.self, from: Data(text.utf8))
            precondition(!old.active.repeatEnabled && old.active.buttons["a"] == "space",
                         "Старі конфіги мають працювати з вимкненим повтором")
        }
        print("Перевірки повторення пройшли")
    }
}
