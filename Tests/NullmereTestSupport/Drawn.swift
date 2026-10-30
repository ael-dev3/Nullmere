#if canImport(CoreGraphics)
import CoreGraphics

/// How many of an image's pixels stand out from black: what a view drawn on
/// black shows of itself. The render tests hold every view to some, where a
/// view that drew nothing at all would otherwise pass for drawn.
public func litPixels(_ image: CGImage) -> Int {
    let width = image.width, height = image.height
    guard width > 0, height > 0, let space = CGColorSpace(name: CGColorSpace.sRGB) else { return 0 }
    var bytes = [UInt8](repeating: 0, count: width * height * 4)
    let drawn = bytes.withUnsafeMutableBytes { buffer -> Bool in
        guard let context = CGContext(data: buffer.baseAddress, width: width, height: height, bitsPerComponent: 8,
                                      bytesPerRow: width * 4, space: space,
                                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return false }
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        return true
    }
    guard drawn else { return 0 }
    var lit = 0
    for index in stride(from: 0, to: bytes.count, by: 4) where Int(bytes[index]) + Int(bytes[index + 1]) + Int(bytes[index + 2]) > 120 {
        lit += 1
    }
    return lit
}
#endif
