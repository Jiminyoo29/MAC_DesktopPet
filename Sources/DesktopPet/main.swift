import AppKit
import SwiftUI

let app = NSApplication.shared
app.setActivationPolicy(.accessory) // 독(Dock)에 아이콘 없음
let delegate = AppDelegate()
app.delegate = delegate
app.run()
