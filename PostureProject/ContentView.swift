//
//  ContentView.swift
//  PostureProject
//
//  Created by Noah M on 2/27/25.
//

import SwiftUI

struct NotchView: View {
    @ObservedObject var frameHandler: FrameHandler
    @ObservedObject var bodyLandmarks: BodyLandmarks

    let notchWidth: CGFloat
    let notchHeight: CGFloat
    let expandedWidth: CGFloat
    let expandedHeight: CGFloat

    @State private var isExpanded = false

    // Left-side indicator state machine. Drives the nag flow:
    // idle -> (15s of bad posture) -> message -> red -> (good) -> green -> (1s) -> idle.
    private enum IndicatorState { case idle, message, red, green }
    @State private var indicatorState: IndicatorState = .idle
    @State private var badPostureTask: Task<Void, Never>?
    @State private var greenClearTask: Task<Void, Never>?

    private let badPostureDelay: Duration = .seconds(15)
    private let messageVisibleDuration: Duration = .seconds(2.5)
    private let greenClearDelay: Duration = .seconds(1)

    private let indicatorSlotWidth: CGFloat = 132
    private let indicatorGap: CGFloat = 6

    private var isGoodPosture: Bool { bodyLandmarks.postureEval == 1.0 }
    private var statusColor: Color { isGoodPosture ? .green : .red }

    private var currentWidth: CGFloat { isExpanded ? expandedWidth : notchWidth }
    private var currentHeight: CGFloat { isExpanded ? expandedHeight : notchHeight }
    private var currentBottomRadius: CGFloat { isExpanded ? 24 : 10 }

    private var contentWidth: CGFloat { expandedWidth - 28 }
    private var contentHeight: CGFloat { expandedHeight - notchHeight - 22 }

    var body: some View {
        ZStack(alignment: .top) {
            leftSideIndicator
                .frame(width: indicatorSlotWidth, height: notchHeight, alignment: .trailing)
                .offset(x: -(notchWidth / 2 + indicatorSlotWidth / 2 + indicatorGap))
                .opacity(isExpanded ? 0 : 1)
                .animation(.easeInOut(duration: 0.2), value: isExpanded)

            ZStack(alignment: .top) {
                Color.black

                expandedContent
                    .frame(width: contentWidth, height: contentHeight)
                    .padding(.top, notchHeight + 6)
                    .opacity(isExpanded ? 1 : 0)
            }
            .frame(width: currentWidth, height: currentHeight, alignment: .top)
            .clipShape(NotchShape(bottomCornerRadius: currentBottomRadius))
            .contentShape(NotchShape(bottomCornerRadius: currentBottomRadius))
            .onHover { hovering in
                withAnimation(.interpolatingSpring(mass: 1, stiffness: 160, damping: 13)) {
                    isExpanded = hovering
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .onChange(of: bodyLandmarks.postureEval) { _, newValue in
            handlePostureChange(newValue)
        }
    }

    // MARK: - Indicator view

    @ViewBuilder
    private var leftSideIndicator: some View {
        switch indicatorState {
        case .idle:
            EmptyView()
        case .message:
            messagePill
                .transition(.asymmetric(
                    insertion: .move(edge: .bottom).combined(with: .opacity),
                    removal: .opacity.combined(with: .scale(scale: 0.9))
                ))
        case .red:
            statusLight(color: .red)
                .transition(.scale(scale: 0.4).combined(with: .opacity))
        case .green:
            statusLight(color: .green)
                .transition(.opacity)
        }
    }

    private var messagePill: some View {
        Capsule()
            .fill(Color.red)
            .frame(width: 116, height: 22)
            .overlay(
                Text("Fix posture")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.white)
            )
            .shadow(color: .red.opacity(0.45), radius: 4)
    }

    private func statusLight(color: Color) -> some View {
        Circle()
            .fill(color)
            .frame(width: 10, height: 10)
            .shadow(color: color.opacity(0.8), radius: 4)
    }

    // MARK: - State machine

    private func handlePostureChange(_ value: Double?) {
        guard let value else { return }

        if value == 0.0 {
            switch indicatorState {
            case .idle:
                scheduleBadAlert()
            case .green:
                // User slouched again before the green confirmation cleared.
                greenClearTask?.cancel()
                withAnimation(.easeInOut(duration: 0.2)) {
                    indicatorState = .red
                }
            case .message, .red:
                break
            }
        } else if value == 1.0 {
            badPostureTask?.cancel()
            badPostureTask = nil

            switch indicatorState {
            case .message, .red:
                withAnimation(.easeInOut(duration: 0.25)) {
                    indicatorState = .green
                }
                scheduleGreenClear()
            case .idle, .green:
                break
            }
        }
    }

    private func scheduleBadAlert() {
        badPostureTask?.cancel()
        badPostureTask = Task { [badPostureDelay, messageVisibleDuration] in
            try? await Task.sleep(for: badPostureDelay)
            guard !Task.isCancelled else { return }
            await MainActor.run {
                withAnimation(.spring(response: 0.45, dampingFraction: 0.72)) {
                    indicatorState = .message
                }
            }
            try? await Task.sleep(for: messageVisibleDuration)
            guard !Task.isCancelled else { return }
            await MainActor.run {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                    indicatorState = .red
                }
            }
        }
    }

    private func scheduleGreenClear() {
        greenClearTask?.cancel()
        greenClearTask = Task { [greenClearDelay] in
            try? await Task.sleep(for: greenClearDelay)
            guard !Task.isCancelled else { return }
            await MainActor.run {
                withAnimation(.easeOut(duration: 0.3)) {
                    indicatorState = .idle
                }
            }
        }
    }

    // MARK: - Expanded panel content

    private var expandedContent: some View {
        VStack(spacing: 6) {
            ZStack {
                FrameView(image: frameHandler.frame)
                    .aspectRatio(16 / 9, contentMode: .fit)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                if let landmarks = bodyLandmarks.landmarks {
                    GeometryReader { geo in
                        ForEach(Array(landmarks.enumerated()), id: \.offset) { _, point in
                            Circle()
                                .fill(Color.red)
                                .frame(width: 6, height: 6)
                                .position(
                                    x: (1 - point.x) * geo.size.width,
                                    y: point.y * geo.size.height
                                )
                        }
                    }
                }

                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(statusColor, lineWidth: 2)
            }

            Text(isGoodPosture ? "Good posture" : "Fix your posture")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(statusColor)
        }
    }
}

// Shape with a flat top edge (flush with the physical notch) and rounded
// bottom corners. The bottom radius animates so the shape feels liquid as it
// stretches out of the notch.
private struct NotchShape: Shape {
    var bottomCornerRadius: CGFloat

    var animatableData: CGFloat {
        get { bottomCornerRadius }
        set { bottomCornerRadius = newValue }
    }

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let r = min(bottomCornerRadius, min(rect.width, rect.height) / 2)
        path.move(to: CGPoint(x: 0, y: 0))
        path.addLine(to: CGPoint(x: rect.width, y: 0))
        path.addLine(to: CGPoint(x: rect.width, y: rect.height - r))
        path.addQuadCurve(
            to: CGPoint(x: rect.width - r, y: rect.height),
            control: CGPoint(x: rect.width, y: rect.height)
        )
        path.addLine(to: CGPoint(x: r, y: rect.height))
        path.addQuadCurve(
            to: CGPoint(x: 0, y: rect.height - r),
            control: CGPoint(x: 0, y: rect.height)
        )
        path.closeSubpath()
        return path
    }
}
