//
//  CameraViewController.swift
//  Card Promise Showcase
//
//  Created by Mohammed Sadiq on 26/07/20.
//  Copyright © 2020 MZaink. All rights reserved.
//

import UIKit
import AVFoundation
import Vision

protocol CameraDelegate {
    func camera(_ camera: CameraViewController, didScan scanResult: RecognizedText)
    /// The scanner screen was dismissed: after a scan, the close button, or the timeout.
    func cameraDidStopScanning(_ camera: CameraViewController)
}


class CameraViewController: UIViewController {
    var scansDroppedSinceLastReset: Int = 0

    // Reused for every frame; frames arrive one at a time on the video queue.
    let textRecognitionRequest: VNRecognizeTextRequest = {
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        // Language correction rewrites digit runs into words.
        request.usesLanguageCorrection = false
        return request
    }()

    var cameraDelegate: CameraDelegate?
    var captureSession: AVCaptureSession?
    var device: AVCaptureDevice?
    var input: AVCaptureDeviceInput?
    var prompt: String = ""

    var cameraOrientation: CameraOrientation = .portrait

    private var previewLayer: AVCaptureVideoPreviewLayer?
    // startRunning() / stopRunning() block, so they run here instead of on the main thread.
    // Serial, so a close tapped while the camera is still starting stops it afterwards.
    private let sessionQueue = DispatchQueue(label: "credit_card_scanner.session")
    private var subjectAreaObserver: NSObjectProtocol?

    /// The centre of the card frame, which is centred on screen, in device coordinates.
    private static let cardFrameCenter = CGPoint(x: 0.5, y: 0.5)
    private static let controlSize: CGFloat = 44.0
    private static let controlSymbolConfiguration = UIImage.SymbolConfiguration(pointSize: 17.0, weight: .semibold)

    public override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        // Added first and kept above everything else, so there is always a way back out,
        // including when the camera never starts (no camera, or access denied).
        addCloseButton()
        // A gesture recognizer rather than a view on top: it doesn't take taps from the buttons.
        view.addGestureRecognizer(
            UITapGestureRecognizer(target: self, action: #selector(handleTapToFocus(_:)))
        )
        gainCameraPermission()
    }

