import Cocoa
import SwiftUI
import CoreGraphics

@MainActor
final class NotiWindowController: NSWindowController, NSWindowDelegate {

    let notificationId: UUID
    private let notiType: NotiType
    private var actionTaken: Bool = false

    // 1. private optional property to hold the logger instance
    private var logger: ShadowNotiLogger?

    private var autoCloseTask: Task<Void, Never>?

    // 창이 닫힐 때, UUID, 타입, 액션 수행 여부를 알려주도록 변경
    private var onCloseCallback: ((UUID, NotiType, Bool) -> Void)?

    init(notificationId: UUID = UUID(), notiWindow: NSWindow, type: NotiType, onClose: @escaping (UUID, NotiType, Bool) -> Void) {
        self.notificationId = notificationId
        self.notiType = type
        self.onCloseCallback = onClose
        super.init(window: notiWindow)
        notiWindow.delegate = self
        notiWindow.isReleasedWhenClosed = false

        self.logger = ShadowNotiLogger.shared
        self.logger?.info("NotiWindowController initialized with id: \(notificationId)")
    }
    
    deinit {
        // ⚠️ This log is not guaranteed to execute due to deinit's nature
        // 올바른 해결 방법: 캡처 리스트 사용
        Task { [logger = self.logger] in
            // 이제 클로저는 self.logger가 아닌 캡처된 'logger' 변수를 사용
            // deinit이 끝나도 logger 인스턴스는 유효하므로 안전
            logger?.info("NotiWindowController deinitialized")
        }
        print("🦊 NotiWindowController deinit")
        autoCloseTask?.cancel()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) not implemented")
    }
    
    func setActionTaken() {
        self.actionTaken = true
    }
    
    func setupAutoClose(after seconds: TimeInterval) {
        autoCloseTask?.cancel()
        autoCloseTask = Task {
            do {
                try await Task.sleep(for: .seconds(seconds))
                // 3. Reuse the logger instance
                self.logger?.info("Auto-close task finished.")
                self.closeWindow()
            } catch {
                self.logger?.info("Auto-close task was cancelled.")
            }
        }
    }
    
    func closeWindow() {
        autoCloseTask?.cancel()
        autoCloseTask = nil
        window?.close()
    }

    func closeWindowSilently() {
        autoCloseTask?.cancel()
        autoCloseTask = nil
        onCloseCallback = nil
        window?.close()
    }

    func windowWillClose(_ notification: Notification) {
        // 3. Reuse the logger instance
        logger?.info("Window will close - cleaning up in controller. id: \(notificationId)")

        autoCloseTask?.cancel()
        autoCloseTask = nil
        onCloseCallback?(self.notificationId, self.notiType, self.actionTaken)
        onCloseCallback = nil
        self.window = nil
    }
}

