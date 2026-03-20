import AppKit

final class SettingsWC: NSWindowController {
    private let recorder: ChunkRecorder
    private let screenshots: ScreenshotRecorder
    private var audioPathField: NSTextField!
    private var screenshotPathField: NSTextField!

    init(recorder: ChunkRecorder, screenshots: ScreenshotRecorder) {
        self.recorder = recorder
        self.screenshots = screenshots
        let win = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 460, height: 210),
                           styleMask: [.titled, .closable], backing: .buffered, defer: false)
        win.title = "aiess – Settings"
        win.center()
        super.init(window: win)
        buildUI()
    }
    required init?(coder: NSCoder) { fatalError() }

    private func buildUI() {
        guard let cv = window?.contentView else { return }

        // Audio folder
        let audioLabel = NSTextField(labelWithString: "Save audio chunks to:")
        audioLabel.translatesAutoresizingMaskIntoConstraints = false
        audioPathField = NSTextField()
        audioPathField.stringValue = recorder.folder.path
        audioPathField.isEditable  = false
        audioPathField.translatesAutoresizingMaskIntoConstraints = false
        let audioBrowse = NSButton(title: "Browse…", target: self, action: #selector(browseAudio))
        audioBrowse.translatesAutoresizingMaskIntoConstraints = false

        // Screenshot folder
        let screenshotLabel = NSTextField(labelWithString: "Save screenshots to:")
        screenshotLabel.translatesAutoresizingMaskIntoConstraints = false
        screenshotPathField = NSTextField()
        screenshotPathField.stringValue = screenshots.folder.path
        screenshotPathField.isEditable  = false
        screenshotPathField.translatesAutoresizingMaskIntoConstraints = false
        let screenshotBrowse = NSButton(title: "Browse…", target: self, action: #selector(browseScreenshots))
        screenshotBrowse.translatesAutoresizingMaskIntoConstraints = false

        let close = NSButton(title: "Close", target: self, action: #selector(closeWindow))
        close.keyEquivalent = "\r"
        close.translatesAutoresizingMaskIntoConstraints = false

        [audioLabel, audioPathField, audioBrowse,
         screenshotLabel, screenshotPathField, screenshotBrowse,
         close].forEach { cv.addSubview($0) }

        NSLayoutConstraint.activate([
            audioLabel.topAnchor.constraint(equalTo: cv.topAnchor, constant: 24),
            audioLabel.leadingAnchor.constraint(equalTo: cv.leadingAnchor, constant: 20),
            audioPathField.topAnchor.constraint(equalTo: audioLabel.bottomAnchor, constant: 8),
            audioPathField.leadingAnchor.constraint(equalTo: cv.leadingAnchor, constant: 20),
            audioPathField.trailingAnchor.constraint(equalTo: audioBrowse.leadingAnchor, constant: -8),
            audioBrowse.centerYAnchor.constraint(equalTo: audioPathField.centerYAnchor),
            audioBrowse.trailingAnchor.constraint(equalTo: cv.trailingAnchor, constant: -20),
            audioBrowse.widthAnchor.constraint(equalToConstant: 80),

            screenshotLabel.topAnchor.constraint(equalTo: audioPathField.bottomAnchor, constant: 20),
            screenshotLabel.leadingAnchor.constraint(equalTo: cv.leadingAnchor, constant: 20),
            screenshotPathField.topAnchor.constraint(equalTo: screenshotLabel.bottomAnchor, constant: 8),
            screenshotPathField.leadingAnchor.constraint(equalTo: cv.leadingAnchor, constant: 20),
            screenshotPathField.trailingAnchor.constraint(equalTo: screenshotBrowse.leadingAnchor, constant: -8),
            screenshotBrowse.centerYAnchor.constraint(equalTo: screenshotPathField.centerYAnchor),
            screenshotBrowse.trailingAnchor.constraint(equalTo: cv.trailingAnchor, constant: -20),
            screenshotBrowse.widthAnchor.constraint(equalToConstant: 80),

            close.topAnchor.constraint(equalTo: screenshotPathField.bottomAnchor, constant: 20),
            close.trailingAnchor.constraint(equalTo: cv.trailingAnchor, constant: -20),
            close.widthAnchor.constraint(equalToConstant: 80),
        ])
    }

    @objc private func browseAudio() {
        guard let url = pickFolder(startingAt: recorder.folder) else { return }
        recorder.setFolder(url); audioPathField.stringValue = url.path
    }

    @objc private func browseScreenshots() {
        guard let url = pickFolder(startingAt: screenshots.folder) else { return }
        screenshots.setFolder(url); screenshotPathField.stringValue = url.path
    }

    private func pickFolder(startingAt dir: URL) -> URL? {
        let p = NSOpenPanel()
        p.canChooseFiles = false; p.canChooseDirectories = true
        p.canCreateDirectories = true; p.prompt = "Select"
        p.directoryURL = dir
        guard p.runModal() == .OK else { return nil }
        return p.url
    }

    @objc private func closeWindow() { window?.close() }
}
