import Cocoa
import FlutterMacOS

public class ShadowNotificationPlugin: NSObject, FlutterPlugin {
    private static var methodChannel: FlutterMethodChannel?
    
    public static var shadowIconImage: NSImage?
    
    override init() {
        super.init()
        print("Shadow Notification Plugin: init() - \(Date())")
        print("Shadow Notification Plugin: 메모리 주소 - \(Unmanaged.passUnretained(self).toOpaque())")
    }
    
    deinit {
        print("Shadow Notification Plugin: deinit() - \(Date())")
    }
    
    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: "shadow_notification", binaryMessenger: registrar.messenger)
        methodChannel = channel
        let instance = ShadowNotificationPlugin()
        
        ShadowNotiLogger.configure(
            subsystem: "com.taperlabs.shadow",
            category: "ShadowNoti",
            retentionDays: 3,
            minimumLogLevel: .info
        )
        registrar.addMethodCallDelegate(instance, channel: channel)
        loadShadowIcon(registrar: registrar)
    }
    
    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        print("NotiPlugin: handle() 호출됨 - 메서드: \(call.method)")
        switch call.method {
        case "showEnabledNotification":
            Task { @MainActor in
                NotiWindowManager.shared.showEnabledNoti()
                result(nil)
            }
        case "showAskNotification":
            Task { @MainActor in
                NotiWindowManager.shared.showAskNoti()
                result(nil)
            }
        case "showAutoWindowFailedNotification":
            Task { @MainActor in
                NotiWindowManager.shared.showAutoWindowFailedNoti()
                result(nil)
            }
        case "showMeetingWindowNotFoundNotification":
            Task { @MainActor in
                NotiWindowManager.shared.showMeetingWindowNotFoundNoti()
                result(nil)
            }
        case "getPlatformVersion":
            result("macOS " + ProcessInfo.processInfo.operatingSystemVersionString)
        default:
            result(FlutterMethodNotImplemented)
        }
    }
    
    private static func loadShadowIcon(registrar: FlutterPluginRegistrar) {
        let assetPath = "assets/images/icons/shadow_brand.svg"
        let assetKey = registrar.lookupKey(forAsset: assetPath)
        // 앱 번들의 기본 경로와 assetKey를 직접 조합하여 전체 파일 경로를 생성
        let bundlePath = Bundle.main.bundlePath
        let filePath = (bundlePath as NSString).appendingPathComponent(assetKey)
        
        // 파일이 실제로 존재하는지 확인
        guard FileManager.default.fileExists(atPath: filePath) else {
            print("❌ ERROR: File does not exist at constructed path: \(filePath)")
            ShadowNotiLogger.shared.error("❌ ERROR: File does not exist at constructed path: \(filePath)")
            return
        }
        
        do {
            // 이제 이 filePath를 사용해 데이터를 읽기
            let fileUrl = URL(fileURLWithPath: filePath)
            let data = try Data(contentsOf: fileUrl)
            self.shadowIconImage = NSImage(data: data)
            print("✅ SVG icon 'shadow.svg' loaded as NSImage.")
            ShadowNotiLogger.shared.info("✅ Autopilit Notification SVG Icon loaded successfully")
        } catch {
            ShadowNotiLogger.shared.error("❌ ERROR: Failed to create NSImage from SVG asset: \(error)")
            print("❌ ERROR: Failed to create NSImage from SVG asset: \(error)")
        }
    }
}


extension ShadowNotificationPlugin {
    // Swift → Flutter 호출을 위한 헬퍼 메서드
    static func sendToFlutter(_ method: ListenAction, data: Any? = nil) {
        methodChannel?.invokeMethod(method.rawValue, arguments: data)
    }
}
