import Foundation
import Network

class Client : CustomStringConvertible {
    let connection: NWConnection
    
    var errorHandler: ((Error) -> Void)?
    var binaryHandler: ((Data) -> Void)?
    var closeHandler: (() -> Void)?
    
    var isSending: Bool
    
    var isJpegSender: Bool = false
    var jpeg: Data?
    
    var description: String {
        return connection.debugDescription
    }
    
    init(connection: NWConnection) {
        self.connection = connection
        self.isSending = false
    
        connection.stateUpdateHandler = { [weak self] (state) in
            guard let self = self else { return }
            
            switch state {
            case .failed(let error), .waiting(let error):
                self.emitError(error)
            default:
                break
            }
        }
    }
    
    func cancel() {
        connection.cancel()
    }
    
    func start() {
        connection.start(queue: DispatchQueue.main)
        
        receive()
    }
    
    private func emitError(_ error: Error) {
        errorHandler?(error)
    }
    
    private func receive() {
        connection.receiveMessage { [weak self] (data, context, isComplete, error) in
            guard let self = self else { return }
            
            do {
                if let error = error {
                    throw error
                }
                
                if let context = context,
                    let metadatas = .some(context.protocolMetadata.compactMap { $0 as? NWProtocolWebSocket.Metadata }),
                    let metadata = metadatas.first
                {
                    assert(metadatas.count == 1)
                    assert(isComplete)
                    
                    switch metadata.opcode {
                    case .binary:
                        if let data = data {
                            self.binaryHandler?(data)
                        }
                    default: break
                    }
                }
                
                self.receive()
            } catch {
                self.emitError(error)
            }
        }
    }
    
    func sendIfAvailable() {
        guard !isSending else { return }
        
        if let jpeg = self.jpeg {
            self.jpeg = nil
            let message = JpegMessage(jpeg: jpeg)
            _send(data: message.serialize())
        }
    }
    
    private func _send(data: Data) {
        precondition(!isSending)

        isSending = true
        
        let webSocketMetadata = NWProtocolWebSocket.Metadata(opcode: NWProtocolWebSocket.Opcode.binary)
        let context = NWConnection.ContentContext(identifier: "context",
                                                  metadata: [webSocketMetadata])
        connection.send(content: data,
                        contentContext: context,
                        isComplete: true,
                        completion: .contentProcessed({ [weak self] (error) in
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
                        }))
    }
}

