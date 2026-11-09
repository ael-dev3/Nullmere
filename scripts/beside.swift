// Sets two screenshots side by side at one height, a little apart on the
// night's dark, as one picture: CI's photograph of the keeper's Mac beside
// their phone, taken together on one realm (scripts/smoke-test-companion.sh).
//
//   swift scripts/beside.swift <left.png> <right.png> <out.png>
import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

func image(at path: String) -> CGImage? {
    guard let source = CGImageSourceCreateWithURL(URL(fileURLWithPath: path) as CFURL, nil) else { return nil }
    return CGImageSourceCreateImageAtIndex(source, 0, nil)
}

let arguments = CommandLine.arguments
guard arguments.count == 4, let left = image(at: arguments[1]), let right = image(at: arguments[2]) else {
    FileHandle.standardError.write(Data("usage: swift scripts/beside.swift <left.png> <right.png> <out.png>\n".utf8))
    exit(2)
}
let height = 900.0, gap = 24.0
let leftWidth = Double(left.width) * height / Double(max(left.height, 1))
let rightWidth = Double(right.width) * height / Double(max(right.height, 1))
let width = Int((leftWidth + gap + rightWidth).rounded(.up))
guard let context = CGContext(data: nil, width: width, height: Int(height), bitsPerComponent: 8, bytesPerRow: 0,
                              space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else {
    FileHandle.standardError.write(Data("error: no room to draw \(width) by \(Int(height))\n".utf8))
    exit(1)
}
context.setFillColor(CGColor(red: 0.035, green: 0.04, blue: 0.06, alpha: 1))
context.fill(CGRect(x: 0, y: 0, width: Double(width), height: height))
context.interpolationQuality = .high
context.draw(left, in: CGRect(x: 0, y: 0, width: leftWidth, height: height))
context.draw(right, in: CGRect(x: leftWidth + gap, y: 0, width: rightWidth, height: height))
guard let drawn = context.makeImage(),
      let out = CGImageDestinationCreateWithURL(URL(fileURLWithPath: arguments[3]) as CFURL, UTType.png.identifier as CFString, 1, nil) else {
    FileHandle.standardError.write(Data("error: \(arguments[3]) couldn't be written\n".utf8))
    exit(1)
}
CGImageDestinationAddImage(out, drawn, nil)
exit(CGImageDestinationFinalize(out) ? 0 : 1)
