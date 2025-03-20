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
     override func registerPlugin(_ registry: FlutterPluginRegistry) {
        GeneratedPluginRegistrant.register(with: registry)
    }
    
    // MARK: - Application Lifecycle
    override func applicationDidEnterBackground(_ application: UIApplication) {
        handleBackgroundTransition()
    }
    
    override func applicationWillEnterForeground(_ application: UIApplication) {
        handleForegroundTransition()
    }
    
    override func applicationWillTerminate(_ application: UIApplication) {
        handleAppTermination()
    }
    
    // MARK: - PIP Functionality
    private func handleStartPip(filePath: String, position: Double, result: @escaping FlutterResult) {
        cleanupPiPResources()
        
        let url = URL(fileURLWithPath: filePath)
        pipPlayer = AVPlayer(url: url)
        
        configureAudioSessionForPlayback()
        
        if position > 0 {
            let cmTime = CMTime(seconds: position / 1000.0, preferredTimescale: 1000)
            pipPlayer?.seek(to: cmTime)
        }
        
        setupPlayerViewController()
        setupPictureInPicture()
        
        pipPlayer?.play()
        result(nil)
    }
    
    private func handleStopPip(result: @escaping FlutterResult) {
        pipController?.stopPictureInPicture()
        cleanupPiPResources()
        result(nil)
    }
    
    // MARK: - Thumbnail Generation
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
    
    // MARK: - PIP Helper Methods
    private func setupPlayerViewController() {
        playerViewController = AVPlayerViewController()
        playerViewController?.player = pipPlayer
        playerViewController?.allowsPictureInPicturePlayback = true
        playerViewController?.showsPlaybackControls = true
        
        if let rootVC = window?.rootViewController {
            rootVC.addChild(playerViewController!)
            rootVC.view.addSubview(playerViewController!.view)
            
            let screenBounds = UIScreen.main.bounds
            let pipWidth = screenBounds.width * 0.3
            let pipHeight = pipWidth * 9/16
            
            playerViewController!.view.frame = CGRect(
                x: screenBounds.width - pipWidth - 16,
                y: screenBounds.height - pipHeight - 16,
                width: pipWidth,
                height: pipHeight
            )
            
            playerViewController!.view.layer.cornerRadius = 8
            playerViewController!.view.layer.masksToBounds = true
            
            let containerView = UIView(frame: playerViewController!.view.frame)
            rootVC.view.insertSubview(containerView, belowSubview: playerViewController!.view)
            containerView.layer.shadowColor = UIColor.black.cgColor
            containerView.layer.shadowOffset = CGSize(width: 0, height: 4)
            containerView.layer.shadowOpacity = 0.3
            containerView.layer.shadowRadius = 8
            
            playerViewController!.didMove(toParent: rootVC)
        }
    }
    
    private func setupPictureInPicture() {
        guard let playerLayer = playerViewController?.playerView?.layer as? AVPlayerLayer else { return }
        
        pipController = AVPictureInPictureController(playerLayer: playerLayer)
        pipController?.delegate = self
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleBackgroundTransition),
            name: UIApplication.didEnterBackgroundNotification,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleForegroundTransition),
            name: UIApplication.willEnterForegroundNotification,
            object: nil
        )
    }
    
    private func cleanupPiPResources() {
        NotificationCenter.default.removeObserver(self, name: UIApplication.didEnterBackgroundNotification, object: nil)
        NotificationCenter.default.removeObserver(self, name: UIApplication.willEnterForegroundNotification, object: nil)
        
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
        pipChannel?.invokeMethod("onRestoreFullScreen", arguments: nil)
        if let rootVC = window?.rootViewController {
            playerViewController?.view.frame = UIScreen.main.bounds
        }
        completionHandler(true)
    }
}

extension AVPlayerViewController {
    var playerView: UIView? {
        return self.view.subviews.first(where: { $0.layer is AVPlayerLayer })
    }
}