import UIKit

class MainViewController: UIViewController,
    URLSessionTaskDelegate,
    URLSessionDataDelegate,
    URLSessionWebSocketDelegate
{

    var session: URLSession!
    
    var webSocket: URLSessionWebSocketTask?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        update {
            let session = URLSession(configuration: .default,
                                     delegate: self,
                                     delegateQueue: .main)
            self.session = session
        }
    }

    @objc private func onStartButton() {
        update {
            let url = URL(string: "ws://192.168.11.100:81")!
            var request = URLRequest(url: url)
            request.addValue("hoge", forHTTPHeaderField: "Sec-WebSocket-Protocol")
            let task = session.webSocketTask(with: request)
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
    
//    urlSEssion
    
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
