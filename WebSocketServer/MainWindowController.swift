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
    
    var listener: NWListener!
    var clients: [Client] = []
    
    override func windowDidLoad() {
        super.windowDidLoad()
        
        update {
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

        let metadata = NWProtocolWebSocket.Metadata(opcode: NWProtocolWebSocket.Opcode.text)
        let context = NWConnection.ContentContext(identifier: "context",
                                                   metadata: [metadata])
        let text = "hello"
        let data = text.data(using: .utf8)!

        newConnection.send(content: data,
                           contentContext: context,
                           isComplete: true,
                           completion: .contentProcessed({ (error) in }))
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
                        print("opcode: \(metadata.opcode)")
                        
                        if let data = data {
                            print("\(data.count)")
                        } else {
                            print("no data")
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
