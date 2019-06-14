import UIKit
import AVFoundation
import os

class MainViewController: UIViewController,
    URLSessionWebSocketDelegate,
    AVCaptureVideoDataOutputSampleBufferDelegate
{
    @IBOutlet private var isSenderSwitch: UISwitch!
    @IBOutlet private var cameraView: UIView!
    @IBOutlet private var receiveImageView: UIImageView!
    
    private var closeButton: UIBarButtonItem!
    private var connectButton: UIBarButtonItem!
    
    var isSender: Bool = false
    
    var urlSession: URLSession!
    var webSocket: URLSessionWebSocketTask?
    var isSending: Bool = false
    
    var captureOutputQueue: DispatchQueue = DispatchQueue(label: "captureOutputQueue")
    var captureSession: AVCaptureSession?
    var videoOutput: AVCaptureVideoDataOutput?
    var previewLayer: AVCaptureVideoPreviewLayer?
    
    var sendPendingJpeg: Data?
    var receivedImage: UIImage?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        update {
            self.connectButton = UIBarButtonItem(title: "Connect", style: .plain,
                                                 target: self, action: #selector(onConnectButton))
            self.closeButton = UIBarButtonItem(title: "Close", style: .plain,
                                              target: self, action: #selector(onCloseButton))

            cameraView.layer.addObserver(self, forKeyPath: "bounds",
                                         options: [],
                                         context: nil)
            
            let session = URLSession(configuration: .default,
                                     delegate: self,
                                     delegateQueue: .main)
            self.urlSession = session
        }
    }
    
    override func observeValue(forKeyPath keyPath: String?,
                               of object: Any?,
                               change: [NSKeyValueChangeKey : Any]?,
                               context: UnsafeMutableRawPointer?)
    {
        if let layer = object as? CALayer, layer == cameraView.layer {
            layoutPreviewLayer()
        }
    }
    
    private func layoutPreviewLayer() {
        if let layer = previewLayer {
            layer.frame = cameraView.layer.bounds
        }
    }
    
    private func startCamera() {
        if let _ = captureSession {
            return
        }
        
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
        
        guard let input = try? AVCaptureDeviceInput(device: camera) else {
            print("input failed")
            return
        }
        captureSession.addInput(input)
        
        let output = AVCaptureVideoDataOutput()
        self.videoOutput = output
        output.videoSettings = [
            String(kCVPixelBufferPixelFormatTypeKey): kCVPixelFormatType_32BGRA
        ]
        output.setSampleBufferDelegate(self, queue: captureOutputQueue)
        captureSession.addOutput(output)

        let layer = AVCaptureVideoPreviewLayer(session: captureSession)
        self.previewLayer = layer
        layer.videoGravity = .resizeAspectFill
        cameraView.layer.insertSublayer(layer, at: 0)
        layoutPreviewLayer()
        
        captureSession.startRunning()
    }
    
    private func stopCamera() {
        if let session = self.captureSession {
            session.stopRunning()
            self.captureSession = nil
        }
        
        if let layer = self.previewLayer {
            layer.removeFromSuperlayer()
            self.previewLayer = nil
        }
        
        if let output = self.videoOutput {
            output.setSampleBufferDelegate(nil, queue: nil)
            self.videoOutput = nil
        }
        
        sendPendingJpeg = nil
    }

    func captureOutput(_ output: AVCaptureOutput,
                       didOutput sampleBuffer: CMSampleBuffer,
                       from connection: AVCaptureConnection)
    {
        let captureCGImage = CGImage.fromVideoCaptureBuffer(sampleBuffer)
        
        let size = CGSize(width: captureCGImage.width, height: captureCGImage.height)
        
        let bitmapInfo = CGBitmapInfo.byteOrder32Little.rawValue |
            CGImageAlphaInfo.premultipliedFirst.rawValue
    
        let context = CGContext(data: nil,
                                width: Int(size.height),
                                height: Int(size.width),
                                bitsPerComponent: 8,
                                bytesPerRow: 4 * captureCGImage.width,
                                space: CGColorSpaceCreateDeviceRGB(),
                                bitmapInfo: bitmapInfo)!
        context.translateBy(x: 0, y: size.width)
        context.rotate(by: -90 * CGFloat.pi / 180)
        context.draw(captureCGImage, in: CGRect(x: 0, y: 0, width: size.width, height: size.height))
        
        let cgImage = context.makeImage()!
        
        let image = UIImage(cgImage: cgImage)
        let jpeg = image.jpegData(compressionQuality: 0.9)!
        
        DispatchQueue.main.async {
            self.sendPendingJpeg = jpeg
            self.sendIfAvailable()
        }
    }

    private func sendIfAvailable() {
        guard let _ = webSocket,
            !isSending else { return }
        
        if let jpeg = sendPendingJpeg {
            self.sendPendingJpeg = nil
            let message = JpegMessage(jpeg: jpeg)
            _send(data: message.serialize())
        }
    }
        
    private func _send(data: Data) {
        precondition(!isSending)
        let webSocket = self.webSocket!
        
        isSending = true
        
        webSocket.send(.data(data)) { [weak self] (error) in
            guard let self = self else { return }
            
            self.update {
                self.isSending = false
                
                do {
                    if let error = error {
                        throw error
                    }
                    
                    self.sendIfAvailable()
                } catch {
                    self.showError(error)
                    self.closeWebSocket()
                }
            }
        }
    }
    
    @objc private func onConnectButton() {
        update {
            let url = URL(string: "ws://192.168.11.100:81")!
            let request = URLRequest(url: url)
            let task = urlSession.webSocketTask(with: request)
            self.webSocket = task
            task.resume()
            receive()
        }
    }
    
    @objc private func onCloseButton() {
        update {
            closeWebSocket()
        }
    }
    
    private func closeWebSocket() {
        webSocket?.cancel()
        webSocket = nil
    }
    
    private func receive() {
        guard let webSocket = self.webSocket else { return }
        
        webSocket.receive { [weak self] (wsMessage) in
            guard let self = self else { return }
            
            self.update {
                do {
                    self.processMessage(try wsMessage.get())
 
                    self.receive()
                } catch {
                    self.showError(error)
                    self.closeWebSocket()
                }
            }
        }
    }
    
    private func processMessage(_ wsMessage: URLSessionWebSocketTask.Message) {
        switch wsMessage {
        case .data(let data):
            guard let message = Messages.parse(data: data) else {
                print("invalid message")
                return
            }
            
            switch message {
            case let m as JpegMessage:
                guard let image = UIImage(data: m.jpeg) else {
                    print("broken jpeg")
                    return
                }
                
                receivedImage = image
            default:
                break
            }
        case .string(let string):
            print("string: \(string)")
        @unknown default:
            print("unknown message type")
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
            
            self.closeWebSocket()
        }
    }
    
    @IBAction private func onIsSenderSwitchChanged() {
        update {
            isSender = isSenderSwitch.isOn
            
            if isSender {
                startCamera()
            } else {
                stopCamera()
            }
        }
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
    
    private func render() {
        let rightButton: UIBarButtonItem?
        
        if let _ = webSocket {
            rightButton = closeButton

            isSenderSwitch.isEnabled = false
        } else {
            rightButton = connectButton
            
            isSenderSwitch.isEnabled = true
        }
        
        navigationItem.rightBarButtonItem = rightButton
        
        isSenderSwitch.isOn = isSender
        
        if let _ = captureSession {
            cameraView.isHidden = false
            receiveImageView.isHidden = true
        } else {
            cameraView.isHidden = true
            receiveImageView.isHidden = false
        }
        
        receiveImageView.image = receivedImage
    }
}
