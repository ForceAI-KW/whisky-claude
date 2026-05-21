import SwiftUI
import AppKit

/// A transparent view that initiates window dragging on mouseDown
/// and triggers a callback on double-click.
/// Place this behind interactive controls so it only catches clicks on empty space.
struct WindowDragArea: NSViewRepresentable {
    var onDoubleClick: (() -> Void)?

    func makeNSView(context: Context) -> DragAreaView {
        let view = DragAreaView()
        view.onDoubleClick = onDoubleClick
        return view
    }

    func updateNSView(_ nsView: DragAreaView, context: Context) {
        nsView.onDoubleClick = onDoubleClick
    }

    class DragAreaView: NSView {
        var onDoubleClick: (() -> Void)?

        override func mouseDown(with event: NSEvent) {
            if event.clickCount == 2 {
                onDoubleClick?()
            } else {
                window?.performDrag(with: event)
            }
        }
    }
}

struct PanelContentView: View {
    @Bindable var sessionStore: SessionStore
    var onClose: () -> Void
    var onToggleExpand: (() -> Void)?

    private var foregroundOpacity: Double {
        sessionStore.isWindowFocused ? 1.0 : 0.6
    }

    /// When expanded + unfocused, make chrome backgrounds semi-transparent
    /// so the user can see through to things like Xcode build status.
    private var chromeBackgroundOpacity: Double {
        (!sessionStore.isWindowFocused && sessionStore.isTerminalExpanded) ? 0.5 : 1.0
    }

    var body: some View {
        VStack(spacing: 0) {
            // Black top border — separate element so it pushes content down
            Rectangle()
                .fill(Color.black)
                .frame(height: 10)

            // Top bar: tabs + controls
            HStack(spacing: 8) {

                ZStack {
                    Button(action: { sessionStore.isPinned.toggle() }) {
                        Image(systemName: sessionStore.isPinned ? "pin.fill" : "pin")
                            .font(.system(size: 12, weight: .medium))
                            .rotationEffect(.degrees(sessionStore.isPinned ? 0 : 45))
                            .frame(width: 28, height: 28)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(.white.opacity(foregroundOpacity))
                    .help(sessionStore.isPinned ? "Unpin panel" : "Pin panel open")
                }
                .padding(.trailing, -4)
                .padding(.leading, -10)

                Rectangle()
                    .foregroundColor(.clear)
                    .frame(height: 12)
                    .overlay(
                        WindowDragArea(onDoubleClick: {
//                        sessionStore.isTerminalExpanded.toggle()
//                        onToggleExpand?()
                        })
                            .frame(height: 200)
                    )


                SessionTabBar(sessionStore: sessionStore)

                Rectangle()
                    .foregroundColor(.clear)
                    .frame(height: 12)
                    .overlay(
                        WindowDragArea(onDoubleClick: {
//                        sessionStore.isTerminalExpanded.toggle()
//                        onToggleExpand?()
                        })
                            .frame(height: 200)
                    )

                ZStack {
                    Button(action: { sessionStore.createQuickSession() }) {
                        Image(systemName: "plus")
                            .font(.system(size: 12, weight: .medium))
                            .frame(width: 28, height: 28)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(.white.opacity(foregroundOpacity))
                    .help("New session")
                }
                .padding(.leading, -4)
                .padding(.trailing, -10)
            }
            .padding(.horizontal, 12)
            .background(Color(nsColor: NSColor(white: 0.14, alpha: 1.0)).opacity(chromeBackgroundOpacity))

            if sessionStore.isTerminalExpanded {
                Divider()

                // Terminal area
                if let session = sessionStore.activeSession {
                    if session.hasStarted {
                        TerminalSessionView(
                            sessionId: session.id,
                            workingDirectory: session.workingDirectory,
                            launchClaude: session.projectPath != nil,
                            generation: session.generation
                        )
                    } else {
                        placeholderView("Click a project tab to start a terminal session")
                            .onTapGesture {
                                sessionStore.startSessionIfNeeded(session.id)
                            }
                    }
                } else if sessionStore.sessions.isEmpty {
                    placeholderView("No sessions open.\nClick + to create a new session.")
                } else {
                    placeholderView("Select a project to begin")
                }
            }
        }
        .clipShape(UnevenRoundedRectangle(topLeadingRadius: 8.5, bottomLeadingRadius: 0, bottomTrailingRadius: 0, topTrailingRadius: 8.5))
        .background(Color(nsColor: NSColor(white: 0.1, alpha: 1.0)).opacity(chromeBackgroundOpacity))
        .clipShape(UnevenRoundedRectangle(topLeadingRadius: 8.5, bottomLeadingRadius: 0, bottomTrailingRadius: 0, topTrailingRadius: 8.5))
        .onAppear {
            if sessionStore.sessions.isEmpty {
                sessionStore.createQuickSession()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.didBecomeKeyNotification)) { notification in
            if notification.object is TerminalPanel {
                sessionStore.isWindowFocused = true
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.didResignKeyNotification)) { notification in
            if notification.object is TerminalPanel {
                sessionStore.isWindowFocused = false
            }
        }
    }

    private func placeholderView(_ message: String) -> some View {
        Color(nsColor: NSColor(white: 0.1, alpha: 1.0))
            .overlay {
                Text(message)
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .opacity(0)
            }
    }
}
