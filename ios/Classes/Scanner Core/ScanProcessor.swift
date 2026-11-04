//
//  CardScanProcessorCore.swift
//  Card ScanProcessor
//
//  Created by Mohammed Sadiq on 26/07/20.
//  Copyright © 2020 MZaink. All rights reserved.
//

import UIKit

public protocol ScanProcessorDelegate {
    func scanProcessor(_ scanProcessor: ScanProcessor, didFinishScanning card: CardDetails)
    /// The scanner closed without a card: the close button, the timeout, or it couldn't open.
    func scanProcessorDidCancel(_ scanProcessor: ScanProcessor)
}

public class ScanProcessor {
    var scanProcessorDelegate: ScanProcessorDelegate?
    var card: CardDetails = CardDetails()
    
    var datesCollectedSoFar: [String] = []
    var validScansSoFar: Int = 0
    var singleFrameCardScanner: SingleFrameCardScanner
    var cardDetailsScanOptimizer: CardDetailsScanOptimizer
    var cardScanOptions: CardScannerOptions
    // Set once the delegate has its answer, so it gets exactly one.
    private var didFinish = false
    private weak var cameraViewController: CameraViewController?
    
    init(withOptions cardScanOptions: CardScannerOptions) {
        self.cardScanOptions = cardScanOptions
        self.singleFrameCardScanner = SingleFrameCardScanner(withOptions: cardScanOptions)
        self.cardDetailsScanOptimizer = CardDetailsScanOptimizer(scannerOptions: cardScanOptions)
    }
    
    func startScanning() {
        guard let presenter = ScanProcessor.topViewController() else {
            didFinish = true
            scanProcessorDelegate?.scanProcessorDidCancel(self)
            return
        }
        let cameraViewController: CameraViewController = makeCameraViewController()
        self.cameraViewController = cameraViewController
        presenter.present(
            cameraViewController,
            animated: true,
            completion: nil
        )
    }
    
    /// Closes the scanner without a card (the scan timeout).
    func cancel() {
        cameraViewController?.stopScanning()
    }
    
    /// The view controller on top of the key window. The root one can't present the scanner
    /// while it is already presenting something else.
    static func topViewController() -> UIViewController? {
        let windows = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
        var top = (windows.first { $0.isKeyWindow } ?? windows.first)?.rootViewController
        while let presented = top?.presentedViewController, !presented.isBeingDismissed {
            top = presented
        }
        return top
    }
    
    func makeCameraViewController() -> CameraViewController {
        let cameraViewController: CameraViewController = CameraViewController()
        cameraViewController.cameraDelegate = self
        cameraViewController.cameraOrientation = cardScanOptions.cameraOrientation
        cameraViewController.prompt = cardScanOptions.prompt
        cameraViewController.modalPresentationStyle = .fullScreen
        
        return cameraViewController
    }
}

// MARK:- CameraDelegate
extension ScanProcessor: CameraDelegate {
    func camera(_ camera: CameraViewController, didScan scanResult: RecognizedText) {
        // Frames keep coming until the camera stops.
        guard !didFinish else { return }
        guard let cardDetails = singleFrameCardScanner.scanSingleFrame(visionText: scanResult) else {
            return
        }
        
        cardDetailsScanOptimizer.processCardDetails(cardDetails: cardDetails)
    
        if (cardDetailsScanOptimizer.isReadyToFinishScan()) {
            vibrateToIndicateScanEnd()
            
            card.cardNumber = cardDetailsScanOptimizer.getOptimalCardDetails()?.cardNumber ?? ""
            card.cardHolderName = cardDetailsScanOptimizer.getOptimalCardDetails()?.cardHolderName ?? ""
            card.expiryDate = cardDetailsScanOptimizer.getOptimalCardDetails()?.expiryDate ?? ""
            
            didFinish = true
            scanProcessorDelegate?.scanProcessor(self, didFinishScanning: card)
            camera.stopScanning()
        }
    }
    
    func vibrateToIndicateScanEnd() {
        // Called on the video queue; UIKit needs the main thread.
        DispatchQueue.main.async {
            let impactFeedbackgenerator = UIImpactFeedbackGenerator(style: .heavy)
            impactFeedbackgenerator.prepare()
            impactFeedbackgenerator.impactOccurred()
        }
    }
    
    func cameraDidStopScanning(_ camera: CameraViewController) {
        // Closed before a card was read. Without this the Flutter call never returned.
        guard !didFinish else { return }
        didFinish = true
        scanProcessorDelegate?.scanProcessorDidCancel(self)
    }
}
