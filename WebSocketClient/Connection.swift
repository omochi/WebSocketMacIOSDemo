import UIKit

public final class Connection {
    private final class DelegateBridge : NSObject, URLSessionWebSocketDelegate {
        public weak var owner: Connection?
        
        func urlSession(_ session: URLSession, task: URLSessionTask,
                        didCompleteWithError error: Error?)
        {
            if let error = error {
                owner?.emitError(error)
            }
        }
    }
    
    private let session: URLSession
    private let task: URLSessionWebSocketTask
    private let delegateBridge: DelegateBridge
    
    private var isSending: Bool
    private var jpeg: Data?
    
    public var errorHandler: ((Error) -> Void)?
    public var jpegHandler: ((UIImage) -> Void)?
    
    public init(url: URL)
    {
        let db = DelegateBridge()
        
        let session = URLSession(configuration: .default,
                                 delegate: db,
                                 delegateQueue: .main)
        self.session = session
        
        let task = session.webSocketTask(with: url)
        self.task = task
        
        self.delegateBridge = db
        
        self.isSending = false
        
        db.owner = self
    }
    
    public func start() {
        task.resume()
        receive()
    }
    
    public func close() {
        task.cancel()
    }
    
    public func sendJpeg(data: Data) {
        self.jpeg = data
        
        sendIfAvailable()
    }
    
    private func sendIfAvailable() {
        if isSending {
            return
        }
        
        if let jpeg = self.jpeg {
            self.jpeg = nil
            let message = JpegMessage(jpeg: jpeg)
            send(data: message.serialize())
        }        
    }
    
    private func emitError(_ error: Error) {
        close()
        errorHandler?(error)
    }
    
    private func receive() {
        task.receive { [weak self] (wm) in
            guard let self = self else { return }
            
            do {
                switch try wm.get() {
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
                        
                        self.jpegHandler?(image)
                    default:
                        break
                    }
                case .string(_):
                    break
                @unknown default:
                    break
                }
                
                self.receive()
            } catch {
                self.emitError(error)
            }
        }
    }
    
    private func send(data: Data) {
        precondition(!isSending)
        
        isSending = true
        
        task.send(.data(data)) { [weak self] (error) in
            guard let self = self else { return }
            
            self.isSending = false
            
            do {
                if let error = error {
                    throw error
                }
                
                self.sendIfAvailable()
            } catch {
                self.emitError(error)
            }
        }
    }
}
