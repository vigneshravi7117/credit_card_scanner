import Flutter
import UIKit

public class SwiftCardScannerPlugin: NSObject, FlutterPlugin {
    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: "nateshmbhat/credit_card_scanner", binaryMessenger: registrar.messenger())
        let instance = SwiftCardScannerPlugin()
        registrar.addMethodCallDelegate(instance, channel: channel)
    }

    var result: FlutterResult?

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        if (call.method == "scan_card") {
            let options = CardScannerOptions(from: call.arguments as? [String: String])
            let scanProcessor: ScanProcessor = ScanProcessor(withOptions: options)

            scanProcessor.scanProcessorDelegate = self

            // An earlier call that never got an answer gets no card.
            self.result?(nil)
            self.result = result

            DispatchQueue.main.async {
                scanProcessor.startScanning()
            }

            if options.cardScannerTimeOut > 0 {
                // Closes only this scanner; it used to dismiss whatever the root view
                // controller presented, even after the scan had finished. Weak: once the
                // scanner is gone there is nothing to close.
                Timer.scheduledTimer(
                    withTimeInterval: TimeInterval(options.cardScannerTimeOut),
                    repeats: false
                ) { [weak scanProcessor] _ in
                    scanProcessor?.cancel()
                }
            }
        } else {
            result(FlutterMethodNotImplemented)
        }
    }

    /// Answers the pending call once, on the main thread: a scan finishes on the video queue.
    private func reply(_ value: Any?) {
        DispatchQueue.main.async {
            guard let result = self.result else { return }
            self.result = nil
            result(value)
        }
    }
}

extension SwiftCardScannerPlugin: ScanProcessorDelegate {
    public func scanProcessor(_ scanProcessor: ScanProcessor, didFinishScanning card: CardDetails) {
        reply(card.dictionary)
    }

    /// Closed without a card: `CardScanner.scanCard` returns null, as on Android.
    public func scanProcessorDidCancel(_ scanProcessor: ScanProcessor) {
        reply(nil)
    }
}