    public override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer?.frame = view.bounds
    }

    public override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        addAnimatingScanLine()
    }

    public override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        if isBeingDismissed {
            stopCaptureSession()
        }
    }

    public override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        if isBeingDismissed {
            if let observer = subjectAreaObserver {
                NotificationCenter.default.removeObserver(observer)
                subjectAreaObserver = nil
            }
            cameraDelegate?.cameraDidStopScanning(self)
        }
    }

    func setupCaptureSession() {
        guard let captureDevice = CameraViewController.preferredBackCamera(),
              let deviceInput = try? AVCaptureDeviceInput(device: captureDevice) else {
            // No camera (e.g. the simulator): the close button is already there.
            return
        }

        let session = AVCaptureSession()
        if session.canSetSessionPreset(.high) {
            session.sessionPreset = .high
        }
        guard session.canAddInput(deviceInput) else {
            return
        }
        session.addInput(deviceInput)

        captureSession = session
        device = captureDevice
        input = deviceInput

        addOutputToInputDevice()

        configureCamera()
        observeSubjectAreaChanges(of: captureDevice)

        createAndAddPreviewLayer()

        addScanControlsAndIndicators()

        startScanning()
    }

    func gainCameraPermission() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            setupCaptureSession()

        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                guard granted else { return }
                DispatchQueue.main.async {
                    self.setupCaptureSession()
                }
            }

        case .denied, .restricted:
            // The user has previously denied access; or
            // The user can't grant access due to restrictions.
            fallthrough

        @unknown default:
            // The screen isn't presented yet, so it can't dismiss itself here; the close
            // button takes the user back.
            NSLog("Camera Permissions Error")
        }
    }

    func createAndAddPreviewLayer() {
        guard let session = captureSession else { return }
        DispatchQueue.main.async {
            let previewLayer = AVCaptureVideoPreviewLayer(session: session)
            previewLayer.frame = self.view.bounds
            previewLayer.videoGravity = .resizeAspectFill
            previewLayer.isOpaque = true
            self.view.layer.isOpaque = true
            // Below every subview: added on top, it hid the close and flash buttons.
            self.view.layer.insertSublayer(previewLayer, at: 0)
            self.previewLayer = previewLayer
        }
    }

    func addOutputToInputDevice() {
        guard let session = captureSession else { return }
        let dataOutput = AVCaptureVideoDataOutput()
        dataOutput.alwaysDiscardsLateVideoFrames = true
        dataOutput.setSampleBufferDelegate(self, queue: DispatchQueue(label: "Video Queue"))
        if session.canAddOutput(dataOutput) {
            session.addOutput(dataOutput)
        }
    }

    func refocus() {
        // `device` is only set once camera access is granted and the capture session is set
        // up. A tap before then - or at all when access was denied - reached here with a nil
        // `device!` and crashed (EXC_BREAKPOINT in captureTap:, Sentry ONEGOLD-NF).
        focus(at: CameraViewController.cardFrameCenter, continuous: true)
    }

    func addScanControlsAndIndicators() {
        addCornerClips()
        addScanYourCardToProceedLabel()
        addNavigationBar()
    }

    func addCornerClips() {
        DispatchQueue.main.async {
            let cornerClipsView = CornerClipsView()
            cornerClipsView.backgroundColor = .clear
            cornerClipsView.frame = self.view.bounds
            cornerClipsView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            // Full screen: it must not swallow taps meant for the buttons or tap to focus.
            cornerClipsView.isUserInteractionEnabled = false
            self.addOverlay(cornerClipsView)
        }
    }


    func addScanYourCardToProceedLabel() {
        DispatchQueue.main.async {
            let center = self.view.center
            let scanYourCardToProceedLabel = UILabel(
                frame: CGRect(
                    origin: CGPoint(
                        x: center.x - 160,
                        y: center.y + 180
                    ),
                    size: CGSize(
                        width: 320,
                        height: 20
                    )
                )
            )

            scanYourCardToProceedLabel.textAlignment = NSTextAlignment.center
            scanYourCardToProceedLabel.text = self.prompt
            scanYourCardToProceedLabel.numberOfLines = 0
            scanYourCardToProceedLabel.font = scanYourCardToProceedLabel.font.withSize(12.0)
            scanYourCardToProceedLabel.textColor = .white
            self.addOverlay(scanYourCardToProceedLabel)
        }
    }


    func addNavigationBar() {
        DispatchQueue.main.async {
            self.addFlashButton()
        }
    }

    /// Adds a non-interactive view below the close and flash buttons.
    private func addOverlay(_ overlay: UIView) {
        view.insertSubview(overlay, belowSubview: closeButton)
    }

    // SF Symbols instead of the PNGs in ios/Assets: the podspec stopped shipping those
    // (s.resources was dropped in 1.0.2), so UIImage(named:) returned nil and the buttons
    // were invisible.
    lazy var closeButton: UIButton = makeControlButton(
        systemImageName: "xmark",
        accessibilityLabel: "Close",
        action: #selector(selectorBackButton)
    )

    lazy var flashButton: UIButton = makeControlButton(
        systemImageName: "bolt.slash.fill",
        accessibilityLabel: "Flashlight",
        action: #selector(selectorFlashLightButton)
    )

    private func makeControlButton(systemImageName: String, accessibilityLabel: String, action: Selector) -> UIButton {
        let button = UIButton(type: .system)
        button.setImage(
            UIImage(systemName: systemImageName, withConfiguration: CameraViewController.controlSymbolConfiguration),
            for: .normal
        )
        button.tintColor = .white
        button.backgroundColor = UIColor.black.withAlphaComponent(0.45)
        button.layer.cornerRadius = CameraViewController.controlSize / 2
        button.accessibilityLabel = accessibilityLabel
        button.translatesAutoresizingMaskIntoConstraints = false
        button.addTarget(self, action: action, for: .touchUpInside)
        return button
    }

    /// Top left, inside the safe area: a fixed y of 55 put it under the Dynamic Island.
    private func addCloseButton() {
        view.addSubview(closeButton)
        NSLayoutConstraint.activate([
            closeButton.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 16.0),
            closeButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 8.0),
            closeButton.widthAnchor.constraint(equalToConstant: CameraViewController.controlSize),
            closeButton.heightAnchor.constraint(equalToConstant: CameraViewController.controlSize),
        ])
    }

    private func addFlashButton() {
        guard let device = device, device.hasTorch, flashButton.superview == nil else { return }
        updateFlashButtonImage()
        view.addSubview(flashButton)
        NSLayoutConstraint.activate([
            flashButton.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -16.0),
            flashButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 8.0),
            flashButton.widthAnchor.constraint(equalToConstant: CameraViewController.controlSize),
            flashButton.heightAnchor.constraint(equalToConstant: CameraViewController.controlSize),
        ])
    }

    private func updateFlashButtonImage() {
        let systemImageName = device?.isTorchOn == true ? "bolt.fill" : "bolt.slash.fill"
        flashButton.setImage(
            UIImage(systemName: systemImageName, withConfiguration: CameraViewController.controlSymbolConfiguration),
            for: .normal
        )
    }

    @objc func selectorFlashLightButton() {
        // The camera in the session, which may be the multi-lens one, not the default device.
        device?.toggleTorch()
        updateFlashButtonImage()
    }

    @objc func selectorBackButton() {
        stopScanning()
    }

    func addAnimatingScanLine() {

        guard let image = UIImage(named: "blueScanLine", in: CameraViewController.assetsBundle, compatibleWith: nil) else {
            return
        }

        let blueScanLineImage = UIImageView(image: image)
        blueScanLineImage.isUserInteractionEnabled = false

        var center = view.center

        for view in view.subviews {
            if let cornerClips = view as? CornerClipsView {
                center = cornerClips.center
            }
        }

        blueScanLineImage.frame = CGRect(origin: CGPoint(x: center.x - 160.0, y: center.y - 95.0), size: CGSize(width: 320.0, height: 30.0))



        DispatchQueue.main.async {
            UIView.animate(withDuration: 2.0, delay: 0, options: [.repeat, .autoreverse], animations: {
                blueScanLineImage.frame = CGRect(origin: CGPoint(x: center.x - 160, y:  center.y + 95.0 - 30.0), size: CGSize(width: 320.0, height: 30.0))
            }, completion: nil)
            self.addOverlay(blueScanLineImage)
        }
    }

    /// The bundle with the plugin's images (ios/Assets, see the podspec's resource_bundles).
    /// With a static framework it is copied next to the app's own resources.
    private static let assetsBundle: Bundle? = {
        for host in [Bundle(for: CameraViewController.self), Bundle.main] {
            if let url = host.url(forResource: "credit_card_scanner_assets", withExtension: "bundle"),
               let bundle = Bundle(url: url) {
                return bundle
            }
        }
        return nil
    }()

    public func startScanning() {
        guard let session = captureSession else { return }
        sessionQueue.async {
            session.startRunning()
            // Starting can apply the session's format, which resets the zoom; set it again.
            self.configureCamera()
        }
    }

    /// Stops the camera and closes the scanner. The delegate hears about it once it is gone.
    public func stopScanning() {
        stopCaptureSession()
        DispatchQueue.main.async {
            guard self.presentingViewController != nil, !self.isBeingDismissed else { return }
            self.dismiss(animated: true, completion: nil)
        }
    }

    private func stopCaptureSession() {
        // Still nil when the camera was never set up (access denied, no camera).
        guard let session = captureSession else { return }
        sessionQueue.async {
            session.stopRunning()
        }
    }
}

