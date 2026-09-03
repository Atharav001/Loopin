import SwiftUI
import AppKit

/// To-Do list window (V1_IMPROVEMENTS §4): the primary task surface.
struct TodoWindowView: View {
    @EnvironmentObject private var bridge: PanelBridge
    @State private var showingWhatNow = false

    var body: some View {
        VStack(spacing: 0) {
            WindowHeaderView(title: "To-Do List")
            Divider()
            QuickAddView()
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
            if showingWhatNow {
                WhatNowView()
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
            }
            Divider()
            TaskListView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            Divider()
            whatNowFooter
        }
        .frame(minWidth: 320, minHeight: 400)
        .background(AppTheme.background)
        .glow(
            accent: AppTheme.accentViolet,
            intensity: .standard,
            active: bridge.isPinned
        )
    }

    private var whatNowFooter: some View {
        HStack {
            Button {
                showingWhatNow.toggle()
            } label: {
                Label(
                    showingWhatNow ? "Hide What now" : "What now",
                    systemImage: "questionmark.circle"
                )
                .font(.system(size: 12))
            }
            .buttonStyle(.plain)
            .foregroundStyle(AppTheme.textSecondary)
            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
    }
}

#Preview {
    TodoWindowView()
        .environmentObject(PanelBridge())
        .environmentObject(TaskStore())
        .environmentObject(SettingsStore())
        .environmentObject(TimerEngine(session: TimerSession()))
        .environmentObject(TimerSession())
}