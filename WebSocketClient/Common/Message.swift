import Foundation

public enum MessageCode : Int32 {
    case jpeg = 1
    
    public var messageType: Message.Type {
        switch self {
        case .jpeg: return JpegMessage.self
        }
    }
    
    public var netValue: Int32 {
        return Int32(bitPattern: CFSwapInt32HostToBig(UInt32(bitPattern: rawValue)))
    }
    
    public init?(netValue: Int32) {
        let hostValue = Int32(bitPattern: CFSwapInt32BigToHost(UInt32(bitPattern: netValue)))
        self.init(rawValue: hostValue)
    }
}

public protocol Message {
    static var code: MessageCode { get }
    
    func _serializeBody() -> Data

    init?(data: Data)
}

extension Message {
    public func serialize() -> Data {
        var data = Data()
        
        let code = type(of: self).code.netValue
        withUnsafePointer(to: code) { (p) in
            data.append(UnsafeBufferPointer(start: p, count: 1))
        }
        
        let body = _serializeBody()
        data.append(body)
        
        return data
    }
}

public enum Messages {    
    public static func parse(data: Data) -> Message? {
        if data.count < 4 {
            return nil
        }
        
        var data = data
        
        let codeNetValue = data.withUnsafeBytes { (b) in
            b.bindMemory(to: Int32.self)[0]
        }
        data = data.subdata(in: (data.startIndex + 4)..<data.endIndex)
        
        guard let code = MessageCode(netValue: codeNetValue) else {
            return nil
        }
        
        let messageType = code.messageType
        
        guard let message = messageType.init(data: data) else {
            return nil
        }
        
        return message
    }
}

public struct JpegMessage : Message {
    public static let code: MessageCode = .jpeg
    
    public var jpeg: Data
    
    public init(jpeg: Data) {
        self.jpeg = jpeg
    }
    
    public init?(data: Data) {
        self.init(jpeg: data)
    }
    
    public func _serializeBody() -> Data {
        return jpeg
    }
}
