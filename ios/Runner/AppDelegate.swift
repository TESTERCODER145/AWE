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
    
    // MARK: - PiP Functionality
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
        
        guard let pipController = pipController, pipController.isPictureInPicturePossible else {
            result(FlutterError(code: "PIP_ERROR", message: "PiP not supported or possible", details: nil))
            cleanupPiPResources()
            return
        }
        
        pipController.startPictureInPicture()
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
        configureAudioSession()
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
                result(AVPictureInPictureController.isPictureInPictureSupported())
            default:
                result(FlutterMethodNotImplemented)
            }
        }
    }
    
    // MARK: - PiP Helper Methods
    private func setupPlayerViewController() {
        playerViewController = AVPlayerViewController()
        playerViewController?.player = pipPlayer
        playerViewController?.allowsPictureInPicturePlayback = true
        playerViewController?.showsPlaybackControls = false

        playerViewController?.view.frame = UIScreen.main.bounds
        window?.rootViewController?.view.addSubview(playerViewController!.view)
        window?.rootViewController?.addChild(playerViewController!)
        playerViewController?.didMove(toParent: window?.rootViewController)
    }
    
    private func cleanupPiPResources() {
        pipPlayer?.pause()
        pipPlayer = nil
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
    }
    
    @objc private func handleForegroundTransition() {
        if pipController?.isPictureInPictureActive == true {
            pipController?.stopPictureInPicture()
        }
    }
}
