import ArgumentParser
import Foundation
import SnapSyphonCore

public struct SnapSyphonCommand: ParsableCommand {
  public static let configuration = CommandConfiguration(
    commandName: "snap-syphon",
    abstract: "Capture still images and recordings from local Syphon sources.",
    version: snapSyphonVersion,
    subcommands: [
      ListSources.self,
      Snapshot.self,
      Record.self,
    ],
  )

  public init() {}
}

struct SourceOptions: ParsableArguments {
  @Option(help: "Match a source name, application name, or UUID.")
  var source: String?

  @Option(help: "Match an application name.")
  var app: String?

  @Option(help: "Match a source name.")
  var name: String?

  @Option(help: "Match an exact source UUID.")
  var uuid: String?

  @Option(help: "Select the zero-based index printed by `list`.")
  var index: Int?

  @Option(help: "Seconds to wait for source discovery.")
  var wait = 0.5

  mutating func validate() throws {
    guard wait >= 0 else {
      throw ValidationError("--wait must be zero or greater.")
    }
    let otherSelectors = [source, app, name, uuid].compactMap(\.self)
    if index != nil, !otherSelectors.isEmpty {
      throw ValidationError(
        "--index cannot be combined with other source selectors.",
      )
    }
  }

  var selection: SourceSelection {
    SourceSelection(
      query: source,
      application: app,
      name: name,
      uuid: uuid,
      index: index,
    )
  }
}

struct StabilityOptions: ParsableArguments {
  @Option(
    help:
    "Require this many frames close to one anchor before proceeding.",
  )
  var stableFrames = 1

  @Option(
    help:
    "Maximum normalized mean RGB difference from the anchor (0...1).",
  )
  var threshold = 0.001

  @Option(help: "Stability samples per second.")
  var sampleRate = 30.0

  @Option(help: "Seconds to wait for frames or stability.")
  var timeout = 30.0

  mutating func validate() throws {
    guard stableFrames >= 1 else {
      throw ValidationError("--stable-frames must be at least 1.")
    }
    guard (0 ... 1).contains(threshold) else {
      throw ValidationError("--threshold must be between 0 and 1.")
    }
    guard sampleRate > 0, sampleRate <= 240 else {
      throw ValidationError(
        "--sample-rate must be greater than zero and no more than 240.",
      )
    }
    guard timeout > 0 else {
      throw ValidationError("--timeout must be greater than zero.")
    }
  }
}

struct ListSources: ParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "list",
    abstract: "List available Syphon sources.",
    aliases: ["sources"],
  )

  @OptionGroup var sourceOptions: ListDiscoveryOptions

  @Flag(help: "Print source descriptions as JSON.")
  var json = false

  mutating func run() throws {
    let sources = SourceDiscovery.discover(wait: sourceOptions.wait)
    let descriptions = sources.map(\.description)

    if json {
      let encoder = JSONEncoder()
      encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
      let data = try encoder.encode(descriptions)
      print(String(decoding: data, as: UTF8.self))
      return
    }

    if descriptions.isEmpty {
      print("No Syphon sources found.")
      return
    }
    for source in descriptions {
      print("[\(source.index)] \(source.displayName)")
      print("    \(source.uuid)")
    }
  }
}

struct ListDiscoveryOptions: ParsableArguments {
  @Option(help: "Seconds to wait for source discovery.")
  var wait = 0.5

  mutating func validate() throws {
    guard wait >= 0 else {
      throw ValidationError("--wait must be zero or greater.")
    }
  }
}

struct Snapshot: ParsableCommand {
  static let configuration = CommandConfiguration(
    abstract: "Capture a PNG or JPEG snapshot.",
    aliases: ["snap"],
  )

  @Argument(help: "Destination .png, .jpg, or .jpeg path.")
  var output: String

  @OptionGroup var sourceOptions: SourceOptions
  @OptionGroup var stability: StabilityOptions

  @Option(help: "JPEG quality from 0 to 1.")
  var quality = 0.92

  @Flag(name: .shortAndLong, help: "Replace an existing output file.")
  var force = false

  mutating func validate() throws {
    guard (0 ... 1).contains(quality) else {
      throw ValidationError("--quality must be between 0 and 1.")
    }
  }

