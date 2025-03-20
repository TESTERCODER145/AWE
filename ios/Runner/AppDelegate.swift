import UIKit
import Flutter
import AVKit
import AVFoundation

@main
@objc class AppDelegate: FlutterAppDelegate {
    private var pipController: AVPictureInPictureController?
    private var pipPlayer: AVPlayer?
    private var pipChannel: FlutterMethodChannel?
    private var playerViewController: AVPlayerViewController?
    
    override func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        // Configure audio session for background playback
        configureAudioSession()
        
        let controller = window?.rootViewController as! FlutterViewController
        
        // Register method channels
        setupThumbnailChannel(controller: controller)
        setupPipChannel(controller: controller)
       
        GeneratedPluginRegistrant.register(with: self)
        return super.application(application, didFinishLaunchingWithOptions: launchOptions)
    }
    
func enablePiP() {
  let pipController = AVPictureInPictureController(playerLayer: playerLayer)
  pipController?.startPictureInPicture()
}
    // Add to AppDelegate
@objc func isPipSupported(call: FlutterMethodCall, result: @escaping FlutterResult) {
    result(AVPictureInPictureController.isPictureInPictureSupported())
}
    
    private func configureAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .moviePlayback)
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("Audio session configuration failed: \(error.localizedDescription)")
        }
    }
    
    private func setupThumbnailChannel(controller: FlutterViewController) {
        let thumbnailChannel = FlutterMethodChannel(
            name: "native_thumbnail",
            binaryMessenger: controller.binaryMessenger
        )
        
        thumbnailChannel.setMethodCallHandler { [weak self] (call, result) in
            guard call.method == "generateThumbnail" else {
                result(FlutterMethodNotImplemented)
                return
            }
            
            guard let args = call.arguments as? [String: Any],
                  let videoPath = args["videoPath"] as? String,
                  let thumbnailPath = args["thumbnailPath"] as? String,
                  let maxWidth = args["maxWidth"] as? Int,
                  let quality = args["quality"] as? Int else {
                result(FlutterError(code: "INVALID_ARGS", message: "Invalid arguments", details: nil))
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
                if let args = call.arguments as? [String: Any],
                   let path = args["path"] as? String,
                   let position = args["position"] as? Double {
                    self?.handleStartPip(
                        filePath: path,
                        position: position,
                        result: result
                    )
                } else {
                    result(FlutterError(code: "INVALID_ARGS", message: "Invalid arguments", details: nil))
                }
            case "stopPip":
                self?.handleStopPip(result: result)
            case "isPipSupported":
                result(AVPictureInPictureController.isPictureInPictureSupported())
            default:
                result(FlutterMethodNotImplemented)
            }
        }
    }
   private func handleStartPip(filePath: String, position: Double, result: @escaping FlutterResult) {
    cleanupPiPResources()
    
    let url = URL(fileURLWithPath: filePath)
    pipPlayer = AVPlayer(url: url)
    
    // Configure audio session for background playback
    do {
        try AVAudioSession.sharedInstance().setCategory(.playback, 
                                                      mode: .moviePlayback,
                                                      options: [.allowAirPlay, .allowBluetooth])
        try AVAudioSession.sharedInstance().setActive(true)
    } catch {
        print("Failed to set up audio session: \(error)")
    }
    
    // Seek to position if provided
    if position > 0 {
        let cmTime = CMTime(seconds: position / 1000.0, preferredTimescale: 1000)
        pipPlayer?.seek(to: cmTime)
    }
    
    // Create Player View Controller
    playerViewController = AVPlayerViewController()
    playerViewController?.player = pipPlayer
    playerViewController?.allowsPictureInPicturePlayback = true
    playerViewController?.showsPlaybackControls = true
    
    // Add to view hierarchy
    if let rootVC = window?.rootViewController {
        rootVC.addChild(playerViewController!)
        rootVC.view.addSubview(playerViewController!.view)
        
        // Position the player in a corner of the screen (similar to Android PiP)
        let screenBounds = UIScreen.main.bounds
        let pipWidth = screenBounds.width * 0.3 // 30% of screen width
        let pipHeight = pipWidth * 9/16 // 16:9 aspect ratio
        
        // Position in bottom-right corner
        playerViewController!.view.frame = CGRect(
            x: screenBounds.width - pipWidth - 16, // 16px from right edge
            y: screenBounds.height - pipHeight - 16, // 16px from bottom edge
            width: pipWidth,
            height: pipHeight
        )
        
        // Make the player view look like PiP with rounded corners and shadow
        playerViewController!.view.layer.cornerRadius = 8
        playerViewController!.view.layer.masksToBounds = true
        playerViewController!.view.clipsToBounds = true
        
        // Add shadow to container view to make it look like floating
        let containerView = UIView(frame: playerViewController!.view.frame)
        rootVC.view.insertSubview(containerView, belowSubview: playerViewController!.view)
        containerView.layer.shadowColor = UIColor.black.cgColor
        containerView.layer.shadowOffset = CGSize(width: 0, height: 4)
        containerView.layer.shadowOpacity = 0.3
        containerView.layer.shadowRadius = 8
        
        playerViewController!.didMove(toParent: rootVC)
    }
    
    // Get player layer
    guard let playerLayer = playerViewController?.playerView?.layer as? AVPlayerLayer else {
        result(FlutterError(code: "PIP_INIT_FAILED", message: "Failed to get player layer", details: nil))
        return
    }
    
    // Start playback
    pipPlayer?.play()
    
    // Now we'll handle the actual iOS PiP differently
    // We'll use it when the app goes to background but use our custom PiP in foreground
    pipController = AVPictureInPictureController(playerLayer: playerLayer)
    pipController?.delegate = self
    
    // Add observers for application state changes
    NotificationCenter.default.addObserver(
        self,
        selector: #selector(applicationDidEnterBackground),
        name: UIApplication.didEnterBackgroundNotification,
        object: nil
    )
    
    NotificationCenter.default.addObserver(
        self,
        selector: #selector(applicationWillEnterForeground),
        name: UIApplication.willEnterForegroundNotification,
        object: nil
    )
    
    // Signal success
    result(nil)
}
@objc func applicationWillEnterForeground() {
    // When coming back to foreground, stop system PiP and use our custom PiP
    if pipController?.isPictureInPictureActive == true {
        pipController?.stopPictureInPicture()
    }
    
    // Make sure our custom PiP is visible
    if let rootVC = window?.rootViewController {
        let screenBounds = UIScreen.main.bounds
        let pipWidth = screenBounds.width * 0.3
        let pipHeight = pipWidth * 9/16
        
        playerViewController?.view.frame = CGRect(
            x: screenBounds.width - pipWidth - 16,
            y: screenBounds.height - pipHeight - 16,
            width: pipWidth,
            height: pipHeight
        )
    }
}
@objc func applicationDidEnterBackground() {
    // Ensure PiP is active when app goes to background
    if pipPlayer != nil && pipController != nil && !pipController!.isPictureInPictureActive {
        pipController?.startPictureInPicture()
    }
    
    // Request additional background execution time if needed
    var backgroundTaskID: UIBackgroundTaskIdentifier = .invalid
    backgroundTaskID = UIApplication.shared.beginBackgroundTask {
        UIApplication.shared.endBackgroundTask(backgroundTaskID)
        backgroundTaskID = .invalid
    }
}

