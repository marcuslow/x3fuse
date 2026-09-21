//
//  ExternalOpenService.swift
//  X3Fuse
//
//  Files handed to the running app from outside: Finder "Open With", drops on the Dock
//  icon, `open -a X3Fuse file.X3F`, and the `x3fuse://` URL scheme that the Finder Quick
//  Action ("Convert to DNG with X3Fuse") uses to queue files *and* start converting them.
//
//  URL scheme:
//    x3fuse://open?path=<percent-encoded POSIX path>[&path=…]            add to the queue
//    x3fuse://convert?path=<…>[&path=…][&format=dng|tiff|jpg]            add and convert now
//
//  Plain file URLs (Open With / Dock) are only added to the queue; the user still presses
//  Convert. The Quick Action is the explicit "make the DNG" gesture, so it converts.
//

import Foundation

@MainActor
@Observable
final class ExternalOpenService {
  static let shared = ExternalOpenService()

  static let urlScheme = "x3fuse"

  /// A parsed request, independent of app state so it can be unit-tested.
  struct Request: Equatable {
    var fileURLs: [URL]
    var convert: Bool
    var outputFormat: OutputFormat?
  }

  private let queue = ConversionQueue.shared
  private let settings = ConversionSettings.shared
  private let fileProcessor = FileProcessor.shared
  private let logger = LoggingService.shared

  /// Files asked to convert while another run was in progress. Drained by `drainTask`.
  private var pendingConvertIDs: [X3FFile.ID] = []
  private var drainTask: Task<Void, Never>?

  private init() {}

  // MARK: - Entry point

  func handle(_ url: URL) {
    guard let request = Self.request(from: url) else {
      logger.logError("Ignoring unrecognised external open request: \(url.absoluteString)")
      return
    }
    apply(request)
  }

  // MARK: - Parsing

  /// Translate an incoming URL into a request. Returns nil for URLs the app does not handle.
  nonisolated static func request(from url: URL) -> Request? {
    if url.isFileURL {
      return Request(fileURLs: [url], convert: false, outputFormat: nil)
    }

    guard url.scheme?.lowercased() == urlScheme,
      let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
    else { return nil }

    // `x3fuse://convert?...` parses with host "convert"; `x3fuse:convert` would put it in the path.
    let action = (components.host ?? components.path.trimmingCharacters(in: CharacterSet(charactersIn: "/")))
      .lowercased()
    guard action == "convert" || action == "open" else { return nil }

    var fileURLs: [URL] = []
    var outputFormat: OutputFormat?

    for item in components.queryItems ?? [] {
      guard let value = item.value, !value.isEmpty else { continue }
      switch item.name.lowercased() {
      case "path":
        fileURLs.append(URL(fileURLWithPath: value))
      case "file":
        // Also accept a full file:// URL for callers that already have one.
        if let fileURL = URL(string: value), fileURL.isFileURL {
          fileURLs.append(fileURL)
        }
      case "format":
        outputFormat = Self.outputFormat(named: value)
      default:
        break
      }
    }

    return Request(fileURLs: fileURLs, convert: action == "convert", outputFormat: outputFormat)
  }

  nonisolated static func outputFormat(named name: String) -> OutputFormat? {
    switch name.lowercased() {
    case "dng": return .dng
    case "tif", "tiff": return .tiff
    case "jpg", "jpeg", "embeddedjpg", "embedded-jpg": return .embeddedJpg
    default: return nil
    }
  }

  // MARK: - Applying a request

  func apply(_ request: Request) {
    var accepted: [X3FFile] = []
    var newURLs: [URL] = []

    for rawURL in request.fileURLs {
      let url = rawURL.standardizedFileURL

      guard url.pathExtension.lowercased() == "x3f" else {
        logger.logDebug("External open: skipping non-X3F item \(url.lastPathComponent)")
        continue
      }

      var isDirectory: ObjCBool = false
      guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory),
        !isDirectory.boolValue
      else {
        logger.logError("External open: file not found: \(url.path)")
        continue
      }

      if let existing = queue.files.first(where: { $0.url.standardizedFileURL.path == url.path }) {
        // Already in the queue (dropped earlier, or listed twice): reuse it instead of duplicating.
        if !accepted.contains(where: { $0.id == existing.id }) {
          accepted.append(existing)
        }
      } else if !newURLs.contains(url) {
        newURLs.append(url)
      }
    }

    if !newURLs.isEmpty {
      queue.addFiles(newURLs)
      let newPaths = Set(newURLs.map(\.path))
      accepted += queue.files.filter { newPaths.contains($0.url.standardizedFileURL.path) }
    }

    if let format = request.outputFormat {
      // An explicit format from the caller (the Quick Action is named "Convert to
      // DNG") applies to this conversion only and also overrides the "Extract JPG
      // only" checkbox; scheduleConversion clears it once the run has finished.
      for file in accepted {
        file.requestedOutputFormat = format
      }
      if format != .embeddedJpg && settings.extractJpgOnly {
        logger.logConversion(
          "External open asked for \(format.displayName); overriding the \"Extract JPG only\" checkbox for these files")
      }
    }

    logger.logConversion(
      "External open: \(accepted.count) X3F file(s) received (\(newURLs.count) new)"
        + (request.convert ? ", starting conversion" : ""))

    guard request.convert, !accepted.isEmpty else { return }
    scheduleConversion(of: accepted.map(\.id))
  }

  // MARK: - Conversion scheduling

  /// Convert the given files as soon as no other conversion is running. Requests that arrive
  /// while a run is in progress (the Quick Action sends one URL per batch of files, and the
  /// user may already have pressed Convert) are collected and processed afterwards.
  private func scheduleConversion(of fileIDs: [X3FFile.ID]) {
    for id in fileIDs where !pendingConvertIDs.contains(id) {
      pendingConvertIDs.append(id)
    }

    guard drainTask == nil else { return }

    drainTask = Task { @MainActor [weak self] in
      guard let self else { return }
      defer { self.drainTask = nil }

      while !self.pendingConvertIDs.isEmpty {
        while self.queue.isProcessing {
          try? await Task.sleep(for: .milliseconds(250))
        }

        let batch = self.pendingConvertIDs
        self.pendingConvertIDs.removeAll()

        // Files the user removed from the queue in the meantime are dropped.
        let liveIDs = Set(batch.filter { id in self.queue.files.contains { $0.id == id } })
        guard !liveIDs.isEmpty else { continue }

        // processSelectedFiles resets already-converted files and overwrites their output:
        // the Quick Action is an explicit per-file request, so no overwrite dialog here.
        await self.fileProcessor.processSelectedFiles(liveIDs)

        // The requested format was for this run only; later manual converts of these
        // queue entries follow the settings and checkbox again.
        for file in self.queue.files where liveIDs.contains(file.id) {
          file.requestedOutputFormat = nil
        }
      }
    }
  }
}
