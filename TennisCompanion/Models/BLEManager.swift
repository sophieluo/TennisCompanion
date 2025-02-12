import CoreBluetooth
import SwiftUI

class BLEManager: NSObject, ObservableObject {
    @Published private(set) var isScanning = false
    @Published private(set) var isConnected = false
    @Published private(set) var discoveredDevices: [CBPeripheral] = []
    
    private var centralManager: CBCentralManager!
    private var peripheral: CBPeripheral?
    private var authCharacteristic: CBCharacteristic?
    private var commandCharacteristic: CBCharacteristic?
    
    private let targetDeviceAddress = "18:7A:3E:72:16:06"
    
    private let AUTH_HANDLE: UInt16 = 0x001d
    private let CMD_HANDLE: UInt16 = 0x0020
    
    private var isReady = false
    private let serviceUUID = CBUUID(string: "FF10")
    private let authUUID = CBUUID(string: "FF12")
    private let commandUUID = CBUUID(string: "FFF3")
    
    override init() {
        super.init()
        centralManager = CBCentralManager(delegate: self, queue: nil)
    }
    
    public func startScanning() {
        guard centralManager.state == .poweredOn else {
            print("❌ Bluetooth is not powered on")
            return
        }
        
        print("Starting scan...")
        centralManager.scanForPeripherals(withServices: [serviceUUID], options: nil)
        isScanning = true
    }
    
    public func stopScanning() {
        centralManager.stopScan()
        isScanning = false
    }
    
    public func connect(to peripheral: CBPeripheral) {
        self.peripheral = peripheral
        self.peripheral?.delegate = self
        centralManager.connect(peripheral, options: nil)
    }
    
    func disconnect() {
        if let peripheral = peripheral {
            centralManager.cancelPeripheralConnection(peripheral)
        }
    }

    public func initializeDevice() {
        guard let peripheral = peripheral else {
            print("❌ No peripheral connected")
            return
        }

        print("Starting device initialization sequence...")
        
        let authCommand = Data([0x01, 0x00])
        print("📤 Sending auth command to handle 0x\(String(format: "%04x", AUTH_HANDLE))")
        writeToHandle(peripheral, handle: AUTH_HANDLE, data: authCommand, withResponse: true)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            let cmd1 = Data(hexString: "7e3a0a0100c30d0a")
            print("📤 Sending command 1 to handle 0x\(String(format: "%04x", self.CMD_HANDLE))")
            self.writeToHandle(peripheral, handle: self.CMD_HANDLE, data: cmd1, withResponse: true)
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                let cmd2 = Data(hexString: "7e3a072200000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000282805100001470d0a")
                print("📤 Sending command 2 to handle 0x\(String(format: "%04x", self.CMD_HANDLE))")
                self.writeLongToHandle(peripheral, handle: self.CMD_HANDLE, data: cmd2)
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    let cmd3 = Data(hexString: "7e3a060100bf0d0a")
                    print("📤 Sending command 3 to handle 0x\(String(format: "%04x", self.CMD_HANDLE))")
                    self.writeToHandle(peripheral, handle: self.CMD_HANDLE, data: cmd3, withResponse: true)
                }
            }
        }
    }
    
    private func writeToHandle(_ peripheral: CBPeripheral, handle: UInt16, data: Data, withResponse: Bool) {
        let handleToUUID: [UInt16: String] = [
            0x001d: "FF12",
            0x0020: "FFF3"
        ]
        
        guard let targetUUID = handleToUUID[handle] else {
            print("❌ No UUID mapping for handle: 0x\(String(format: "%04x", handle))")
            return
        }
        
        for service in peripheral.services ?? [] {
            for characteristic in service.characteristics ?? [] {
                if characteristic.uuid.uuidString == targetUUID {
                    peripheral.writeValue(data, for: characteristic, type: withResponse ? .withResponse : .withoutResponse)
                    return
                }
            }
        }
        print("❌ No characteristic found for UUID: \(targetUUID)")
    }
    
    private func writeLongToHandle(_ peripheral: CBPeripheral, handle: UInt16, data: Data) {
        let chunkSize = 18
        var offset = 0
        
        func writeNextChunk() {
            guard offset < data.count else {
                writeToHandle(peripheral, handle: handle, data: Data(), withResponse: true)
                return
            }
            
            let end = min(offset + chunkSize, data.count)
            let chunk = data.subdata(in: offset..<end)
            writeToHandle(peripheral, handle: handle, data: chunk, withResponse: true)
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                offset += chunkSize
                writeNextChunk()
            }
        }
        
        writeNextChunk()
    }
    
    private func writeCharacteristic(_ characteristic: CBCharacteristic, value: Data) {
        guard let peripheral = peripheral else {
            print("❌ No connection")
            return
        }
        
        guard characteristic.properties.contains(.write) || 
              characteristic.properties.contains(.writeWithoutResponse) else {
            print("❌ Property not supported")
            return
        }
        
        let writeType: CBCharacteristicWriteType = 
            characteristic.properties.contains(.write) ? .withResponse : .withoutResponse
            
        peripheral.writeValue(value, for: characteristic, type: writeType)
    }
    
    private func writeLongCharacteristic(data: Data, handle: Int) {
        let chunkSize = 18
        var offset = 0
        
        func writeNextChunk() {
            guard offset < data.count else {
                peripheral?.writeValue(Data(), for: handle, type: .withResponse)
                return
            }
            
            let end = min(offset + chunkSize, data.count)
            let chunk = data.subdata(in: offset..<end)
            peripheral?.writeValue(chunk, for: handle, type: .withResponse)
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                offset += chunkSize
                writeNextChunk()
            }
        }
        
        writeNextChunk()
    }
    
    private func startInitialization() {
        guard let peripheral = peripheral,
              let authChar = authCharacteristic else {
            print("❌ Missing peripheral or auth characteristic")
            return
        }
        
        print("Starting device initialization sequence...")
        let authCommand = Data([0x01, 0x00])
        print("📤 Sending auth command: \(authCommand.hexEncodedString())")
        
        if authChar.properties.contains(.write) {
            peripheral.writeValue(authCommand, for: authChar, type: .withResponse)
        } else if authChar.properties.contains(.writeWithoutResponse) {
            peripheral.writeValue(authCommand, for: authChar, type: .withoutResponse)
        } else {
            print("❌ Auth characteristic doesn't support writing")
        }
    }
}

