import SwiftUI

struct NotiView: View {
    var title: String
    var baseSubtitle: String
    var initialCount: Int
    var buttonText: String
    var buttonAction: () -> Void
    
    @State private var count: Int
    @State private var timer: Timer?
    
    // 뷰가 초기화될 때 초기 카운트 값을 설정
    init(title: String, baseSubtitle: String, initialCount: Int, buttonText: String, buttonAction: @escaping () -> Void) {
        self.title = title
        self.baseSubtitle = baseSubtitle
        self.initialCount = initialCount
        self.buttonText = buttonText
        self.buttonAction = buttonAction
        self._count = State(initialValue: initialCount)
    }
    
    private var countdownText: Text {
        Text("\(baseSubtitle) ")
            .font(.system(size: 12.5, weight: .light)) +
        Text("\(count)")
            .font(.system(size: 12.5, weight: .regular)) + // 숫자만 강조
        Text("..")
            .font(.system(size: 12.5, weight: .light))
    }
    
    var body: some View {
        HStack(alignment: .center, spacing: 0) {
            if let icon = ShadowNotificationPlugin.shadowIconImage {
                Image(nsImage: icon)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 30, height: 30)
                    .foregroundColor(.orange)
            } else {
                Image(systemName: "questionmark.circle")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 30, height: 30)
                    .foregroundColor(.orange)
            }
            
            // 아이콘과 첫 번째 Divider 사이의 간격을 조절
            Spacer().frame(width: 12)
            
            Rectangle()
                .fill(Color.backgroundSoft) // 시스템 회색
                .frame(width: 1.5, height: 35)
            
//            Divider()
//                .frame(height: 35)
//                .overlay(Color.backgroundHard.opacity(0.1))
            
            // 여기 Spacer의 width를 조정하여 Divider와 VStack 사이의 간격을 조절합니다.
            Spacer().frame(width: 10) // 예시: 5pt
            
            VStack(alignment: .leading, spacing: 8) {
                Text(title)
                    .font(.system(size: 13, weight: .regular))
                    .foregroundColor(Color.text0)
                
                countdownText
                    .monospacedDigit()
                    .foregroundColor(Color.text2)
            }
            
            // 여기 Spacer의 width를 조정하여 VStack과 두 번째 Divider 사이의 간격을 조절합니다.
            Spacer().frame(width: 7) // 예시: 5pt
            
            Rectangle()
                .fill(Color.backgroundSoft) // 시스템 회색
                .frame(width: 1.5, height: 35)
            
//            Divider()
//                .frame(height: 35)
//                .overlay(Color.backgroundHard.opacity(0.1))
            
            // 마지막 Divider와 버튼 사이의 간격을 조절
            Spacer().frame(width: 12)
            
            Button(action: buttonAction) {
                Text(buttonText)
                    .font(.system(size: 13, weight: .regular))
                    .foregroundColor(buttonText == "Cancel" ? .text4 : .brandSecondary)
            }
            .buttonStyle(.plain)
        }
        .padding()
        .background(Color.backgroundHard)
        .clipShape(RoundedRectangle(cornerRadius: 9))
        .overlay(
            RoundedRectangle(cornerRadius: 9)
                .strokeBorder(Color.borderSoft, lineWidth: 1) // strokeBorder 사용
        )
        .onAppear {
            timer?.invalidate()
            timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
                if self.count > 0 {
                    print("Count --> \(count)")
                    self.count -= 1
                } else {
                    self.timer?.invalidate()
                    self.timer = nil
                }
            }
        }
        .onDisappear {
            print("NotiView is disappearing. Invalidating timer.")
            timer?.invalidate()
            timer = nil
        }
    }
}
