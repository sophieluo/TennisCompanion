import SwiftUI

struct ContentView: View {
    @StateObject private var bleManager = BLEManager()
    @State private var showDeviceSheet = false
    
    var body: some View {
        VStack(spacing: 20) {
            // Status section
            VStack(alignment: .leading, spacing: 10) {
                Text("Status: \(bleManager.isConnected ? "Connected" : "Disconnected")")
                    .foregroundColor(bleManager.isConnected ? .green : .red)
                    .bold()
                
                Text("Scanning: \(bleManager.isScanning ? "Yes" : "No")")
                
                Text("Found Devices: \(bleManager.discoveredDevices.count)")
                
                // List discovered devices
                if !bleManager.discoveredDevices.isEmpty {
                    Text("Devices:")
                    ForEach(bleManager.discoveredDevices, id: \.identifier) { device in
                        Text("- \(device.name ?? "Unknown") (\(device.identifier))")
                            .font(.caption)
                    }
                }
            }
            .padding()
            .background(Color.gray.opacity(0.1))
            .cornerRadius(10)
            
            // Control buttons
            Button(action: {
                showDeviceSheet = true
            }) {
                Text("Scan for Devices")
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }
            
            if bleManager.isConnected {
                Button(action: {
                    bleManager.disconnect()
                }) {
                    Text("Disconnect")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.red)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
            }
        }
        .padding()
        .sheet(isPresented: $showDeviceSheet) {
            DeviceListView(bleManager: bleManager, isPresented: $showDeviceSheet)
        }
    }
}