import AVFoundation
import Flutter
import UIKit
import UniformTypeIdentifiers

/// The iOS side of the `fadl/adhan` channel: previews, and importing an
/// audio file as an adhan. iOS rings a notification sound only from the app
/// bundle or Library/Sounds and only up to 30 s, so an import is cut to its
/// first 29.5 s with a fade-out and saved to Library/Sounds as CAF, under
/// the same ids Android uses (`fajr_<ms>`, `regular_<ms>`). Scheduling stays
/// in Dart (lib/core/local_notifications.dart).
final class AdhanSounds: NSObject, UIDocumentPickerDelegate {
  static let clipSeconds = 29.5
  static let fadeSeconds = 3.0
  private static let namesKey = "fadl.adhan.importNames"

  private var player: AVAudioPlayer?
  private var pending: (kind: String, result: FlutterResult)?

  static var soundsDirectory: URL {
    FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask)[0]
      .appendingPathComponent("Sounds", isDirectory: true)
  }

  static func isImportId(_ id: String) -> Bool {
    id.range(of: "^(fajr|regular)_[0-9]+$", options: .regularExpression) != nil
  }

  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    let arguments = call.arguments as? [String: Any]
    switch call.method {
    case "preview":
      preview(arguments?["soundId"] as? String, result: result)
    case "stopPreview":
      player?.stop()
      player = nil
      result(nil)
    case "pickAndImport":
      pick(kind: arguments?["kind"] as? String == "fajr" ? "fajr" : "regular", result: result)
    case "listImported":
      result(Self.listImported())
    case "deleteImported":
      if let id = arguments?["id"] as? String { Self.delete(id) }
      result(nil)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  // MARK: Preview

  private func soundURL(_ id: String) -> URL? {
    if let bundled = Bundle.main.url(forResource: id, withExtension: "caf") {
      return bundled
    }
    guard Self.isImportId(id) else { return nil }
    let file = Self.soundsDirectory.appendingPathComponent("\(id).caf")
    return FileManager.default.fileExists(atPath: file.path) ? file : nil
  }

  private func preview(_ id: String?, result: FlutterResult) {
    guard let id, let url = soundURL(id) else {
      result(FlutterError(code: "missing_sound", message: nil, details: nil))
      return
    }
    do {
      player?.stop()
      player = try AVAudioPlayer(contentsOf: url)
      player?.play()
      result(nil)
    } catch {
      result(FlutterError(code: "preview_failed", message: nil, details: nil))
    }
  }

  // MARK: Import

  private func pick(kind: String, result: @escaping FlutterResult) {
    guard pending == nil else {
      result(FlutterError(code: "busy", message: nil, details: nil))
      return
    }
    guard let presenter = Self.topViewController() else {
      result(FlutterError(code: "no_window", message: nil, details: nil))
      return
    }
    let picker = UIDocumentPickerViewController(forOpeningContentTypes: [.audio], asCopy: true)
    picker.delegate = self
    picker.allowsMultipleSelection = false
    pending = (kind, result)
    presenter.present(picker, animated: true)
  }

  func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
    guard let request = pending else { return }
    pending = nil
    guard let source = urls.first else {
      request.result(nil)
      return
    }
    DispatchQueue.global(qos: .userInitiated).async {
      let id = "\(request.kind)_\(Int64(Date().timeIntervalSince1970 * 1000))"
      let name = source.deletingPathExtension().lastPathComponent
      do {
        try Self.writeClip(from: source, to: Self.soundsDirectory.appendingPathComponent("\(id).caf"))
        Self.setName(name, for: id)
        DispatchQueue.main.async { request.result(["id": id, "name": name, "kind": request.kind]) }
      } catch {
        DispatchQueue.main.async {
          request.result(FlutterError(code: "import_failed", message: nil, details: nil))
        }
      }
    }
  }

  func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
    pending?.result(nil)
    pending = nil
  }

  enum ClipError: Error {
    case empty, unsupported
  }

  /// The first [clipSeconds] of [source] as mono 16-bit PCM CAF at 22.05 kHz,
  /// fading out over the last [fadeSeconds].
  static func writeClip(from source: URL, to target: URL) throws {
    try FileManager.default.createDirectory(at: soundsDirectory, withIntermediateDirectories: true)
    let input = try AVAudioFile(forReading: source)
    let format = input.processingFormat
    let frames = AVAudioFrameCount(min(Double(input.length), clipSeconds * format.sampleRate))
    guard frames > 0, let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frames) else {
      throw ClipError.empty
    }
    try input.read(into: buffer, frameCount: frames)

    let total = Int(buffer.frameLength)
    let fade = min(total, Int(fadeSeconds * format.sampleRate))
    if let channels = buffer.floatChannelData, fade > 0 {
      for channel in 0..<Int(format.channelCount) {
        for i in 0..<fade {
          channels[channel][total - fade + i] *= Float(fade - i) / Float(fade)
        }
      }
    }

    guard
      let outFormat = AVAudioFormat(
        commonFormat: .pcmFormatInt16, sampleRate: 22050, channels: 1, interleaved: true),
      let converter = AVAudioConverter(from: format, to: outFormat),
      let output = AVAudioPCMBuffer(
        pcmFormat: outFormat,
        frameCapacity: AVAudioFrameCount(Double(total) * 22050 / format.sampleRate) + 4096)
    else { throw ClipError.unsupported }
    converter.downmix = true
    var supplied = false
    var conversionError: NSError?
    let status = converter.convert(to: output, error: &conversionError) { _, inputStatus in
      if supplied {
        inputStatus.pointee = .endOfStream
        return nil
      }
      supplied = true
      inputStatus.pointee = .haveData
      return buffer
    }
    if status == .error { throw conversionError ?? ClipError.unsupported }

    try? FileManager.default.removeItem(at: target)
    let file = try AVAudioFile(
      forWriting: target, settings: outFormat.settings, commonFormat: .pcmFormatInt16,
      interleaved: true)
    try file.write(from: output)
  }

  // MARK: Imported files

  private static func names() -> [String: String] {
    UserDefaults.standard.dictionary(forKey: namesKey) as? [String: String] ?? [:]
  }

  private static func setName(_ name: String, for id: String) {
    var all = names()
    all[id] = name
    UserDefaults.standard.set(all, forKey: namesKey)
  }

  static func listImported() -> [[String: String]] {
    let files =
      (try? FileManager.default.contentsOfDirectory(atPath: soundsDirectory.path)) ?? []
    let all = names()
    return files.compactMap { file -> [String: String]? in
      guard file.hasSuffix(".caf") else { return nil }
      let id = String(file.dropLast(4))
      guard isImportId(id) else { return nil }
      return ["id": id, "name": all[id] ?? id, "kind": id.hasPrefix("fajr_") ? "fajr" : "regular"]
    }
    .sorted { $0["id"]! < $1["id"]! }
  }

  static func delete(_ id: String) {
    guard isImportId(id) else { return }
    try? FileManager.default.removeItem(at: soundsDirectory.appendingPathComponent("\(id).caf"))
    var all = names()
    all.removeValue(forKey: id)
    UserDefaults.standard.set(all, forKey: namesKey)
  }

  private static func topViewController() -> UIViewController? {
    let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
    let window = scenes.flatMap(\.windows).first { $0.isKeyWindow } ?? scenes.first?.windows.first
    var top = window?.rootViewController
    while let presented = top?.presentedViewController { top = presented }
    return top
  }
}
