import UIKit
import AVFoundation
import os

class MainViewController: UIViewController
{
    @IBOutlet private var ipTextField: UITextField!
    @IBOutlet private var isSenderSwitch: UISwitch!
    @IBOutlet private var cameraView: UIView!
    @IBOutlet private var receiveImageView: UIImageView!
    
    private var closeButton: UIBarButtonItem!
    private var connectButton: UIBarButtonItem!
    
    var ip: String = "" {
        didSet {
            UserDefaults.standard.set(ip, forKey: "ip")
            UserDefaults.standard.synchronize()
        }
    }
    
    var isSender: Bool { _isSender }
    private var _isSender: Bool = false {
        didSet {
            UserDefaults.standard.set(isSender, forKey: "isSender")
            UserDefaults.standard.synchronize()
        }
    }
    
    var connection: Connection?
    var cameraCapture: CameraCapture?
    var receivedImage: UIImage?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        update {
            self.connectButton = UIBarButtonItem(title: "Connect", style: .plain,
                                                 target: self, action: #selector(onConnectButton))
            self.closeButton = UIBarButtonItem(title: "Close", style: .plain,
                                              target: self, action: #selector(onCloseButton))

            let ud = UserDefaults.standard
            
            ip = ud.string(forKey: "ip") ?? ""
            
            try setIsSender(value: ud.bool(forKey: "isSender"))
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        update {
            ipTextField.text = ip
            isSenderSwitch.isOn = isSender
        }
    }
    
    private func startConnection() {
        let url = URL(string: "ws://\(self.ip):81")!
        
        let connection = Connection(url: url)
        self.connection = connection
        
        connection.errorHandler = { [weak self] (error) in
            guard let self = self else { return }
            
            self.update {
                self.showError(error)
                self.closeConnection()
            }
        }
        
        connection.jpegHandler = { [weak self] (image) in
            guard let self = self else { return }
            
            self.update {
                self.receivedImage = image
            }
        }
        
        connection.start()
    }
    
    private func closeConnection() {
        connection?.close()
        connection = nil
    }
    
    private func startCapture() throws {
        let capture = CameraCapture(queue: DispatchQueue(label: "CameraCapture"),
                                    previewView: cameraView)
        self.cameraCapture = capture
        
        capture.jpegHandler = { [weak self] (jpeg) in
            guard let self = self else { return }
            
            DispatchQueue.main.async {
                self.update {
                    self.connection?.sendJpeg(data: jpeg)
                }
            }
        }
        
        try capture.start()
    }
    
    @objc private func onConnectButton() {
        update {
            view.endEditing(true)
            startConnection()
        }
    }
    
    @objc private func onCloseButton() {
        update {
            closeConnection()
        }
    }

    private func setIsSender(value: Bool) throws {
        _isSender = value
        
        if isSender {
            try startCapture()
        } else {
            cameraCapture?.stop()
            cameraCapture = nil
        }
    }

    @IBAction private func onIPTextFieldChanged() {
        update {
            ip = ipTextField.text ?? ""
        }
    }
    
    @IBAction private func onIsSenderSwitchChanged() {
        update {
            try setIsSender(value: isSenderSwitch.isOn)
        }
    }
    
    @IBAction private func onTapView() {
        view.endEditing(true)
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
        let message = "\(error)"
        let alert = UIAlertController(title: "エラー",
                                      message: message,
                                      preferredStyle: UIAlertController.Style.alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
        self.present(alert, animated: true, completion: nil)
    }
    
    private func render() {
        let rightButton: UIBarButtonItem?
        
        if let _ = connection {
            rightButton = closeButton

            ipTextField.isEnabled = false
            isSenderSwitch.isEnabled = false
        } else {
            rightButton = connectButton
            
            ipTextField.isEnabled = true
            isSenderSwitch.isEnabled = true
        }
        
        navigationItem.rightBarButtonItem = rightButton
        
        if let _ = cameraCapture {
            cameraView.isHidden = false
            receiveImageView.isHidden = true
        } else {
            cameraView.isHidden = true
            receiveImageView.isHidden = false
        }
        
        receiveImageView.image = receivedImage
    }
}
