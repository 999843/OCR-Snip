import AppKit

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
// .accessory：常驻菜单栏，不占 Dock、不抢焦点
app.setActivationPolicy(.accessory)
app.run()
