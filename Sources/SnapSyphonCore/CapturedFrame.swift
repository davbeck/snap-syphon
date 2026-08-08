import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

public struct CapturedFrame {
  public let image: CGImage

  public var width: Int {
    image.width
  }

  public var height: Int {
    image.height
  }

  public func fingerprint(size: Int = 32) throws -> [UInt8] {
    let dimension = max(1, size)
    var bytes = [UInt8](repeating: 0, count: dimension * dimension * 4)
    let colorSpace = CGColorSpaceCreateDeviceRGB()
    let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue

    guard
      let context = CGContext(
        data: &bytes,
        width: dimension,
        height: dimension,
        bitsPerComponent: 8,
        bytesPerRow: dimension * 4,
        space: colorSpace,
        bitmapInfo: bitmapInfo,
      )
    else {
      throw SnapSyphonError.capture(
        "Could not create a frame comparison buffer.",
      )
    }

    context.interpolationQuality = .medium
    context.draw(
      image,
      in: CGRect(x: 0, y: 0, width: dimension, height: dimension),
    )
    return bytes
  }

  public func write(to url: URL, quality: Double = 0.92) throws {
    let type: UTType
    switch url.pathExtension.lowercased() {
    case "png":
      type = .png
    case "jpg", "jpeg":
      type = .jpeg
    default:
      throw SnapSyphonError.output(
        "Snapshot output must use a .png, .jpg, or .jpeg extension.",
      )
    }

    guard
      let destination = CGImageDestinationCreateWithURL(
        url as CFURL,
        type.identifier as CFString,
        1,
        nil,
      )
    else {
      throw SnapSyphonError.output(
        "Could not create the image at \(url.path).",
      )
    }

    let properties: CFDictionary? = if type == .jpeg {
      [
        kCGImageDestinationLossyCompressionQuality:
          min(1, max(0, quality)),
      ] as CFDictionary
    } else {
      nil
    }

    CGImageDestinationAddImage(destination, image, properties)
    guard CGImageDestinationFinalize(destination) else {
      throw SnapSyphonError.output(
        "Could not finish writing \(url.path).",
      )
    }
  }
}
