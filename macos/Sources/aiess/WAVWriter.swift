import Foundation

extension Data {
    mutating func appendLE<T: FixedWidthInteger>(_ v: T) {
        var x = v.littleEndian
        Swift.withUnsafeBytes(of: &x) { self.append(contentsOf: $0) }
    }
}

func writeWAV(samples: [Float], sampleRate: Int = 16000, to url: URL) throws {
    // #5: защита от integer overflow — UInt32 покрывает ~37 мин при 16 kHz
    guard samples.count <= Int(UInt32.max / 2) else {
        throw NSError(domain: "WAVWriter", code: 1,
                      userInfo: [NSLocalizedDescriptionKey: "Audio chunk too large for WAV format"])
    }
    let dataSize = UInt32(samples.count * 2)
    var d = Data()
    d.append(contentsOf: "RIFF".utf8); d.appendLE(dataSize + 36)
    d.append(contentsOf: "WAVE".utf8)
    d.append(contentsOf: "fmt ".utf8); d.appendLE(UInt32(16))
    d.appendLE(Int16(1)); d.appendLE(Int16(1))
    d.appendLE(UInt32(sampleRate)); d.appendLE(UInt32(sampleRate * 2))
    d.appendLE(Int16(2)); d.appendLE(Int16(16))
    d.append(contentsOf: "data".utf8); d.appendLE(dataSize)
    for s in samples {
        d.appendLE(Int16(max(-32768, min(32767, Int32(s * 32767)))))
    }
    try d.write(to: url, options: .atomic)
}