// MARK: - Focus
extension CameraViewController {
    /// The back multi-lens (virtual) camera when its ultra-wide lens can autofocus, otherwise
    /// the main lens.
    ///
    /// On recent iPhones, Pro models especially, the main lens can't focus closer than about
    /// 15-20 cm, so a card held close enough to fill the frame stayed blurry. Like the Camera
    /// app, the multi-lens camera switches to the ultra-wide lens by itself for close subjects
    /// (macro). Phones whose ultra-wide is fixed-focus have no macro to switch to, and their
    /// main lens already focuses closer, so they keep it.
    static func preferredBackCamera() -> AVCaptureDevice? {
        for type in [AVCaptureDevice.DeviceType.builtInTripleCamera, .builtInDualWideCamera] {
            guard let device = AVCaptureDevice.default(type, for: .video, position: .back) else {
                continue
            }
            let ultraWideFocuses = device.constituentDevices.contains {
                $0.deviceType == .builtInUltraWideCamera && $0.isFocusModeSupported(.autoFocus)
            }
            if ultraWideFocuses {
                return device
            }
        }
        return AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back)
            ?? AVCaptureDevice.default(for: .video)
    }

    /// On a multi-lens camera, videoZoomFactor 1.0 is the ultra-wide lens and the main lens
    /// starts at the first switch-over factor (2.0 on current iPhones). 1 for other cameras.
    private var mainLensZoomFactor: CGFloat {
        guard let device = device,
              device.isVirtualDevice,
              let switchOver = device.virtualDeviceSwitchOverVideoZoomFactors.first else {
            return 1.0
        }
        return CGFloat(truncating: switchOver)
    }

    /// Opens on the main lens's field of view (a multi-lens camera starts on the ultra-wide),
    /// with continuous autofocus on the card frame.
    private func configureCamera() {
        if let device = device, mainLensZoomFactor != 1.0, (try? device.lockForConfiguration()) != nil {
            // Lens switching stays automatic, so it still moves to the ultra-wide for close-ups.
            device.videoZoomFactor = min(
                max(mainLensZoomFactor, device.minAvailableVideoZoomFactor),
                device.maxAvailableVideoZoomFactor
            )
            device.unlockForConfiguration()
        }
        refocus()
    }

    /// Focuses and exposes at `devicePoint`. Continuous keeps following the card as it moves;
    /// otherwise focus is set once (tap to focus) and goes back to continuous when the scene
    /// changes.
    ///
    /// The scanner used to focus once (.autoFocus) before the camera had even started and then
    /// stay locked there, so a card brought closer never came into focus.
    private func focus(at devicePoint: CGPoint, continuous: Bool) {
        guard let device = device else { return }
        do {
            try device.lockForConfiguration()
        } catch {
            NSLog("Camera focus error: %@", error.localizedDescription)
            return
        }
        defer { device.unlockForConfiguration() }

        // The point of interest only applies once the focus / exposure mode is set after it.
        let focusMode: AVCaptureDevice.FocusMode = continuous ? .continuousAutoFocus : .autoFocus
        if device.isFocusPointOfInterestSupported {
            device.focusPointOfInterest = devicePoint
        }
        if device.isFocusModeSupported(focusMode) {
            device.focusMode = focusMode
        }
        // A card is always held close: search near distances first.
        if device.isAutoFocusRangeRestrictionSupported {
            device.autoFocusRangeRestriction = .near
        }
        if device.isSmoothAutoFocusSupported {
            device.isSmoothAutoFocusEnabled = false
        }

        if device.isExposurePointOfInterestSupported {
            device.exposurePointOfInterest = devicePoint
        }
        if device.isExposureModeSupported(.continuousAutoExposure) {
            device.exposureMode = .continuousAutoExposure
        }

        device.isSubjectAreaChangeMonitoringEnabled = !continuous
    }

    private func observeSubjectAreaChanges(of captureDevice: AVCaptureDevice) {
        subjectAreaObserver = NotificationCenter.default.addObserver(
            forName: .AVCaptureDeviceSubjectAreaDidChange,
            object: captureDevice,
            queue: .main
        ) { [weak self] _ in
            // After a tap to focus, the card moved: follow it again.
            self?.refocus()
        }
    }

    @objc func handleTapToFocus(_ gesture: UITapGestureRecognizer) {
        guard device != nil, let previewLayer = previewLayer else { return }
        // The preview layer fills the view, so view and layer coordinates are the same.
        let layerPoint = gesture.location(in: view)
        let devicePoint = previewLayer.captureDevicePointConverted(fromLayerPoint: layerPoint)
        focus(at: devicePoint, continuous: false)
        showFocusIndicator(at: layerPoint)
    }

    private func showFocusIndicator(at point: CGPoint) {
        let size: CGFloat = 70.0
        let indicator = UIView(
            frame: CGRect(x: point.x - size / 2, y: point.y - size / 2, width: size, height: size)
        )
        indicator.isUserInteractionEnabled = false
        indicator.layer.borderColor = UIColor.systemYellow.cgColor
        indicator.layer.borderWidth = 1.5
        indicator.transform = CGAffineTransform(scaleX: 1.4, y: 1.4)
        addOverlay(indicator)

        UIView.animate(withDuration: 0.25, animations: {
            indicator.transform = .identity
        }, completion: { _ in
            UIView.animate(withDuration: 0.3, delay: 0.6, options: [], animations: {
                indicator.alpha = 0
            }, completion: { _ in
                indicator.removeFromSuperview()
            })
        })
    }
}

