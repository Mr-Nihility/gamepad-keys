import AppKit

// Точка входу без SwiftUI: у SDK macOS 27 обгортки типу @State — це макроси,
// а плагіни для них ідуть лише з повним Xcode. AppKit будується самими
// Command Line Tools.

let application = NSApplication.shared
let delegate = AppDelegate()
application.delegate = delegate

// .accessory — програма живе в рядку стану: без іконки в Dock,
// але з можливістю показувати вікна.
application.setActivationPolicy(.accessory)
application.run()
