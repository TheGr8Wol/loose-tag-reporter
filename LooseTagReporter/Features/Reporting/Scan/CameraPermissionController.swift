import Foundation
import TagReportingCore

/// Camera permission + DataScanner availability gate (T11 stub — no live camera required).
enum CameraPermissionStatus: Equatable, Sendable {
    case notDetermined
    case authorized
    case denied
    case restricted
    case unsupported
}

protocol CameraPermissionChecking: Sendable {
    func status() async -> CameraPermissionStatus
}

struct CameraPermissionController: CameraPermissionChecking {
    var isSimulatorOrUnsupported: Bool = false

    func status() async -> CameraPermissionStatus {
        if isSimulatorOrUnsupported { return .unsupported }
        // Real AVCaptureDevice / DataScannerViewController checks land with T11 live scanner.
        return .notDetermined
    }

    /// Denied / restricted / unsupported → manual identity path (never blocks a find).
    static func shouldUseManualPath(_ status: CameraPermissionStatus) -> Bool {
        switch status {
        case .denied, .restricted, .unsupported:
            return true
        case .authorized, .notDetermined:
            return false
        }
    }
}

/// Headless recognizer for CI (T11).
protocol TextRecognizing: Sendable {
    func recognize(in imageData: Data) async -> [String]
}

struct MockRecognizer: TextRecognizing {
    var fragments: [String]

    func recognize(in imageData: Data) async -> [String] {
        _ = imageData
        return fragments
    }
}
