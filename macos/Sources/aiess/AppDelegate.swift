import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private let recorder   = ChunkRecorder()
    private let screenshots = ScreenshotRecorder()
    private var settingsWC: SettingsWC?

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupStatusItem()
        recorder.start()
        screenshots.start()
    }

    // #2: сохраняем последний аудио-чанк при выходе
    func applicationWillTerminate(_ notification: Notification) {
        recorder.stop()
        screenshots.stop()
    }

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        updateIcon()
        statusItem.button?.action = #selector(clicked)
        statusItem.button?.target = self
        statusItem.button?.sendAction(on: [.leftMouseUp, .rightMouseUp])
    }

    // #3: разные иконки для разных состояний
    private func updateIcon() {
        let name: String
        if recorder.muted {
            name = "mic.slash.fill"    // аудио выключено (скриншоты не важны)
        } else if screenshots.paused {
            name = "mic.badge.xmark"   // аудио пишем, скриншоты на паузе
        } else {
            name = "mic.fill"          // всё активно
        }
        let img = NSImage(systemSymbolName: name, accessibilityDescription: nil)
        img?.isTemplate = true
        statusItem.button?.image = img
    }

    @objc private func clicked() {
        let menu = NSMenu()
        menu.addItem(.init(title: recorder.muted ? "Unmute" : "Mute",
                           action: #selector(toggleMute), keyEquivalent: "m"))
        menu.addItem(.init(title: screenshots.paused ? "Resume Screenshots" : "Pause Screenshots",
                           action: #selector(toggleScreenshots), keyEquivalent: "s"))
        menu.addItem(.separator())
        menu.addItem(.init(title: "Open Audio Folder",
                           action: #selector(openFolder), keyEquivalent: "o"))
        menu.addItem(.init(title: "Open Screenshots Folder",
                           action: #selector(openScreenshotsFolder), keyEquivalent: "p"))
        menu.addItem(.init(title: "Settings…",
                           action: #selector(openSettings), keyEquivalent: ","))
        menu.addItem(.separator())

        let quitItem = NSMenuItem(title: "Quit",
                                  action: #selector(quit), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        // Set target for all items except Quit (already set above)
        for item in menu.items where item !== quitItem && !item.isSeparatorItem {
            item.target = self
        }

        statusItem.menu = menu
        statusItem.button?.performClick(nil)
        statusItem.menu = nil
    }

    @objc private func toggleMute() { recorder.setMuted(!recorder.muted); updateIcon() }
    @objc private func toggleScreenshots() { screenshots.setPaused(!screenshots.paused); updateIcon() }
    @objc private func openFolder() { NSWorkspace.shared.open(recorder.folder) }
    @objc private func openScreenshotsFolder() { NSWorkspace.shared.open(screenshots.folder) }
    @objc private func openSettings() {
        if settingsWC == nil { settingsWC = SettingsWC(recorder: recorder, screenshots: screenshots) }
        settingsWC?.showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    @objc func quit() { NSApp.terminate(nil) }
}
