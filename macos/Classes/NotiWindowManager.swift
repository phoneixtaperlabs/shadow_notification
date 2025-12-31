import Foundation
import CoreGraphics
import SwiftUI

// MARK: - Animation Types
enum WindowAnimationType {
    case slideInFromRight
    case slideInFromTop
    case fadeIn
    case none
    
    var duration: TimeInterval {
        switch self {
        case .slideInFromRight, .slideInFromTop: return 0.3
        case .fadeIn: return 0.25
        case .none: return 0
        }
    }
}

// MARK: - Window Animator Protocol
protocol WindowAnimatable {
    func showWithAnimation(_ type: WindowAnimationType, to targetFrame: NSRect)
    func hideWithAnimation(_ type: WindowAnimationType, completion: (() -> Void)?)
}

enum NotiType {
    case enabled // 'Cancel' 버튼이 있는 경우
    case ask     // 'Listen' 버튼이 있는 경우
    
    // 타입에 따라 다른 부제목을 반환
    var baseSubtitle: String {
        switch self {
        case .enabled:
            return "I'll start listening in "
        case .ask:
            return "Automatically dismissing in "
        }
    }
    
    // 타입에 따라 다른 버튼 텍스트를 반환
    var buttonText: String {
        switch self {
        case .enabled:
            return "Cancel"
        case .ask:
            return "Listen"
        }
    }
    
    var duration: TimeInterval {
        switch self {
        case .enabled:
            return 3.0 // enabled 타입은 3초
        case .ask:
            return 10.0 // ask 타입은 5초
        }
    }
}

// Flutter에 어떤 행동을 할지 알려주는 Enum
enum ListenAction: String {
    case startListen // "Listen을 시작해라"
    case dismissListen  // "Listen을 중지/취소해라"
}

// 해당 액션이 왜 발생했는지 원인을 알려주는 Enum
enum ActionTrigger: String {
    case userAction // 사용자가 직접 버튼을 눌렀음
    case timeout    // 아무것도 안 해서 창이 시간 초과로 닫혔음
}

struct ListenStatePayload {
    let action: ListenAction
    let trigger: ActionTrigger
    
    // MethodChannel로 전송하기 위해 Dictionary로 변환하는 함수
    func toDictionary() -> [String: String] {
        return [
            "action": self.action.rawValue,   // "startListen" 또는 "stopListen"
            "trigger": self.trigger.rawValue // "userAction" 또는 "timeout"
        ]
    }
}

// Inactive 노티피케이션 액션
enum InactiveAction: String {
    case inactiveCancelled  // 사용자가 Cancel 버튼 클릭
    case inactiveTimeout    // timeout으로 종료
}

struct InactiveStatePayload {
    let action: InactiveAction
    let trigger: ActionTrigger
    
    func toDictionary() -> [String: String] {
        return [
            "action": self.action.rawValue,
            "trigger": self.trigger.rawValue
        ]
    }
}

@MainActor
final class NotiWindowManager {
    static let shared = NotiWindowManager()
    
    // MARK: - Multi-notification Stack Support
    private var notiWindowControllers: [UUID: NotiWindowController] = [:]
    private var notiOrder: [UUID] = []  // 스택 순서 (인덱스 0 = 맨 위)
    
    // 설정 상수
    private let maxVisibleNotifications: Int = 5
    private let verticalSpacing: CGFloat = 10
    private let topMargin: CGFloat = 20
    private let rightMargin: CGFloat = 10
    
    private var targetWindowTimer: Timer?
    private var logger: ShadowNotiLogger?
    
    private init() {
        self.logger = ShadowNotiLogger.shared
        self.logger?.info("NotiWindowManager initialized")
    }
    
    deinit {
        Task { [logger = self.logger] in
            // 이제 클로저는 self.logger가 아닌 캡처된 'logger' 변수를 사용합니다.
            // deinit이 끝나도 logger 인스턴스는 유효하므로 안전합니다.
            logger?.info("NotiWindowManager deinit")
        }
        print("NotiWindowManager deinit")
    }
    
    // MARK: - Position Calculation
    
