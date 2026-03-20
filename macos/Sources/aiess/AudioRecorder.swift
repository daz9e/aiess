import AVFoundation

final class ChunkRecorder {

    private(set) var folder: URL
    private(set) var muted = false

    private let engine      = AVAudioEngine()
    private let targetRate: Double = 16_000
    private var conv: AVAudioConverter?
    private var samples     = [Float]()
    private var lock        = NSLock()
    private var chunkTimer: Timer?
    private var tapInstalled = false
    private var chunkStart  = Date()

    private let chunkSecs: TimeInterval = 30

    // #9: кешируем DateFormatter вместо создания при каждом saveChunk/stopEngine
    private let fmt: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd_HH-mm-ss"; return f
    }()

    init() {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        folder = UserDefaults.standard.url(forKey: "audioFolder")
               ?? docs.appendingPathComponent("aiess")
        ensureFolder()
    }

    func setFolder(_ url: URL) {
        folder = url
        UserDefaults.standard.set(url, forKey: "audioFolder")
        ensureFolder()
    }

    func start() {
        guard !muted else { return }
        do { try setupEngine() }
        catch { print("Engine error: \(error)") }
    }

    // #2: публичный stop() для вызова из applicationWillTerminate
    func stop() {
        stopEngine()
    }

    func setMuted(_ m: Bool) {
        muted = m
        m ? stopEngine() : start()
    }

    // MARK: private

    private func setupEngine() throws {
        stopEngine()
        let node      = engine.inputNode
        let inputFmt  = node.outputFormat(forBus: 0)
        let targetFmt = AVAudioFormat(commonFormat: .pcmFormatFloat32,
                                      sampleRate: targetRate,
                                      channels: 1, interleaved: false)!
        guard let converter = AVAudioConverter(from: inputFmt, to: targetFmt) else {
            throw NSError(domain: "Recorder", code: 1)
        }
        self.conv = converter
        chunkStart = Date()

        node.installTap(onBus: 0, bufferSize: 4096, format: inputFmt) { [weak self] buf, _ in
            self?.convert(buf, conv: converter, fmt: targetFmt)
        }
        tapInstalled = true
        engine.prepare()
        try engine.start()

        chunkTimer = Timer.scheduledTimer(withTimeInterval: chunkSecs, repeats: true) { [weak self] _ in
            self?.saveChunk()
        }
        print("🎙 Recording…")
    }

    private func convert(_ buf: AVAudioPCMBuffer, conv: AVAudioConverter, fmt: AVAudioFormat) {
        let ratio     = targetRate / buf.format.sampleRate
        let outFrames = AVAudioFrameCount(Double(buf.frameLength) * ratio + 1)
        guard let out = AVAudioPCMBuffer(pcmFormat: fmt, frameCapacity: outFrames) else { return }
        var used = false
        conv.convert(to: out, error: nil) { _, status in
            if used { status.pointee = .noDataNow; return nil }
            used = true; status.pointee = .haveData; return buf
        }
        guard out.frameLength > 0, let ch = out.floatChannelData?[0] else { return }
        let slice = Array(UnsafeBufferPointer(start: ch, count: Int(out.frameLength)))
        lock.lock(); samples += slice; lock.unlock()
    }

    // #11: защита от деления на 0 при пустом массиве
    private func isSilence(_ samples: [Float], threshold: Float = 0.01) -> Bool {
        guard !samples.isEmpty else { return true }
        let rms = sqrt(samples.map { $0 * $0 }.reduce(0, +) / Float(samples.count))
        return rms < threshold
    }

    private func saveChunk() {
        lock.lock()
        guard !samples.isEmpty else { lock.unlock(); return }
        let snap  = samples; samples = []
        lock.unlock()

        let start = chunkStart
        chunkStart = Date()

        if isSilence(snap) {
            print("🔇 Silence skipped")
            return
        }

        let name = fmt.string(from: start)
        let url  = folder.appendingPathComponent("\(name).wav")

        do {
            try writeWAV(samples: snap, to: url)
            print("💾 Saved: \(url.lastPathComponent) (\(snap.count / 16000)s)")
        } catch {
            print("Write error: \(error)")
        }
    }

    private func stopEngine() {
        chunkTimer?.invalidate(); chunkTimer = nil
        if tapInstalled { engine.inputNode.removeTap(onBus: 0); tapInstalled = false }
        if engine.isRunning { engine.stop() }
        engine.reset()
        // flush remaining
        lock.lock(); let left = samples; samples = []; lock.unlock()
        if !left.isEmpty && !isSilence(left) {
            let url = folder.appendingPathComponent("\(fmt.string(from: chunkStart)).wav")
            try? writeWAV(samples: left, to: url)
        }
    }

    private func ensureFolder() {
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    }
}
