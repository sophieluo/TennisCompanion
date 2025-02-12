import SwiftUI
import CoreBluetooth

struct DeviceListView: View {
    @ObservedObject var bleManager: BLEManager
    @Binding var isPresented: Bool
    @State private var selectedDevice: CBPeripheral? // Track selected device
    @State private var navigateToStartView = false  // Navigation state

    var body: some View {
        NavigationStack {
            VStack {
                List(bleManager.discoveredDevices, id: \.identifier) { device in
                    Button(action: {
                        bleManager.connect(to: device)
                        selectedDevice = device
                    }) {
                        HStack {
                            Text(device.name ?? "Unknown Device")
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundColor(.gray)
                        }
                    }
                }
                .navigationTitle("Available Devices")
                .navigationBarItems(
                    leading: Button("Cancel") {
                        isPresented = false
                    },
                    trailing: Button(action: {
                        bleManager.startScanning()
                    }) {
                        Image(systemName: "arrow.clockwise")
                    }
                )
            }
            .onAppear {
                bleManager.startScanning()
            }
            .onDisappear {
                bleManager.stopScanning()
            }
            .onReceive(bleManager.$isConnected) { connected in
                if connected {
                    navigateToStartView = true
                }
            }
            .navigationDestination(isPresented: $navigateToStartView) {
                StartView(bleManager: bleManager)
            }
        }
    }
}

