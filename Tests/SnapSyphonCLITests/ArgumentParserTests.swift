import ArgumentParser
import XCTest

@testable import SnapSyphonCLI
@testable import SnapSyphonCore

final class ArgumentParserTests: XCTestCase {
  func testListJSONAndWait() throws {
    let command = try SnapSyphonCommand.parseAsRoot([
      "list", "--json", "--wait", "1.25",
    ])
    let list = try XCTUnwrap(command as? ListSources)

    XCTAssertTrue(list.json)
    XCTAssertEqual(list.sourceOptions.wait, 1.25)
  }

  func testSnapshotParsesStabilityAndSourceOptions() throws {
    let command = try SnapSyphonCommand.parseAsRoot([
      "snapshot",
      "frame.png",
      "--app",
      "Renderer",
      "--name",
      "Output",
      "--stable-frames",
      "15",
      "--threshold",
      "0.002",
      "--sample-rate",
      "24",
      "--timeout",
      "45",
      "--force",
    ])
    let snapshot = try XCTUnwrap(command as? Snapshot)

    XCTAssertEqual(snapshot.output, "frame.png")
    XCTAssertEqual(snapshot.sourceOptions.app, "Renderer")
    XCTAssertEqual(snapshot.sourceOptions.name, "Output")
    XCTAssertEqual(snapshot.stability.stableFrames, 15)
    XCTAssertEqual(snapshot.stability.threshold, 0.002)
    XCTAssertEqual(snapshot.stability.sampleRate, 24)
    XCTAssertEqual(snapshot.stability.timeout, 45)
    XCTAssertTrue(snapshot.force)
  }

  func testRecordParsesVideoOptions() throws {
    let command = try SnapSyphonCommand.parseAsRoot([
      "record",
      "clip.mov",
      "--index",
      "2",
      "--duration",
      "4.5",
      "--fps",
      "60",
      "--codec",
      "prores",
    ])
    let record = try XCTUnwrap(command as? Record)

    XCTAssertEqual(record.output, "clip.mov")
    XCTAssertEqual(record.sourceOptions.index, 2)
    XCTAssertEqual(record.duration, 4.5)
    XCTAssertEqual(record.framesPerSecond, 60)
    XCTAssertEqual(record.codec, .prores)
  }

  func testIndexCannotBeCombinedWithOtherSelectors() {
    XCTAssertThrowsError(
      try SnapSyphonCommand.parseAsRoot([
        "snapshot",
        "frame.png",
        "--index",
        "0",
        "--name",
        "Output",
      ]),
    )
  }

  func testRecordRequiresDuration() {
    XCTAssertThrowsError(
      try SnapSyphonCommand.parseAsRoot(["record", "clip.mov"]),
    )
  }

  func testVersionComesFromArgumentParser() throws {
    XCTAssertEqual(SnapSyphonCommand.configuration.version, "0.1.0")
    XCTAssertThrowsError(
      try SnapSyphonCommand.parseAsRoot(["--version"]),
    )
  }
}