  mutating func run() throws {
    let outputURL = OutputFile.url(for: output)
    try OutputFile.validateSnapshot(outputURL)
    let source = try selectedSource(using: sourceOptions)
    let capture = try SyphonCapture(source: source)

    if stability.stableFrames > 1 {
      writeProgress(
        "Waiting for \(stability.stableFrames) consistent frames "
          + "(threshold \(stability.threshold))…",
      )
    }
    var lastProgress = 0
    let requiredStableFrames = stability.stableFrames
    let frame = try capture.capture(
      stableFrames: requiredStableFrames,
      threshold: stability.threshold,
      sampleRate: stability.sampleRate,
      timeout: stability.timeout,
    ) { observation in
      guard requiredStableFrames > 1,
            observation.consistentFrames != lastProgress
      else {
        return
      }
      lastProgress = observation.consistentFrames
      writeProgress(
        "Consistent frames: \(observation.consistentFrames)"
          + "/\(observation.requiredFrames)",
      )
    }

    try OutputFile.writeAtomically(to: outputURL, force: force) {
      try frame.write(to: $0, quality: quality)
    }
    print(
      "Saved \(frame.width)x\(frame.height) snapshot from "
        + "\(source.description.displayName) to \(outputURL.path)",
    )
  }
}

struct Record: ParsableCommand {
  static let configuration = CommandConfiguration(
    abstract: "Record video from a Syphon source.",
  )

  @Argument(help: "Destination .mov or .mp4 path.")
  var output: String

  @OptionGroup var sourceOptions: SourceOptions
  @OptionGroup var stability: StabilityOptions

  @Option(help: "Required recording duration in seconds.")
  var duration: Double

  @Option(name: .customLong("fps"), help: "Output frames per second.")
  var framesPerSecond = 30.0

  @Option(help: "Video codec: h264, hevc, or prores.")
  var codec = VideoCodec.h264

  @Flag(name: .shortAndLong, help: "Replace an existing output file.")
  var force = false

  mutating func validate() throws {
    guard duration > 0 else {
      throw ValidationError("--duration must be greater than zero.")
    }
    guard framesPerSecond > 0, framesPerSecond <= 240 else {
      throw ValidationError(
        "--fps must be greater than zero and no more than 240.",
      )
    }
  }

  mutating func run() throws {
    let outputURL = OutputFile.url(for: output)
    try OutputFile.validateRecording(outputURL, codec: codec)
    let source = try selectedSource(using: sourceOptions)
    let capture = try SyphonCapture(source: source)

    if stability.stableFrames > 1 {
      writeProgress(
        "Waiting for \(stability.stableFrames) consistent frames "
          + "before recording…",
      )
      _ = try capture.capture(
        stableFrames: stability.stableFrames,
        threshold: stability.threshold,
        sampleRate: stability.sampleRate,
        timeout: stability.timeout,
      )
    }

    writeProgress(
      "Recording \(duration) seconds from "
        + "\(source.description.displayName)…",
    )
    var lastReportedSecond = -1
    try OutputFile.writeAtomically(to: outputURL, force: force) {
      temporaryURL in
      try capture.record(
        to: temporaryURL,
        duration: duration,
        framesPerSecond: framesPerSecond,
        codec: codec,
      ) { progress in
        let second = Int(progress.elapsed)
        guard second != lastReportedSecond else {
          return
        }
        lastReportedSecond = second
        writeProgress(
          "Recorded \(progress.frame)/\(progress.totalFrames) frames",
        )
      }
    }
    print("Saved recording to \(outputURL.path)")
  }
}

extension VideoCodec: ExpressibleByArgument {}

private func selectedSource(using options: SourceOptions) throws -> SyphonSource {
  let sources = SourceDiscovery.discover(wait: options.wait)
  guard !sources.isEmpty else {
    throw SnapSyphonError.sourceNotFound(
      "No Syphon sources were found. Check that a source is publishing.",
    )
  }
  return try SourceDiscovery.select(from: sources, using: options.selection)
}

private func writeProgress(_ message: String) {
  FileHandle.standardError.write(Data((message + "\n").utf8))
}
