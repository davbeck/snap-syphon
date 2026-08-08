import AVFoundation
import CoreImage
import CoreVideo
import Foundation

public enum VideoCodec: String, CaseIterable, Sendable {
  case h264
  case hevc
  case prores

  var avCodec: AVVideoCodecType {
    switch self {
    case .h264:
      .h264
    case .hevc:
      .hevc
    case .prores:
      .proRes422
    }
  }
}

public struct RecordingProgress: Equatable, Sendable {
  public let frame: Int
  public let totalFrames: Int
  public let elapsed: TimeInterval
}

extension SyphonCapture {
  public func record(
    to url: URL,
    duration: TimeInterval,
    framesPerSecond: Double = 30,
    codec: VideoCodec = .h264,
    progress: ((RecordingProgress) -> Void)? = nil,
  ) throws {
    guard duration > 0 else {
      throw SnapSyphonError.recording("Duration must be greater than zero.")
    }
    guard framesPerSecond > 0, framesPerSecond <= 240 else {
      throw SnapSyphonError.recording(
        "Frame rate must be greater than zero and no more than 240.",
      )
    }

    guard let firstImage = waitForImage(timeout: 5) else {
      throw SnapSyphonError.capture(
        "The source did not provide a frame within 5 seconds.",
      )
    }
    let width = Int(firstImage.extent.width.rounded())
    let height = Int(firstImage.extent.height.rounded())
    guard width > 0, height > 0 else {
      throw SnapSyphonError.capture("The source returned an empty frame.")
    }

    let fileType = try Self.fileType(for: url, codec: codec)
    let writer = try AVAssetWriter(outputURL: url, fileType: fileType)
    let settings: [String: Any] = [
      AVVideoCodecKey: codec.avCodec,
      AVVideoWidthKey: width,
      AVVideoHeightKey: height,
    ]
    let input = AVAssetWriterInput(
      mediaType: .video,
      outputSettings: settings,
    )
    input.expectsMediaDataInRealTime = true

    let attributes: [String: Any] = [
      kCVPixelBufferPixelFormatTypeKey as String:
        kCVPixelFormatType_32BGRA,
      kCVPixelBufferWidthKey as String: width,
      kCVPixelBufferHeightKey as String: height,
      kCVPixelBufferMetalCompatibilityKey as String: true,
    ]
    let adaptor = AVAssetWriterInputPixelBufferAdaptor(
      assetWriterInput: input,
      sourcePixelBufferAttributes: attributes,
    )

    guard writer.canAdd(input) else {
      throw SnapSyphonError.recording(
        "The selected codec cannot be added to this recording.",
      )
    }
    writer.add(input)
    guard writer.startWriting() else {
      throw SnapSyphonError.recording(
        writer.error?.localizedDescription
          ?? "The video writer could not start.",
      )
    }
    writer.startSession(atSourceTime: .zero)

    let totalFrames = max(1, Int((duration * framesPerSecond).rounded(.up)))
    let start = CFAbsoluteTimeGetCurrent()

    for frameIndex in 0 ..< totalFrames {
      let targetTime = start + Double(frameIndex) / framesPerSecond
      Self.wait(until: targetTime)

      while !input.isReadyForMoreMediaData {
        guard writer.status == .writing else {
          throw SnapSyphonError.recording(
            writer.error?.localizedDescription
              ?? "The video writer stopped unexpectedly.",
          )
        }
        Self.runLoopSleep(0.002)
      }

      guard let pool = adaptor.pixelBufferPool else {
        throw SnapSyphonError.recording(
          "The video writer did not create a pixel buffer pool.",
        )
      }
      var optionalBuffer: CVPixelBuffer?
      let result = CVPixelBufferPoolCreatePixelBuffer(
        nil,
        pool,
        &optionalBuffer,
      )
      guard result == kCVReturnSuccess, let buffer = optionalBuffer else {
        throw SnapSyphonError.recording(
          "Could not allocate video frame \(frameIndex + 1).",
        )
      }

      guard let image = frameIndex == 0 ? firstImage : currentImage() else {
        throw SnapSyphonError.capture(
          "The source stopped providing frames.",
        )
      }
      context.render(
        image,
        to: buffer,
        bounds: CGRect(x: 0, y: 0, width: width, height: height),
        colorSpace: colorSpace,
      )

      let presentationTime = CMTime(
        seconds: Double(frameIndex) / framesPerSecond,
        preferredTimescale: 60000,
      )
      guard adaptor.append(buffer, withPresentationTime: presentationTime) else {
        throw SnapSyphonError.recording(
          writer.error?.localizedDescription
            ?? "Could not append video frame \(frameIndex + 1).",
        )
      }
      progress?(
        RecordingProgress(
          frame: frameIndex + 1,
          totalFrames: totalFrames,
          elapsed: Double(frameIndex + 1) / framesPerSecond,
        ),
      )
    }

    input.markAsFinished()
    let completion = DispatchSemaphore(value: 0)
    writer.finishWriting {
      completion.signal()
    }
    while completion.wait(timeout: .now() + 0.05) == .timedOut {
      Self.runLoopSleep(0.01)
    }

    guard writer.status == .completed else {
      throw SnapSyphonError.recording(
        writer.error?.localizedDescription
          ?? "The video writer did not finish successfully.",
      )
    }
  }

  private func waitForImage(timeout: TimeInterval) -> CIImage? {
    let deadline = Date(timeIntervalSinceNow: timeout)
    repeat {
      if let image = currentImage() {
        return image
      }
      Self.runLoopSleep(0.02)
    } while Date() < deadline
    return nil
  }

  private static func fileType(
    for url: URL,
    codec: VideoCodec,
  ) throws -> AVFileType {
    switch url.pathExtension.lowercased() {
    case "mov":
      return .mov
    case "mp4":
      guard codec != .prores else {
        throw SnapSyphonError.recording(
          "ProRes recordings require a .mov output file.",
        )
      }
      return .mp4
    default:
      throw SnapSyphonError.recording(
        "Recording output must use a .mov or .mp4 extension.",
      )
    }
  }

  private static func wait(until target: CFAbsoluteTime) {
    while true {
      let remaining = target - CFAbsoluteTimeGetCurrent()
      guard remaining > 0 else {
        return
      }
      runLoopSleep(min(remaining, 0.01))
    }
  }
}
