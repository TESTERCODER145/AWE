import Flutter
import AVKit
import AVFoundation

public class PipHandler: NSObject, AVPictureInPictureControllerDelegate {
    private var pipController: AVPictureInPictureController?
    private var player: AVPlayer?
    private var channel: FlutterMethodChannel?
    
    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: "pip_channel", binaryMessenger: registrar.messenger())
        let instance = PipHandler()
        instance.channel = channel
        registrar.addMethodCallDelegate(instance, channel: channel)
    }
    
    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "startPip":
            guard let args = call.arguments as? [String: Any],
                  let path = args["path"] as? String,
                  let position = args["position"] as? Double else {
                result(FlutterError(code: "INVALID_ARG", message: "Invalid arguments", details: nil))
                return
            }
            startPip(path: path, position: position, result: result)
            
        case "stopPip":
            stopPip(result: result)
            
        case "isPipSupported":
            result(AVPictureInPictureController.isPictureInPictureSupported())
            
        default:
            result(FlutterMethodNotImplemented)
        }
    }
    
    private func startPip(path: String, position: Double, result: @escaping FlutterResult) {
        // Clean up previous resources
        stopPip(result: nil)
        
        // Create new player
        let player = AVPlayer(url: URL(fileURLWithPath: path))
        player.seek(to: CMTime(seconds: position / 1000, preferredTimescale: 1000))
        
        // Setup player layer
        let playerLayer = AVPlayerLayer(player: player)
        playerLayer.frame = UIScreen.main.bounds
        
        // Configure PiP controller
        guard let pipController = AVPictureInPictureController(playerLayer: playerLayer) else {
            result(FlutterError(code: "PIP_UNAVAIL", message: "PiP not available", details: nil))
            return
        }
        
        self.pipController = pipController
        self.player = player
        pipController.delegate = self
        
        // Start PiP
        pipController.startPictureInPicture()
        result(true)
    }
    
    private func stopPip(result: FlutterResult?) {
        player?.pause()
        player = nil
        pipController?.stopPictureInPicture()
        pipController = nil
        result?(true)
    }
    
    // MARK: - AVPictureInPictureControllerDelegate
    public func pictureInPictureControllerDidStartPictureInPicture(_ controller: AVPictureInPictureController) {
        channel?.invokeMethod("onPiPStarted", arguments: nil)
    }
    
    public func pictureInPictureControllerDidStopPictureInPicture(_ controller: AVPictureInPictureController) {
        channel?.invokeMethod("onPiPStopped", arguments: nil)
    }
}