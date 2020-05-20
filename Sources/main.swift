import AppKit

// `@NSApplicationMain` loads whatever nib it can find in our bundle, which is not what we want.
let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
