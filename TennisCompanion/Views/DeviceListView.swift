import SwiftUI

struct DeviceListView: View {
    @ObservedObject var bleManager: BLEManager
    @Binding var isPresented: Bool
    
    var body: some View {
        NavigationView {
            List(bleManager.discoveredDevices, id: \.identifier) { device in
                Button(action: {
                    bleManager.connect(to: device)
                    isPresented = false
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
    }
}