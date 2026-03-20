import AppKit

final class ScreenshotRecorder {

    private(set) var folder: URL
    private(set) var paused = false
    private var timer: Timer?
    private let interval: TimeInterval = 10
    private var lastHash: Data?
    private let fmt: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd_HH-mm-ss"; return f
    }()
    private let captureQueue = DispatchQueue(label: "aiess.screenshot.capture", qos: .utility)

    var isRunning: Bool { timer != nil }

    init() {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        folder = UserDefaults.standard.url(forKey: "screenshotFolder")
               ?? docs.appendingPathComponent("aiess-screenshots")
        ensureFolder()
    }

    func setFolder(_ url: URL) {
        folder = url
        UserDefaults.standard.set(url, forKey: "screenshotFolder")
        ensureFolder()
    }

    func start() {
        guard !paused else { return }
        stop()  // #8: не утечём старый таймер
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            self?.capture()
        }
        capture()
    }

    func stop() { timer?.invalidate(); timer = nil }

    func setPaused(_ p: Bool) {
        paused = p
        if p {
            stop()
        } else {
            start()
        }
    }

    private func capture() {
        // #6: захватываем folder на main thread до перехода в фоновую очередь
        let dest = folder
        captureQueue.async { [weak self] in  // #1: не блокируем main thread
            self?.captureBackground(folder: dest)
        }
    }

    private func captureBackground(folder: URL) {
        let tmp = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("\(UUID().uuidString).jpg")  // #7: уникальное имя

        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
        task.arguments = ["-x", "-t", "jpg", tmp.path]
        try? task.run()
        task.waitUntilExit()

        guard let data = try? Data(contentsOf: tmp) else { return }

        let hash = thumbHash(data)

        // #4: nil hash (ошибка хеширования) никогда не считается совпадением — всегда сохраняем
        if let hash = hash, hash == lastHash {
            try? FileManager.default.removeItem(at: tmp)
            return
        }
        lastHash = hash

        let name = fmt.string(from: Date())
        let dest = folder.appendingPathComponent("\(name).jpg")
        try? FileManager.default.moveItem(at: tmp, to: dest)  // #10: move вместо copy
    }

    private func thumbHash(_ data: Data) -> Data? {
        guard let src = NSImage(data: data),
              let cgImg = src.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return nil }

        let size = 16
        var pixels = [UInt8](repeating: 0, count: size * size)
        let ctx = CGContext(data: &pixels, width: size, height: size,
                            bitsPerComponent: 8, bytesPerRow: size,
                            space: CGColorSpaceCreateDeviceGray(),
                            bitmapInfo: CGImageAlphaInfo.none.rawValue)
        ctx?.draw(cgImg, in: CGRect(x: 0, y: 0, width: size, height: size))
        return Data(pixels)
    }

    private func ensureFolder() {
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    }
}
