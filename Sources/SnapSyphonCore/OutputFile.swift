import Foundation

public enum OutputFile {
  public static func url(for path: String) -> URL {
    let expanded = (path as NSString).expandingTildeInPath
    return URL(fileURLWithPath: expanded).standardizedFileURL
  }

  public static func writeAtomically(
    to url: URL,
    force: Bool,
    _ write: (URL) throws -> Void,
  ) throws {
    try validateDestination(url, force: force)

    let temporaryURL = temporaryURL(for: url)
    defer {
      try? FileManager.default.removeItem(at: temporaryURL)
    }

    try write(temporaryURL)

    var temporaryIsDirectory: ObjCBool = false
    guard
      FileManager.default.fileExists(
        atPath: temporaryURL.path,
        isDirectory: &temporaryIsDirectory,
      ), !temporaryIsDirectory.boolValue
    else {
      throw SnapSyphonError.output(
        "Output writer did not create \(temporaryURL.path).",
      )
    }

    try validateDestination(url, force: force)

    do {
      if FileManager.default.fileExists(atPath: url.path) {
        _ = try FileManager.default.replaceItemAt(
          url,
          withItemAt: temporaryURL,
        )
      } else {
        try FileManager.default.moveItem(at: temporaryURL, to: url)
      }
    } catch {
      throw SnapSyphonError.output(
        "Could not save \(url.path): \(error.localizedDescription)",
      )
    }
  }

  private static func validateDestination(_ url: URL, force: Bool) throws {
    var isDirectory: ObjCBool = false
    let parent = url.deletingLastPathComponent()
    guard
      FileManager.default.fileExists(
        atPath: parent.path,
        isDirectory: &isDirectory,
      ), isDirectory.boolValue
    else {
      throw SnapSyphonError.output(
        "Output directory does not exist: \(parent.path)",
      )
    }

    var outputIsDirectory: ObjCBool = false
    guard
      FileManager.default.fileExists(
        atPath: url.path,
        isDirectory: &outputIsDirectory,
      )
    else {
      return
    }
    guard !outputIsDirectory.boolValue else {
      throw SnapSyphonError.output(
        "Output path is a directory and will not be replaced: \(url.path)",
      )
    }
    guard force else {
      throw SnapSyphonError.output(
        "Output already exists: \(url.path). Use --force to replace it.",
      )
    }
  }

  private static func temporaryURL(for url: URL) -> URL {
    let fileExtension = url.pathExtension
    let basename = url.deletingPathExtension().lastPathComponent
    let suffix = fileExtension.isEmpty ? "" : ".\(fileExtension)"
    return url.deletingLastPathComponent().appendingPathComponent(
      ".\(basename).\(UUID().uuidString)\(suffix)",
    )
  }

  public static func validateSnapshot(_ url: URL) throws {
    guard ["png", "jpg", "jpeg"].contains(url.pathExtension.lowercased()) else {
      throw SnapSyphonError.output(
        "Snapshot output must use a .png, .jpg, or .jpeg extension.",
      )
    }
  }

  public static func validateRecording(_ url: URL, codec: VideoCodec) throws {
    let fileExtension = url.pathExtension.lowercased()
    guard ["mov", "mp4"].contains(fileExtension) else {
      throw SnapSyphonError.recording(
        "Recording output must use a .mov or .mp4 extension.",
      )
    }
    if codec.requiresMOVContainer, fileExtension != "mov" {
      throw SnapSyphonError.recording(
        "\(codec.rawValue) recordings require a .mov output file.",
      )
    }
  }
}
