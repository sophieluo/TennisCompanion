import SwiftUI

struct StartView: View {
    @ObservedObject var bleManager: BLEManager
    
    var body: some View {
        VStack {
            Text("Tennis Ball Machine")
                .font(.largeTitle)
                .padding()
            
            Button(action: startMachine) {
                Text("START")
                    .font(.title)
                    .padding()
                    .frame(width: 200, height: 50)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }
            .disabled(!bleManager.isConnected) // Disable button if not connected
            .opacity(bleManager.isConnected ? 1.0 : 0.5)
        }
    }
    
    private func startMachine() {
        print("Starting machine...")
        bleManager.initializeDevice() // Call existing method in BLEManager
    }
}

// Preview
struct StartView_Previews: PreviewProvider {
    static var previews: some View {
        StartView(bleManager: BLEManager())
    }
}

