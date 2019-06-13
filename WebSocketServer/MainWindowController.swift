import Cocoa
import Network

class MainWindowController: NSWindowController, NSWindowDelegate {
    class Client {
        let connection: NWConnection
        
        init(connection: NWConnection) {
            self.connection = connection
        }
    }
    
    @IBOutlet private var connectionNumLabel: NSTextField!
    @IBOutlet private var imageView: NSImageView!
    
    var listener: NWListener!
    var clients: [Client] = []
    
    override func windowDidLoad() {
        super.windowDidLoad()
        
        update {
            imageView.imageScaling = .scaleAxesIndependently
            
            let options = NWProtocolWebSocket.Options()
            options.autoReplyPing = true
            let parameters = NWParameters.tcp
            parameters.defaultProtocolStack.applicationProtocols = [
                options
            ]
            let listener = try NWListener(using: parameters, on: 81)
            self.listener = listener
            listener.newConnectionHandler = { [weak self] (newConnection) in
                guard let self = self else { return }
                self.update {
                    self.handleNewConnection(newConnection)
                }
            }
            listener.start(queue: .main)
        }
    }

    func windowWillClose(_ notification: Notification) {
        print("close")
    }
    
    private func handleNewConnection(_ newConnection: NWConnection) {
        print("newConnection: \(newConnection)")
        let client = Client(connection: newConnection)
        clients.append(client)
        newConnection.stateUpdateHandler = { [weak self, weak newConnection] (state) in
            guard let self = self,
                let newConnection = newConnection else { return }
            
            self.update {
                switch state {
                case .waiting(let error), .failed(let error):
                    print("error: \(error)")
                    self.removeConnection(newConnection)
                default:
                    break
                }
            }
        }
        newConnection.start(queue: .main)
        receive(connection: newConnection)
    }
    
    private func removeConnection(_ connection: NWConnection) {
        print("removeConnection: \(connection)")
        clients.removeAll { $0.connection === connection }
    }
    
    private func isValidConnection(_ connection: NWConnection) -> Bool {
        clients.contains { $0.connection === connection }
    }
    
    private func receive(connection: NWConnection) {
        guard isValidConnection(connection) else {
            return
        }
        
        connection.receiveMessage { [weak self, weak connection] (data, context, isComplete, error) in
            guard let self = self,
                let connection = connection else { return }
            
            self.update {
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
                                self.handleBinary(data: data)
                            }
                        default: break
                        }
                    } else {
                        print("no WebSocket Metadata")
                    }
                    
                    self.receive(connection: connection)
                } catch {
                    print("error: \(error)")
                    self.removeConnection(connection)
                }
            }
        }
    }
    
    private func handleBinary(data: Data) {
        if data.count < 4 {
            return
        }
        
        var data = data
        
        let codeData = data.subdata(in: data.startIndex..<(data.startIndex + 4))
        let code = codeData.withUnsafeBytes { (b) in
            Int(CFSwapInt32BigToHost(b.bindMemory(to: UInt32.self)[0]))
        }
        data = data.subdata(in: (data.startIndex + 4)..<data.endIndex)
        
        switch code {
        case 1:
            guard let image = NSImage(data: data) else {
                print("broken jpeg")
                return
            }
            imageView.image = image
        default:
            break
        }
        
    }
    
    private func update(_ f: () throws -> Void) {
        do {
            try f()
        } catch {
            let alert = NSAlert(error: error)
            _ = alert.runModal()
        }
        
        render()
    }
    
    private func render() {
        connectionNumLabel.stringValue = "connection: \(clients.count)"
    }
}