extension CameraViewController: AVCaptureVideoDataOutputSampleBufferDelegate {
    public func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        // .right = portrait mode
        // .up = landscapeRight
        let requestHandler = VNImageRequestHandler(
            cmSampleBuffer: sampleBuffer,
            orientation: orientationForScanning,
            options: [:]
        )

        do {
            try requestHandler.perform([textRecognitionRequest])
        } catch {
            #if DEBUG
            NSLog("Text recognition failed: %@", error.localizedDescription)
            #endif
            return
        }

        let result = RecognizedText(observations: textRecognitionRequest.results ?? [])
        cameraDelegate?.camera(self, didScan: result)
    }
}

// MARK: - Auxilliary methods
extension CameraViewController {
    func vibrateToIndicateTouch() {
        let impactFeedbackgenerator = UIImpactFeedbackGenerator(style: .medium)
        impactFeedbackgenerator.prepare()
        impactFeedbackgenerator.impactOccurred()
    }

    var orientationForScanning: CGImagePropertyOrientation {
        if (cameraOrientation == .landscape) {
            // landscape mode
            return .up
        } else {
            // portrait mode
            return .right
        }
    }

    func imageOrientation(
        deviceOrientation: UIDeviceOrientation,
        cameraPosition: AVCaptureDevice.Position
    ) -> UIImage.Orientation {
        switch deviceOrientation {
        case .portrait:
            return cameraPosition == .front ? .leftMirrored : .right
        case .landscapeLeft:
            return cameraPosition == .front ? .downMirrored : .up
        case .portraitUpsideDown:
            return cameraPosition == .front ? .rightMirrored : .left
        case .landscapeRight:
            return cameraPosition == .front ? .upMirrored : .down
        case .faceDown, .faceUp, .unknown:
            return .up
        @unknown default:
            return .up
        }
    }
}

