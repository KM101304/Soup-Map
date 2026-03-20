import SwiftUI

struct BubbleAnnotationView: View {
    let node: ActivityBubbleNode

    @State private var breathe = false
    @State private var ripple = false

    var body: some View {
        ZStack {
            Circle()
                .fill(node.palette.halo.opacity(0.22))
                .frame(width: node.radius * 2.2, height: node.radius * 2.2)
                .blur(radius: 18)
                .scaleEffect(breathe ? 1.08 : 0.96)
                .opacity(breathe ? 0.85 : 0.58)
                .animation(.easeInOut(duration: 2.2).repeatForever(autoreverses: true), value: breathe)

            if node.isRippling {
                Circle()
                    .stroke(node.palette.fill.opacity(0.55), lineWidth: 2)
                    .frame(width: node.radius * 2.1, height: node.radius * 2.1)
                    .scaleEffect(ripple ? 1.34 : 0.88)
                    .opacity(ripple ? 0 : 0.9)
            }

            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            node.palette.fill.opacity(0.92),
                            node.palette.fill.opacity(0.66),
                            node.palette.halo.opacity(0.68)
                        ],
                        center: .center,
                        startRadius: 4,
                        endRadius: node.radius
                    )
                )
                .frame(width: node.radius * 2, height: node.radius * 2)
                .overlay(
                    Circle()
                        .stroke(Color.white.opacity(node.isJoined ? 0.34 : 0.14), lineWidth: 1)
                )

            VStack(spacing: 4) {
                Text("\(node.participantCount)")
                    .font(.system(size: node.radius > 40 ? 20 : 16, weight: .bold, design: .rounded))
                    .foregroundStyle(node.palette.text)

                Text(subtitle)
                    .font(.system(size: node.radius > 40 ? 11 : 10, weight: .semibold, design: .rounded))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(node.palette.text.opacity(0.86))
                    .lineLimit(2)
                    .padding(.horizontal, 8)
            }
        }
        .frame(width: node.radius * 2.3, height: node.radius * 2.3)
        .shadow(color: node.palette.halo.opacity(0.32), radius: 16, y: 8)
        .animation(.spring(response: 0.42, dampingFraction: 0.82), value: node.radius)
        .onAppear {
            withAnimation(.easeInOut(duration: 2.2).repeatForever(autoreverses: true)) {
                breathe = true
            }
            if node.isRippling {
                ripple = true
            }
        }
        .onChange(of: node.isRippling) { value in
            if value {
                ripple = false
                withAnimation(.easeOut(duration: 0.9)) {
                    ripple = true
                }
            }
        }
    }

    private var subtitle: String {
        switch node.kind {
        case let .activity(activity):
            return activity.category.title
        case let .cluster(activities):
            return "\(activities.count) nearby"
        }
    }
}