@objc func applicationWillTerminate() {
    // This will be called when the app is about to terminate
    // We want to make sure PiP continues even after app termination
    if pipPlayer != nil && pipController != nil {
        // Make sure PiP is active
        if !pipController!.isPictureInPictureActive {
            pipController?.startPictureInPicture()
        }
    }
}

@objc func playerItemDidReachEnd(notification: Notification) {
    // Loop video if desired, or handle end of playback
    if let playerItem = notification.object as? AVPlayerItem {
        playerItem.seek(to: .zero, completionHandler: nil)
        pipPlayer?.play()
    }
}
    private func handleDisablePip(result: @escaping FlutterResult) {
        pipController?.stopPictureInPicture()
        cleanupPiPResources()
        result(nil)
    }
     private func handleStopPip(result: @escaping FlutterResult) {
        pipController?.stopPictureInPicture()
        cleanupPiPResources()
        result(nil)
    }
    
     private func cleanupPiPResources() {
    // Remove all observers
    NotificationCenter.default.removeObserver(self, name: UIApplication.didEnterBackgroundNotification, object: nil)
    NotificationCenter.default.removeObserver(self, name: UIApplication.willTerminateNotification, object: nil)
    NotificationCenter.default.removeObserver(self, name: .AVPlayerItemDidPlayToEndTime, object: pipPlayer?.currentItem)
    
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
    
    private func generateThumbnail(videoPath: String, thumbnailPath: String, maxWidth: Int, quality: Int, result: @escaping FlutterResult) {
        let url = URL(fileURLWithPath: videoPath)
        let asset = AVAsset(url: url)
        let imageGenerator = AVAssetImageGenerator(asset: asset)
        imageGenerator.appliesPreferredTrackTransform = true
        imageGenerator.maximumSize = CGSize(width: maxWidth, height: maxWidth)
        
        let time = CMTime(seconds: asset.duration.seconds / 2, preferredTimescale: 600)
        
        do {
            let cgImage = try imageGenerator.copyCGImage(at: time, actualTime: nil)
            let uiImage = UIImage(cgImage: cgImage)
            
            if let data = uiImage.jpegData(compressionQuality: CGFloat(quality)/100.0) {
                try data.write(to: URL(fileURLWithPath: thumbnailPath))
                result(thumbnailPath)
            } else {
                result(FlutterError(code: "IMAGE_ERROR", message: "Failed to create JPEG data", details: nil))
            }
        } catch {
            result(FlutterError(code: "THUMBNAIL_ERROR", message: error.localizedDescription, details: nil))
        }
    }
    private func setupDraggablePlayerView() {
    guard let playerView = playerViewController?.view else { return }
    
    // Add pan gesture recognizer
    let panGesture = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
    playerView.addGestureRecognizer(panGesture)
    playerView.isUserInteractionEnabled = true
}

@objc private func handlePan(_ gesture: UIPanGestureRecognizer) {
    guard let playerView = gesture.view else { return }
    let translation = gesture.translation(in: window?.rootViewController?.view)
    
    if gesture.state == .changed {
        playerView.center = CGPoint(
            x: playerView.center.x + translation.x,
            y: playerView.center.y + translation.y
        )
        gesture.setTranslation(.zero, in: window?.rootViewController?.view)
    }
    
    if gesture.state == .ended {
        // Snap to edges
        if let parentView = window?.rootViewController?.view {
            let screenBounds = parentView.bounds
            let pipWidth = playerView.frame.width
            let pipHeight = playerView.frame.height
            
            var newFrame = playerView.frame
            
            // Snap to closest edge
            if playerView.center.x < screenBounds.width / 2 {
                // Left side
                newFrame.origin.x = 16
            } else {
                // Right side
                newFrame.origin.x = screenBounds.width - pipWidth - 16
            }
            
            // Ensure it stays within vertical bounds
            newFrame.origin.y = max(16, min(screenBounds.height - pipHeight - 16, newFrame.origin.y))
            
            UIView.animate(withDuration: 0.3) {
                playerView.frame = newFrame
            }
        }
    }
}
    
    
   

    // MARK: - Orientation handling
    override func application(
        _ application: UIApplication,
        supportedInterfaceOrientationsFor window: UIWindow?
    ) -> UIInterfaceOrientationMask {
        return .allButUpsideDown
    }
}
extension AVPlayerViewController {
    var playerView: UIView? {
        return self.view.subviews.first(where: { $0.layer is AVPlayerLayer })
    }
}


