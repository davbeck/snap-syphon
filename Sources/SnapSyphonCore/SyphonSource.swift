import CSyphon
import Foundation

public struct SourceSelection: Equatable, Sendable {
  public var query: String?
  public var application: String?
  public var name: String?
  public var uuid: String?
  public var index: Int?

  public init(
    query: String? = nil,
    application: String? = nil,
    name: String? = nil,
    uuid: String? = nil,
    index: Int? = nil,
  ) {
    self.query = query
    self.application = application
    self.name = name
    self.uuid = uuid
    self.index = index
  }
}

public struct SyphonSourceDescription: Codable, Equatable, Sendable {
  public let index: Int
  public let application: String
  public let name: String
  public let uuid: String

  public var displayName: String {
    let app = application.isEmpty ? "Unknown application" : application
    let server = name.isEmpty ? "Unnamed source" : name
    return "\(app) — \(server)"
  }
}

public final class SyphonSource {
  public let description: SyphonSourceDescription
  let nativeSource: SSYSource

  init(index: Int, nativeSource: SSYSource) {
    description = SyphonSourceDescription(
      index: index,
      application: nativeSource.applicationName,
      name: nativeSource.name,
      uuid: nativeSource.uuid,
    )
    self.nativeSource = nativeSource
  }
}

public enum SourceDiscovery {
  public static func discover(wait: TimeInterval = 0.5) -> [SyphonSource] {
    let deadline = Date(timeIntervalSinceNow: max(0, wait))
    var nativeSources = SSYDiscoverSources()

    repeat {
      _ = RunLoop.current.run(
        mode: .default,
        before: Date(timeIntervalSinceNow: 0.05),
      )
      nativeSources = SSYDiscoverSources()
    } while Date() < deadline

    return
      nativeSources
        .sorted {
          let left = "\($0.applicationName)\u{0}\($0.name)\u{0}\($0.uuid)"
          let right = "\($1.applicationName)\u{0}\($1.name)\u{0}\($1.uuid)"
          return left.localizedCaseInsensitiveCompare(right) == .orderedAscending
        }
        .enumerated()
        .map { SyphonSource(index: $0.offset, nativeSource: $0.element) }
  }

  public static func select(
    from sources: [SyphonSource],
    using selection: SourceSelection,
  ) throws -> SyphonSource {
    if let index = selection.index {
      guard sources.indices.contains(index) else {
        throw SnapSyphonError.sourceNotFound(
          "No source exists at index \(index).",
        )
      }
      return sources[index]
    }

    var matches = sources

    if let uuid = selection.uuid {
      matches = matches.filter {
        $0.description.uuid.caseInsensitiveCompare(uuid) == .orderedSame
      }
    }
    if let application = selection.application {
      matches = matches.filter {
        contains($0.description.application, query: application)
      }
    }
    if let name = selection.name {
      matches = matches.filter {
        contains($0.description.name, query: name)
      }
    }
    if let query = selection.query {
      matches = matches.filter {
        contains($0.description.application, query: query)
          || contains($0.description.name, query: query)
          || contains($0.description.uuid, query: query)
      }
    }

    if matches.count == 1 {
      return matches[0]
    }
    if matches.isEmpty {
      throw SnapSyphonError.sourceNotFound(
        "No source matched the supplied selector.",
      )
    }
    if selection == SourceSelection(), sources.count == 1 {
      return sources[0]
    }

    let candidates =
      matches
        .map { "[\($0.description.index)] \($0.description.displayName)" }
        .joined(separator: "\n")
    throw SnapSyphonError.ambiguousSource(
      "More than one source matched. Use --index, --uuid, --app, or --name:\n"
        + candidates,
    )
  }

  private static func contains(_ value: String, query: String) -> Bool {
    value.range(of: query, options: [.caseInsensitive, .diacriticInsensitive]) != nil
  }
}