// MARK: - CBCentralManagerDelegate
extension BLEManager: CBCentralManagerDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        switch central.state {
            case .poweredOn:
                print("Bluetooth is powered on")
            case .poweredOff:
                print("Bluetooth is powered off")
            case .unsupported:
                print("Bluetooth is unsupported")
            case .unauthorized:
                print("Bluetooth is unauthorized")
            case .resetting:
                print("Bluetooth is resetting")
            case .unknown:
                print("Bluetooth state is unknown")
            @unknown default:
                print("Unknown Bluetooth state")
        }
    }
    
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String: Any], rssi RSSI: NSNumber) {
        print("🔍 Discovered Device: \(peripheral.identifier.uuidString) - \(peripheral.name ?? "Unknown")")

        if !discoveredDevices.contains(where: { $0.identifier == peripheral.identifier }) {
            discoveredDevices.append(peripheral)
        }
    }
    
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        print("✅ Connected to: \(peripheral.identifier.uuidString)")
        isConnected = true
        self.peripheral = peripheral
        self.peripheral?.delegate = self
        self.peripheral?.discoverServices(nil)
    }
    
    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        print("Disconnected from peripheral")
        isConnected = false
        authCharacteristic = nil
        commandCharacteristic = nil
    }
}

// MARK: - CBPeripheralDelegate
extension BLEManager: CBPeripheralDelegate {
    public func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard error == nil else {
            print("❌ Error discovering services: \(error!.localizedDescription)")
            return
        }
        
        guard let services = peripheral.services else {
            print("❌ No services found")
            return
        }
        
        for service in services {
            if service.uuid == serviceUUID {
                print("✅ Found service: \(service.uuid)")
                peripheral.discoverCharacteristics([authUUID, commandUUID], for: service)
            }
        }
    }

    public func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        guard error == nil else {
            print("❌ Error discovering characteristics: \(error!.localizedDescription)")
            return
        }
        
        guard let characteristics = service.characteristics else {
            print("❌ No characteristics found")
            return
        }
        
        for characteristic in characteristics {
            if characteristic.uuid == authUUID {
                print("✅ Auth characteristic found: \(characteristic.uuid)")
                authCharacteristic = characteristic
                peripheral.setNotifyValue(true, for: characteristic)
            }
            if characteristic.uuid == commandUUID {
                print("✅ Command characteristic found: \(characteristic.uuid)")
                commandCharacteristic = characteristic
            }
        }
        
        if authCharacteristic != nil && commandCharacteristic != nil {
            print("✅ Found both required characteristics, starting initialization...")
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                self.startInitialization()
            }
        }
    }

    public func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        guard error == nil else {
            print("❌ Error receiving notification: \(error!.localizedDescription)")
            return
        }
        
        if characteristic.uuid == authUUID {
            if let value = characteristic.value {
                print("✅ Received value from \(characteristic.uuid): \(value.hexEncodedString())")
                isReady = true
            }
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: Error?) {
        if let error = error {
            print("❌ Error writing characteristic: \(error.localizedDescription)")
        } else {
            print("✅ Successfully wrote to \(characteristic.uuid.uuidString)")
        }
    }
}

// MARK: - Data Extension
extension Data {
    init(hexString: String) {
        self.init()
        var hex = hexString
        while hex.count > 0 {
            let subIndex = hex.index(hex.startIndex, offsetBy: 2)
            let c = String(hex[..<subIndex])
            hex = String(hex[subIndex...])
            var ch: UInt32 = 0
            Scanner(string: c).scanHexInt32(&ch)
            self.append(UInt8(ch))
        }
    }

    func hexEncodedString() -> String {
        return map { String(format: "%02x", $0) }.joined()
    }
}

// Add extension to CBPeripheral to support writing by handle
extension CBPeripheral {
    private static var handleToCharacteristic: [Int: CBCharacteristic] = [:]
    
    func writeValue(_ data: Data, for handle: Int, type: CBCharacteristicWriteType) {
        if let characteristic = CBPeripheral.handleToCharacteristic[handle] {
            writeValue(data, for: characteristic, type: type)
        } else {
            print("❌ No characteristic found for handle: 0x\(String(format: "%04x", handle))")
        }
    }
    
    static func storeCharacteristic(_ characteristic: CBCharacteristic, for handle: Int) {
        handleToCharacteristic[handle] = characteristic
    }
}
