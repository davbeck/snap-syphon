import Foundation

public enum SnapSyphonError: Error, LocalizedError, Equatable {
  case invalidArguments(String)
  case sourceNotFound(String)
  case ambiguousSource(String)
  case capture(String)
  case output(String)
  case recording(String)

  public var errorDescription: String? {
    switch self {
    case let .invalidArguments(message),
         let .sourceNotFound(message),
         let .ambiguousSource(message),
         let .capture(message),
         let .output(message),
         let .recording(message):
      message
    }
  }
}
