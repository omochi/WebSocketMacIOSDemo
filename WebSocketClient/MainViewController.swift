import UIKit
import AVFoundation
import os

class MainViewController: UIViewController,
    URLSessionWebSocketDelegate,
    AVCaptureVideoDataOutputSampleBufferDelegate
{
    @IBOutlet private var cameraView: UIView!
    @IBOutlet private var imageCheckView: UIImageView!
    
    var urlSession: URLSession!
    var webSocket: URLSessionWebSocketTask?
    var isSending: Bool = false
    
    var captureOutputQueue: DispatchQueue!
    var captureSession: AVCaptureSession!
    var camera: AVCaptureDevice?
    var previewLayer: AVCaptureVideoPreviewLayer?
    var latestImageJpeg: Data?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        update {
            let session = URLSession(configuration: .default,
                                     delegate: self,
                                     delegateQueue: .main)
            self.urlSession = session
            
            startCamera()
        }
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        
        if let layer = previewLayer {
            layer.frame = cameraView.layer.bounds
        }
    }
    
    private func startCamera() {
        let captureSession = AVCaptureSession()
        self.captureSession = captureSession
        captureSession.sessionPreset = .vga640x480
        
        let deviceDiscovery = AVCaptureDevice.DiscoverySession(deviceTypes: [AVCaptureDevice.DeviceType.builtInWideAngleCamera],
                                                               mediaType: AVMediaType.video,
                                                               position: AVCaptureDevice.Position.back)
        guard let camera = deviceDiscovery.devices.first else {
            print("no camera")
            return
        }
        self.camera = camera
        
        guard let input = try? AVCaptureDeviceInput(device: camera) else {
            print("input failed")
            return
        }
        captureSession.addInput(input)
        
        let outputQueue = DispatchQueue(label: "captureOutputQueue")
        self.captureOutputQueue = outputQueue
        let output = AVCaptureVideoDataOutput()
        output.videoSettings = [
            String(kCVPixelBufferPixelFormatTypeKey): kCVPixelFormatType_32BGRA
        ]
        output.setSampleBufferDelegate(self, queue: outputQueue)
        captureSession.addOutput(output)

        let layer = AVCaptureVideoPreviewLayer(session: captureSession)
        self.previewLayer = layer
        layer.videoGravity = .resizeAspectFill
        cameraView.layer.insertSublayer(layer, at: 0)
        
        view.setNeedsLayout()
        
        captureSession.startRunning()
    }

    func captureOutput(_ output: AVCaptureOutput,
                       didOutput sampleBuffer: CMSampleBuffer,
                       from connection: AVCaptureConnection)
    {
        let ib = sampleBuffer.imageBuffer!
        
        CVPixelBufferLockBaseAddress(ib, CVPixelBufferLockFlags.readOnly)
        
        let pointer = CVPixelBufferGetBaseAddressOfPlane(ib, 0)!
        let bytesPerRow = CVPixelBufferGetBytesPerRow(ib)
        let width = CVPixelBufferGetWidth(ib)
        let height = CVPixelBufferGetHeight(ib)
        
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo: UInt32 = CGBitmapInfo.byteOrder32Little.rawValue |
            CGImageAlphaInfo.premultipliedFirst.rawValue
        let cgContext = CGContext(data: pointer,
                                  width: Int(width),
                                  height: Int(height),
                                  bitsPerComponent: 8,
                                  bytesPerRow: Int(bytesPerRow),
                                  space: colorSpace,
                                  bitmapInfo: bitmapInfo)!
        
        let cgImage = cgContext.makeImage()!
        let image = UIImage(cgImage: cgImage, scale: 1, orientation: UIImage.Orientation.right)
        let jpeg = image.jpegData(compressionQuality: 0.9)!

        CVPixelBufferUnlockBaseAddress(ib, CVPixelBufferLockFlags.readOnly)
        
        DispatchQueue.main.async {
            self.emitJpeg(data: jpeg)
        }
    }
    
    private func emitJpeg(data: Data) {
        self.latestImageJpeg = data
        _sendIfNeed()
    }
    
    private func _sendJpeg(data: Data) {
        precondition(!isSending)
        let webSocket = self.webSocket!
        
        isSending = true
        
        var message = Data()
        let code = CFSwapInt32HostToBig(1)
        withUnsafeBytes(of: code) { (b) in
            message.append(b.bindMemory(to: UInt8.self))
        }
        message.append(data)
        
        webSocket.send(.data(message)) { [weak self] (error) in
            guard let self = self else { return }
            
            self.update {
                self.isSending = false
                
                do {
                    if let error = error {
                        throw error
                    }
                    
                    self._sendIfNeed()
                } catch {
                    self.showError(error)
                    self.closeWebSocket()
                }
            }
        }
    }
    
    private func _sendIfNeed() {
        guard let _ = webSocket,
            !isSending else { return }
        
        if let jpeg = latestImageJpeg {
            self.latestImageJpeg = nil
            _sendJpeg(data: jpeg)
        }
    }
    
    @objc private func onStartButton() {
        update {
            let url = URL(string: "ws://192.168.11.100:81")!
            let request = URLRequest(url: url)
            let task = urlSession.webSocketTask(with: request)
            self.webSocket = task
            task.resume()
            receive()
        }
    }
    
    private func closeWebSocket() {
        webSocket?.cancel()
        webSocket = nil
    }
    
    private func receive() {
        guard let webSocket = self.webSocket else { return }
        
        webSocket.receive { [weak self] (message) in
            guard let self = self else { return }
            
            self.update {
                do {
                    switch try message.get() {
                    case .data(let data):
                        print("data: \(data.count)")
                    case .string(let string):
                        print("string: \(string)")
                    @unknown default:
                        print("unknown message type")
                    }
                    self.receive()
                } catch {
                    self.showError(error)
                    self.closeWebSocket()
                }
            }
        }
        
    }
    
    func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didOpenWithProtocol protocol: String?)
    {
        update {
            print("connected: \(`protocol`.debugDescription)")
        }
    }
    
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?)
    {
        update {
            print("complete, \(error.debugDescription)")
            
            self.webSocket = nil
        }
    }
    
    private func render() {
        let button = UIBarButtonItem(title: "Start", style: .plain,
                                     target: self, action: #selector(onStartButton))
        if let _ = webSocket {
            button.isEnabled = false
        }
        
        navigationItem.rightBarButtonItem = button
    }
    
    private func update(_ f: () throws -> Void) {
        do {
            try f()
        } catch {
            showError(error)
        }
        
        render()
    }
    
    private func showError(_ error: Error) {
        showError("\(error)")
    }
    
    private func showError(_ error: String) {
        let alert = UIAlertController(title: "エラー", message: error, preferredStyle: UIAlertController.Style.alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
        self.present(alert, animated: true, completion: nil)
    }
}
