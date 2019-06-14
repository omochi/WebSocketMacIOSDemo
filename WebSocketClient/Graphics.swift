import Foundation
import AVFoundation

extension CGImage {
    static func fromVideoCaptureBuffer(_ sampleBuffer: CMSampleBuffer) -> CGImage {
        let ib = sampleBuffer.imageBuffer!
        
        CVPixelBufferLockBaseAddress(ib, CVPixelBufferLockFlags.readOnly)
        
        let pointer = CVPixelBufferGetBaseAddressOfPlane(ib, 0)!
        let bytesPerRow = CVPixelBufferGetBytesPerRow(ib)
        let width = Int(CVPixelBufferGetWidth(ib))
        let height = Int(CVPixelBufferGetHeight(ib))
        
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGBitmapInfo.byteOrder32Little.rawValue |
            CGImageAlphaInfo.premultipliedFirst.rawValue
        let cgContext = CGContext(data: pointer,
                                  width: width,
                                  height: height,
                                  bitsPerComponent: 8,
                                  bytesPerRow: Int(bytesPerRow),
                                  space: colorSpace,
                                  bitmapInfo: bitmapInfo)!
        
        let cgImage = cgContext.makeImage()!
        
        CVPixelBufferUnlockBaseAddress(ib, CVPixelBufferLockFlags.readOnly)
        
        return cgImage
    }
}
