import SwiftUI

struct BotFaceView: View {
    // Drives sprite + tint from the global notch state machine.
    private var displayState: NotchDisplayState { .current }

    var body: some View {
        Image(systemName: symbolName)
            .resizable()
            .aspectRatio(contentMode: .fit)
            .foregroundStyle(tint)
            .symbolRenderingMode(.hierarchical)
            .clipped()
            .animation(.spring(duration: 0.3), value: displayState)
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
