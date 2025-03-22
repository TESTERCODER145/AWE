import UIKit
import Flutter
import AVKit
import AVFoundation
import fl_pip

@main
@objc class AppDelegate: FlutterAppDelegate {
    private var pipController: AVPictureInPictureController?
    private var pipPlayer: AVPlayer?
    private var pipChannel: FlutterMethodChannel?
    private var playerViewController: AVPlayerViewController?
    private var pipSetupWorkItem: DispatchWorkItem?
    
    override func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        configureAudioSession()
        
        let controller = window?.rootViewController as! FlutterViewController
        
        // Initialize both channels
        setupThumbnailChannel(controller: controller)
        setupPipChannel(controller: controller)
        
        GeneratedPluginRegistrant.register(with: self)
        return super.application(application, didFinishLaunchingWithOptions: launchOptions)
    }
    
    // MARK: - Application Lifecycle
    override func applicationWillEnterForeground(_ application: UIApplication) {
        handleForegroundTransition()
    }
    
    override func applicationDidEnterBackground(_ application: UIApplication) {
        handleBackgroundTransition()
    }
    
    override func applicationWillTerminate(_ application: UIApplication) {
        cleanupPiPResources()
    }
    
    // MARK: - PIP Functionality
    private func handleStartPip(filePath: String, position: Double, result: @escaping FlutterResult) {
        cleanupPiPResources()
        
        // Check if file exists
        let fileManager = FileManager.default
        guard fileManager.fileExists(atPath: filePath) else {
            result(FlutterError(code: "FILE_NOT_FOUND", message: "Video file not found at path: \(filePath)", details: nil))
            return
        }
        
        let url = URL(fileURLWithPath: filePath)
        pipPlayer = AVPlayer(url: url)
        
        // Check if the media can be played
        let asset = AVAsset(url: url)
        let playableKey = "playable"
        
        asset.loadValuesAsynchronously(forKeys: [playableKey]) { [weak self] in
            guard let self = self else { return }
            
            var error: NSError? = nil
            let status = asset.statusOfValue(forKey: playableKey, error: &error)
            
            DispatchQueue.main.async {
                if status == .failed || error != nil {
                    result(FlutterError(code: "MEDIA_ERROR", 
                                      message: "Cannot play media: \(error?.localizedDescription ?? "Unknown error")", 
                                      details: nil))
                    return
                }
                
                self.configureAudioSessionForPlayback()
                
                if position > 0 {
                    let cmTime = CMTime(seconds: position / 1000.0, preferredTimescale: 1000)
                    self.pipPlayer?.seek(to: cmTime)
                }
                
                self.setupPlayerViewController()
                self.setupPictureInPicture(result: result)
                
                self.pipPlayer?.play()
            }
        }
    }
    
    private func handleStopPip(result: @escaping FlutterResult) {
        pipController?.stopPictureInPicture()
        cleanupPiPResources()
        result(nil)
    }
    
    // MARK: - Thumbnail Generation
    private func generateThumbnail(videoPath: String, thumbnailPath: String, maxWidth: Int, quality: Int, result: @escaping FlutterResult) {
        let fileManager = FileManager.default
        guard fileManager.fileExists(atPath: videoPath) else {
            result(FlutterError(code: "FILE_NOT_FOUND", message: "Video file not found at path: \(videoPath)", details: nil))
            return
        }
        
        let url = URL(fileURLWithPath: videoPath)
        let asset = AVAsset(url: url)
        let imageGenerator = AVAssetImageGenerator(asset: asset)
        imageGenerator.appliesPreferredTrackTransform = true
        imageGenerator.maximumSize = CGSize(width: maxWidth, height: maxWidth)
        
        // Ensure video duration is valid
        if asset.duration.seconds <= 0 {
            result(FlutterError(code: "INVALID_VIDEO", message: "Invalid video duration", details: nil))
            return
        }
        
        let time = CMTime(seconds: asset.duration.seconds / 2, preferredTimescale: 600)
        
        do {
            let cgImage = try imageGenerator.copyCGImage(at: time, actualTime: nil)
            let uiImage = UIImage(cgImage: cgImage)
            
            if let data = uiImage.jpegData(compressionQuality: CGFloat(quality)/100.0) {
                // Ensure directory exists
                let thumbnailURL = URL(fileURLWithPath: thumbnailPath)
                try fileManager.createDirectory(at: thumbnailURL.deletingLastPathComponent(), 
                                             withIntermediateDirectories: true)
                
                try data.write(to: thumbnailURL)
                result(thumbnailPath)
            } else {
                result(FlutterError(code: "IMAGE_ERROR", message: "Failed to create JPEG data", details: nil))
            }
        } catch {
            result(FlutterError(code: "THUMBNAIL_ERROR", message: error.localizedDescription, details: nil))
        }
    }
    
    // MARK: - Configuration Methods
    private func configureAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .moviePlayback)
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("Audio session configuration failed: \(error.localizedDescription)")
        }
    }
    
    private func configureAudioSessionForPlayback() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback,
                                                          mode: .moviePlayback,
                                                          options: [.allowAirPlay, .allowBluetooth])
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("Playback audio session error: \(error)")
        }
    }
    
    private func setupThumbnailChannel(controller: FlutterViewController) {
        let thumbnailChannel = FlutterMethodChannel(
            name: "native_thumbnail",
            binaryMessenger: controller.binaryMessenger
        )
        
        thumbnailChannel.setMethodCallHandler { [weak self] (call, result) in
            guard call.method == "generateThumbnail",
                  let args = call.arguments as? [String: Any],
                  let videoPath = args["videoPath"] as? String,
                  let thumbnailPath = args["thumbnailPath"] as? String,
                  let maxWidth = args["maxWidth"] as? Int,
                  let quality = args["quality"] as? Int else {
                result(FlutterMethodNotImplemented)
                return
            }
            
            self?.generateThumbnail(
                videoPath: videoPath,
                thumbnailPath: thumbnailPath,
                maxWidth: maxWidth,
                quality: quality,
                result: result
            )
        }
    }
    
    private func setupPipChannel(controller: FlutterViewController) {
        pipChannel = FlutterMethodChannel(
            name: "pip_channel",
            binaryMessenger: controller.binaryMessenger
        )
        
        pipChannel?.setMethodCallHandler { [weak self] (call, result) in
            switch call.method {
            case "startPip":
               guard let args = call.arguments as? [String: Any],
                  let path = args["path"] as? String,
                  let position = args["position"] as? Double else {
                result(FlutterError(code: "INVALID_ARGS", message: "Invalid arguments", details: nil))
                return
            }
            self?.handleStartPip(filePath: path, position: position, result: result)
            case "stopPip":
                self?.handleStopPip(result: result)
            case "isPipSupported":
                 let isSupported = AVPictureInPictureController.isPictureInPictureSupported()
                 result(isSupported)
            default:
                result(FlutterMethodNotImplemented)
            }
        }
    }
    
    // MARK: - PIP Helper Methods
    private func setupPlayerViewController() {
        playerViewController = AVPlayerViewController()
        playerViewController?.player = pipPlayer
        playerViewController?.allowsPictureInPicturePlayback = true
        playerViewController?.showsPlaybackControls = false

        // Use full screen layout initially
        playerViewController?.view.frame = UIScreen.main.bounds
        window?.rootViewController?.view.addSubview(playerViewController!.view)
        window?.rootViewController?.addChild(playerViewController!)
        playerViewController?.didMove(toParent: window?.rootViewController)
    }
    
    private func setupPictureInPicture(result: @escaping FlutterResult) {
        // Cancel any existing setup
        pipSetupWorkItem?.cancel()
        
        let workItem = DispatchWorkItem { [weak self] in
            guard let self = self,
                  let playerViewController = self.playerViewController,
                  let playerLayer = playerViewController.playerView?.layer as? AVPlayerLayer,
                  AVPictureInPictureController.isPictureInPictureSupported() else {
                result(FlutterError(code: "PIP_ERROR", message: "PiP setup failed - layer not ready or unsupported", details: nil))
                self?.cleanupPiPResources()
                return
            }
            
            self.pipController = AVPictureInPictureController(playerLayer: playerLayer)
            self.pipController?.delegate = self
            
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(self.handleBackgroundTransition),
                name: UIApplication.didEnterBackgroundNotification,
                object: nil
            )
            
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(self.handleForegroundTransition),
                name: UIApplication.willEnterForegroundNotification,
                object: nil
            )
            
            // Start PiP immediately if supported
            guard let pipController = self.pipController else {
                result(FlutterError(code: "PIP_ERROR", message: "PiP not supported", details: nil))
                self.cleanupPiPResources()
                return
            }
            
            if pipController.isPictureInPicturePossible {
                pipController.startPictureInPicture()
                result(nil)
            } else {
                result(FlutterError(code: "PIP_ERROR", message: "PiP not possible", details: nil))
                self.cleanupPiPResources()
            }
        }
        
        pipSetupWorkItem = workItem
        
        // Add timeout for PiP setup
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1, execute: workItem)
        DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) { [weak self] in
            if let workItem = self?.pipSetupWorkItem, !workItem.isCancelled {
                workItem.cancel()
                result(FlutterError(code: "PIP_TIMEOUT", message: "PiP setup timed out", details: nil))
                self?.cleanupPiPResources()
            }
        }
    }
    
    private func cleanupPiPResources() {
        pipSetupWorkItem?.cancel()
        pipSetupWorkItem = nil
        
        NotificationCenter.default.removeObserver(self, 
            name: UIApplication.didEnterBackgroundNotification, 
            object: nil
        )
        NotificationCenter.default.removeObserver(self, 
            name: UIApplication.willEnterForegroundNotification, 
            object: nil
        )
        
        pipPlayer?.pause()
        pipPlayer = nil
        
        if pipController?.isPictureInPictureActive == true {
            pipController?.stopPictureInPicture()
        }
        pipController = nil
        
        playerViewController?.willMove(toParent: nil)
        playerViewController?.view.removeFromSuperview()
        playerViewController?.removeFromParent()
        playerViewController = nil
    }
    
    // MARK: - Lifecycle Handlers
    @objc private func handleBackgroundTransition() {
        if pipPlayer != nil && pipController != nil && !pipController!.isPictureInPictureActive {
            pipController?.startPictureInPicture()
        }
        
        var backgroundTaskID: UIBackgroundTaskIdentifier = .invalid
        backgroundTaskID = UIApplication.shared.beginBackgroundTask {
            UIApplication.shared.endBackgroundTask(backgroundTaskID)
            backgroundTaskID = .invalid
        }
    }
    
    @objc private func handleForegroundTransition() {
        if pipController?.isPictureInPictureActive == true {
            pipController?.stopPictureInPicture()
        }
    }
    
    private func handleAppTermination() {
        if pipPlayer != nil && pipController != nil {
            if !pipController!.isPictureInPictureActive {
                pipController?.startPictureInPicture()
            }
        }
    }
    
    // MARK: - Orientation
    override func application(_ application: UIApplication, supportedInterfaceOrientationsFor window: UIWindow?) -> UIInterfaceOrientationMask {
        return .allButUpsideDown
    }
}

