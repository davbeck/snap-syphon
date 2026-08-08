import CoreImage
import CSyphon
import Foundation
import Metal

public final class SyphonCapture {
  public let source: SyphonSource

  let colorSpace: CGColorSpace
  let context: CIContext
  private let client: SSYClient

  public init(source: SyphonSource) throws {
    guard let colorSpace = CGColorSpace(name: CGColorSpace.sRGB) else {
      throw SnapSyphonError.capture("Could not create the sRGB color space.")
    }
    guard let device = MTLCreateSystemDefaultDevice() else {
      throw SnapSyphonError.capture("No Metal device is available.")
    }
    guard
      let client = SSYClient(
        source: source.nativeSource,
        device: device,
      )
    else {
      throw SnapSyphonError.capture(
        "Could not connect to \(source.description.displayName).",
      )
    }

    self.source = source
    self.client = client
    self.colorSpace = colorSpace
    context = CIContext(mtlDevice: device)
  }

  deinit {
    client.stop()
  }

  public func capture(
    stableFrames: Int = 1,
    threshold: Double = 0.001,
    sampleRate: Double = 30,
    timeout: TimeInterval = 30,
    progress: ((StabilityObservation) -> Void)? = nil,
  ) throws -> CapturedFrame {
    var gate = StabilityGate(
      requiredFrames: stableFrames,
      threshold: threshold,
    )
    let deadline = Date(timeIntervalSinceNow: max(0, timeout))
    let interval = 1 / max(1, sampleRate)
    var bestCount = 0

    repeat {
      if let frame = try currentFrame() {
        let observation = try gate.observe(frame.fingerprint())
        bestCount = max(bestCount, observation.consistentFrames)
        progress?(observation)
        if observation.isStable {
          return frame
        }
      }

      Self.runLoopSleep(interval)
    } while Date() < deadline

    throw SnapSyphonError.capture(
      "Timed out after \(Self.format(timeout)) seconds waiting for "
        + "\(stableFrames) consistent frames (best run: \(bestCount)).",
    )
  }

  public func currentFrame(timeout: TimeInterval = 0) throws -> CapturedFrame? {
    let deadline = Date(timeIntervalSinceNow: max(0, timeout))
    repeat {
      if let image = currentImage(),
         let cgImage = context.createCGImage(image, from: image.extent)
      {
        return CapturedFrame(image: cgImage)
      }
      if timeout > 0 {
        Self.runLoopSleep(0.02)
      }
    } while Date() < deadline

    return nil
  }

  func currentImage() -> CIImage? {
    guard client.isValid,
          let texture = client.currentTexture()
    else {
      return nil
    }
    return CIImage(
      mtlTexture: texture,
      options: [.colorSpace: colorSpace],
    )
  }

  static func runLoopSleep(_ seconds: TimeInterval) {
    guard seconds > 0 else {
      return
    }
    let deadline = Date(timeIntervalSinceNow: seconds)
    repeat {
      _ = RunLoop.current.run(mode: .default, before: deadline)
    } while Date() < deadline
  }

  private static func format(_ value: Double) -> String {
    value.formatted(.number.precision(.fractionLength(0 ... 2)))
  }
}
