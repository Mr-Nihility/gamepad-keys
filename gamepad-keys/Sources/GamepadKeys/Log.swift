import Foundation

/// Кільцевий журнал на 500 рядків: показується у вікні і дублюється в Console.app.
///
/// Сповіщення про новий запис навмисне «злипаються»: під час гри події сиплються
/// десятками за секунду, і перемальовувати текст на кожну — марно.
final class Log {
    static let shared = Log()

    private var lines: [String] = []
    private var notificationPending = false
    private let lock = NSLock()

    private let time: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss.SSS"
        return formatter
    }()

    var onAppend: (() -> Void)?

    /// Дублюємо на диск: журнал у вікні живе лише поки програма запущена,
    /// а розбиратись доводиться і з тим, що сталося до перезапуску.
    static let fileURL = Config.url.deletingLastPathComponent()
        .appendingPathComponent("log.txt")

    private lazy var file: FileHandle? = {
        let path = Log.fileURL.path
        try? FileManager.default.createDirectory(
            at: Log.fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        // Кожен запуск починає файл заново, щоб він не ріс безмежно.
        FileManager.default.createFile(atPath: path, contents: nil)
        return FileHandle(forWritingAtPath: path)
    }()

    var text: String {
        lock.lock()
        defer { lock.unlock() }
        return lines.joined(separator: "\n")
    }

    func write(_ message: String) {
        let line = "\(time.string(from: Date()))  \(message)"

        lock.lock()
        file?.write(Data((line + "\n").utf8))
        lines.append(line)
        if lines.count > 500 { lines.removeFirst(lines.count - 500) }
        let shouldNotify = !notificationPending
        notificationPending = true
        lock.unlock()

        guard shouldNotify else { return }
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.lock.lock()
            self.notificationPending = false
            self.lock.unlock()
            self.onAppend?()
        }
    }

    func clear() {
        lock.lock()
        lines.removeAll()
        lock.unlock()
        onAppend?()
    }
}

/// Коротка форма, щоб виклики не захаращували код.
func log(_ message: String) {
    Log.shared.write(message)
}
