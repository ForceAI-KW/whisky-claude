import SwiftUI

struct BotFaceView: View {
    private var displayState: NotchDisplayState { .current }
    @State private var jumpY: CGFloat = 0

    var body: some View {
        Image(systemName: symbolName)
            .resizable()
            .aspectRatio(contentMode: .fit)
            .foregroundStyle(tint)
            .symbolRenderingMode(.hierarchical)
            .clipped()
            // SwiftUI y grows DOWNWARD. We want a positive jumpY to move the
            // mascot UP, so the offset is negative.
            .offset(y: -jumpY)
            .animation(.spring(duration: 0.3), value: displayState)
            .onAppear {
                MascotAnimator.shared.onTick = { y in
                    DispatchQueue.main.async { jumpY = y }
                }
            }
            .onChange(of: displayState) { _, new in
                switch new {
                case .waitingForInput:  MascotAnimator.shared.jump()
                case .taskCompleted:    MascotAnimator.shared.bounce()
                default: break
                }
            }
    }

    private var symbolName: String {
        switch displayState {
        case .idle:              return "sparkle"
        case .working:           return "sparkles"
        case .waitingForInput:   return "exclamationmark.bubble.fill"
        case .taskCompleted:     return "checkmark.seal.fill"
        }
    }

    private var tint: Color {
        switch displayState {
        case .idle:              return Color(red: 1.0, green: 0.47, blue: 0.0)  // #FF7700 Claude orange
        case .working:           return .cyan
        case .waitingForInput:   return .orange
        case .taskCompleted:     return .green
        }
    }
}

#Preview {
    BotFaceView()
        .frame(width: 30, height: 30)
        .padding()
        .background(Color.black)
}