class CornerClipsView: UIView {
    override func draw(_ rect: CGRect) {
        super.draw(rect)

        let halfWidth: CGFloat = 160.0
        let halfHeight: CGFloat = 95.0
        let startPoint: CGPoint = CGPoint(x: center.x - halfWidth, y: center.y - halfHeight)
        let endPoint: CGPoint = CGPoint(x: center.x + halfWidth, y: center.y + halfHeight)


        let leftTopCorner: CGPoint = startPoint
        let rightTopCorner: CGPoint = CGPoint(x: endPoint.x, y: startPoint.y)
        let leftBottomCorner: CGPoint = CGPoint(x: startPoint.x, y: endPoint.y)
        let rightBottomCorner: CGPoint = endPoint

        guard let ctx  = UIGraphicsGetCurrentContext() else {
            return
        }

        ctx.setLineWidth(2.0)
        ctx.setStrokeColor(UIColor.white.cgColor)

        ctx.move(to: leftTopCorner)
        ctx.addLine(to: CGPoint(x: leftTopCorner.x + 30, y: leftTopCorner.y))
        ctx.move(to: leftTopCorner)
        ctx.addLine(to: CGPoint(x: leftTopCorner.x, y: leftTopCorner.y + 20))

        ctx.move(to: leftBottomCorner)
        ctx.addLine(to: CGPoint(x: leftBottomCorner.x + 30, y: leftBottomCorner.y))
        ctx.move(to: leftBottomCorner)
        ctx.addLine(to: CGPoint(x: leftBottomCorner.x, y: leftBottomCorner.y - 20))

        ctx.move(to: rightTopCorner)
        ctx.addLine(to: CGPoint(x: rightTopCorner.x - 30, y: rightTopCorner.y))
        ctx.move(to: rightTopCorner)
        ctx.addLine(to: CGPoint(x: rightTopCorner.x, y: rightTopCorner.y + 20))

        ctx.move(to: rightBottomCorner)
        ctx.addLine(to: CGPoint(x: rightBottomCorner.x - 30, y: rightBottomCorner.y))
        ctx.move(to: rightBottomCorner)
        ctx.addLine(to: CGPoint(x: rightBottomCorner.x, y: rightBottomCorner.y - 20))

        ctx.strokePath()
    }
}

extension AVCaptureDevice {
    var isLocked: Bool {
        do {
            try lockForConfiguration()
            return true
        } catch {
            print(error)
            return false
        }
    }

    func toggleTorch() {
        guard hasTorch && isLocked else { return }

        defer { unlockForConfiguration() }

        if torchMode == .off {
            torchMode = .on
        }  else {
            torchMode = .off
        }
    }

    var isTorchOn: Bool {
        return torchMode == .on
    }
}