    /// 스택에서 해당 인덱스의 노티피케이션 위치를 계산합니다.
    /// - Parameters:
    ///   - index: 스택에서의 인덱스 (0 = 맨 위)
    ///   - width: 노티피케이션 윈도우 너비
    ///   - height: 노티피케이션 윈도우 높이
    /// - Returns: 계산된 윈도우 프레임
    private func calculateNotificationFrame(at index: Int, width: CGFloat, height: CGFloat) -> NSRect {
        guard let screen = NSScreen.main else { return .zero }
        let screenFrame = screen.visibleFrame
        
        let xPos = screenFrame.maxX - width - rightMargin
        
        // 기존 노티들의 높이를 누적하여 y 위치 계산
        var yOffset: CGFloat = topMargin
        for i in 0..<index {
            guard i < notiOrder.count else { break }
            let id = notiOrder[i]
            if let controller = notiWindowControllers[id],
               let window = controller.window {
                yOffset += window.frame.height + verticalSpacing
            }
        }
        
        let yPos = screenFrame.maxY - height - yOffset
        return NSRect(x: xPos, y: yPos, width: width, height: height)
    }
    
    /// 모든 기존 노티피케이션의 위치를 재조정합니다.
    private func repositionExistingNotifications() {
        for (index, id) in notiOrder.enumerated() {
            guard let controller = notiWindowControllers[id],
                  let window = controller.window else { continue }
            
            let newFrame = calculateNotificationFrame(
                at: index,
                width: window.frame.width,
                height: window.frame.height
            )
            
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.25
                context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                window.animator().setFrame(newFrame, display: true)
            }
        }
    }
    
    /// 최대 개수 초과 시 가장 오래된 노티를 제거합니다.
    private func removeOldestNotificationIfNeeded() {
        while notiWindowControllers.count >= maxVisibleNotifications {
            guard let oldestId = notiOrder.last else { break }
            logger?.info("Removing oldest notification: \(oldestId)")
            if let controller = notiWindowControllers[oldestId] {
                controller.closeWindowSilently()
            }
            notiWindowControllers.removeValue(forKey: oldestId)
            notiOrder.removeAll { $0 == oldestId }
        }
    }
    
    func showNotification(
        title: String,
        subtitle: String,
        secondarySubtitle: String? = nil,
        duration: TimeInterval,
        actionButton: (text: String, action: () -> Void)? = nil,
        onTimeout: (() -> Void)? = nil,
        width: CGFloat = 360,
        height: CGFloat = 75,
        showCountdown: Bool = false,
        separatorHeight: CGFloat? = nil,
        animation: WindowAnimationType = .slideInFromRight
    ) {
        // 최대 개수 초과 시 오래된 노티 제거
        removeOldestNotificationIfNeeded()
        
        // 새 노티 ID 생성
        let notiId = UUID()
        
        // 새 노티는 맨 위(인덱스 0) 위치에 표시 - 기존 노티들이 한 칸씩 내려갈 것을 고려
        let targetFrame = calculateNotificationFrame(at: 0, width: width, height: height)
        
        let customNotiWindow = NSPanel(
            contentRect: targetFrame,
            styleMask: [.borderless, .fullSizeContentView, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        
        configureNotiWindow(customNotiWindow)
        
        // Create controller FIRST (like showNotiWindow does)
        let controller = NotiWindowController(
            notificationId: notiId,
            notiWindow: customNotiWindow,
            type: .ask,
            onClose: { [weak self] closedId, _, wasActionTaken in
                if !wasActionTaken, let timeoutHandler = onTimeout {
                    timeoutHandler()
                }
                self?.handleNotificationClosed(id: closedId)
            }
        )
        notiWindowControllers[notiId] = controller
        
        // 새 노티를 notiOrder에 추가하고 기존 노티들을 아래로 이동
        notiOrder.insert(notiId, at: 0)
        repositionExistingNotifications()
        
        // Create config
        let config: NotificationView.Config
        if let button = actionButton {
            // 버튼 액션을 래핑하여 setActionTaken과 closeWindow를 자동 처리
            let wrappedButtonAction: () -> Void = { [weak self, weak controller] in
                button.action()
                controller?.setActionTaken()
                controller?.closeWindow()
            }
            config = .withButton(
                title: title,
                subtitle: subtitle,
                secondarySubtitle: secondarySubtitle,
                duration: duration,
                buttonText: button.text,
                buttonAction: wrappedButtonAction,
                showCountdown: showCountdown,
                separatorHeight: separatorHeight
            )
        } else {
            config = .withoutButton(
                title: title,
                subtitle: subtitle,
                secondarySubtitle: secondarySubtitle,
                duration: duration,
                showCountdown: showCountdown,
                separatorHeight: separatorHeight
            )
        }
        
        // THEN create view (like showNotiWindow does)
        let contentView = NotificationView(
            config: config,
            onCancel: { [weak self] in
                self?.cleanupNotification(id: notiId)
            }
        )
        
        let hostingView = NSHostingView(rootView: contentView)
        customNotiWindow.contentView = hostingView
        
        controller.setupAutoClose(after: duration)
        
        customNotiWindow.showWithAnimation(animation, to: targetFrame)
    }
    
    // MARK: - Convenience Notification Methods
    
    func showAskNoti(duration: TimeInterval = 10.0) {
        showNotification(
            title: "Meeting Detected",
            subtitle: "I'll start listening in",
            duration: duration,
            actionButton: ("Listen", {
                print("Listen Clicked")
                let payload = ListenStatePayload(action: .startListen, trigger: .userAction)
                ShadowNotificationPlugin.sendToFlutter(.startListen, data: payload.toDictionary())
                // 버튼 클릭 시 setActionTaken과 closeWindow는 showNotification 내부에서 처리됨
            }),
            onTimeout: {
                print("Default action for .ask: Dismissing without action.")
                let payload = ListenStatePayload(action: .dismissListen, trigger: .timeout)
                ShadowNotificationPlugin.sendToFlutter(.dismissListen, data: payload.toDictionary())
            },
            showCountdown: true
        )
    }
    
    func showEnabledNoti(duration: TimeInterval = 3.0) {
        showNotification(
            title: "Meeting Detected",
            subtitle: "I'll start listening in",
            duration: duration,
            actionButton: ("Cancel", {
                print("Cancel Clicked")
                let payload = ListenStatePayload(action: .dismissListen, trigger: .userAction)
                ShadowNotificationPlugin.sendToFlutter(.dismissListen, data: payload.toDictionary())
                // 버튼 클릭 시 setActionTaken과 closeWindow는 showNotification 내부에서 처리됨
            }),
            onTimeout: {
                print("Default action for .enabled: Proceeding to listen.")
                let payload = ListenStatePayload(action: .startListen, trigger: .timeout)
                ShadowNotificationPlugin.sendToFlutter(.startListen, data: payload.toDictionary())
            },
            showCountdown: true
        )
    }
    
    func showGoogleMeetWindowFailedNoti(duration: TimeInterval = 10.0) {
        let subtitle = "I can't capture screenshots while you're on a different tab.\nDon't worry—I'll start again when you come back!"
        
        showNotification(
            title: "Heads up: Screenshots paused",
            subtitle: subtitle,
            secondarySubtitle: "* This message is not visible to others.",
            duration: duration,
            actionButton: nil,
            width: 450,
            height: 130
        )
    }
    
    func showAutoWindowFailedNoti(duration: TimeInterval = 10.0) {
        showNotification(
            title: "Heads up: Screenshots paused",
            subtitle: "I couldn't auto-select the meeting window.",
            secondarySubtitle: "* This message is not visible to others.",
            duration: duration,
            actionButton: nil,
            width: 390,
            height: 110
        )
    }
    
    func showMeetingWindowNotFoundNoti(duration: TimeInterval = 10.0) {
//                let subtitle = "The meeting window isn't visible.\nThey'll resume automatically when it's back, \nor you can select a window manually."
        let subtitle = "The meeting window isn’t visible. I’ll resume\n when it’s back, or you can select one now."
        
        showNotification(
            title: "Heads up: Screenshots paused",
            subtitle: subtitle,
            secondarySubtitle: "* This message is not visible to others.",
            duration: duration,
            actionButton: nil,
            width: 450,
            height: 130
        )
    }
    
    func showUpcomingEventNoti(params: [String: Any]?) {
        let title = params?["title"] as? String ?? "Upcoming Event"
        let subtitle = params?["subtitle"] as? String ?? ""
        let hasListenButton = params?["hasListenButton"] as? Bool ?? false
        let duration = params?["duration"] as? Double ?? 10.0
        
        if hasListenButton {
            showNotification(
                title: title,
                subtitle: subtitle,
                duration: duration,
                actionButton: ("Join", {
                    print("Listen Clicked from UpcomingEvent")
                    let payload = ListenStatePayload(action: .startListen, trigger: .userAction)
                    ShadowNotificationPlugin.sendToFlutter(.startListen, data: payload.toDictionary())
                }),
                onTimeout: nil,
                showCountdown: false
            )
        } else {
            showNotification(
                title: title,
                subtitle: subtitle,
                duration: duration,
                actionButton: nil,
                onTimeout: nil,
                showCountdown: false
            )
        }
    }
    
    func showInactiveNoti(params: [String: Any]?) {
        let title = params?["title"] as? String ?? "Still in a meeting?"
        let subtitle = params?["subtitle"] as? String ?? ""
        let hasButton = params?["hasButton"] as? Bool ?? false
        let duration = params?["duration"] as? Double ?? 10.0
        
        let subtitleWithButton =
        "I haven't heard anything for 10 minutes.\nAre you still in a meeting?"
        
        let subtitleWithoutButton =
        "Looks like the meeting's over.\nI'll stop listening in "
        
        if hasButton {
            showNotification(
                title: title,
                subtitle: subtitleWithoutButton,
                duration: duration,
                actionButton: ("Cancel", {
                    print("Cancel Clicked from InactiveNoti")
                    let payload = InactiveStatePayload(action: .inactiveCancelled, trigger: .userAction)
                    ShadowNotificationPlugin.sendToFlutter(InactiveAction.inactiveCancelled, data: payload.toDictionary())
                }),
                onTimeout: {
                    print("InactiveNoti timeout")
                    let payload = InactiveStatePayload(action: .inactiveTimeout, trigger: .timeout)
                    ShadowNotificationPlugin.sendToFlutter(InactiveAction.inactiveTimeout, data: payload.toDictionary())
                },
                width: 390,
                height: 110,
                showCountdown: true
            )
            
        } else {
            showNotification(
                title: title,
                subtitle: subtitleWithButton,
                duration: duration,
                width: 390,
                height: 110,
                showCountdown: false
            )
        }
    }
    
    func showNotiWindow(type: NotiType, autoCloseAfter seconds: TimeInterval? = nil, width: CGFloat = 350, height: CGFloat = 75) {
        // 최대 개수 초과 시 오래된 노티 제거
        removeOldestNotificationIfNeeded()
        
        // 새 노티 ID 생성
        let notiId = UUID()
        
        guard let screen = NSScreen.main else { return }
        
        // 새 노티는 맨 위(인덱스 0) 위치에 표시 - 기존 노티들이 한 칸씩 내려갈 것을 고려
        let targetFrame = calculateNotificationFrame(at: 0, width: width, height: height)
        
        print("screen frame for showNotiWindow -- \(screen.visibleFrame)")
        print("x for showNotiWindow -- \(targetFrame.origin.x), y for showNotiWindow -- \(targetFrame.origin.y)")
        
        let customNotiWindow = NSWindow(
            contentRect: targetFrame,
            styleMask: [.borderless, .fullSizeContentView, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        
        configureNotiWindow(customNotiWindow)
        
        let effectiveSeconds = seconds ?? type.duration
        
        // --- ⭐️ 1. 순서 변경: NotiWindowController를 먼저 생성합니다. ⭐️ ---
        let controller = NotiWindowController(
            notificationId: notiId,
            notiWindow: customNotiWindow,
            type: type,
            onClose: { [weak self] (closedId, closedType, wasActionTaken) in
                
                let payload: ListenStatePayload
                
                if !wasActionTaken {
                    print("Window closed without a button click (timeout).")
                    switch closedType {
                    case .enabled:
                        print("Default action for .enabled: Proceeding to listen.")
                        payload = ListenStatePayload(action: .startListen, trigger: .timeout)
                        ShadowNotificationPlugin.sendToFlutter(.startListen, data: payload.toDictionary())
                    case .ask:
                        print("Default action for .ask: Dismissing without action.")
                        payload = ListenStatePayload(action: .dismissListen, trigger: .timeout)
                        ShadowNotificationPlugin.sendToFlutter(.dismissListen, data: payload.toDictionary())
                    }
                }
                self?.handleNotificationClosed(id: closedId)
            }
        )
        notiWindowControllers[notiId] = controller
        
        // 새 노티를 notiOrder에 추가하고 기존 노티들을 아래로 이동
        notiOrder.insert(notiId, at: 0)
        repositionExistingNotifications()
        
        // --- ⭐️ 2. 이제 NotiView를 생성합니다. ⭐️ ---
        // 이 시점에는 controller가 유효한 값을 가지므로,
        // buttonAction 클로저가 올바른 컨트롤러를 캡처할 수 있습니다.
        let contentView = NotiView(
            title: "Meeting Detected",
            baseSubtitle: type.baseSubtitle,
            initialCount: Int(effectiveSeconds) - 1,
            buttonText: type.buttonText,
            buttonAction: { [weak controller] in
                print("\(type.buttonText) Clicked")
                controller?.setActionTaken()
                
                let payload: ListenStatePayload
                
                switch type {
                case .enabled:
                    print("Internal logic: Canceling the pending listen action.")
                    payload = ListenStatePayload(action: .dismissListen, trigger: .userAction)
                    ShadowNotificationPlugin.sendToFlutter(.dismissListen, data: payload.toDictionary())
                case .ask:
                    print("Internal logic: Force starting the listen action.")
                    payload = ListenStatePayload(action: .startListen, trigger: .userAction)
                    ShadowNotificationPlugin.sendToFlutter(.startListen, data: payload.toDictionary())
                }
                controller?.closeWindow()
            }
        )
        
        let hostingView = NSHostingView(rootView: contentView)
        customNotiWindow.contentView = hostingView
        
        controller.setupAutoClose(after: effectiveSeconds - 0.5)
        
        customNotiWindow.makeKeyAndOrderFront(nil)
        customNotiWindow.orderFrontRegardless()
    }
    
    private func configureNotiWindow(_ window: NSWindow) {
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = false
        window.level = .screenSaver
        window.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
        window.ignoresMouseEvents = false
        window.isReleasedWhenClosed = false
        
//        window.sharingType = .none
        
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
    }
    
    
    /// 특정 노티피케이션이 닫혔을 때 호출
    private func handleNotificationClosed(id: UUID) {
        print("Window closed callback received for id: \(id)")
        notiWindowControllers.removeValue(forKey: id)
        notiOrder.removeAll { $0 == id }
        
        // 남은 노티들 위치 재조정
        repositionExistingNotifications()
    }
    
    /// 특정 노티피케이션 삭제
    private func cleanupNotification(id: UUID) {
        print("Cleaning up notification: \(id)")
        
        if let controller = notiWindowControllers[id] {
            controller.closeWindow()
        }
        // handleNotificationClosed가 onClose 콜백에서 호출되므로 여기서는 제거하지 않음
        print("Custom Notification cleanup complete for id: \(id)")
    }
    
    /// 모든 노티피케이션을 제거
    func cleanupAllNotifications() {
        print("Cleaning up all notifications...")
        for (_, controller) in notiWindowControllers {
            controller.closeWindowSilently()
        }
        notiWindowControllers.removeAll()
        notiOrder.removeAll()
        print("All notifications cleanup complete")
    }
}


extension NSWindow: WindowAnimatable {
    
    func showWithAnimation(_ type: WindowAnimationType, to targetFrame: NSRect) {
        switch type {
        case .slideInFromRight:
            // 화면 오른쪽 밖에서 시작
            let startFrame = NSRect(
                x: targetFrame.maxX + 50,  // 오른쪽 밖
                y: targetFrame.origin.y,
                width: targetFrame.width,
                height: targetFrame.height
            )
            animateFrame(from: startFrame, to: targetFrame, duration: type.duration)
            
        case .slideInFromTop:
            // 화면 위에서 시작
            let startFrame = NSRect(
                x: targetFrame.origin.x,
                y: targetFrame.maxY + 50,  // 위쪽 밖
                width: targetFrame.width,
                height: targetFrame.height
            )
            animateFrame(from: startFrame, to: targetFrame, duration: type.duration)
            
        case .fadeIn:
            self.setFrame(targetFrame, display: true)
            self.alphaValue = 0
            self.orderFrontRegardless()
            NSAnimationContext.runAnimationGroup { context in
                context.duration = type.duration
                context.timingFunction = CAMediaTimingFunction(name: .easeOut)
                self.animator().alphaValue = 1
            }
            
        case .none:
            self.setFrame(targetFrame, display: true)
            self.orderFrontRegardless()
        }
    }
    
    func hideWithAnimation(_ type: WindowAnimationType, completion: (() -> Void)? = nil) {
        let currentFrame = self.frame
        
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = type.duration
            context.timingFunction = CAMediaTimingFunction(name: .easeIn)
            
            switch type {
            case .slideInFromRight:
                let endFrame = NSRect(
                    x: currentFrame.maxX + 50,
                    y: currentFrame.origin.y,
                    width: currentFrame.width,
                    height: currentFrame.height
                )
                self.animator().setFrame(endFrame, display: true)
                
            case .slideInFromTop:
                let endFrame = NSRect(
                    x: currentFrame.origin.x,
                    y: currentFrame.maxY + 50,
                    width: currentFrame.width,
                    height: currentFrame.height
                )
                self.animator().setFrame(endFrame, display: true)
                
            case .fadeIn:
                self.animator().alphaValue = 0
                
            case .none:
                break
            }
        }, completionHandler: {
            completion?()
        })
    }
    
    // MARK: - Private Helper
    private func animateFrame(from startFrame: NSRect, to endFrame: NSRect, duration: TimeInterval) {
        self.setFrame(startFrame, display: true)
        self.orderFrontRegardless()
        
        NSAnimationContext.runAnimationGroup { context in
            context.duration = duration
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            self.animator().setFrame(endFrame, display: true)
        }
    }
}
