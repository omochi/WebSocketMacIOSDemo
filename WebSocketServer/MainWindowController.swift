import Cocoa
import Network

class MainWindowController: NSWindowController, NSWindowDelegate {
    @IBOutlet private var connectionNumLabel: NSTextField!
    @IBOutlet private var imageView: ImageView!
    
    var listener: NWListener!
    var clients: [Client] = []
    
    var image: NSImage?
    
    override func windowDidLoad() {
        super.windowDidLoad()
        
        update {
            imageView.contentsGravity = .resizeAspectFill
            
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
        
        client.errorHandler = { [weak self, weak client] (error) in
            guard let self = self,
                let client = client else { return }
            
            self.update {
                print("error: \(error)")
                self.removeClient(client)
            }
        }
        client.binaryHandler = { [weak self, weak client] (data) in
            guard let self = self,
                let client = client else { return }
            
            self.update {
                self.handleBinary(client: client, data: data)
            }
        }
        
        client.start()
    }
    
    private func removeClient(_ client: Client) {
        print("removeClient: \(client)")
        clients.removeAll { $0 === client }
    }
    
    private func handleBinary(client: Client, data: Data) {
        guard let message = Messages.parse(data: data) else {
            return
        }

        switch message {
        case let m as JpegMessage:
            guard let image = NSImage(data: m.jpeg) else {
                print("broken jpeg")
                return
            }
            client.isJpegSender = true
            self.image = image
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
        imageView.image = image
    }
}
