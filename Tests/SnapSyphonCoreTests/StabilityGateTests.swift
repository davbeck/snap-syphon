import XCTest

@testable import SnapSyphonCore

final class StabilityGateTests: XCTestCase {
  func testCountsFramesAgainstOriginalAnchor() {
    var gate = StabilityGate(requiredFrames: 3, threshold: 0.01)
    let anchor: [UInt8] = [100, 100, 100, 255]
    let close: [UInt8] = [102, 101, 100, 255]

    XCTAssertEqual(gate.observe(anchor).consistentFrames, 1)
    XCTAssertEqual(gate.observe(close).consistentFrames, 2)
    XCTAssertTrue(gate.observe(anchor).isStable)
  }

  func testDifferenceResetsRunAndUsesNewAnchor() {
    var gate = StabilityGate(requiredFrames: 2, threshold: 0.001)
    let dark: [UInt8] = [0, 0, 0, 255]
    let light: [UInt8] = [255, 255, 255, 255]

    _ = gate.observe(dark)
    let reset = gate.observe(light)
    XCTAssertEqual(reset.consistentFrames, 1)
    XCTAssertEqual(reset.differenceFromAnchor, 1)
    XCTAssertTrue(gate.observe(light).isStable)
  }

  func testAlphaIsIgnored() {
    let difference = StabilityGate.normalizedDifference(
      [10, 20, 30, 0],
      [10, 20, 30, 255],
    )
    XCTAssertEqual(difference, 0)
  }

  func testMismatchedFingerprintsAreDifferent() {
    XCTAssertEqual(
      StabilityGate.normalizedDifference([0, 0, 0, 255], [0]),
      1,
    )
  }
}
