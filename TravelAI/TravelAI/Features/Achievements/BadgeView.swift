import SwiftUI

struct BadgeView: View {
    let badge: BadgeDefinition
    let isUnlocked: Bool

    @State private var shineOffset: CGFloat = -80
    @State private var shimmerActive = false
    @State private var pulseScale: CGFloat = 1.0

    private let cardWidth:    CGFloat = 70
    private let cardHeight:   CGFloat = 90
    private let cornerRadius: CGFloat = 28

    var body: some View {
        ZStack {
            // Background
            if isUnlocked { unlockedBackground } else { lockedBackground }
            // Content
            VStack(spacing: 5) {
                symbolView.font(.system(size: 26)).frame(height: 32)
                Text(badge.shortName)
                    .font(.system(size: badge.shortName.count > 2 ? 11 : 15,
                                  weight: .bold,
                                  design: badge.shortName.count <= 2 ? .rounded : .default))
                    .foregroundColor(isUnlocked ? .white : Color.white.opacity(0.35))
                    .lineLimit(1).minimumScaleFactor(0.7)
            }
            .padding(.horizontal, 6)
            // Shine layer (unlocked only)
            if isUnlocked { shineLayer }
            // Lock icon (locked only)
            if !isUnlocked { lockedOverlay }
            // Gold border (unlocked only)
            if isUnlocked {
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(
                        LinearGradient(
                            colors: [Color(hex: "#FFD700").opacity(0.9),
                                     Color(hex: "#FFA500").opacity(0.5),
                                     Color(hex: "#FFD700").opacity(0.9)],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        ), lineWidth: 1.5
                    )
            }
        }
        .frame(width: cardWidth, height: cardHeight)
        .scaleEffect(isUnlocked ? pulseScale : 1.0)
        .onAppear {
            guard isUnlocked else { return }
            withAnimation(.easeInOut(duration: 0.8).delay(Double.random(in: 0...0.6))) {
                shineOffset = 100
                shimmerActive = true
            }
            withAnimation(.easeInOut(duration: 2.2)
                .repeatForever(autoreverses: true)
                .delay(Double.random(in: 0...1.0))) {
                pulseScale = 1.03
            }
        }
    }

    @ViewBuilder private var unlockedBackground: some View {
        RoundedRectangle(cornerRadius: cornerRadius)
            .fill(LinearGradient(colors: [badge.primaryColor, badge.secondaryColor],
                                  startPoint: .topLeading, endPoint: .bottomTrailing))
            .overlay(RoundedRectangle(cornerRadius: cornerRadius)
                .fill(LinearGradient(colors: [Color.white.opacity(0.18), Color.clear],
                                      startPoint: .top, endPoint: .center)))
            .shadow(color: badge.primaryColor.opacity(0.55), radius: 8, x: 0, y: 4)
    }

    @ViewBuilder private var lockedBackground: some View {
        RoundedRectangle(cornerRadius: cornerRadius)
            .fill(Color(hex: "#1A1A1A"))
            .overlay(RoundedRectangle(cornerRadius: cornerRadius)
                .stroke(Color.white.opacity(0.12), lineWidth: 1))
    }

    @ViewBuilder private var symbolView: some View {
        if badge.symbolIsEmoji {
            Text(badge.symbolChar).font(.system(size: 26)).opacity(isUnlocked ? 1.0 : 0.25)
        } else {
            Image(systemName: badge.symbolChar)
                .font(.system(size: 22, weight: .medium))
                .foregroundColor(isUnlocked ? .white : Color.white.opacity(0.2))
        }
    }

    @ViewBuilder private var shineLayer: some View {
        RoundedRectangle(cornerRadius: cornerRadius)
            .fill(LinearGradient(
                colors: [Color.clear, Color.white.opacity(0.25), Color.clear],
                startPoint: .leading, endPoint: .trailing))
            .rotationEffect(.degrees(25))
            .offset(x: shimmerActive ? shineOffset : -80)
            .clipped()
            .allowsHitTesting(false)
    }

    @ViewBuilder private var lockedOverlay: some View {
        VStack {
            Spacer()
            Image(systemName: "lock.fill")
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(Color.white.opacity(0.3))
                .padding(.bottom, 6)
        }
    }
}
