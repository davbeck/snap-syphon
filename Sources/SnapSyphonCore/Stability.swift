import Foundation

public struct StabilityObservation: Equatable, Sendable {
  public let consistentFrames: Int
  public let requiredFrames: Int
  public let differenceFromAnchor: Double

  public var isStable: Bool {
    consistentFrames >= requiredFrames
  }
}

public struct StabilityGate: Sendable {
  public let requiredFrames: Int
  public let threshold: Double

  private var anchor: [UInt8]?
  private var consistentFrames = 0

  public init(requiredFrames: Int, threshold: Double) {
    self.requiredFrames = max(1, requiredFrames)
    self.threshold = max(0, threshold)
  }

  public mutating func observe(_ fingerprint: [UInt8]) -> StabilityObservation {
    guard let anchor else {
      self.anchor = fingerprint
      consistentFrames = 1
      return StabilityObservation(
        consistentFrames: consistentFrames,
        requiredFrames: requiredFrames,
        differenceFromAnchor: 0,
      )
    }

    let difference = Self.normalizedDifference(anchor, fingerprint)
    if difference <= threshold {
      consistentFrames += 1
    } else {
      self.anchor = fingerprint
      consistentFrames = 1
    }

    return StabilityObservation(
      consistentFrames: consistentFrames,
      requiredFrames: requiredFrames,
      differenceFromAnchor: difference,
    )
  }

  public static func normalizedDifference(
    _ first: [UInt8],
    _ second: [UInt8],
  ) -> Double {
    guard first.count == second.count, !first.isEmpty else {
      return 1
    }

    var total = 0
    var comparedComponents = 0
    for index in first.indices where index % 4 != 3 {
      total += abs(Int(first[index]) - Int(second[index]))
      comparedComponents += 1
    }
    guard comparedComponents > 0 else {
      return 0
    }
    return Double(total) / Double(comparedComponents * 255)
  }
}
