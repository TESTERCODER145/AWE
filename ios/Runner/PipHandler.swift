import Flutter
import AVKit
import AVFoundation

public class PipHandler: NSObject, AVPictureInPictureControllerDelegate {
    private var pipController: AVPictureInPictureController?
    private var player: AVPlayer?
    private var eventSink: FlutterEventSink?
    
    public static func register(with registrar: FlutterPluginRegistrar) {
        let methodChannel = FlutterMethodChannel(name: "pip_channel", 
                                               binaryMessenger: registrar.messenger())
        let eventChannel = FlutterEventChannel(name: "pip_events",
                                             binaryMessenger: registrar.messenger())
        let instance = PipHandler()
        
        registrar.addMethodCallDelegate(instance, channel: methodChannel)
        eventChannel.setStreamHandler(instance)
    }
    
    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "startPip":
            guard let args = call.arguments as? [String: Any],
                  let path = args["path"] as? String,
                  let position = args["position"] as? Double else {
                result(FlutterError(code: "INVALID_ARG", 
                                   message: "Missing path or position", 
                                   details: nil))
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
        stopPip(result: nil)
        
        guard let url = URL(string: path) else {
            result(FlutterError(code: "INVALID_PATH", 
                              message: "Invalid video path", 
                              details: nil))
            return
        }
        
        player = AVPlayer(url: url)
        player?.seek(to: CMTime(seconds: position / 1000, 
                              preferredTimescale: CMTimeScale(NSEC_PER_SEC)))
        
        guard let playerLayer = AVPlayerLayer(player: player),
              let pipController = AVPictureInPictureController(playerLayer: playerLayer) 
        else {
            result(FlutterError(code: "PIP_UNAVAILABLE", 
                              message: "PiP not supported", 
                              details: nil))
            return
        }
        
        self.pipController = pipController
        pipController.delegate = self
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
        eventSink?("started")
    }
    
    public func pictureInPictureControllerDidStopPictureInPicture(_ controller: AVPictureInPictureController) {
        eventSink?("stopped")
    }
}

extension PipHandler: FlutterStreamHandler {
    public func onListen(withArguments arguments: Any?, 
                       eventSink: @escaping FlutterEventSink) -> FlutterError? {
        self.eventSink = eventSink
        return nil
    }
    
    public func onCancel(withArguments arguments: Any?) -> FlutterError? {
        eventSink = nil
        return nil
    }
}