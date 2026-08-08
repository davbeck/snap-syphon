import AVFoundation
import XCTest

@testable import SnapSyphonCore

final class VideoCodecTests: XCTestCase {
  func testAVFoundationCodecMappings() {
    XCTAssertEqual(VideoCodec.h264.avCodec, .h264)
    XCTAssertEqual(VideoCodec.hevc.avCodec, .hevc)
    XCTAssertEqual(VideoCodec.hevcWithAlpha.avCodec, .hevcWithAlpha)
    XCTAssertEqual(VideoCodec.prores.avCodec, .proRes422)
    XCTAssertEqual(VideoCodec.prores4444.avCodec, .proRes4444)
  }
}
