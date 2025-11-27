import SwiftUI

struct NotiViewNew: View {
    // MARK: - Configuration Structure
    struct Configuration {
        let title: String
        let subtitle: String
        let primaryButtonText: String?
        let duration: TimeInterval
        let type: NotiType
        
        static func from(type: NotiType) -> Configuration {
            return Configuration(
                title: "Meeting Detected",
                subtitle: type.baseSubtitle,
                primaryButtonText: type.buttonText,
                duration: type.duration,
                type: type
            )
        }
    }
    
    let config: Configuration
    let onPrimaryAction: () -> Void
    let onCancel: () -> Void
    
    @State private var progress: CGFloat = 0.0
    @State private var timer: Timer?
    private let refreshRate: TimeInterval = 0.05
    
    var body: some View {
        ZStack(alignment: .topLeading) {
            
            // 1. Main Content Card
            VStack(spacing: 0) {
                // Top Content
                HStack(alignment: .center, spacing: 0) {
                    
                    Spacer().frame(width: 14)
                    
                    iconView
                    
                    verticalSeparator
                        .padding(.horizontal, 10)
                    
                    VStack(alignment: .leading, spacing: 3) {
                        Text(config.title)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(Color.text0)
                        
                        Text(config.subtitle)
                            .font(.system(size: 12.5, weight: .light))
                            .foregroundColor(Color.text2)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    
                    Spacer(minLength: 10)
                    
                    if let btnText = config.primaryButtonText {
                        verticalSeparator
                            .padding(.trailing, 10)
                        
                        Button(action: onPrimaryAction) {
                            Text(btnText)
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(Color.brandSecondary)
                        }
                        .buttonStyle(.plain)
                    }
                    
                    Spacer().frame(width: 12)
                }
                .padding(.vertical, 14)
                
                // REMOVED Spacer(minLength: 0) here!
                
                // 2. Bottom Gauge
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        Rectangle()
                            .fill(Color.backgroundMedium)
                        
                        Rectangle()
                            .fill(Color.text4.opacity(0.5))
                            .frame(width: geometry.size.width * progress)
                            .animation(.linear(duration: refreshRate), value: progress)
                    }
                }
                .frame(height: 6)
            }
            .background(Color.backgroundHard)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(Color.borderSoft, lineWidth: 1)
            )
            .padding(10)
            
            // 3. Close Button
            Button(action: onCancel) {
                Image(systemName: "xmark")
                    .resizable()
                    .frame(width: 9, height: 9)
                    .foregroundColor(Color.white)
                    .padding(6)
                    .background(
                        Circle()
                            .fill(Color.backgroundSoft)  // ✅ Use your design system color
                    )
            }
            .buttonStyle(.plain)
            .offset(x: 2, y: 2)
        }
        .onAppear { startProgressTimer() }
        .onDisappear { stopTimer() }
    }
    
    private var iconView: some View {
        Group {
            if let icon = ShadowNotificationPlugin.shadowIconImage {
                Image(nsImage: icon)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 28, height: 28)
                    .foregroundColor(.orange)
            } else {
                Image(systemName: "waveform.circle.fill")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 28, height: 28)
                    .foregroundColor(.orange)
            }
        }
    }
    
    private var verticalSeparator: some View {
        Rectangle()
            .fill(Color.backgroundSoft)
            .frame(width: 1.5, height: 24)
    }
    
    private func startProgressTimer() {
        stopTimer()
        progress = 0.0
        let totalSteps = config.duration / refreshRate
        let stepAmount = 1.0 / totalSteps
        timer = Timer.scheduledTimer(withTimeInterval: refreshRate, repeats: true) { _ in
            if progress < 1.0 { progress += stepAmount }
            else { progress = 1.0; stopTimer() }
        }
    }
    
    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
}
