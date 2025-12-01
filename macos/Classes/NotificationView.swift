import SwiftUI

struct NotificationView: View {
    // MARK: - Configuration
    struct Config {
        let title: String
        let subtitle: String
        let secondarySubtitle: String?
        let duration: TimeInterval
        let actionButton: ActionButton?
        let showCountdown: Bool

        struct ActionButton {
            let text: String
            let action: () -> Void
        }

        // Convenience initializers
        static func withButton(
            title: String,
            subtitle: String,
            secondarySubtitle: String? = nil,
            duration: TimeInterval,
            buttonText: String,
            buttonAction: @escaping () -> Void,
            showCountdown: Bool = false
        ) -> Config {
            Config(
                title: title,
                subtitle: subtitle,
                secondarySubtitle: secondarySubtitle,
                duration: duration,
                actionButton: .init(text: buttonText, action: buttonAction),
                showCountdown: showCountdown
            )
        }

        static func withoutButton(
            title: String,
            subtitle: String,
            secondarySubtitle: String? = nil,
            duration: TimeInterval,
            showCountdown: Bool = false
        ) -> Config {
            Config(
                title: title,
                subtitle: subtitle,
                secondarySubtitle: secondarySubtitle,
                duration: duration,
                actionButton: nil,
                showCountdown: showCountdown
            )
        }
    }

    // MARK: - Properties
    let config: Config
    let onCancel: () -> Void

    @State private var isHovered: Bool = false
    @State private var progress: CGFloat = 0.0
    @State private var elapsedTime: TimeInterval = 0.0
    @State private var countdown: Int
    @State private var timer: Timer?
    private let refreshRate: TimeInterval = 0.05

    // Custom initializer to set initial countdown
    init(config: Config, onCancel: @escaping () -> Void) {
        self.config = config
        self.onCancel = onCancel
        self._countdown = State(initialValue: Int(config.duration))
    }

    // MARK: - Computed Properties
    private var countdownText: Text {
        Text("\(config.subtitle) ")
            .font(.system(size: 12.5, weight: .light)) +
        Text("\(countdown)")
            .font(.system(size: 12.5, weight: .regular)) +
        Text("..")
            .font(.system(size: 12.5, weight: .light))
    }

    // MARK: - Body
    var body: some View {
        ZStack(alignment: .topLeading) {
            // Main content card
            VStack(spacing: 0) {
                // Top content row
                HStack(alignment: .center, spacing: 0) {
                    Spacer().frame(width: 14)

                    iconView

                    verticalSeparator
                        .padding(.horizontal, 10)

                    // Title & subtitle
                    VStack(alignment: .leading, spacing: 6) {
                        Text(config.title)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(Color.text0)

                        if config.showCountdown {
                            countdownText
                                .monospacedDigit()
                                .foregroundColor(Color.text2)
                        } else {
                            Text(config.subtitle)
                                .font(.system(size: 12.5, weight: .light))
                                .foregroundColor(Color.text2)
                        }
                        
                        if let secondary = config.secondarySubtitle {
                                Text(secondary)
                                    .font(.system(size: 12.5, weight: .bold))
                                    .foregroundColor(Color.text2)
                                    .padding(.top, 2)
                            }
                    }

                    Spacer(minLength: 10)

                    // Optional action button
                    if let button = config.actionButton {
                        verticalSeparator
                            .padding(.trailing, 10)

                        Button(action: button.action) {
                            Text(button.text)
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(Color.brandSecondary)
                        }
                        .buttonStyle(.plain)
                    }

                    Spacer().frame(width: 12)
                }
                .padding(.vertical, 14)

                // Progress bar
                progressBar
            }
            .background(Color.backgroundHard)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(Color.borderSoft, lineWidth: 1)
            )
            .padding(10)

            // Close button (appears on hover)
            if isHovered {
                Button(action: onCancel) {
                    Image(systemName: "xmark")
                        .resizable()
                        .frame(width: 9, height: 9)
                        .foregroundColor(Color.white)
                        .padding(6)
                        .background(
                            Circle()
                                .fill(Color.backgroundSoft)
                        )
                }
                .buttonStyle(.plain)
                .offset(x: 2, y: 2)
                .transition(.opacity)
            }
        }
        .onContinuousHover { phase in
            switch phase {
            case .active:
                isHovered = true
            case .ended:
                isHovered = false
            }
        }
        .onAppear { startProgressTimer() }
        .onDisappear { stopTimer() }
    }

    // MARK: - Subviews
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
            .frame(width: 1.5, height: 32)
    }

    private var progressBar: some View {
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

    // MARK: - Timer Management
    private func startProgressTimer() {
        stopTimer()
        progress = 0.0
        elapsedTime = 0.0
        countdown = Int(config.duration)

        let totalSteps = config.duration / refreshRate
        let progressStep = 1.0 / totalSteps

        timer = Timer.scheduledTimer(withTimeInterval: refreshRate, repeats: true) { _ in
            if progress < 1.0 {
                // Update progress every tick (0.05s) for smooth animation
                progress += progressStep
                elapsedTime += refreshRate

                // Update countdown only when a full second has passed
                if config.showCountdown {
                    let newCountdown = max(0, Int(config.duration - elapsedTime))
                    if newCountdown != countdown {
                        countdown = newCountdown
                    }
                }
            } else {
                progress = 1.0
                stopTimer()
            }
        }
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
}
