import CoreBluetooth
import SwiftUI

class BLEManager: NSObject, ObservableObject {
    // MARK: - Published Properties
    @Published var isScanning = false
    @Published var isConnected = false
    @Published var discoveredDevices: [CBPeripheral] = []
    
    // MARK: - Private Properties
    private var centralManager: CBCentralManager!
    private var peripheral: CBPeripheral?
    private var authCharacteristic: CBCharacteristic?
    private var commandCharacteristic: CBCharacteristic?
    
    // Target device address - from Python script
    private let targetDeviceAddress = "18:7A:3E:72:16:06"
    
    // MARK: - Initialization
    override init() {
        super.init()
        centralManager = CBCentralManager(delegate: self, queue: nil)
    }
    
    // MARK: - Public Methods
    func startScanning() {
        guard centralManager.state == .poweredOn else {
            print("Bluetooth not powered on")
            return
        }
        print("Starting scan...")
        isScanning = true
        discoveredDevices.removeAll()
        // Scan for all devices initially
        centralManager.scanForPeripherals(withServices: nil, options: [CBCentralManagerScanOptionAllowDuplicatesKey: true])
    }
    
    func stopScanning() {
        print("Stopping scan...")
        isScanning = false
        centralManager.stopScan()
    }
    
    func connect(to peripheral: CBPeripheral) {
        print("Attempting to connect to: \(peripheral)")
        self.peripheral = peripheral
        centralManager.connect(peripheral, options: nil)
    }
    
    func disconnect() {
        if let peripheral = peripheral {
            centralManager.cancelPeripheralConnection(peripheral)
        }
    }
    
    // MARK: - Private Methods
    private func initializeDevice() {
        guard let peripheral = peripheral,
              let authChar = authCharacteristic,
              let commandChar = commandCharacteristic else {
            print("Missing required characteristics")
            return
        }
        
        print("Starting device initialization sequence...")
        
        // Auth command
        let authCommand = Data([0x01, 0x00])
        peripheral.writeValue(authCommand, for: authChar, type: .withResponse)
        print("Auth command sent")
        
        // Wait for response before sending next command
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            // First command
            let cmd1 = Data(hexString: "7e3a0a0100c30d0a")
            peripheral.writeValue(cmd1, for: commandChar, type: .withResponse)
            print("First command sent")
            
            // Wait before sending start command
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                // Long start command - handle chunking
                let cmd2 = Data(hexString: "7e3a072200000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000282805100001470d0a")
                self.writeLongCharacteristic(data: cmd2, characteristic: commandChar)
                print("Start command sent")
                
                // Wait before sending final command
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    let cmd3 = Data(hexString: "7e3a060100bf0d0a")
                    peripheral.writeValue(cmd3, for: commandChar, type: .withResponse)
                    print("Final command sent")
                }
            }
        }
    }
    
    private func writeLongCharacteristic(data: Data, characteristic: CBCharacteristic) {
        let chunkSize = 18
        var offset = 0
        
        while offset < data.count {
            let end = min(offset + chunkSize, data.count)
            let chunk = data.subdata(in: offset..<end)
            peripheral?.writeValue(chunk, for: characteristic, type: .withResponse)
            offset += chunkSize
        }
        
        // Send empty chunk to complete the write
        peripheral?.writeValue(Data(), for: characteristic, type: .withResponse)
    }
}

// MARK: - CBCentralManagerDelegate
extension BLEManager: CBCentralManagerDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        switch central.state {
        case .poweredOn:
            print("Bluetooth is powered on")
            startScanning() // Auto-start scanning when Bluetooth is ready
        case .poweredOff:
            print("Bluetooth is powered off")
            isConnected = false
        case .resetting:
            print("Bluetooth is resetting")
        case .unauthorized:
            print("Bluetooth is unauthorized")
        case .unsupported:
            print("Bluetooth is unsupported")
        case .unknown:
            print("Bluetooth state is unknown")
        @unknown default:
            print("Unknown Bluetooth state")
        }
    }
    
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        print("Discovered device: \(peripheral.identifier.uuidString) - \(peripheral.name ?? "Unknown")")
        
        // Check if this is our target device
        // Note: iOS doesn't provide MAC address directly, so we'll check the identifier
        if !discoveredDevices.contains(where: { $0.identifier == peripheral.identifier }) {
            discoveredDevices.append(peripheral)
        }
    }
    
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        print("Connected to peripheral")
        isConnected = true
        peripheral.delegate = self
        peripheral.discoverServices(nil)
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
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard let services = peripheral.services else { return }
        print("Discovered services: \(services)")
        
        for service in services {
            peripheral.discoverCharacteristics(nil, for: service)
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        guard let characteristics = service.characteristics else { return }
        print("Discovered characteristics for service \(service.uuid): \(characteristics)")
        
        for characteristic in characteristics {
            // Look for characteristics by UUID
            if characteristic.properties.contains(.write) || characteristic.properties.contains(.writeWithoutResponse) {
                // Using UUIDs instead of handles
                // Note: Replace these UUIDs with the actual UUIDs from your device
                if characteristic.uuid.uuidString == "FF01" {  // Auth characteristic UUID
                    authCharacteristic = characteristic
                    print("Found auth characteristic")
                } else if characteristic.uuid.uuidString == "FF02" {  // Command characteristic UUID
                    commandCharacteristic = characteristic
                    print("Found command characteristic")
                }
            }
        }
        
        // If we found both characteristics, start the initialization
        if authCharacteristic != nil && commandCharacteristic != nil {
            initializeDevice()
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: Error?) {
        if let error = error {
            print("Error writing characteristic: \(error.localizedDescription)")
        } else {
            print("Successfully wrote characteristic")
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
}
