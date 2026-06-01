//
//  BarcodeScannerView.swift
//  RecipeBox
//

import SwiftUI
import AVFoundation

/// Full-screen barcode scanner for packaged foods, inspired by Lose It.
/// Uses the real AVFoundation pipeline when a camera exists; otherwise shows a
/// placeholder. Manual entry is always available so it works in the simulator.
struct BarcodeScannerView: View {
    @Environment(\.dismiss) private var dismiss

    /// Called with the detected/typed barcode string.
    var onScan: (String) -> Void

    @State private var manualCode = ""
    @State private var showingManual = false
    @State private var didScan = false

    private var cameraAvailable: Bool {
        UIImagePickerController.isSourceTypeAvailable(.camera)
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if cameraAvailable {
                BarcodeCameraView { code in
                    guard !didScan else { return }
                    didScan = true
                    let generator = UINotificationFeedbackGenerator()
                    generator.notificationOccurred(.success)
                    onScan(code)
                }
                .ignoresSafeArea()
                reticle
            } else {
                placeholder
            }

            VStack {
                topBar
                Spacer()
                bottomBar
            }
        }
        .alert("Enter Barcode", isPresented: $showingManual) {
            TextField("e.g. 0123456789012", text: $manualCode)
                .keyboardType(.numberPad)
            Button("Look Up") {
                let code = manualCode.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !code.isEmpty else { return }
                onScan(code)
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Type the number printed beneath the barcode.")
        }
    }

    // MARK: - Overlays

    private var topBar: some View {
        HStack {
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 40, height: 40)
                    .background(.ultraThinMaterial, in: .circle)
            }
            Spacer()
            Text("Scan Barcode")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.white)
            Spacer()
            Color.clear.frame(width: 40, height: 40)
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }

    private var reticle: some View {
        VStack(spacing: 18) {
            RoundedRectangle(cornerRadius: 20)
                .stroke(.white, lineWidth: 3)
                .frame(width: 260, height: 160)
                .background(Color.white.opacity(0.04), in: .rect(cornerRadius: 20))
                .shadow(color: .black.opacity(0.4), radius: 12)
            Text("Line up the barcode inside the frame")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.white.opacity(0.9))
        }
    }

    private var placeholder: some View {
        VStack(spacing: 16) {
            Image(systemName: "barcode.viewfinder")
                .font(.system(size: 64, weight: .light))
                .foregroundStyle(.white.opacity(0.85))
            Text("Camera Unavailable")
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(.white)
            Text("Install this app on your device via the Rork App to scan barcodes with the camera. You can still enter a barcode number manually below.")
                .font(.system(size: 14))
                .foregroundStyle(.white.opacity(0.75))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 36)
        }
    }

    private var bottomBar: some View {
        Button {
            manualCode = ""
            showingManual = true
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "keyboard")
                Text("Enter Barcode Manually")
                    .font(.system(size: 16, weight: .semibold))
            }
            .foregroundStyle(.white)
            .padding(.vertical, 14)
            .padding(.horizontal, 24)
            .background(.ultraThinMaterial, in: .capsule)
        }
        .padding(.bottom, 36)
    }
}

/// AVFoundation barcode capture wrapped for SwiftUI. Detects common retail symbologies.
private struct BarcodeCameraView: UIViewControllerRepresentable {
    var onFound: (String) -> Void

    func makeUIViewController(context: Context) -> BarcodeCaptureController {
        let controller = BarcodeCaptureController()
        controller.onFound = onFound
        return controller
    }

    func updateUIViewController(_ uiViewController: BarcodeCaptureController, context: Context) {}
}

/// Hosts an `AVCaptureSession` configured to read barcodes and report the first match.
final class BarcodeCaptureController: UIViewController, AVCaptureMetadataOutputObjectsDelegate {
    var onFound: ((String) -> Void)?

    private let session = AVCaptureSession()
    private var previewLayer: AVCaptureVideoPreviewLayer?
    private var hasReported = false

    private let symbologies: [AVMetadataObject.ObjectType] = [
        .ean8, .ean13, .upce, .code39, .code93, .code128, .itf14, .pdf417,
    ]

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        configureSession()
    }

    private func configureSession() {
        guard let device = AVCaptureDevice.default(for: .video),
              let input = try? AVCaptureDeviceInput(device: device),
              session.canAddInput(input) else { return }
        session.addInput(input)

        let output = AVCaptureMetadataOutput()
        guard session.canAddOutput(output) else { return }
        session.addOutput(output)
        output.setMetadataObjectsDelegate(self, queue: .main)
        output.metadataObjectTypes = symbologies.filter { output.availableMetadataObjectTypes.contains($0) }

        let layer = AVCaptureVideoPreviewLayer(session: session)
        layer.videoGravity = .resizeAspectFill
        layer.frame = view.bounds
        view.layer.addSublayer(layer)
        previewLayer = layer

        Task.detached { [session] in
            session.startRunning()
        }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer?.frame = view.bounds
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        if session.isRunning { session.stopRunning() }
    }

    func metadataOutput(
        _ output: AVCaptureMetadataOutput,
        didOutput metadataObjects: [AVMetadataObject],
        from connection: AVCaptureConnection
    ) {
        guard !hasReported,
              let object = metadataObjects.first as? AVMetadataMachineReadableCodeObject,
              let value = object.stringValue, !value.isEmpty else { return }
        hasReported = true
        session.stopRunning()
        onFound?(value)
    }
}
