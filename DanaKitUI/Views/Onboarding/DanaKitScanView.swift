import LoopKitUI
import SwiftUI
import UIKit 

struct DanaKitScanView: View {
    @Environment(\.isPresented) var isPresented
    @Environment(\.dismissAction) private var dismiss

    @ObservedObject var viewModel: DanaKitScanViewModel
    

    @State private var isShowingUIKitAlert = false

    var body: some View {
        Group {
            VStack(alignment: .leading) {
                Text(LocalizedString("Found Dana-i/RS pumps", comment: "Title for DanaKitScanView"))
                    .font(.title)
                    .bold()
                    .padding(.horizontal)

                HStack(alignment: .center, spacing: 0) {
                    Text(
                        !$viewModel.isConnecting.wrappedValue ?
                            LocalizedString("Scanning", comment: "Scanning text") :
                            LocalizedString("Connecting", comment: "Connecting text")
                    )
                    Spacer()
                    ActivityIndicator(isAnimating: .constant(true), style: .medium)
                }
                .padding(.horizontal)

                Divider()
                content
            }
            .navigationBarHidden(false)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(LocalizedString("Cancel", comment: "Cancel button title"), action: {
                        viewModel.stopScan()
                        self.dismiss()
                    })
                }
            }
            .onChange(of: isPresented) { newValue in
                if !newValue {
                    viewModel.stopScan()
                }
            }
            .alert(
                LocalizedString("Error while connecting to device", comment: "Connection error message"),
                isPresented: $viewModel.isConnectionError,
                presenting: $viewModel.connectionErrorMessage,
                actions: { _ in
                    Button(LocalizedString("Oke", comment: "Dana-RS v3 pincode prompt oke"), action: {})
                },
                message: { detail in Text(detail.wrappedValue ?? "") }
            )

            .alert(
                LocalizedString("Dana-RS v3 found!", comment: "Dana-RS v3 found"),
                isPresented: Binding(
                    get: { viewModel.isPromptingPincode && isIOS16AndAbove },
                    set: { viewModel.isPromptingPincode = $0 }
                )
            ) {
                Button(LocalizedString("Cancel", comment: "Cancel button title"), role: .cancel) {
                    viewModel.cancelPinPrompt()
                }
                Button(LocalizedString("Oke", comment: "Dana-RS v3 pincode prompt oke")) {
                    viewModel.processPinPrompt()
                }
                TextField(LocalizedString("Pin 1", comment: "Dana-RS v3 pincode prompt pin 1"), text: $viewModel.pin1)
                TextField(LocalizedString("Pin 2", comment: "Dana-RS v3 pincode prompt pin 2"), text: $viewModel.pin2)
            } message: {
                if let message = $viewModel.pinCodePromptError.wrappedValue {
                    Text(message)
                }
            }
        }

        .background(
            Group {
                if !isIOS16AndAbove {
                    PincodeAlertController(isPresented: $isShowingUIKitAlert, viewModel: viewModel)
                }
            }
        )

        .onAppear {
            if !isIOS16AndAbove {
                viewModel.showUIKitAlert = {
                    isShowingUIKitAlert = true
                }
            }
        }
    }

    @ViewBuilder private var content: some View {
        List($viewModel.scannedDevices) { $result in
            Button(action: { viewModel.connect($result.wrappedValue) }) {
                HStack {
                    Text($result.name.wrappedValue)
                    Spacer()
                    if !$viewModel.isConnecting.wrappedValue {
                        NavigationLink.empty
                    } else if $result.name.wrappedValue == viewModel.connectingTo {
                        ActivityIndicator(isAnimating: .constant(true), style: .medium)
                    }
                }
                .padding(.horizontal)
            }
            .disabled($viewModel.isConnecting.wrappedValue)
            .buttonStyle(.plain)
        }
        .listStyle(.plain)
    }
    
    private var isIOS16AndAbove: Bool {
        ProcessInfo.processInfo.operatingSystemVersion.majorVersion >= 16
    }
}



struct PincodeAlertController: UIViewControllerRepresentable {
    @Binding var isPresented: Bool
    @ObservedObject var viewModel: DanaKitScanViewModel
    
    func makeUIViewController(context: Context) -> UIViewController {
        UIViewController()
    }
    
    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {
        guard isPresented else {
            if uiViewController.presentedViewController != nil {
                uiViewController.dismiss(animated: true)
            }
            return
        }
        
        guard uiViewController.presentedViewController == nil else {
            return
        }

        let alertController = UIAlertController(
            title: LocalizedString("Dana-RS v3 found!", comment: "Dana-RS v3 found"),
            message: viewModel.pinCodePromptError,
            preferredStyle: .alert
        )

        alertController.addTextField { textField in
            textField.placeholder = LocalizedString("Pin 1", comment: "Dana-RS v3 pincode prompt pin 1")
            textField.text = viewModel.pin1
            textField.addTarget(context.coordinator, action: #selector(context.coordinator.pin1Changed), for: .editingChanged)
        }
        alertController.addTextField { textField in
            textField.placeholder = LocalizedString("Pin 2", comment: "Dana-RS v3 pincode prompt pin 2")
            textField.text = viewModel.pin2
            textField.addTarget(context.coordinator, action: #selector(context.coordinator.pin2Changed), for: .editingChanged)
        }
        
        alertController.addAction(UIAlertAction(title: LocalizedString("Cancel", comment: "Cancel button title"), style: .cancel) { _ in
            self.isPresented = false
            self.viewModel.cancelPinPrompt()
        })
        
        alertController.addAction(UIAlertAction(title: LocalizedString("Oke", comment: "Dana-RS v3 pincode prompt oke"), style: .default) { _ in
            self.isPresented = false
            self.viewModel.processPinPrompt()
        })
        
        uiViewController.present(alertController, animated: true)
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject {
        var parent: PincodeAlertController
        
        init(_ parent: PincodeAlertController) {
            self.parent = parent
        }

        @objc func pin1Changed(_ textField: UITextField) {
            parent.viewModel.pin1 = textField.text ?? ""
        }

        @objc func pin2Changed(_ textField: UITextField) {
            parent.viewModel.pin2 = textField.text ?? ""
        }
    }
}


#Preview {
    DanaKitScanView(viewModel: DanaKitScanViewModel(nextStep: {}))
}