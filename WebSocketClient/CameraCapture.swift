import UIKit
import AVFoundation

public final class CameraCapture {
    private final class DelegateBridge : NSObject, AVCaptureVideoDataOutputSampleBufferDelegate {
        public weak var owner: CameraCapture?
        
        override func observeValue(forKeyPath keyPath: String?,
                                   of object: Any?,
                                   change: [NSKeyValueChangeKey : Any]?,
                                   context: UnsafeMutableRawPointer?)
        {
            guard let owner = self.owner else { return }
            
            if let object = object as? NSObject {
                if object == owner.previewView.layer {
                    owner.layoutPreviewLayer()
                }
            }
        }
        
        func captureOutput(_ output: AVCaptureOutput,
                           didOutput sampleBuffer: CMSampleBuffer,
                           from connection: AVCaptureConnection)
        {
            guard let owner = self.owner else { return }
            let image = CGImage.fromVideoCaptureBuffer(sampleBuffer)
            owner.handleCapture(image: image)
        }
    }
    
    private let queue: DispatchQueue
    private let previewView: UIView
    private let delegateBridge: DelegateBridge
    
    private var session: AVCaptureSession?
    private var output: AVCaptureVideoDataOutput?
    private var previewLayer: AVCaptureVideoPreviewLayer?
    
    public var jpegHandler: ((Data) -> Void)?
    
    public init(queue: DispatchQueue,
                previewView: UIView)
    {
        self.queue = queue
        self.previewView = previewView
        self.delegateBridge = DelegateBridge()
        
        delegateBridge.owner = self
    }
    
    public func start() throws {
        if let _ = session {
            return
        }
        
        let session = AVCaptureSession()
        self.session = session
        session.sessionPreset = .vga640x480
        
        let deviceDiscovery = AVCaptureDevice.DiscoverySession(deviceTypes: [AVCaptureDevice.DeviceType.builtInWideAngleCamera],
                                                               mediaType: AVMediaType.video,
                                                               position: AVCaptureDevice.Position.back)
        guard let camera = deviceDiscovery.devices.first else {
            throw MessageError("no camera")
        }
        
        guard let input = try? AVCaptureDeviceInput(device: camera) else {
            throw MessageError("input init failed")
        }
        session.addInput(input)
        
        let output = AVCaptureVideoDataOutput()
        self.output = output
        output.videoSettings = [
            String(kCVPixelBufferPixelFormatTypeKey): kCVPixelFormatType_32BGRA
        ]
        output.setSampleBufferDelegate(delegateBridge, queue: queue)
        session.addOutput(output)
        
        let layer = AVCaptureVideoPreviewLayer(session: session)
        self.previewLayer = layer
        layer.videoGravity = .resizeAspectFill
        previewView.layer.insertSublayer(layer, at: 0)
        
        previewView.layer.addObserver(delegateBridge,
                                      forKeyPath: "bounds",
                                      options: [],
                                      context: nil)
        
        layoutPreviewLayer()
        
        session.startRunning()
    }

    public func stop() {
        queue.sync {
            previewView.layer.removeObserver(delegateBridge, forKeyPath: "bounds")
            
            if let session = self.session {
                session.stopRunning()
                self.session = nil
            }
            
            if let layer = self.previewLayer {
                layer.removeFromSuperlayer()
                self.previewLayer = nil
            }
            
            if let output = self.output {
                output.setSampleBufferDelegate(nil, queue: nil)
                self.output = nil
            }
        }
    }
    
    private func layoutPreviewLayer() {
        if let layer = previewLayer {
            layer.frame = previewView.layer.bounds
        }
    }
    
    private func handleCapture(image: CGImage) {
        let image = rotateRight90(image: image)
        
        let uiImage = UIImage(cgImage: image)
        let jpeg = uiImage.jpegData(compressionQuality: 0.9)!
        
        jpegHandler?(jpeg)
    }
    
    private func rotateRight90(image: CGImage) -> CGImage {
        let size = CGSize(width: image.width, height: image.height)
        
        let bitmapInfo = CGBitmapInfo.byteOrder32Little.rawValue |
            CGImageAlphaInfo.premultipliedFirst.rawValue
        
        let context = CGContext(data: nil,
                                width: Int(size.height),
                                height: Int(size.width),
                                bitsPerComponent: 8,
                                bytesPerRow: Int(4 * size.width),
                                space: CGColorSpaceCreateDeviceRGB(),
                                bitmapInfo: bitmapInfo)!
        context.translateBy(x: 0, y: size.width)
        context.rotate(by: -90 * CGFloat.pi / 180)
        context.draw(image, in: CGRect(x: 0, y: 0, width: size.width, height: size.height))
        
        return context.makeImage()!
    }
}

