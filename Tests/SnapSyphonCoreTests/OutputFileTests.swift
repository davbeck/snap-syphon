import Foundation
import XCTest

@testable import SnapSyphonCore

final class OutputFileTests: XCTestCase {
  enum TestError: Error {
    case failedWrite
  }

  func testRefusesToReplaceDirectoryEvenWithForce() throws {
    let directory = FileManager.default.temporaryDirectory
      .appendingPathComponent(UUID().uuidString, isDirectory: true)
    try FileManager.default.createDirectory(
      at: directory,
      withIntermediateDirectories: false,
    )
    defer { try? FileManager.default.removeItem(at: directory) }

    XCTAssertThrowsError(
      try OutputFile.writeAtomically(to: directory, force: true) { _ in
        XCTFail("The writer should not run for a directory destination.")
      },
    )
    var isDirectory: ObjCBool = false
    XCTAssertTrue(
      FileManager.default.fileExists(
        atPath: directory.path,
        isDirectory: &isDirectory,
      ),
    )
    XCTAssertTrue(isDirectory.boolValue)
  }

  func testExistingFileRequiresForce() throws {
    let file = FileManager.default.temporaryDirectory
      .appendingPathComponent(UUID().uuidString)
    try Data("old".utf8).write(to: file)
    defer { try? FileManager.default.removeItem(at: file) }

    XCTAssertThrowsError(
      try OutputFile.writeAtomically(to: file, force: false) { _ in
        XCTFail("The writer should not run without --force.")
      },
    )
    XCTAssertEqual(try String(contentsOf: file, encoding: .utf8), "old")
  }

  func testFailedForcedWritePreservesExistingFile() throws {
    let file = FileManager.default.temporaryDirectory
      .appendingPathComponent(UUID().uuidString)
      .appendingPathExtension("txt")
    try Data("old".utf8).write(to: file)
    defer { try? FileManager.default.removeItem(at: file) }

    XCTAssertThrowsError(
      try OutputFile.writeAtomically(to: file, force: true) { temporaryURL in
        try Data("partial".utf8).write(to: temporaryURL)
        throw TestError.failedWrite
      },
    )
    XCTAssertEqual(try String(contentsOf: file, encoding: .utf8), "old")
  }

  func testSuccessfulForcedWriteReplacesExistingFile() throws {
    let file = FileManager.default.temporaryDirectory
      .appendingPathComponent(UUID().uuidString)
      .appendingPathExtension("txt")
    try Data("old".utf8).write(to: file)
    defer { try? FileManager.default.removeItem(at: file) }

    try OutputFile.writeAtomically(to: file, force: true) { temporaryURL in
      try Data("new".utf8).write(to: temporaryURL)
    }

    XCTAssertEqual(try String(contentsOf: file, encoding: .utf8), "new")
  }

  func testFileCreatedDuringWriteIsNotReplacedWithoutForce() throws {
    let file = FileManager.default.temporaryDirectory
      .appendingPathComponent(UUID().uuidString)
      .appendingPathExtension("txt")
    defer { try? FileManager.default.removeItem(at: file) }

    XCTAssertThrowsError(
      try OutputFile.writeAtomically(to: file, force: false) { temporaryURL in
        try Data("new".utf8).write(to: temporaryURL)
        try Data("racer".utf8).write(to: file)
      },
    )
    XCTAssertEqual(try String(contentsOf: file, encoding: .utf8), "racer")
  }
}