// MARK: - PIP Controller Delegate
extension AppDelegate: AVPictureInPictureControllerDelegate {
    func pictureInPictureControllerDidStartPictureInPicture(_ pictureInPictureController: AVPictureInPictureController) {
        pipChannel?.invokeMethod("onPiPStarted", arguments: nil)
        playerViewController?.view.isHidden = true
    }
    
    func pictureInPictureControllerDidStopPictureInPicture(_ pictureInPictureController: AVPictureInPictureController) {
        pipChannel?.invokeMethod("onPiPStopped", arguments: nil)
        
        if UIApplication.shared.applicationState != .active {
            // App is in background, clean up resources
            cleanupPiPResources()
        } else {
            // App is active, show player in full screen
            playerViewController?.view.isHidden = false
            playerViewController?.view.frame = UIScreen.main.bounds
            // Let the Flutter app decide what to do next
        }
    }
    
    func pictureInPictureController(_ pictureInPictureController: AVPictureInPictureController, failedToStartPictureInPictureWithError error: Error) {
        pipChannel?.invokeMethod("onPiPError", arguments: error.localizedDescription)
        cleanupPiPResources()
    }
    
    func pictureInPictureController(_ pictureInPictureController: AVPictureInPictureController, restoreUserInterfaceForPictureInPictureStopWithCompletionHandler completionHandler: @escaping (Bool) -> Void) {
        pipChannel?.invokeMethod("onRestoreFullScreen", arguments: nil)
        // Show the player in full screen
        playerViewController?.view.isHidden = false
        playerViewController?.view.frame = UIScreen.main.bounds
        completionHandler(true)
    }
}

extension AVPlayerViewController {
    var playerView: UIView? {
        return self.view.subviews.first(where: { $0.layer is AVPlayerLayer })
    }
}