// MARK: - PiP Controller Delegate
extension AppDelegate: AVPictureInPictureControllerDelegate {
    func pictureInPictureControllerDidStartPictureInPicture(_ pictureInPictureController: AVPictureInPictureController) {
        pipChannel?.invokeMethod("onPiPStarted", arguments: nil)
        // Remove view hiding logic
    }
    
    func pictureInPictureControllerDidStopPictureInPicture(_ pictureInPictureController: AVPictureInPictureController) {
        pipChannel?.invokeMethod("onPiPStopped", arguments: nil)
         if UIApplication.shared.applicationState == .active {
        if let rootVC = window?.rootViewController {
            let screenBounds = UIScreen.main.bounds
            let pipWidth = screenBounds.width * 0.3
            let pipHeight = pipWidth * 9/16
            
            playerViewController?.view.frame = CGRect(
                x: screenBounds.width - pipWidth - 16,
                y: screenBounds.height - pipHeight - 16,
                width: pipWidth,
                height: pipHeight
            )
        }
    }
        cleanupPiPResources()
    }
    
    func pictureInPictureController(_ pictureInPictureController: AVPictureInPictureController, failedToStartPictureInPictureWithError error: Error) {
        pipChannel?.invokeMethod("onPiPError", arguments: error.localizedDescription)
        cleanupPiPResources()
    }
    func pictureInPictureController(_ pictureInPictureController: AVPictureInPictureController, restoreUserInterfaceForPictureInPictureStopWithCompletionHandler completionHandler: @escaping (Bool) -> Void) {
        // Handle full-screen restore
        pipChannel?.invokeMethod("onRestoreFullScreen", arguments: nil)
        // If app was terminated and relaunched through PiP interface tap, 
    // we need to handle restoration properly
    if let rootVC = window?.rootViewController {
        // Bring the player view back into visible area
        let screenBounds = UIScreen.main.bounds
        playerViewController?.view.frame = screenBounds
    }
        completionHandler(true)
    }
    
    
   
}