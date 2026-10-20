import AppKit

// 顶层代码本身在主线程运行，assumeIsolated 仅为满足 MainActor 隔离检查
MainActor.assumeIsolated {
    let application = NSApplication.shared
    let delegate = AppDelegate()
    application.delegate = delegate
    application.run()
}
