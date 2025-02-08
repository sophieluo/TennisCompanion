import CoreBluetooth

struct BLEConstants {
    // Commands
    static let authCommand = Data([0x01, 0x00])
    
    static func hexStringToData(_ hexString: String) -> Data {
        var hex = hexString
        var data = Data()
        while hex.count > 0 {
            let subIndex = hex.index(hex.startIndex, offsetBy: 2)
            let c = String(hex[..<subIndex])
            hex = String(hex[subIndex...])
            var ch: UInt32 = 0
            Scanner(string: c).scanHexInt32(&ch)
            data.append(UInt8(ch))
        }
        return data
    }
    
    static let firstCommand = hexStringToData("7e3a0a0100c30d0a")
    static let startCommand = hexStringToData("7e3a072200000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000282805100001470d0a")
    static let finalCommand = hexStringToData("7e3a060100bf0d0a")
}
